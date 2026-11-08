#!/bin/sh
# 템플릿 .claude/hooks/verify.sh 검사: 검증 명령을 바꿔 끼워 기록·--check 결과를 기대값과 비교한다.
W=$(cd "$(dirname "$0")/.." && pwd)/plugins/add/template
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
cd "$r"; git init -q; git config user.email t@t; git config user.name t
mkdir -p docs .github .claude/hooks src
cp "$W/.github/spec-trace.sh" .github/
fail=0
mk() { awk -v c="$1" '{ if ($0 == "{{VERIFY_CMD}}") print c; else print }' "$W/.claude/hooks/verify.sh" > .claude/hooks/verify.sh; }
v() { sh .claude/hooks/verify.sh >/dev/null 2>&1; echo $?; }
c() { sh .claude/hooks/verify.sh --check >/dev/null 2>&1; echo $?; }
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }

printf '# s\n' > docs/specification.md
mk true
t "index 없는 새 저장소 verify" "$(v)" 0; t "index 없는 새 저장소 check" "$(c)" 0
echo a > a.txt; git add -A; git commit -qm i
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
printf '## 7. t\n| TC | 대상 |\n| --- | --- |\n| `TC#1` | [FR#9] |\n' >> docs/specification.md
mk true; t "스펙 결함" "$(v)" 1; t "스펙 결함 check" "$(c)" 2
[ $fail -eq 0 ] && echo PASS || exit 1
