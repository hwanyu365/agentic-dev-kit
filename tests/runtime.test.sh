#!/bin/sh
# 런타임 관문의 진입 판정: version 을 올리지 않은 변경은 Claude 없이 통과하고, 올린 변경은 secret 이 없으면 실패한다.
# secret 이 있는 경로(실제 Claude·시험 저장소 실행)는 CI 의 runtime job 이 돌린다.
A=$(cd "$(dirname "$0")/.." && pwd)
fail=0
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }

p=plugins/adk/.claude-plugin/plugin.json
mkdir -p "$r/p/$(dirname "$p")" && cd "$r/p" && git init -q || exit 1
printf '{\n  "name": "adk",\n  "version": "1.2.3"\n}\n' > "$p"
git add -A && git -c user.email=t@t -c user.name=t commit -qm base && git branch -q base || exit 1
g() { (cd "$r/p" && env -u CLAUDE_CODE_OAUTH_TOKEN -u ADK_TEST_TOKEN "$@" sh "$A/tests/runtime.sh" base >"$r/out" 2>&1); echo $?; }

t "TC#5 version 불변이면 secret 없이 통과" "$(g)" 0
grep -q 'version 불변' "$r/out" || { echo "FAIL TC#5 통과 사유를 남기지 않음"; fail=1; }
printf '{\n  "name": "adk",\n  "description": "x"\n,  "version": "1.2.3"\n}\n' > "$p"
t "TC#5 version 외 변경은 version 불변" "$(g)" 0
printf '{\n  "name": "adk",\n  "version": "1.2.4"\n}\n' > "$p"
t "TC#5 version 올림 + secret 없음 → 실패" "$(g)" 1
grep -q 'secret' "$r/out" || { echo "FAIL TC#5 실패 사유에 secret 이 없음"; fail=1; }
t "TC#5 version 올림 + 시험 저장소 토큰만 없음 → 실패" "$(g CLAUDE_CODE_OAUTH_TOKEN=x)" 1
t "TC#5 version 올림 + Claude 토큰만 없음 → 실패" "$(g ADK_TEST_TOKEN=x)" 1
printf '{\n  "name": "adk"\n}\n' > "$p"
t "TC#5 version 을 읽지 못하면 실패" "$(g)" 1
t "TC#5 기준 ref 가 없으면 실패" "$( (cd "$r/p" && sh "$A/tests/runtime.sh" nope >/dev/null 2>&1); echo $?)" 1

[ "$fail" -eq 0 ] && echo "runtime ok"
exit "$fail"
