#!/bin/sh
# /adk:ship 4-b·5 검사: merge 명령에 --delete-branch 가 없고, cleanup.md 의 정리 명령이 워크트리에서 시작한 브랜치를 끝까지 지우는지 임시 저장소로 돌려 본다.
A=$(cd "$(dirname "$0")/.." && pwd)
fail=0
ok() { echo "ok   $1"; }
ng() { echo "FAIL $1"; fail=1; }

# TC#43 4-b 의 merge 명령은 --delete-branch 를 붙이지 않는다 → 워크트리의 로컬 브랜치를 지우지 못해 명령이 실패한다
m=$(grep -n 'gh pr merge --squash <번호>' "$A/plugins/adk/skills/ship/SKILL.md")
[ -n "$m" ] || ng "ship 4-b 의 merge 명령을 찾지 못함"
case "$m" in *--delete-branch*) ng "ship 4-b 의 merge 명령에 --delete-branch 가 있음" ;; *) ok "ship 4-b 의 merge 명령에 --delete-branch 없음" ;; esac

# cleanup.md 의 첫 sh 코드블록을 자리표시자만 바꿔 그대로 실행한다
cmds=$(awk '/^  ```sh$/ { on = 1; next } on && /^  ```$/ { exit } on { sub(/^  /, ""); print }' "$A/plugins/adk/skills/ship/cleanup.md")
[ -n "$cmds" ] || ng "cleanup.md 의 sh 코드블록을 찾지 못함"

run() { # 원격 브랜치를 미리 지울지(0/1)
  r=$(mktemp -d)
  git init -q --bare "$r/origin.git"
  git clone -q "$r/origin.git" "$r/main" 2>/dev/null
  (cd "$r/main" && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base && git branch -M main && git push -q -u origin main 2>/dev/null)
  git -C "$r/main" worktree add -q "$r/wt" -b feat/x 2>/dev/null
  (cd "$r/wt" && git commit -q --allow-empty -m work && git push -q origin feat/x 2>/dev/null)
  # merge 를 흉내 낸다: main 에 반영하고, 자동 삭제 저장소면 원격 브랜치를 지운다
  (cd "$r/main" && git merge -q --ff-only origin/feat/x 2>/dev/null; git push -q origin main 2>/dev/null; git reset -q --hard HEAD~1)
  [ "$1" = 1 ] && git -C "$r/main" push -q origin --delete feat/x 2>/dev/null
  script=$(printf '%s\n' "$cmds" | sed "s#<main 클론>#$r/main#g; s#<워크트리>#$r/wt#g; s#<브랜치>#feat/x#g")
  # agent 는 한 줄씩 실행하고 줄마다 종료 코드를 본다 → 줄 하나라도 0 이 아니면 정리 실패로 읽힌다
  rc=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    sh -c "$line" >/dev/null 2>&1 || { rc=$?; break; }
  done <<EOS
$script
EOS
  left=""
  [ -d "$r/wt" ] && left="$left 워크트리"
  git -C "$r/main" show-ref -q --verify refs/heads/feat/x && left="$left 로컬브랜치"
  git -C "$r/main" ls-remote --exit-code --heads origin feat/x >/dev/null 2>&1 && left="$left 원격브랜치"
  [ "$(git -C "$r/main" rev-parse HEAD)" = "$(git -C "$r/main" rev-parse origin/main)" ] || left="$left main미갱신"
  rm -rf "$r"
}
run 0
[ $rc -eq 0 ] && [ -z "$left" ] && ok "원격 브랜치가 남은 저장소: 워크트리·로컬·원격 브랜치 정리, main 갱신" || ng "원격 브랜치가 남은 저장소: rc=$rc 남음:$left"
run 1
[ $rc -eq 0 ] && [ -z "$left" ] && ok "merge 때 원격 브랜치를 자동 삭제하는 저장소: 오류 없이 정리" || ng "자동 삭제 저장소: rc=$rc 남음:$left"

[ $fail -eq 0 ] && echo PASS || exit 1
