#!/bin/sh
# 보안 경계 mutation: 목록의 조건마다 그 줄을 바꾼 사본에서 지정한 테스트가 실패하는지 본다.
# 사용: mutation.sh <저장소 루트> <목록>
# 목록 한 행 = 파일<TAB>바꿀 줄에 든 문자열<TAB>대신 넣을 줄<TAB>실패해야 할 테스트. # 으로 시작하는 줄과 빈 줄은 건너뛴다.
# 바꿀 줄은 정확히 한 줄에만 맞아야 한다 → 코드가 바뀌어 mutation 이 공허해지면 실패로 드러난다.
root=$1; list=$2
[ -d "$root" ] && [ -f "$list" ] || { echo "사용: $0 <저장소 루트> <목록>" >&2; exit 2; }
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
(cd "$root" && git ls-files -co --exclude-standard | tar cf - -T -) | (cd "$w" && tar xf -) || { echo "사본을 만들지 못함" >&2; exit 2; }
# 테스트가 git 저장소를 전제할 수 있다
(cd "$w" && git init -q && git add -A && git -c user.email=m@m -c user.name=m commit -qm base) || exit 2
T=$(printf '\t')
fail=0

rows=$(grep -v '^#' "$list" | grep -v '^[[:space:]]*$')
[ -n "$rows" ] || { echo "목록이 비어 있음" >&2; exit 1; }

# 원본에서 실패하는 테스트는 mutation 을 판정할 수 없다
for t in $(printf '%s\n' "$rows" | awk -F'\t' 'NF == 4 { print $4 }' | sort -u); do
  (cd "$w" && sh "$t" >/dev/null 2>&1) || { echo "FAIL 원본에서 $t 가 실패함 → mutation 판정 불가" >&2; exit 1; }
done

n=0
while IFS= read -r row; do
  n=$((n + 1))
  nf=$(printf '%s\n' "$row" | awk -F'\t' '{ print NF }')
  [ "$nf" -eq 4 ] || { echo "FAIL 행 $n: 칸이 4개가 아님 ($nf)" >&2; fail=1; continue; }
  f=$(printf '%s\n' "$row" | cut -f1); t=$(printf '%s\n' "$row" | cut -f4)
  [ -f "$w/$f" ] || { echo "FAIL 행 $n: $f 없음 → 적용되지 않음" >&2; fail=1; continue; }
  cp "$w/$f" "$w/.adk-orig"
  printf '%s\n' "$row" > "$w/.adk-row"
  awk -v rowf="$w/.adk-row" '
    BEGIN { getline r < rowf; split(r, a, "\t"); find = a[2]; rep = a[3] }
    index($0, find) { hit++; print rep; next }
    { print }
    END { if (hit != 1) { print hit + 0 > "/dev/stderr"; exit 3 } }
  ' "$w/.adk-orig" > "$w/$f" 2>"$w/.adk-hit"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL 행 $n: $f 에서 '$(printf '%s\n' "$row" | cut -f2)' 가 $(cat "$w/.adk-hit")줄에 맞음 → 적용되지 않음 (정확히 한 줄이어야 함)" >&2
    fail=1
  elif (cd "$w" && sh "$t" >/dev/null 2>&1); then
    echo "FAIL 행 $n: $f '$(printf '%s\n' "$row" | cut -f2)' 를 바꿔도 $t 가 통과 → 살아남음" >&2
    fail=1
  else
    echo "killed $n: $f — $t"
  fi
  cat "$w/.adk-orig" > "$w/$f"
  (cd "$w" && git checkout -q -- . && git clean -qfdx -e .adk-orig -e .adk-row -e .adk-hit)
done <<EOF
$rows
EOF
rm -f "$w/.adk-orig" "$w/.adk-row" "$w/.adk-hit"
exit "$fail"
