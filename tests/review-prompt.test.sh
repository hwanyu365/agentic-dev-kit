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
# TC#80 리뷰·@claude job 은 권한 모드를 명시한다 → action 기본값(auto mode)이 허용 목록 밖 호출을 검토로 넘기지 않게
mode() { awk '/claude_args: \|/{f=1;next} f&&/^ *[a-z_]+:/{f=0} f' "$1" | grep -o -e '--permission-mode [a-zA-Z]*'; }
for f in plugins/adk/template/.github/workflows/claude-review.yml:default .github/workflows/claude-review.yml:default plugins/adk/template/.github/workflows/claude.yml:acceptEdits .github/workflows/claude.yml:acceptEdits; do
  p=${f%%:*}; want="--permission-mode ${f##*:}"
  [ -f "$r/$p" ] || { echo "FAIL $p 없음"; fail=1; continue; }
  got=$(mode "$r/$p")
  [ "$got" = "$want" ] || { echo "FAIL $p 의 claude_args 권한 모드: '$got' (기대 '$want')"; fail=1; }
done
[ $fail -eq 0 ] && echo PASS || exit 1
