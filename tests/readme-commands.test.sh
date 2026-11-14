#!/bin/sh
# TC#16 README 명령 표의 `/adk:<이름>` 행 집합이 plugins/adk/skills/ 의 스킬 폴더 집합과 같아야 한다.
r=${1:-$(cd "$(dirname "$0")/.." && pwd)}
want=$(for d in "$r"/plugins/adk/skills/*/; do basename "$d"; done | LC_ALL=C sort)
have=$(grep -o '^| `/adk:[a-z0-9-]*' "$r/README.md" | sed 's/^| `\/adk://' | LC_ALL=C sort -u)
fail=0
for n in $want; do printf '%s\n' "$have" | grep -qx "$n" || { echo "FAIL TC#16 README 명령 표에 /adk:$n 행 없음"; fail=1; }; done
for n in $have; do printf '%s\n' "$want" | grep -qx "$n" || { echo "FAIL TC#16 README 명령 표의 /adk:$n 에 해당하는 스킬 폴더 없음"; fail=1; }; done
[ -n "$want" ] || { echo "FAIL TC#16 스킬 폴더를 찾지 못함"; fail=1; }

[ "$fail" = 0 ] && echo PASS

exit "$fail"
