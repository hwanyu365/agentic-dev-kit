#!/bin/sh
# 런타임 관문의 격리 확인용 워크플로 생성 검사: 렌더한 리뷰 워크플로와 같은 격리 설정에서 프롬프트·허용 도구만 바뀌는지 본다.
A=$(cd "$(dirname "$0")/.." && pwd)
fail=0
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }
py=$(command -v python3 || command -v python) || { echo "FAIL python 없음"; exit 1; }

sh "$A/tests/render.sh" "$r/m" >/dev/null || { echo "FAIL 렌더"; exit 1; }
(cd "$r/m" && "$py" -P "$A/tests/probe.py" .) || { echo "FAIL 생성"; exit 1; }
w=$r/m/.github/workflows

q() { (cd "$r/m" && PYTHONIOENCODING=utf-8 "$py" -P -c "
import sys, yaml
def load(p):
    d = yaml.safe_load(open(p, encoding='utf-8'))
    d['on'] = d.pop(True, d.get('on'))
    return d
base = load('.github/workflows/claude-review.yml'); s = load('.github/workflows/adk-probe.yml'); n = load('.github/workflows/adk-probe-noscrub.yml')
job = lambda d: d['jobs']['review']
step = lambda d: [x for x in job(d)['steps'] if x.get('id') == 'claude'][0]
$1
"); }

t "TC#14 생성한 두 워크플로가 있음" "$([ -f "$w/adk-probe.yml" ] && [ -f "$w/adk-probe-noscrub.yml" ] && echo y)" y
t "TC#14 PR 을 열 때만 돈다" "$(q "print(s['on'] == {'pull_request': {'types': ['opened']}}, n['on'] == s['on'])")" "True True"
t "TC#14 scrub 변형은 템플릿의 job env 를 그대로 둠" "$(q "print(job(s).get('env') == job(base).get('env'), job(base)['env'].get('CLAUDE_CODE_SUBPROCESS_ENV_SCRUB'))")" "True 1"
t "TC#14 대조군은 scrub 만 빠짐" "$(q "e = dict(job(base)['env']); e.pop('CLAUDE_CODE_SUBPROCESS_ENV_SCRUB'); print('CLAUDE_CODE_SUBPROCESS_ENV_SCRUB' in (job(n).get('env') or {}), (job(n).get('env') or {}) == e)")" "False True"
t "TC#14 action 의 격리 설정(settings)은 템플릿과 같음" "$(q "print(step(s)['with']['settings'] == step(base)['with']['settings'] == step(n)['with']['settings'])")" True
t "TC#14 action 앞 step(격리 도구 설치 등)은 템플릿과 같음" "$(q "i = [x.get('id') for x in job(base)['steps']].index('claude'); print(job(s)['steps'][:i] == job(base)['steps'][:i] == job(n)['steps'][:i])")" True
t "TC#14 허용 도구는 템플릿 목록 + probe 스크립트" "$(q "print('Bash(sh probe/env.sh)' in step(s)['with']['claude_args'], step(base)['with']['claude_args'].split('--allowedTools')[1].strip().strip(chr(34)).split(chr(34))[0] in step(s)['with']['claude_args'])")" "True True"
t "TC#14 요약 확인 step 이 없고 판정 step 이 있음" "$(q "print(any('리뷰 요약이 없음' in (x.get('run') or '') for x in job(s)['steps']), any('ADK-PROBE' in (x.get('run') or '') for x in job(s)['steps']))")" "False True"
t "TC#14 probe 스크립트가 값을 출력하지 않음" "$(grep -c 'echo.*\$CLAUDE_CODE_OAUTH_TOKEN' "$r/m/probe/env.sh")" 0
t "TC#14 진단 줄은 변수 이름만 냄" "$(SECRETX=val-123 sh "$r/m/probe/env.sh" | grep -c val-123)" 0
t "TC#14 probe 스크립트: 토큰 없음/있음 판정" "$({ env -u CLAUDE_CODE_OAUTH_TOKEN -u DEFAULT_WORKFLOW_TOKEN sh "$r/m/probe/env.sh"; CLAUDE_CODE_OAUTH_TOKEN=x DEFAULT_WORKFLOW_TOKEN= sh "$r/m/probe/env.sh"; DEFAULT_WORKFLOW_TOKEN=y sh "$r/m/probe/env.sh"; } | grep "^ADK-ENV")" "ADK-ENV oauth=absent workflow_token=absent
ADK-ENV oauth=present workflow_token=absent
ADK-ENV oauth=absent workflow_token=present"
t "TC#14 생성 결과가 렌더 검사를 통과" "$(sh "$A/tests/render.sh" --check-parse "$r/m" >/dev/null 2>&1; echo $?)" 0

# TC#15 판정: 실행 기록에서 토큰 유무와 읽기 거부를 뽑고, 시도하지 않은 읽기·다른 이유의 오류는 거부로 보지 않는다
J() { printf '%s' "$1" > "$r/exec.json"; (cd "$r" && PYTHONIOENCODING=utf-8 "$py" -P m/probe/judge.py exec.json) | grep "^ADK-PROBE"; }
u() { printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"%s","input":%s}]}}' "$1" "$2" "$3"; }
o() { printf '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"%s","is_error":%s,"content":"%s"}]}}' "$1" "$2" "$3"; }
B='blocked by the blockReadsOutsideWorkingDirectories setting'
e=$(u 1 Bash '{"command":"sh probe/env.sh"}'); eo=$(o 1 false 'ADK-ENV oauth=absent workflow_token=absent')
re=$(u 2 Read '{"file_path":"/proc/self/environ"}'); rs=$(u 3 Read '{"file_path":"/home/runner/.claude/settings.json"}')
t "TC#15 토큰 없음·두 읽기 거부" "$(J "[$e,$eo,$re,$(o 2 true "$B"),$rs,$(o 3 true "$B")]")" "ADK-PROBE oauth=absent workflow_token=absent read_environ=blocked read_settings=blocked"
t "TC#15 토큰 있음" "$(J "[$e,$(o 1 false 'ADK-ENV oauth=absent workflow_token=present')]")" "ADK-PROBE oauth=absent workflow_token=present read_environ=not-attempted read_settings=not-attempted"
t "TC#15 읽기가 성공하면 read" "$(J "[$re,$(o 2 false 'X=1')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=read read_settings=not-attempted"
t "TC#15 장치·프로세스 파일 규칙으로 막힌 것도 거부" "$(J "[$re,$(o 2 true "Cannot read /proc/self/environ: this path names a device or process file that this tool does not read.")]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=blocked read_settings=not-attempted"
t "TC#15 다른 이유의 오류는 거부로 보지 않음" "$(J "[$rs,$(o 3 true 'File does not exist')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=error-other"
t "TC#15 스크립트를 돌리지 않았으면 not-run" "$(J "[]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted"

[ "$fail" -eq 0 ] && echo "probe ok"
exit "$fail"
