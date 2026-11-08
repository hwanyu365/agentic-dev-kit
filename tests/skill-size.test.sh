#!/bin/sh
# 스킬 본문 크기와 같은 폴더의 참조 파일 링크를 검사한다.
# 컨텍스트 압축 뒤 Claude Code 는 스킬마다 앞 5,000 토큰만 다시 붙인다 → 넘는 뒷부분은 압축 뒤 절차에서 사라진다.
# 토큰 수는 로컬에서 정확히 잴 수 없어 바이트로 상한을 둔다. 넘으면 특정 상황에서만 쓰는 절차를 같은 폴더의 참조 파일로 옮긴다.
S=$(cd "$(dirname "$0")/.." && pwd)/plugins/add/skills
max=11000
fail=0
for f in "$S"/*/SKILL.md; do
  n=$(wc -c < "$f" | tr -d ' ')
  [ "$n" -le "$max" ] || { echo "FAIL ${f#$S/}: ${n}바이트 > ${max}"; fail=1; }
done
for f in "$S"/*/*.md; do
  d=$(dirname "$f")
  for l in $(grep -o '](\([A-Za-z0-9_-]*\.md\))' "$f" | sed 's/^](//; s/)$//' | sort -u); do
    [ -f "$d/$l" ] || { echo "FAIL ${f#$S/}: 링크 대상 $l 없음"; fail=1; }
  done
done
[ "$fail" = 0 ] && echo PASS
exit "$fail"
