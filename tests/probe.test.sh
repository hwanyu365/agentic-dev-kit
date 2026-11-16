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
qx() { (cd "$r/m" && PYTHONIOENCODING=utf-8 "$py" -P -c "
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
t "TC#15 토큰 없음·두 읽기 거부" "$(J "[$e,$eo,$re,$(o 2 true "$B"),$rs,$(o 3 true "$B")]")" "ADK-PROBE oauth=absent workflow_token=absent read_environ=blocked read_settings=blocked pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#15 토큰 있음" "$(J "[$e,$(o 1 false 'ADK-ENV oauth=absent workflow_token=present')]")" "ADK-PROBE oauth=absent workflow_token=present read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#15 읽기가 성공하면 read" "$(J "[$re,$(o 2 false 'X=1')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=read read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#15 장치·프로세스 파일 규칙으로 막힌 것도 거부" "$(J "[$re,$(o 2 true "Cannot read /proc/self/environ: this path names a device or process file that this tool does not read.")]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=blocked read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#15 다른 이유의 오류는 거부로 보지 않음" "$(J "[$rs,$(o 3 true 'File does not exist')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=error-other pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#15 스크립트를 돌리지 않았으면 not-run" "$(J "[]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"

# TC#77 리뷰 prompt 의 이전 라운드 명령을 그대로 돌리고, 같은 환경에서 대조군 --comments 를 돌린다
t "TC#77 prompt 의 이전 라운드 명령이 들어감" "$(q "import re; c = re.search(r'\`(gh pr view <PR NUMBER> [^\`]*)\`', step(base)['with']['prompt']).group(1).replace('<PR NUMBER>', '\${{ github.event.pull_request.number }}'); print(all(c in step(x)['with']['prompt'] for x in (s, n)))")" True
t "TC#77 대조군 --comments 가 두 변형에 들어감" "$(q "print(all('gh pr view \${{ github.event.pull_request.number }} --comments' in step(x)['with']['prompt'] for x in (s, n)))")" True
cp -R "$r/m" "$r/x" && sed -i.bak 's/gh pr view <PR NUMBER> --json/gh pr view --json/' "$r/x/.github/workflows/claude-review.yml"
t "TC#77 prompt 에서 명령을 찾지 못하면 생성 실패" "$( (cd "$r/x" && "$py" -P "$A/tests/probe.py" . >/dev/null 2>&1); echo $?)" 1
gv=$(u 4 Bash '{"command":"gh pr view 7 --json body,comments"}'); gc=$(u 5 Bash '{"command":"gh pr view 7 --comments"}')
P='GraphQL: Resource not accessible by integration (repository.pullRequest.statusCheckRollup)'
t "TC#77 --json 성공, --comments 권한 오류" "$(J "[$gv,$(o 4 false '{}'),$gc,$(o 5 true "$P")]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=ok pr_comments=perm-error edit=not-attempted outside=not-attempted mode=not-run"
t "TC#77 --json 이 권한 오류면 perm-error" "$(J "[$gv,$(o 4 true "$P")]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=perm-error pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=not-run"
t "TC#77 성공 출력 안의 오류 문구는 권한 오류가 아님" "$(J "[$gc,$(o 5 false "$P")]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=ok edit=not-attempted outside=not-attempted mode=not-run"
t "TC#77 다른 오류는 error-other" "$(J "[$gc,$(o 5 true 'no pull requests found')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=error-other edit=not-attempted outside=not-attempted mode=not-run"

# TC#81 권한 모드는 템플릿 그대로 두고, 허용 목록 밖 명령 하나를 시도하게 한다
t "TC#81 권한 모드는 템플릿과 같음" "$(q "import re; m = lambda d: re.findall(r'--permission-mode \S+', step(d)['with']['claude_args']); print(m(base) != [] and m(s) == m(base) == m(n))")" True
t "TC#81 허용 목록 밖 스크립트가 있고 허용 도구에 없음" "$([ -f "$r/m/probe/outside.sh" ] && echo y)$(q "print(all('outside.sh' not in step(x)['with']['claude_args'] and 'sh probe/outside.sh' in step(x)['with']['prompt'] for x in (s, n)))")" yTrue
ou=$(u 6 Bash '{"command":"sh probe/outside.sh"}')
t "TC#81 실행 표지가 있으면 ran" "$(J "[$ou,$(o 6 false 'ADK-OUTSIDE ran')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=ran mode=not-run"
dn='{"type":"result","permission_denials":[{"tool_name":"Bash","tool_use_id":"6","tool_input":{"command":"sh probe/outside.sh"}}]}'
in='{"type":"system","subtype":"init","permissionMode":"default"}'
t "TC#81 권한 거부 목록에 있으면 denied (문구와 무관)" "$(J "[$in,$ou,$(o 6 true 'This command requires approval'),$dn]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=denied mode=default"
t "TC#81 거부 목록에 없는 오류는 error-other" "$(J "[$ou,$(o 6 true 'This command requires approval')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=error-other mode=not-run"
t "TC#81 세션 권한 모드를 init 메시지에서 읽음" "$(J "[$(printf '%s' "$in" | sed 's/default/auto/')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=not-attempted outside=not-attempted mode=auto"

# TC#85 권한 모드 대조군: 리뷰 변형에서 --permission-mode 만 빠진다
t "TC#85 대조군은 권한 모드만 빠지고 나머지 claude_args 는 scrub 변형과 같음" "$(qx "import re; a = load('.github/workflows/adk-probe-automode.yml'); ca, cs = step(a)['with']['claude_args'], step(s)['with']['claude_args']; print(re.findall(r'--permission-mode', ca) == [], re.sub(r'--permission-mode \\S+\\n', '', cs) == ca, job(a).get('env') == job(s).get('env'), step(a)['with']['prompt'] == step(s)['with']['prompt'])")" "True True True True"

# TC#83 @claude 확인 워크플로: 렌더한 claude.yml 에서 트리거 문구·판정 step·action step id 만 다르다
qm() { (cd "$r/m" && PYTHONIOENCODING=utf-8 "$py" -P -c "
import copy, yaml
def load(p):
    d = yaml.safe_load(open(p, encoding='utf-8'))
    d['on'] = d.pop(True, d.get('on'))
    return d
c = load('.github/workflows/claude.yml'); m = load('.github/workflows/adk-probe-mention.yml')
act = lambda d: [x for x in d['jobs']['claude']['steps'] if 'claude-code-action' in (x.get('uses') or '')][0]
$1
"); }
t "TC#83 @claude 확인 워크플로가 있음" "$([ -f "$w/adk-probe-mention.yml" ] && echo y)" y
t "TC#83 트리거 이벤트·job 권한·env·timeout 이 claude.yml 과 같음" "$(qm "jc, jm = c['jobs']['claude'], m['jobs']['claude']; print(m['on'] == c['on'], all(jc.get(k) == jm.get(k) for k in ('permissions', 'env', 'timeout-minutes', 'runs-on')))")" "True True"
t "TC#83 실행 조건은 트리거 문구만 바뀜" "$(qm "print(m['jobs']['claude']['if'] == c['jobs']['claude']['if'].replace('@claude', '@adk-probe'), '@claude' in m['jobs']['claude']['if'])")" "True False"
t "TC#83 action 입력은 trigger_phrase 만 더해짐" "$(qm "w = dict(act(m)['with']); tp = w.pop('trigger_phrase', None); print(tp, w == act(c)['with'])")" "@adk-probe True"
t "TC#83 action 앞 step 은 같고 action 에 id 가 붙고 판정 step 이 뒤에 있음" "$(qm "sc, sm = c['jobs']['claude']['steps'], m['jobs']['claude']['steps']; i = sc.index(act(c)); print(sm[:i] == sc[:i], act(m).get('id'), 'judge.py' in (sm[-1].get('run') or ''), len(sm) == i + 2)")" "True claude True True"
ed=$(u 7 Bash '{"command":"sed -i s/x/y/ probe/notes.md"}')
t "TC#83 작업 트리 수정이 실행되면 ran" "$(J "[$ed,$(o 7 false '')]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=ran outside=not-attempted mode=not-run"
t "TC#83 작업 트리 수정이 거부 목록에 있으면 denied" "$(J "[$ed,$(o 7 true 'This command requires approval'),{\"type\":\"result\",\"permission_denials\":[{\"tool_use_id\":\"7\"}]}]")" "ADK-PROBE oauth=not-run workflow_token=not-run read_environ=not-attempted read_settings=not-attempted pr_view=not-attempted pr_comments=not-attempted edit=denied outside=not-attempted mode=not-run"

[ "$fail" -eq 0 ] && echo "probe ok"
exit "$fail"
