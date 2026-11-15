#!/bin/sh
# 템플릿 .claude/hooks/commit-gate.sh 의 git commit 옵션 해석 검사.
g=$(cd "$(dirname "$0")/.." && pwd)/plugins/adk/template/.claude/hooks/commit-gate.sh
fail=0
t() { # 기대종료코드 명령(JSON 문자열 안에 그대로 들어간다)
  got=$(printf '{"tool_input":{"command":"%s"}}' "$2" | sh "$g" 2>&1); rc=$?
  [ $rc -eq "$1" ] || { echo "FAIL($1) $2 → $rc $got"; fail=1; }
}
# TC#31 pre-commit 을 끄는 옵션은 묶음·약어도 막는다
t 2 'git commit -anm x'
t 2 'git commit -nam x'
t 2 'git commit -a -n -m x'
t 2 'git commit -n'
t 2 'git commit --no-verify -m x'
t 2 'git commit --no-veri -m x'
t 2 'git commit --amend -n'
t 2 'git add -A && git commit -anm x'
t 2 'git commit -mx -n'
t 2 'git commit -S -n -m x'
# TC#32 값 자리의 글자와 경로는 옵션으로 보지 않는다
t 0 'git commit -m \"-n\"'
t 0 'git commit -amn'
t 0 'git commit -m nothing'
t 0 'git commit --message -n'
t 0 'git commit -F msg.txt -- -n'
t 0 'git commit -am x'
t 0 'git commit -C HEAD --amend'
t 0 'git status -n'
t 0 'echo git commit -n'
# TC#33 값 여부를 모르는 긴 옵션은 다음 낱말을 건너뛰지 않는다
t 2 'git commit --foo x -n'
t 2 'git commit --mess x -n'
# TC#34 전역 옵션과 감싸기를 벗기고 하위 명령을 찾는다
t 2 'git -C d commit -an'
t 2 'env git commit -an'
t 2 'git -c user.name=x commit -an'
t 2 'git --git-dir .git commit -an'
t 0 'git -C commit status -n'
t 0 'git -c user.name=x commit -m x'
# TC#35 hook 경로·alias 설정은 하위 명령과 관계없이 막는다
t 2 'git -c core.HooksPath=x commit -m x'
t 2 'git --config-env=core.hookspath=E commit -m x'
t 2 'git --config-env core.HOOKSPATH=E commit -m x'
t 2 'git -c alias.ci=\"commit -n\" ci -m x'
t 2 'git -c Alias.x=y status'
t 2 'git -ccore.hooksPath=x commit -m x'
t 2 'git -c include.path=f commit -m x'
t 2 'git config core.HooksPath x && git commit -m x'
t 2 'git config set core.hooksPath x'
t 2 'git config --add alias.ci \"commit -n\"'
t 2 'git config --local IncludeIf.gitdir:x.path f'
t 0 'git config user.name x'
# 조회·해제와 값 자리의 글자도 막는다 → 인자 위치를 해석하지 않는 쪽(막는 쪽)으로 둔다
t 2 'git config --get core.hooksPath'
t 2 'git config --unset alias.x'
t 2 'git config user.name alias.foo'
# TC#61 목록에 없는 전역 옵션 뒤에 commit·config 가 있으면 막는다
t 2 'git --attr-source HEAD commit -n'
t 2 'git --attr-source=HEAD commit -n'
t 2 'git --super-prefix x/ commit -n'
t 2 'git --unknown x config core.hooksPath y'
t 2 'git --unknown x -c core.hooksPath=y status'
t 2 'git --unk -C commit -n'
# TC#62 알려진 전역 옵션과 commit·config 가 없는 명령은 통과한다
t 0 'git --no-pager log -n 3'
t 0 'git --attr-source HEAD commit -m x'
t 0 'git --unknown status'
t 0 'git --literal-pathspecs commit -m x'
t 0 'git -v --version -h --help --exec-path --html-path --man-path --info-path -p --paginate -P --no-pager --bare --no-replace-objects --no-lazy-fetch --no-optional-locks --no-advice --literal-pathspecs --glob-pathspecs --noglob-pathspecs --icase-pathspecs --namespace=x --attr-source=x --exec-path=x --list-cmds=x -C d -c user.name=x --config-env user.email=E --namespace x --attr-source x commit -m x'
# TC#63 commit 이 저장소 위치를 바꾸는 옵션·환경변수를 쓰면 값과 무관하게 막는다
t 2 'git --git-dir=../B/.git --work-tree=. commit -m x'
t 2 'git --git-dir .git commit -m x'
t 2 'git --work-tree . commit -m x'
t 2 'GIT_DIR=../B/.git git commit -m x'
t 2 'env git_work_tree=. git commit -m x'
t 2 'GIT_COMMON_DIR=x git commit -m x'
t 0 'git --git-dir .git log'
t 0 'GIT_DIR=.git git status'
# TC#64 GIT_CONFIG 환경변수와 help.autocorrect 는 하위 명령과 무관하게 막는다
t 2 'GIT_CONFIG_PARAMETERS=x git commit -m x'
t 2 'GIT_CONFIG_COUNT=1 git ci'
t 2 'git_config_global=f git status'
t 2 'env GIT_CONFIG_KEY_0=x git commit'
t 2 'git -c help.autocorrect=immediate comit -n'
t 2 'git config Help.AutoCorrect 1'
t 0 'GIT_AUTHOR_NAME=x git commit -m x'
# TC#66 감싸는 명령을 벗긴 뒤 git 이 아니면 남은 낱말의 git 으로 막는다
t 2 'env -u X git commit -n'
t 2 'env -C d git commit -n'
t 2 'env -S \"git commit -n\"'
t 2 'time -o f git commit -n'
t 2 'exec -a x git commit -n'
t 2 'nice --adjustment 5 git commit -n'
t 2 'env -u X /usr/bin/git status'
t 2 'env -S\"git commit -n\"'
t 2 'env --split-string=\"git commit -n\"'
t 2 'env -S \"git.exe commit -n\"'
t 2 'env -S \"git	commit -n\"'
t 0 'env FOO=1 make'
t 0 'timeout 5 sh -c \"echo git\"'
t 0 'env -u X make'
t 2 'sudo git commit -n'
t 2 'xargs git commit -n'
t 2 'env -iS x'
t 2 'env -S '\''git\_commit -n'\'''
t 0 'env FOO=\"a git b\" git commit -m x'
t 0 'GIT_MSG=\"use git now\" env make'
t 0 'env LC_ALL=C cat docs/git.md'
t 0 'timeout --signal=KILL 5 make'
# TC#36 해석에 실패하면 commit 글자가 있을 때만 막는다
t 2 'echo \"unclosed git commit'
t 0 'echo \"unclosed'
# TC#40 해석 실패의 commit 글자는 명령에서만 찾는다 → 저장소 경로의 글자로 막지 않는다
got=$(printf '%s' '{"cwd":"/w/commit-tools","transcript_path":"/h/commit/x.jsonl","tool_input":{"command":"echo \"unclosed"}}' | sh "$g" 2>&1); rc=$?
[ $rc -eq 0 ] || { echo "FAIL(0) cwd 에 commit → $rc $got"; fail=1; }
[ $fail -eq 0 ] && echo PASS || exit 1
