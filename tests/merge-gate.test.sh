#!/bin/sh
# 템플릿 .claude/hooks/merge-gate.sh 의 merge 명령 해석 검사 (네트워크 없이 --parse 로).
g=$(cd "$(dirname "$0")/.." && pwd)/plugins/adk/template/.claude/hooks/merge-gate.sh
fail=0
t() { # 기대값 JSON
  got=$(printf '%s' "$2" | sh "$g" --parse 2>&1); rc=$?
  if [ "$1" = deny ]; then [ $rc -eq 2 ] || { echo "FAIL(deny 기대) $2 → $got"; fail=1; }
  else [ $rc -eq 0 ] && [ "$got" = "$1" ] || { echo "FAIL($1) $2 → $got"; fail=1; }; fi
}
t '11 abc1234' '{"tool_input":{"command":"gh pr merge 11 --squash --match-head-commit abc1234 --body \"- gh pr merge 직전 hook\n- PR 24 개 중 22 개\""}}'
t '- abc1234' '{"tool_input":{"command":"gh pr merge --squash --delete-branch --subject \"chore: 12 건\" --body \"gh pr merge 24\" --match-head-commit abc1234"}}'
t '8 -' '{"tool_input": {"command": "gh pr merge https://github.com/o/r/pull/8 --squash"}}'
t '12 x' '{"tool_input":{"command":"cd ../wt && gh pr merge 12 --squash --match-head-commit=x && echo \"gh pr merge 99\""}}'
t '12 -' '{"tool_input":{"command":"gh pr merge 12\t--squash"}}'
t '12 -' '{"tool_input":{"command":"gh pr merge 12 --body '"'"'a 99 b'"'"' --squash"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash *"}}'
t deny '{"tool_input":{"command":"gh pr merge feat/GH-9 --squash"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash -R other/repo 12"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash --repo=other/repo 12"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash 12 13"}}'
t '12 abcdef0' '{"tool_input":{"command":"gh pr merge --squash 12 --delete-branch --match-head-commit abcdef0 --subject \\"x\\""}}'
t deny '{"tool_input":{}}'
# 모든 Bash 명령에서 돈다 → merge 가 아닌 명령은 판정 없이 통과한다.
t none '{"tool_input":{"command":"gh pr view 12 --json mergeable"}}'
t none '{"tool_input":{"command":"git merge origin/main"}}'
t none '{"tool_input":{"command":"gh pr comment 12 --body \"gh pr merge 12 할 예정\""}}'
t none '{"tool_input":{"command":"cat > f <<'"'"'EOF'"'"'\ngh pr merge 12\nEOF"}}'
t none '{"tool_input":{"command":"echo \"닫히지 않음"}}'
t '12 x' '{"tool_input":{"command":"H=$(gh pr view 12 -q .x); gh pr merge 12 --squash --match-head-commit x"}}'
t deny '{"tool_input":{"command":"gh -R o/r pr merge --squash 12"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash 12 --body \"닫히지 않음"}}'
# 셸 문법·감싸기를 벗겨 안쪽 gh pr merge 를 찾는다
t '12 -' '{"tool_input":{"command":"if true; then gh pr merge --squash 12; fi"}}'
t '12 -' '{"tool_input":{"command":"env gh pr merge 12 --squash"}}'
t '12 -' '{"tool_input":{"command":"timeout 60 gh pr merge 12 --squash"}}'
# 인자는 찾은 단순 명령의 낱말에서 읽는다 → 주석·따옴표 안의 글자가 대상이 되지 않는다
t '12 -' '{"tool_input":{"command":"# gh pr merge 99 --match-head-commit aaa\ngh pr merge 12 --squash"}}'
t '12 -' '{"tool_input":{"command":"gh pr merge --squash 12 --subject \"x README\" --body y"}}'
t none '{"tool_input":{"command":"echo merge"}}'
t none '{"tool_input":{"command":"npm run merge-reports"}}'
# 허용 목록 밖의 merge, 다른 저장소 지정, 대상이 둘 이상이면 막는다
t deny '{"tool_input":{"command":"sh -c \"gh pr merge --squash 12\""}}'
t deny '{"tool_input":{"command":"$(echo gh) pr merge --squash 12"}}'
t deny '{"tool_input":{"command":"xargs gh pr merge"}}'
t deny '{"tool_input":{"command":"GH_REPO=o/r gh pr merge --squash 12"}}'
t deny '{"tool_input":{"command":"export GH_REPO=o/r; gh pr merge --squash 12"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash 12 && gh pr merge --squash 13"}}'
t none '{"tool_input":{"command":"gh pr view 12 --json merge"}}'
# gh 에서 merge 글자가 보이면 gh pr merge 이거나 조회 하위 명령이어야 한다
t none '{"tool_input":{"command":"gh pr view 12 --json mergeable,mergeStateStatus"}}'
t none '{"tool_input":{"command":"gh pr list --search merged"}}'
t deny '{"tool_input":{"command":"gh api -X PUT repos/o/r/pulls/12/merge"}}'
t deny '{"tool_input":{"command":"gh api graphql -f query='"'"'mutation{mergePullRequest}'"'"'"}}'
t deny '{"tool_input":{"command":"m=merge; gh pr $m 12"}}'
t deny '{"tool_input":{"command":"gh pr $(echo merge) 12"}}'
# ${...} 안의 명령 치환은 해석하지 않으므로 merge 글자가 있으면 막는다
t deny '{"tool_input":{"command":"echo ${X:-$(gh pr merge --squash 12)}"}}'
t none '{"tool_input":{"command":"echo ${HOME}"}}'
# 글자를 쪼갠 merge: gh 의 하위 명령 자리에 확장이 있으면, 해석 실패에 gh 가 보이면 막는다
t deny '{"tool_input":{"command":"m=mer; gh pr ${m}ge 12"}}'
t deny '{"tool_input":{"command":"X=\"pr mer\"ge; gh $X 12"}}'
t deny '{"tool_input":{"command":"echo ${X:-$(gh pr mer\"\"ge 12)}"}}'
# merge 방식은 squash 뿐이다
t deny '{"tool_input":{"command":"gh pr merge 12"}}'
t none '{"tool_input":{"command":"gh pr view $N --json state"}}'
t none '{"tool_input":{"command":"echo ${X:-$(date)}"}}'
# 명령 해석기를 실행하지 못하면 막는다
x=$(mktemp -d) && cp "$g" "$(dirname "$g")/hook-lib.sh" "$x/"
printf '%s' '{"tool_input":{"command":"gh pr merge 12"}}' | sh "$x/merge-gate.sh" --parse >/dev/null 2>&1; rc=$?; rm -rf "$x"
[ $rc -eq 2 ] || { echo "FAIL(deny 기대) 해석기 없음 → $rc"; fail=1; }
# TC#10 허용 목록 밖의 플래그는 막는다 → 브랜치 보호 우회(--admin)·판정과 merge 시점 분리(--auto) 등
for f in --admin --auto --disable-auto -m --merge -r --rebase -sd -- --unknown -x; do
  t deny "{\"tool_input\":{\"command\":\"gh pr merge 12 --squash $f --match-head-commit abc1234\"}}"
done
# TC#11 허용 플래그만 붙인 형태는 통과하고, 값 자리의 낱말은 플래그로 보지 않는다
t '12 abc1234' '{"tool_input":{"command":"gh pr merge 12 -s -d --match-head-commit abc1234"}}'
t '12 abc1234' '{"tool_input":{"command":"gh pr merge 12 --squash --delete-branch --match-head-commit=abc1234 --subject=x --body=y --body-file=f --author-email=a@b"}}'
t '12 abc1234' '{"tool_input":{"command":"gh pr merge 12 --squash -t x -b y -F f -A a@b --match-head-commit abc1234"}}'
t '12 abc1234' '{"tool_input":{"command":"gh pr merge 12 --squash --body \"--admin\" --subject --auto --match-head-commit abc1234"}}'
# TC#12 merge 방식은 squash 뿐이다
t deny '{"tool_input":{"command":"gh pr merge 12 --delete-branch --match-head-commit abc1234"}}'
[ $fail -eq 0 ] && echo PASS || exit 1

# 판정: gh 를 흉내 내는 stub 을 PATH 앞에 둔다. 코멘트 jq 필터는 실제 gh 의 jq 로 돌린다 → gh 인증이 없으면 실패로 끝낸다.
real=$(command -v gh) || { echo "FAIL 판정: gh 없음 → 판정을 검사하지 못함"; exit 1; }
"$real" auth status >/dev/null 2>&1 || { echo "FAIL 판정: gh 미인증 → 판정을 검사하지 못함"; exit 1; }
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
mkdir -p "$r/bin" "$r/repo"
cat > "$r/bin/gh" <<'GH'
#!/bin/sh
case "$1 $2" in
  "pr view") echo "12 abc1234def" ;;
  "pr checks") exit "${FAKE_CHECKS:-0}" ;;
  "api user") echo me ;;
  api\ repos/*) exec "$REAL_GH" api rate_limit --jq "$FAKE_COMMENTS as \$d | \$d | $5" ;;
  *) echo "stub: 모르는 호출 $*" >&2; exit 1 ;;
esac
GH
chmod +x "$r/bin/gh"
(cd "$r/repo" && git init -q)
bot='user:{login:"claude[bot]",type:"Bot"},performed_via_github_app:{slug:"claude"}'
usr='user:{login:"me",type:"User"},performed_via_github_app:null'
oth='user:{login:"evil",type:"User"},performed_via_github_app:null'
ok='"HEAD: abc1234def\n## 개요\n## 🔴 Blocking (merge 전 수정 필수)\n\n없음.\n\n## 🟡 Should Fix\n### [S1] x\n"'
bl='"HEAD: abc1234def\n## 🔴 Blocking (merge 전 수정 필수)\n\n### [B1] 크래시\n"'
old='"HEAD: 0000000000\n## 🔴 Blocking\n\n없음.\n"'
j() { # 기대종료코드 모드(github|local) mh 코멘트들 [checks]
  rm -rf "$r/repo/.github"; [ "$2" = github ] && mkdir -p "$r/repo/.github/workflows" && : > "$r/repo/.github/workflows/claude-review.yml"
  got=$(cd "$r/repo" && printf '{"tool_input":{"command":"gh pr merge --squash 12 --match-head-commit %s"}}' "$3" |
    PATH="$r/bin:$PATH" REAL_GH="$real" FAKE_COMMENTS="[$4]" FAKE_CHECKS="${5:-0}" sh "$g" 2>&1); rc=$?
  [ $rc -eq "$1" ] || { echo "FAIL 판정($1) $2 mh=$3 → $rc $got"; fail=1; }
}
j 0 github abc1234 "{$bot,body:$ok}"
j 2 github abc1234 "{$bot,body:$bl}"
j 0 github abc1234 "{$bot,body:$bl},{$bot,body:$ok}"
j 2 github abc1234 "{$usr,body:$ok}"
j 2 github abc1234 "{$bot,body:$old}"
j 2 github abc9999 "{$bot,body:$ok}"
j 2 github abc12 "{$bot,body:$ok}"
j 2 github abc1234 "{$bot,body:$ok}" 1
j 0 local abc1234 "{$usr,body:$ok}"
j 2 local abc1234 "{$usr,body:$bl},{$oth,body:$ok}"
quoted='"HEAD: abc1234def\n## 개요\n```md\n## 🔴 Blocking (merge 전 수정 필수)\n없음.\n```\n## 🔴 Blocking (merge 전 수정 필수)\n### [B1] 실제 지적\n"'
j 2 github abc1234 "{$bot,body:$quoted}"
nobl='"HEAD: abc1234def\n## 개요\n- x\n"'
j 2 github abc1234 "{$bot,body:$nobl}"
[ $fail -eq 0 ] && echo PASS-판정 || exit 1
