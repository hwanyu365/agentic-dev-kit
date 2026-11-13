#!/bin/sh
# 템플릿을 고정 값으로 렌더한 저장소가 init 이 약속한 상태(치환 완료·파싱 가능·검증과 커밋 검사 동작)인지 본다.
A=$(cd "$(dirname "$0")/.." && pwd)
fail=0
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }

sh "$A/tests/render.sh" "$r/m" >/dev/null || { echo "FAIL 렌더 실행"; exit 1; }

t "TC#3 렌더 결과에 치환되지 않은 자리표시자가 없음" "$(sh "$A/tests/render.sh" --check-left "$r/m"; echo $?)" 0
mkdir -p "$r/bad" && printf 'a {{VERIFY_CMD}} b\n' > "$r/bad/x.md" && printf 'run: ${{ github.sha }}\n' > "$r/bad/y.yml"
t "TC#3 남은 자리표시자를 찾으면 실패" "$(sh "$A/tests/render.sh" --check-left "$r/bad" >/dev/null 2>&1; echo $?)" 1
rm "$r/bad/x.md"
t "TC#3 GitHub Actions 식은 자리표시자로 보지 않음" "$(sh "$A/tests/render.sh" --check-left "$r/bad" >/dev/null 2>&1; echo $?)" 0

t "TC#3 템플릿 자리표시자 = init 자리표시자 표" "$(sh "$A/tests/render.sh" --check-table "$A/plugins/adk/template" "$A/plugins/adk/skills/init/SKILL.md"; echo $?)" 0
mkdir -p "$r/tpl" && printf '{{PROJECT}} {{NEW_ONE}}\n' > "$r/tpl/a.md" && printf '| `{{PROJECT}}` | x |\n| `{{GONE}}` | y |\n' > "$r/table.md"
o=$(sh "$A/tests/render.sh" --check-table "$r/tpl" "$r/table.md" 2>&1); rc=$?
t "TC#3 표와 템플릿이 어긋나면 실패" "$rc" 1
case "$o" in *NEW_ONE*GONE*|*GONE*NEW_ONE*) ;; *) echo "FAIL TC#3 어긋난 이름을 양쪽 모두 보고하지 않음: $o"; fail=1 ;; esac

t "TC#3 렌더된 YAML·JSON·셸이 파싱됨" "$(sh "$A/tests/render.sh" --check-parse "$r/m"; echo $?)" 0
printf 'a: [\n' > "$r/bad/z.yml"
t "TC#3 파싱되지 않는 YAML 이 있으면 실패" "$(sh "$A/tests/render.sh" --check-parse "$r/bad" >/dev/null 2>&1; echo $?)" 1

# 렌더 저장소의 커밋 검사는 커밋되는 워크트리의 검증 기록으로 판정한다
cd "$r/m" && git init -q && git config user.email t@t && git config user.name t && git add -A && git commit -qm i && git worktree add -q ../wt -b x || { echo "FAIL 렌더 저장소 준비"; exit 1; }
t "TC#4 렌더 저장소 main 에서 verify.sh 통과" "$(sh .claude/hooks/verify.sh >/dev/null 2>&1; echo $?)" 0
t "TC#4 검증 후 hook 경로가 .githooks" "$(git config core.hooksPath)" .githooks
cd "$r/wt" && echo a > a.txt && git add a.txt
t "TC#4 워크트리에서 검증 전 커밋은 막힘" "$(git commit -qm a >/dev/null 2>&1; echo $?)" 1
sh .claude/hooks/verify.sh >/dev/null 2>&1
t "TC#4 워크트리에서 검증 후 커밋은 통과" "$(git commit -qm a >/dev/null 2>&1; echo $?)" 0

[ "$fail" -eq 0 ] && echo "render ok"
exit "$fail"
