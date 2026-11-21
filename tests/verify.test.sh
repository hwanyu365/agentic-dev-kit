#!/bin/sh
# 템플릿 .claude/hooks/verify.sh 검사: 검증 명령을 바꿔 끼워 기록·--check 결과를 기대값과 비교한다.
W=$(cd "$(dirname "$0")/.." && pwd)/plugins/adk/template
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
cd "$r"; git init -q; git config user.email t@t; git config user.name t
mkdir -p docs .github .claude/hooks src
cp "$W/.github/spec-trace.sh" .github/
mkdir -p .githooks; cp "$W/.githooks/pre-commit" .githooks/; cp "$W/.claude/hooks/hooks-path.sh" .claude/hooks/
fail=0
# macOS awk 는 -v 값의 줄바꿈을 거부한다 → 여러 줄 검증 명령은 환경 변수로 넘긴다
mk() { C="$1" awk '{ if ($0 == "{{VERIFY_CMD}}") print ENVIRON["C"]; else print }' "$W/.claude/hooks/verify.sh" > .claude/hooks/verify.sh; }
v() { sh .claude/hooks/verify.sh >/dev/null 2>&1; echo $?; }
c() { sh .claude/hooks/verify.sh --check >/dev/null 2>&1; echo $?; }
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }

printf '# s\n' > docs/specification.md
mk true
t "index 없는 새 저장소 verify" "$(v)" 0; t "index 없는 새 저장소 check" "$(c)" 0
echo a > a.txt; git add -A; git -c core.hooksPath=/dev/null commit -qm i || { echo "FAIL 준비 커밋"; exit 1; }
mk true
t "통과" "$(v)" 0; t "통과 check" "$(c)" 0
git add a.txt; t "stage 만 바꿈" "$(c)" 0
echo b >> a.txt; t "파일 수정" "$(c)" 2
v >/dev/null; echo n > new.txt; t "새 미추적 파일" "$(c)" 2
mk 'false && true'; t "false && true" "$(v)" 1; t "false && true check" "$(c)" 2
mk 'false
true'; t "여러 줄 앞줄 실패" "$(v)" 1
mk 'echo x | grep -q x && test -f a.txt'; t "파이프 + && 통과" "$(v)" 0
mk 'cd src && true'; t "검증 명령 안의 cd" "$(v)" 0; t "검증 명령 안의 cd check" "$(c)" 0
printf '## 7. t\n| TC | 대상 |\n| --- | --- |\n| `TC''#1` | [FR#9] |\n' >> docs/specification.md
mk true; t "스펙 결함" "$(v)" 1; t "스펙 결함 check" "$(c)" 2

# 검증 명령 실행 여부는 저장소 밖 기록 파일로 본다 → 기록 파일이 작업 트리 변경으로 세지지 않는다
RAN_LOG=$(mktemp); export RAN_LOG; trap 'rm -rf "$r" "$r.wt" "$r.skip" "$r.spec" "$RAN_LOG"' EXIT
ran() { if [ -s "$RAN_LOG" ]; then echo yes; else echo no; fi; : > "$RAN_LOG"; }
full=$(git rev-parse --path-format=absolute --git-path add-verified-full)
printf '# s\n' > docs/specification.md
printf 'docs/\n\n# 주석\nnotes/\n' > .github/verify-skip-paths
mkdir -p notes
mk 'echo run >> "$RAN_LOG"; test -z "$FAILCMD"'
v >/dev/null; ran >/dev/null
echo d > docs/x.md
b=$(cat "$full"); o=$(sh .claude/hooks/verify.sh 2>&1); rc=$?
t "TC#103 범위 안 미추적 파일만 바뀜 → 종료 코드" "$rc" 0; t "TC#103 범위 안 → 검증 명령 미실행" "$(ran)" no; t "TC#103 범위 안 → check 통과" "$(c)" 0
case "$o" in *건너뜀*"$b"*docs/x.md*) ;; *) echo "FAIL TC#103 건너뛴 사실·기준 트리·바뀐 파일을 출력하지 않음: $o"; fail=1 ;; esac
cp docs/specification.md "$r.spec"; printf '## 7. t
| TC | 대상 |
| --- | --- |
| `TC''#1` | [FR#9] |
' >> docs/specification.md
t "TC#103 범위 안 변경이어도 추적성 검사가 먼저 실패" "$(v)" 1; t "TC#103 추적성 검사 실패 → 검증 명령 미실행" "$(ran)" no
cp "$r.spec" docs/specification.md
echo n > notes/y.txt; v >/dev/null
t "TC#103 빈 줄·# 줄 뒤의 pathspec 도 범위" "$(ran)" no
rm docs/x.md notes/y.txt; v >/dev/null
t "TC#106 건너뛴 변경을 되돌려 마지막 전체 통과 트리와 같아짐 → 실행" "$(ran)" yes
echo s > src/s.txt; v >/dev/null; ran >/dev/null

echo b >> a.txt; t "TC#104 범위 밖 변경 → 검증 명령의 종료 코드를 따름" "$(FAILCMD=1 v)" 1; ran >/dev/null; v >/dev/null
t "TC#104 범위 밖 파일 변경 → 실행" "$(ran)" yes
v >/dev/null; ran >/dev/null; echo h > '# 주석'; v >/dev/null
t "TC#104 범위 파일의 # 줄과 같은 이름의 파일은 범위 밖 → 실행" "$(ran)" yes
v >/dev/null
t "TC#104 변경 0건 → 실행" "$(ran)" yes
echo .github/ >> .github/verify-skip-paths; v >/dev/null
t "TC#104 범위 안에 있는 범위 파일 변경 → 실행" "$(ran)" yes
echo .claude/ >> .github/verify-skip-paths; v >/dev/null; ran >/dev/null
echo '# x' >> .claude/hooks/verify.sh; v >/dev/null
t "TC#104 범위 안에 있는 verify.sh 변경 → 실행" "$(ran)" yes
echo 0000000000000000000000000000000000000000 > "$full"; echo d2 > docs/z.md; v >/dev/null
t "TC#104 전체 통과 기록 손상 → 실행" "$(ran)" yes
mv .github/verify-skip-paths "$r.skip"; v >/dev/null; ran >/dev/null; echo d3 > docs/w.md; v >/dev/null
t "TC#104 범위 파일 없음 → 실행" "$(ran)" yes
printf '\n# 주석\n' > .github/verify-skip-paths; v >/dev/null; ran >/dev/null; echo d4 >> docs/w.md; v >/dev/null
t "TC#104 범위 파일에 유효 줄 없음 → 실행" "$(ran)" yes
mv "$r.skip" .github/verify-skip-paths; echo m > src/m.txt; v >/dev/null; ran >/dev/null
mv src/m.txt docs/m.txt; v >/dev/null
t "TC#105 범위 밖에서 범위 안으로 옮긴 파일 → 실행" "$(ran)" yes

printf 'docs/ \r\n  \r\nnotes/\r\n' > .github/verify-skip-paths; v >/dev/null; ran >/dev/null
echo t > docs/t.md; echo u > notes/u.txt; v >/dev/null
t "TC#110 CRLF·줄 끝 공백이 붙은 범위 파일도 범위로 읽음" "$(ran)" no

git add -A; git -c core.hooksPath=/dev/null commit -qm s || { echo "FAIL 워크트리 준비 커밋"; exit 1; }
git worktree add -q "$r.wt" -b w
(cd "$r.wt" && echo d5 > docs/v.md && sh .claude/hooks/verify.sh >/dev/null 2>&1)
t "TC#104 전체 통과 기록이 없는 새 워크트리 → 실행" "$(ran)" yes
[ $fail -eq 0 ] && echo PASS || exit 1
