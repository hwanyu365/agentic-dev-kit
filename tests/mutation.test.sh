#!/bin/sh
# mutation 실행기 자체 검사: 잡힌 mutation 만 통과시키고, 적용되지 않거나 살아남은 mutation 은 실패시키는지 본다.
A=$(cd "$(dirname "$0")/.." && pwd)
fail=0
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }
T=$(printf '\t')

mkdir -p "$r/p/src" "$r/p/tests"
cat > "$r/p/src/gate.sh" <<'EOF'
[ "$1" = ok ] || exit 2
echo pass
EOF
cat > "$r/p/tests/gate.test.sh" <<'EOF'
d=$(cd "$(dirname "$0")/.." && pwd)
sh "$d/src/gate.sh" no >/dev/null 2>&1 && exit 1
exit 0
EOF
printf 'echo weak\n' > "$r/p/tests/weak.test.sh"
cd "$r/p" && git init -q && git add -A && git -c user.email=t@t -c user.name=t commit -qm i || { echo "FAIL 준비"; exit 1; }
cd "$A" || exit 1

m() { printf '%s\n' "$1" > "$r/list"; sh "$A/tests/mutation.sh" "$r/p" "$r/list" >"$r/out" 2>&1; echo $?; }

t "TC#2 테스트가 잡는 mutation 은 통과" "$(m "src/gate.sh${T}[ \"\$1\" = ok ] || exit 2${T}:${T}tests/gate.test.sh")" 0
t "TC#2 테스트가 잡지 못하는 mutation 은 실패" "$(m "src/gate.sh${T}[ \"\$1\" = ok ] || exit 2${T}:${T}tests/weak.test.sh")" 1
grep -q '살아남음' "$r/out" || { echo "FAIL TC#2 살아남은 mutation 을 보고하지 않음"; fail=1; }
t "TC#2 대상 줄이 없으면 실패" "$(m "src/gate.sh${T}[ \"\$1\" = gone ] || exit 2${T}:${T}tests/gate.test.sh")" 1
grep -q '적용되지 않음' "$r/out" || { echo "FAIL TC#2 적용되지 않은 mutation 을 보고하지 않음"; fail=1; }
printf '[ "$1" = ok ] || exit 2\n' >> "$r/p/src/gate.sh"
t "TC#2 대상 줄이 둘 이상이면 실패" "$(m "src/gate.sh${T}[ \"\$1\" = ok ] || exit 2${T}:${T}tests/gate.test.sh")" 1
git -C "$r/p" checkout -q -- src/gate.sh
t "TC#2 원본 테스트가 실패하면 mutation 판정 전에 실패" "$(printf 'exit 1\n' > "$r/p/tests/gate.test.sh"; m "src/gate.sh${T}[ \"\$1\" = ok ] || exit 2${T}:${T}tests/gate.test.sh")" 1
git -C "$r/p" checkout -q -- tests/gate.test.sh
t "TC#2 행 형식이 틀리면 실패" "$(m "src/gate.sh${T}only-two")" 1
t "TC#2 원본 저장소는 바뀌지 않음" "$(git -C "$r/p" status --porcelain | wc -l | tr -d ' ')" 0
# 저장소 목록 전체(tests/mutations.tsv)는 행마다 테스트를 다시 돌려 오래 걸린다 → test.yml 의 mutation job 이 돈다

[ "$fail" -eq 0 ] && echo "mutation ok"
exit "$fail"
