# agentic-dev-kit — 커밋 게이트

## 1. 개요

- 문서 정보: 작성 2026-11-15 / 기준 커밋 `c17de0c` (origin/main) / 이슈 GH#28, GH#54, GH#55, GH#61
- 기능: 템플릿 `.claude/hooks/commit-gate.sh` 가 Bash 명령 직전에 `git … commit` 의 옵션을 해석해 pre-commit 을 끄는 형태를 막는다
- 목적 (Why)
  - 비밀 파일·검증 기록 검사는 git pre-commit 에만 있다. pre-commit 을 끄는 형태를 막는 장치는 `.claude/settings.json` deny 문자열 규칙뿐이다.
  - deny 는 거부 목록이라 짧은 옵션 묶음(`git commit -anm`)·섞인 대소문자(`-c core.HooksPath=`) 같은 변형이 통과한다.

## 2. 목표 및 범위

- In Scope: 커밋 게이트 hook, 템플릿 `settings.json` hook 등록, 템플릿 `CLAUDE.md` "막지 못하는 범위", README hook 표
- Out of Scope
  - 설정 파일에 정의된 git alias(`git ci -n`), `sh -c "git commit -n"`, 스크립트 파일 안의 커밋 → 명령 문자열로 판정할 수 없다. 템플릿 `CLAUDE.md` 에 남긴다
  - deny 규칙 → 그대로 둔다 (게이트와 이중)
  - 앞 세그먼트의 `export GIT_DIR=…`·`export GIT_CONFIG_…=…`, `cd` 로 옮긴 다른 저장소 → 명령 문자열로 실행 시점 환경을 알 수 없다. 템플릿 `CLAUDE.md` 에 남긴다
  - FR#9 목록 밖의 감싸는 명령 → 명령 이름 공간이 열려 있다. 템플릿 `CLAUDE.md` 에 남긴다
  - FR#2·FR#7 목록 밖의 `-c` 설정 → 설정 이름 공간이 열려 있어 허용 목록을 둘 수 없다. 템플릿 `CLAUDE.md` 에 남긴다
  - 명령 전체가 확장에서 오는 경우(`$CMD`·`eval "…"`) → 명령에 `commit` 낱말이 없으면 판정할 수 없다. `sh -c` 와 함께 템플릿 `CLAUDE.md` 에 남긴다
  - git 전역 옵션 값의 따옴표 밖 확장(`git -C $D status`)이 쪼개져 `commit` 이 되는 경우 → 뒤 낱말에 `commit`·`config` 가 없으면 통과한다. 값 자리까지 막으면 `git -C $M log` 처럼 흔한 명령이 모두 막힌다. 템플릿 `CLAUDE.md` 에 남긴다

## 3. 요구사항

- `FR#1` [요구사항] 게이트는 단순 명령마다 `git` 의 전역 옵션을 건너뛰고 하위 명령이 `commit` 이면 그 옵션을 해석해, pre-commit 을 끄는 옵션이 있으면 막는다.
  - 짧은 옵션 낱말(`-` 하나로 시작)은 글자를 차례로 읽는다. `n` 이면 막는다.
  - `m`·`F`·`C`·`c`·`t` 는 값을 받는다: 낱말의 나머지, 나머지가 없으면 다음 낱말이 값이다. `u`·`S` 는 낱말의 나머지가 값이다. 값 안의 글자는 보지 않는다 [as-built: git-commit(1) OPTIONS]
  - 긴 옵션이 `--no-veri` 로 시작하고 `--no-verify` 의 접두사이면 막는다 → git 은 모호하지 않은 접두사 약어를 받는다.
  - 값을 받는 긴 옵션은 정확한 이름일 때만 다음 낱말을 값으로 건너뛴다: `--message` `--file` `--template` `--reuse-message` `--reedit-message` `--fixup` `--squash` `--author` `--date` `--cleanup` `--trailer` `--pathspec-from-file`. 그 밖의 긴 옵션은 다음 낱말을 건너뛰지 않는다 → 값으로 오인해 뒤의 `-n` 을 놓치지 않는다.
  - `--` 뒤의 낱말은 경로다.
- `FR#2` [요구사항] 게이트는 `git` 전역 옵션 `-c`·`--config-env` 의 설정 이름, 하위 명령 `config` 의 인자가 `core.hooksPath` 이거나 `alias.`·`include.`·`includeIf.` 로 시작하면 막는다. 설정 이름은 대소문자를 가리지 않는다 [as-built: `git config core.HooksPath x` 가 `core.hooksPath` 를 바꿈]
  - `git config` 는 인자 위치(이름·값·조회·해제)를 가리지 않고 판정한다 → 막는 쪽으로 틀어진다. deny 의 `hooksPath` 글자 규칙도 조회를 막으므로 범위가 같다.
  - `git config … && git commit` 처럼 한 명령 안에서 바꾸면 커밋 직전 hook(`hooks-path.sh --check`)이 바뀌기 전 설정을 본다 → 게이트가 설정 쓰기를 막아야 한다.
  - 전역 옵션의 분리된 값은 하위 명령으로 읽지 않는다 (FR#5).
- `FR#3` [요구사항] 명령 해석에 실패하면 명령에 `commit` 글자가 있을 때 막는다 [as-built: `hook-lib.sh` `load`]
- `FR#4` [요구사항] 템플릿 `settings.json` PreToolUse 에 게이트를 모든 Bash 명령 직전 hook(`onFailure: block`)으로 둔다. 템플릿 `CLAUDE.md` "막지 못하는 범위" 에서 짧은 옵션 묶음·섞인 대소문자 `hooksPath`(`-c`)를 빼고 남는 범위(설정 파일 alias, `sh -c`, 스크립트)를 적는다.
- `FR#5` [요구사항] 게이트는 `git` 전역 옵션을 허용 목록으로 해석한다 [as-built: git 2.55 `git -h` usage, git(1)]
  - 분리된 값을 받는 옵션: `-C` `-c` `--config-env` `--git-dir` `--work-tree` `--namespace` `--attr-source` [as-built: `git --attr-source HEAD rev-parse` 성공]
  - `=` 로 값을 붙이는 옵션: `--git-dir=` `--work-tree=` `--namespace=` `--attr-source=` `--config-env=` `--exec-path=` `--list-cmds=`
  - 붙여 쓴 `-c<설정>` 은 FR#2 의 설정 판정을 받는다.
  - 값 없는 옵션: `-v` `--version` `-h` `--help` `--exec-path` `--html-path` `--man-path` `--info-path` `-p` `--paginate` `-P` `--no-pager` `--no-replace-objects` `--no-lazy-fetch` `--no-optional-locks` `--no-advice` `--bare` `--literal-pathspecs` `--glob-pathspecs` `--noglob-pathspecs` `--icase-pathspecs`
  - 목록에 없는 `-` 옵션이 하위 명령 앞에 오면, 그 옵션 뒤의 모든 낱말(알려진 옵션의 값 포함) 중 `commit`·`config`·`-c…`·`--config-env…` 가 있을 때 그 옵션 이름과 함께 막는다. 없으면 통과한다 → 값 자리를 하위 명령으로 오인해 `commit -n` 을 놓치지 않는다.
- `FR#6` [요구사항] 게이트는 하위 명령이 `commit` 이고 다음 중 하나가 있으면 막는다 → pre-commit 이 세션 작업 트리의 hook 이 아니라 다른 저장소의 설정으로 정해진다 [as-built: `git --git-dir=../B/.git --work-tree=. commit` 이 B 에 커밋되고 A 의 pre-commit 미실행]
  - 전역 옵션 `--git-dir`·`--work-tree` (값과 무관)
  - 명령 앞 환경변수 `GIT_DIR`·`GIT_WORK_TREE`·`GIT_COMMON_DIR` (`VAR=값` 접두, `env VAR=값`)
- `FR#7` [요구사항] 게이트는 `git` 앞 환경변수 이름이 `GIT_CONFIG` 로 시작하면 하위 명령과 무관하게 막는다 → `-c` 와 같이 hook 경로·alias 를 바꾼다 [as-built: `GIT_CONFIG_PARAMETERS`·`GIT_CONFIG_COUNT/KEY_0/VALUE_0`·`GIT_CONFIG_GLOBAL` 로 `core.hooksPath` 를 바꾼 커밋이 pre-commit 미실행]
  - FR#6·FR#7 의 환경변수 이름은 대소문자를 가리지 않는다 [as-built: Windows git 은 `git_config_parameters` 를 읽음 → deny `*GIT_CONFIG*` 를 지남]
  - FR#2 의 막는 설정에 `help.autocorrect` 를 더한다 [as-built: `git -c help.autocorrect=immediate comit -n` 이 commit 으로 실행되어 pre-commit 을 건너뜀]
- `FR#9` [요구사항] 감싸는 명령을 벗긴 뒤 첫 낱말이 `git` 이 아니면, 남은 낱말 중 `git`·`git.exe`(경로 포함)와 정확히 같은 낱말이 있을 때 막는다 → 감싸는 명령 옵션의 값(`env -u X`·`time -o f`·`exec -a x`)을 명령으로 오인해 놓치지 않는다 [as-built: origin/main 에서 `env -u X git commit -n`·`env -C d …`·`time -o f …`·`exec -a x …`·`nice --adjustment 5 …`·`nice -n5 …`·`sudo git commit -n` 통과]
  - 감싸는 명령: `env` `timeout` `nice` `nohup` `time` `command` `exec` `builtin` (옵션을 벗김), `sudo` `doas` `xargs` `setsid` `stdbuf` `ionice` `taskset` `chrt` `flock` (벗기지 않음 → 뒤의 `git` 낱말로 막힘)
  - 감싸는 명령의 옵션 값은 해석하지 않는다 → 도구·플랫폼(GNU·BSD env)마다 값 받는 옵션이 달라 목록이 새 빈틈이 된다.
  - 감싸는 명령의 옵션 중 `-…S…`(`-` 하나로 시작하고 `S` 를 담음)·`--sp…` 가 있으면 내용과 무관하게 막는다 → `env -S` 문자열은 env 가 이스케이프(`\_`)·변수(`${G}`)를 펼쳐 명령 문자열로 판정할 수 없다.
  - `VAR=값` 의 값, 감싸기를 벗긴 뒤 git 명령의 인자 글자는 보지 않는다.
  - 목록 밖 감싸는 명령은 통과한다 (§2 Out of Scope).
- `FR#10` [요구사항] 해석기(`segments.awk`)는 셸이 명령 자리에서만 특별하게 읽는 글자를 그 자리에서만 연산자로 읽는다 → 명령 중간의 글자로 단순 명령을 끊어 뒤의 옵션을 다른 명령으로 넘기지 않는다 [as-built: bash `printf '[%s]' } -anm x` → `[}][-anm][x]`, `git commit 2> >(cat) -anm x` 가 origin/main 게이트를 통과]
  - 명령 자리: 단순 명령의 첫 낱말 앞, 앞 낱말이 모두 셸 예약어(`if` `then` `else` `elif` `do` `while` `until` `time`)일 때, `function 이름` 뒤
  - 함수 정의 `이름()`·`function 이름()` 의 `()` 는 서브셸이 아니다 → 이름을 버리고 본문을 명령 자리에서 읽는다
  - `(`: 명령 자리면 서브셸, 아니면 해석 실패 (배열 `a=(…)`·extglob `@(…)` 등은 해석하지 않는다)
  - `<(`·`>(`: 자리와 무관하게 프로세스 치환 → 안쪽을 별도 명령으로 읽고, 바깥 단순 명령은 끊지 않는다. 결과 낱말은 리다이렉션 대상이면 버리고 아니면 인자로 남는다
  - `{`·`}`·`!`: 명령 자리면 묶음·부정, 아니면 낱말의 글자
- `FR#11` [요구사항] 해석기는 실행할 때 정해지는 낱말을 표시하고, 게이트는 그 낱말이 막을 대상이 될 수 있는 자리에 오면 막는다 [as-built: origin/main 게이트에서 `git commit $(echo -n)`·`` git commit `echo -n` ``·`git commit $X`·`git commit {-n,}` 통과]
  - 따옴표 밖 확장: `$` 변수·`${`·`$(`·백틱·`$'…'`·`$"…"`, glob(`*`·`?`·`]` 로 닫히는 `[`), brace(`{`·`}`) → 여러 낱말로 쪼개지거나 옵션이 될 수 있다
  - 따옴표 안 확장(`"$X"`·`"$(…)"`): 한 낱말이지만 값을 알 수 없다
  - commit 인자의 `--` 앞: 따옴표 밖 확장 낱말은 자리와 무관하게 막는다. 따옴표 안 확장 낱말은 값 자리(`-m "$(cat <<'EOF' …)"`)면 통과, 옵션 자리면 막는다
  - git 전역 옵션 자리의 확장 낱말은 모르는 옵션으로 본다 (FR#5)
  - git 전역 옵션·하위 명령 자리(전역 옵션의 값 제외)의 따옴표 밖 확장은 막는다 → `-c` 설정이나 `commit -n` 으로 쪼개질 수 있다
  - 그 자리의 따옴표 안 확장은 하위 명령 `commit` 일 수 있으므로 뒤 낱말을 commit 인자로 판정한다
  - 옵션 묶음 안의 따옴표 안 확장(`-nm"$X"`)은 확장 앞 글자를 차례로 읽어 `n` 이 값을 받는 글자보다 먼저 오면 막는다
  - 감싸는 명령을 벗긴 뒤 명령 이름 자리가 확장 낱말이면, 남은 낱말에 `commit`·`config` 가 있을 때 막는다
  - `-c`·`--config-env` 의 값에 따옴표 밖 확장이 있거나 설정 이름에 확장이 있으면 막는다. `git config` 는 인자 위치를 가리지 않으므로(FR#2) 확장이 든 인자를 모두 막는다
- `FR#8` [요구사항] 템플릿 `CLAUDE.md` 에 FR#5~FR#7·FR#9~FR#11 과 §2 Out of Scope 의 남는 범위를 적는다. README hook 표에는 막는 범위(FR#5~FR#7·FR#9~FR#11)를 적는다.
- `NFR#1` [요구사항] 게이트의 차단 조건마다 `tests/mutations.tsv` 에 행을 둔다.
- `NFR#2` [요구사항] 판정은 ubuntu gawk·ubuntu mawk·macOS awk 에서 같다.

## 6. 동작 로직 및 정책

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 옵션을 해석하는 hook [FR#1] | deny 패턴 추가(`git commit -*n*`) | 거부 목록은 변형마다 뚫린다. 글자 포함 패턴은 `-m "nothing"` 같은 값까지 막는다 |
| D2 | 커밋 직전 hook 에 비밀 파일·검증 기록 검사를 다시 둠 | — | 워크트리마다 판정이 달라지는 문제(GH#12)로 pre-commit 으로 옮긴 것. 검사 본체는 한 곳에 두고 끄는 경로를 막는다 |
| D3 | 모르는 긴 옵션은 값을 건너뛰지 않음 [FR#1] | 값 여부를 추측 | 잘못 건너뛰면 `-n` 을 놓친다(통과). 건너뛰지 않으면 값 자리의 `-n` 을 막을 뿐이다(오탐, 안전) |
| D5 | 전역 옵션 허용 목록, 모르는 옵션은 뒤에 `commit`·`config`·`-c`·`--config-env` 가 있을 때만 막음 [FR#5] | 거부 목록 유지 / 모르는 옵션이면 모든 git 명령 막음 | 거부 목록은 값 받는 옵션이 늘 때마다 뚫린다. 전부 막으면 git 이 새 옵션을 더할 때 `status`·`log` 까지 막혀, 불편이 커밋·설정 명령 밖으로 번진다 |
| D6 | `--git-dir`·`--work-tree`·`GIT_DIR` 류는 commit 에서 값과 무관하게 막음 [FR#6] | 값이 세션 저장소와 같을 때만 통과 | 앞 세그먼트 `cd` 로 cwd 가 달라지고 상대·절대·Windows 경로 정규화가 필요해 비교 로직이 새 빈틈이 된다. 세션이 자기 저장소에 커밋할 때 쓸 일이 없다 |
| D7 | `GIT_CONFIG*` 환경변수를 대소문자 무관하게 게이트에서도 막음 [FR#7] | deny `*GIT_CONFIG*` 에 맡김 | deny 는 글자 그대로 비교해 Windows 의 소문자 표기를 놓친다 |
| D8 | 감싸는 명령을 벗긴 뒤 git 이 아니면 남은 낱말의 `git` 으로 막고, `env -S` 는 내용과 무관하게 막음 [FR#9] | `unwrap` 에 값 받는 옵션 목록 추가 / `-S` 문자열 안을 글자 패턴으로 판정 | 옵션 목록은 GNU·BSD 마다 다르고 약어도 받는다. `-S` 문자열은 env 가 이스케이프·변수를 펼쳐 글자 패턴이 놓치는 형태와 잘못 막는 형태(`VAR="a git b"`, `docs/git.md`)가 둘 다 생긴다 |
| D4 | `merge-gate.sh` 와 같은 해석기(`hook-lib.sh`) | 별도 파서 | 따옴표·heredoc·명령 치환 해석이 두 게이트에서 같아야 한다 |
| D9 | 명령 자리 밖의 `(` 는 해석 실패, `{`·`}`·`!` 는 글자 [FR#10] | 배열·extglob 문법까지 해석 | 실패는 needle 글자가 있을 때만 막으므로 다른 명령에 번지지 않는다. 문법을 늘릴수록 해석기와 셸이 갈리는 자리가 늘어난다 |
| D10 | 확장 낱말은 표시만 하고 판정은 게이트가 자리로 함 [FR#11] | 확장이 보이면 해석 실패 | 실패로 내면 `git add src/*.ts && git commit -m x` 처럼 commit 과 무관한 낱말의 glob 까지 명령 전체를 막는다 |
| D11 | 따옴표 안 확장은 값 자리에서 통과 [FR#11] | 확장이면 모두 막음 | agent 의 여러 줄 메시지는 `-m "$(cat <<'EOF' …)"` 형태다. 따옴표 안 확장은 한 낱말이라 값 자리를 벗어나지 못한다 |

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#31 | FR#1 | `git commit -anm x`·`-nam x`·`-a -n -m x`·`-n`·`--no-verify`·`--no-veri`·`--amend -n` → 막음 | `tests/commit-gate.test.sh` |
| TC#32 | FR#1 | `-m "-n"`·`-amn`(n 은 메시지)·`-m nothing`·`--message -n`·`-- -n`(경로)·`-anm` 이 아닌 `-am x` → 통과 | `tests/commit-gate.test.sh` |
| TC#33 | FR#1 | 모르는 긴 옵션 뒤 `-n`(`--foo x -n`)·값 받는 옵션의 약어 뒤(`--mess x -n`) → 막음 | `tests/commit-gate.test.sh` |
| TC#34 | FR#1 FR#2 | `git -C d commit -an`·`env git commit -an`·`git -c user.name=x commit -an` → 막음, `git -C commit status`(값 `commit`) → 통과 | `tests/commit-gate.test.sh` |
| TC#35 | FR#2 | `git -c core.HooksPath=x commit`·`git --config-env=core.hookspath=E commit`·`git -c alias.ci="commit -n" ci`·`git -c include.path=f commit`·`git config core.HooksPath x && git commit`·`git config --add alias.ci …`·`git config --local IncludeIf.….path f`·`git config --get core.hooksPath`·`--unset alias.x`·`user.name alias.foo` → 막음, `git config user.name x` → 통과 | `tests/commit-gate.test.sh` |
| TC#36 | FR#3 | 해석 실패 + `commit` 글자 → 막음, 해석 실패 + 글자 없음 → 통과 | `tests/commit-gate.test.sh` |
| TC#61 | FR#5 | `git --attr-source HEAD commit -n`·`git --attr-source=HEAD commit -n`·`git --super-prefix x/ commit -n`·`git --unknown x config core.hooksPath y`·`git --unknown x -c core.hooksPath=y status`·`git --unk -C commit -n` → 막음 | `tests/commit-gate.test.sh` |
| TC#62 | FR#5 | `git --no-pager log -n 3`·`git --attr-source HEAD commit -m x`·`git --unknown status`·`git --literal-pathspecs commit -m x`·허용 목록 중 commit 을 막지 않는 옵션 전부(값 없는 옵션, `--namespace=`·`--attr-source=`·`--exec-path=`·`--list-cmds=`, 분리값 `-C`·`-c`·`--config-env`·`--namespace`·`--attr-source`)를 앞에 둔 `commit -m x` → 통과 | `tests/commit-gate.test.sh` |
| TC#63 | FR#6 | `git --git-dir=../B/.git --work-tree=. commit -m x`·`git --git-dir .git commit -m x`·`git --work-tree . commit -m x`·`GIT_DIR=../B/.git git commit -m x`·`env git_work_tree=. git commit -m x`·`GIT_COMMON_DIR=x git commit -m x` → 막음, `git --git-dir .git log`·`GIT_DIR=.git git status` → 통과 | `tests/commit-gate.test.sh` |
| TC#64 | FR#7 | `GIT_CONFIG_PARAMETERS=x git commit -m x`·`GIT_CONFIG_COUNT=1 git ci`·`git_config_global=f git status`·`env GIT_CONFIG_KEY_0=x git commit`·`git -c help.autocorrect=immediate comit -n`·`git config Help.AutoCorrect 1` → 막음, `GIT_AUTHOR_NAME=x git commit -m x` → 통과 | `tests/commit-gate.test.sh` |
| TC#66 | FR#9 | `env -u X git commit -n`·`env -C d git commit -n`·`time -o f git commit -n`·`exec -a x git commit -n`·`nice --adjustment 5 git commit -n`·`env -u X /usr/bin/git status`·`sudo git commit -n`·`xargs git commit -n`·`env -S "git commit -n"`·`env -S"git commit -n"`·`env --split-string="git commit -n"`·`env -iS x`·`env -S 'git\_commit -n'` → 막음, `env FOO=1 make`·`timeout 5 sh -c "echo git"`·`env -u X make`·`env FOO="a git b" git commit -m x`·`GIT_MSG="use git now" env make`·`env LC_ALL=C cat docs/git.md`·`timeout --signal=KILL 5 make` → 통과 | `tests/commit-gate.test.sh` |
| TC#69 | FR#10 | `git commit 2> >(cat) -anm x`·`git commit -m x < <(echo) -n`·`git commit <(true) -anm x`·`git commit } -anm x`·`git commit { -anm x`·`git commit ! -anm x`·`git commit x{ -n`·`git commit a=(b) -n`(해석 실패)·`{ git commit -n; }`·`(git commit -n)`·`if true; then (git commit -n); fi`·`f() { git commit -n; }; f`·`f () { git commit -n; }`·`function f { git commit -n; }`·`function f() { git commit -n; }`·`time (git commit -n)`·`git commit f() -n`(해석 실패) → 막음 | `tests/commit-gate.test.sh` |
| TC#70 | FR#10 | `git commit -m ok 2> >(cat)`·`cat <(echo commit -n)`·`git commit -m "a >(b)"`·`(cd d && git log) && git commit -m x`·`{ git add -A; git commit -m x; }`·`! git diff --quiet && git commit -m x`·`if true; then (git status); fi`·`git commit -m x 2> >(cat)`·`diff <(git log) <(git log)`·`git commit -m x }`·`f() { git commit -m x; }; f`·`time (git status) && git commit -m x` → 통과 | `tests/commit-gate.test.sh` |
| TC#71 | FR#11 | `git commit $(echo -n)`·`` git commit `echo -n` ``·`git commit $X`·`git commit "$X"`·`git commit -m $X`·`git commit {-n,}`·`git commit -?`·`git commit $'-n'`·`git $X commit -m x`·`$G commit -m x`·`env "$G" config core.hooksPath x`·`git commit [-]n`·`git commit "${X}"`·`git commit -m $(cat f)`·`git commit -m $X"$(y)"`·`git -c user.name=$N commit -m x`·`git -c$K=x commit -m x`·`git config "$K" x`·`git commit -nm"$X"`·`git commit -anm"$X"`·`git commit -nC"$X"`·`git "$S" -nm x`·`git $S -m x` → 막음 | `tests/commit-gate.test.sh` |
| TC#72 | FR#11 | `git commit -m "$(cat <<'EOF'` (여러 줄 heredoc 메시지)·`git commit -m "$MSG"`·`git commit -F "$F"`·`git commit -m x -- $FILES`·`git add src/*.ts && git commit -m x`·`git log $REF`·`"$G" status`·`git commit -m x "src/$F"`·`find . -exec cat {} \;`·`git commit -Sn"$K" -m x`·`git "$S" status` → 통과 | `tests/commit-gate.test.sh` |
| TC#65 | FR#8 | 템플릿 `CLAUDE.md` 가 FR#5~FR#7·FR#9~FR#11 과 남는 범위를, README 가 막는 범위를 같은 내용으로 적음 | (수동) 대조 |
| TC#37 | NFR#1 | 차단 조건 mutation 이 모두 잡힘 | `tests/mutation.sh` (CI `mutation` job) |
| TC#38 | NFR#2 | TC#31~TC#36·TC#61~TC#64·TC#66·TC#69~TC#72 이 세 awk 에서 통과 | CI `test.yml` |
| TC#67 | FR#3 | 해석 실패 명령의 `commit` 글자는 명령에서만 찾음: `cwd`·`transcript_path` 에 `commit` 이 든 입력 + 해석 실패 명령(글자 없음) → 통과 | `tests/commit-gate.test.sh` |
| TC#41 | FR#1 FR#4 | 렌더한 틀의 실제 Claude Code 세션(우회 모드)에서 `git commit --allow-empty -anm bundled` 가 실행되지 않음 | `tests/runtime.sh` (version 올림 PR 의 CI `runtime` job) |
| TC#39 | FR#4 | 템플릿 `settings.json` 에 게이트 hook, README 가 막는 범위를 템플릿 `CLAUDE.md` 와 같게 적음 | (수동) 대조 |

## 부록 — 변경 이력

- GH-28: 커밋 게이트 (짧은 옵션 묶음·`-c` 설정의 pre-commit 건너뛰기 차단)
- GH-54·GH-55: 전역 옵션 허용 목록, commit 의 다른 저장소 지정·`GIT_CONFIG*` 환경변수·`help.autocorrect`·감싸는 명령 옵션 뒤 git 차단
- GH-57: 해석 실패 판정의 TC 를 TC#67 로 분리 (merge 게이트 TC#40 을 쓰던 태그 정리)
- GH-61: 명령 자리 밖 `(`·`{`·`}`·`!` 와 프로세스 치환의 낱말 경계, 실행할 때 정해지는 낱말의 자리 판정
