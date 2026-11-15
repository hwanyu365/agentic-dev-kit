#!/bin/sh
# 리뷰 job 이 따르는 지시의 gh pr view 는 --json 으로 필드를 정해야 job 권한으로 동작한다.
r=$(cd "$(dirname "$0")/.." && pwd)
fail=0
# TC#75 리뷰 지시의 gh pr view 마다 --json 이 있다
for f in plugins/adk/template/.github/workflows/claude-review.yml .github/workflows/claude-review.yml plugins/adk/skills/ship/review.md; do
  [ -f "$r/$f" ] || { echo "FAIL $f 없음"; fail=1; continue; }
  grep -q '`gh pr view' "$r/$f" || { echo "FAIL $f 에 이전 라운드 gh pr view 없음"; fail=1; }
  bad=$(grep -o '`gh pr view [^`]*`' "$r/$f" | grep -v -e '--json')
  [ -z "$bad" ] || { echo "FAIL $f: --json 없는 gh pr view"; printf '%s\n' "$bad"; fail=1; }
done
[ $fail -eq 0 ] && echo PASS || exit 1
