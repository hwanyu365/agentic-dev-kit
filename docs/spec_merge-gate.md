# agentic-dev-kit — merge 게이트 플래그

## 1. 개요

- 문서 정보: 작성 2026-11-14 / 기준 커밋 `03422a5` (origin/main) / 이슈 GH#16, GH#27, GH#29, GH#61, GH#77
- 기능: 템플릿 `.claude/hooks/merge-gate.sh` 가 `gh pr merge`·`gh stack merge` 의 플래그를 허용 목록으로 거르고, merge 될 PR 마다 판정한다
- 목적 (Why)
  - 게이트는 대상 PR·`--match-head-commit` 만 해석하고 나머지 `-*` 를 건너뛴다 → `--admin`·`--auto` 를 붙인 merge 가 통과한다
  - 자율 범위 `merge` 의 allow `Bash(gh pr merge --squash:*)` 는 접두사 일치라 뒤에 붙은 플래그도 묻지 않고 실행된다
  - `--admin`: 브랜치 보호를 건너뛴다. 보호가 없거나 관리자 강제가 꺼진 저장소는 게이트가 유일한 경계다
  - `--auto`: 판정 시점과 실제 merge 시점이 분리된다 → 판정 뒤 상태 변화를 게이트가 보지 못한다
  - 스택에 속한 PR 은 `gh pr merge` 로 merge 되지 않는다 [as-built: gh-stack 문서 "Regular `gh pr merge` doesn't work with stacked PRs", GitHub Docs "The legacy pull request merge endpoints can't merge a stack"] → `gh stack merge` 는 게이트가 "gh pr merge 형태가 아닌 gh 의 merge" 로 막아 세션이 스택을 merge 할 수단이 없다

## 2. 목표 및 범위

- In Scope: 게이트의 플래그 허용 목록, 템플릿 `CLAUDE.md` 자율 범위 `merge` 행 문구 (GH#16 2·3), `gh stack merge` 의 허용 형태와 스택 대상 PR 마다 판정 (GH#77)
- Out of Scope: 스크립트·alias·REST 직접 호출 등 게이트가 원래 막지 못하는 범위 (템플릿 `CLAUDE.md` 에 이미 적힘)

## 3. 요구사항

- `FR#1` [요구사항] 게이트는 `gh pr merge` 의 플래그 중 허용 목록만 통과시키고, 그 밖의 `-` 로 시작하는 낱말이 있으면 막는다.
  - 허용: `-s`·`--squash`, `-d`·`--delete-branch`, `--match-head-commit`(값 분리·`=`), `-t`·`--subject`·`-b`·`--body`·`-F`·`--body-file`·`-A`·`--author-email`(값 분리, 긴 옵션은 `=` 도)
  - 막음 예: `--admin`, `--auto`, `--disable-auto`, `-m`·`--merge`, `-r`·`--rebase`, 묶음 `-sd`, `--`, 모르는 플래그
  - 값을 받는 옵션의 값은 플래그로 보지 않는다 (`--body "--admin"` 은 통과)
- `FR#2` [요구사항] `-s`·`--squash` 가 없는 `gh pr merge` 는 막는다 → 템플릿의 merge 방식은 squash 뿐이다.
- `FR#3` [요구사항] 템플릿 `CLAUDE.md` 자율 범위 `merge` 행이 CI 실패 수정 방식을 적는다: 새 커밋, 사람 리뷰·승인 저장소는 기존 커밋 amend [as-built: `/adk:ship` SKILL.md 의 CI 수정 규칙]
- `FR#5` [요구사항] 명령 해석에 실패하면 hook 입력의 명령(`tool_input.command`)에 `gh` 글자가 있을 때만 막는다. `cwd`·`transcript_path` 등 다른 필드의 글자는 보지 않는다 → 저장소 경로에 `gh` 가 든 저장소의 일반 명령을 막지 않는다.
- `FR#6` [요구사항] 리다이렉션은 단순 명령의 인자가 아니다. 연산자(`>`·`>>`·`>|`·`>&`·`<`·`<&`·`<>`·`&>`·`&>>`·`<<<`), 연산자에 따옴표 없이 붙은 fd 번호, 대상 낱말을 낱말 목록에서 뺀다.
  - 따옴표·escape 가 든 숫자(`"2">x`)는 fd 가 아니라 인자다 → 대상 PR 이 빠져 현재 브랜치 PR 로 판정되지 않는다.
  - 대상 자리의 명령 치환(`> $(…)`)은 명령으로 읽는다.
  - here-string(`<<<`) 의 대상은 데이터다.
- `FR#7` [요구사항] 게이트는 해석기의 확장 표시(커밋 게이트 스펙 FR#11)를 쓴다 → 펼친 뒤 허용 목록 밖 플래그가 될 수 있는 낱말을 통과시키지 않는다.
  - 확장 낱말을 담은 `export`·`declare` 등의 뒤에 오는 merge 는 막는다 → 펼친 결과가 `GH_REPO`·`GH_HOST` 를 정할 수 있다
  - gh 하위 명령 자리: 첫 낱말의 확장, 첫 낱말이 `pr`·`stack` 일 때 둘째 낱말의 확장 (`gh stack m?rge` 도 merge 가 될 수 있다), 둘째 낱말의 `$`·백틱을 막는다 → `gh api` 경로의 질의 문자열 `?` 는 glob 표시가 붙어도 막지 않는다 (REST 직접 호출은 Out of Scope)
  - `gh pr merge` 인자의 따옴표 밖 확장 낱말은 자리와 무관하게 막는다 (값 자리의 `-b $X` 도 쪼개져 `--admin` 이 될 수 있다)
  - 따옴표 안 확장 낱말은 값 자리(`-b "$BODY"`)면 통과한다. 대상 PR 자리면 FR#1 대로 해석하지 못해 막는다
  - gh 하위 명령 자리의 확장 판정에 brace·glob 을 더한다
  - 해석기의 낱말 경계(커밋 게이트 스펙 FR#10)는 두 게이트가 같다 → `2> >(cat) --admin` 의 `--admin` 이 merge 인자로 남는다
- `FR#4` [요구사항] `merge` 행 "저장소 소유자 지시 후" 열 값이 "먼저 묻는 예외" 목록과의 관계를 한 번에 읽히게 적는다.
- `FR#8` [요구사항] 게이트는 `gh stack merge <번호> --squash [-y|--yes]` 형태만 통과시킨다 (GH#77, 저장소 소유자 결정 2026-11-20).
  - squash 지정: `--squash`, `--merge-method squash`, `--merge-method=squash`. 없으면 막는다 → merge 방식은 squash 뿐이다 (FR#2)
  - 번호가 없으면 막는다 → 번호 없는 `gh stack merge` 는 현재 브랜치의 스택 전체를 merge 하는데, 게이트가 로컬 추적 상태로 대상을 정할 수 없다
  - 그 밖의 `-` 로 시작하는 낱말(`--merge`·`--rebase`·다른 `--merge-method`·`-R`·`--repo`·모르는 플래그), 대상 둘 이상, 숫자가 아닌 대상, 따옴표 밖 확장 낱말은 막는다 (FR#1·FR#7 과 같은 기준)
  - `GH_REPO`·`GH_HOST` 를 붙이거나 앞에서 확장 낱말을 export 한 뒤의 merge, 한 명령에 merge 가 둘 이상(`gh pr merge` 와 섞인 경우 포함)이면 막는다
- `FR#9` [요구사항] `gh stack merge <번호>` 의 merge 대상을 GitHub 에서 조회해 정한다. 스택 번호와 PR 번호는 겹치지 않는다 [as-built: gh-stack CLI 문서 "stack and PR numbers never overlap"]
  - 번호가 PR 이면: 그 PR 의 스택(`stack.number`)에서 아래부터 그 PR 까지(`stack.position` 이하). PR 이 스택에 없으면 막는다 → 스택이 아닌 PR 은 `gh pr merge` 로 merge 한다
  - 번호가 PR 이 아니면 스택 번호로 보고 그 스택의 PR 전부
  - 대상 중 이미 merge 된 PR 은 판정에서 뺀다. 대상에 닫힌 PR 이 있으면 막는다
  - 스택 조회의 PR 목록은 아래부터이고 `stack.position` 은 1부터다 [as-built: 시험 저장소 스택 #44 의 `pull_requests` 41·42·43, position 1·2·3] → 잘라낸 목록의 맨 위가 대상 PR 이 아니면 막는다
  - 대상 PR 하나라도 조회에 실패하면 막는다. 조회 결과의 낱말은 펼치지 않는다 → 작성자 `dependabot[bot]` 이 glob 으로 파일 이름이 되지 않게 한다
  - PR·스택 조회가 모두 실패하면 막는다 → 무엇이 merge 될지 모르는 채로 통과시키지 않는다
- `FR#10` [요구사항] 대상 PR 마다 `gh pr merge` 와 같은 판정을 한다: CI 통과, 그 PR 현재 head 의 리뷰 요약(작성자 규칙 같음), 요약의 Blocking 0건. 하나라도 아니면 막는다
  - Dependabot 작성 PR 이 대상에 있으면 막는다 → 세션 계정 요약을 인정하는 Dependabot 예외(Dependabot merge 스펙)는 단독 PR 의 커밋 검사에 묶여 있다
- `FR#11` [요구사항] `gh stack merge` 로 막지 못하는 범위를 템플릿 `CLAUDE.md` 에 적는다
  - 검사한 head 와 merge 되는 head 를 묶을 수 없다 → 검사 뒤 끼어든 push 는 통과한다 [as-built: gh-stack v0.3.0 `gh stack merge --help` 의 플래그는 merge 방식과 `--yes` 뿐]
  - 커밋 메시지를 지정할 수 없다 → squash 커밋 메시지는 GitHub 기본값이다

## 6. 동작 로직 및 정책

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 허용 목록 [FR#1] | `--admin`·`--auto` 만 막는 차단 목록 | gh 가 플래그를 더하면 차단 목록은 조용히 뚫린다. 막는 장치는 허용 목록이 원칙 |
| D2 | 짧은 옵션 묶음(`-sd`)은 막는다 [FR#1] | 묶음을 풀어 글자마다 판정 | 묶음 안의 값 옵션(`-sb x`) 해석이 gh 와 갈릴 수 있다. agent 는 풀어 쓰면 된다 |
| D3 | 스택 merge 는 `gh stack merge` 에 게이트를 건다 [FR#8 FR#11] (저장소 소유자 결정 2026-11-20) | `PUT …/pulls/{n}/merge-async` 를 `sha`·커밋 제목·본문과 함께 허용 | CLI 는 적용 저장소들이 이미 쓰는 경로다. API 경로는 결과 폴링이 필요하고 스택에서 메시지가 어느 PR 에 적용되는지 문서에 없다 → 대신 head 고정·메시지 지정을 포기하고 FR#11 로 범위를 적는다 |

## 7. 테스트 및 검증 기준

| TC | 대상 | 시나리오 | 비고 |
| --- | --- | --- | --- |
| TC#10 | FR#1 | `--admin`·`--auto`·`--disable-auto`·`-m`·`-r`·`-sd`·`--`·모르는 플래그 → 막음 | |
| TC#11 | FR#1 | 허용 플래그만 붙인 형태(분리·`=`·짧은 형태) → 통과, 값 자리의 `--admin` → 통과 | |
| TC#12 | FR#2 | `--squash` 없는 merge → 막음 | |
| TC#40 | FR#5 | `cwd`·`transcript_path` 에 `gh` 가 든 입력에서 해석 실패 명령(`${X:-$(date)}`, 닫히지 않은 따옴표) → 통과, 명령에 gh 가 든 해석 실패 → 막음 | `tests/merge-gate.test.sh` |
| TC#42 | FR#6 | `2>&1 \| tail`·`2>/dev/null`·`2> /dev/null`·`> out.txt`·`>>log 2>&1`·`&>out.txt`·`</dev/null` 뒤의 대상 PR 이 `17 abc1234`, `17 > 18`·`17 2>18` → `17`, `"2">x` → `2`, `17 "2">x` → 막음, `> $(gh pr merge …)`·`2>"$(…)"` → merge 로 읽음, `echo > ; gh pr merge …` → merge 로 읽음, `cat <<< "gh pr merge 12"` → 통과 | `tests/merge-gate.test.sh` |
| TC#73 | FR#7 | `gh pr merge 17 --squash --match-head-commit abc1234 2> >(cat) --admin`·`… < <(echo) --auto`·`… } --admin`·`… $X`·`… -b $X`·`… {--admin,}`·`gh pr {merge,x} 17 …`·`gh pr {mer,}ge 17 …`·`gh pr m?rge 17 …`·`gh p? merge 17 …`·`gh p? m?rge 17 …`·`gh alias $X`·`export $V; gh pr merge 17 …`·`gh {pr,x} merge 17 …`·`gh pr merge "$N" …`·`f() { gh pr merge 17 --squash --admin; }; f`·`function f { gh pr merge … --admin; }` → 막음, `… 2> >(cat)` → `17 abc1234`, `… -b "$BODY"`·`… --subject "$(cat t)"` → 통과, `gh api repos/o/r/commits?per_page=5 …`·`j() { gh pr view "$1" …; }; j 17`·`time (gh pr view 17)` → none | `tests/merge-gate.test.sh` |
| TC#13 | FR#3 FR#4 | 템플릿 `merge` 행 문구 | (수동) diff 리뷰 |
| TC#98 | FR#8 | `gh stack merge 12 --squash --yes`·`… -y`·`… --merge-method squash`·`… --merge-method=squash`·`gh stack merge --squash 12` → `stack 12`, `gh stack merge 12`·`… --merge`·`… --rebase`·`… --merge-method rebase`·`… --squash -R o/r`·`… --squash --admin`·`gh stack merge --squash --yes`·`… 12 13 --squash`·`… x --squash`·`… $N --squash`·`GH_REPO=o/r gh stack merge 12 --squash`·`gh stack merge 12 --squash && gh pr merge 13 --squash` → 막음, `gh stack view --json`·`gh stack submit --auto` → none | `tests/merge-gate.test.sh` |
| TC#99 | FR#9 FR#10 | stub: PR 12 가 스택 7 의 2번째 → PR 11·12 모두 요약·CI 통과면 통과, 11 이 Blocking·CI 실패·요약 없음이면 막음, 스택 3번째 PR 13 의 상태는 보지 않음. PR 12 가 스택에 없음 → 막음. 번호 7(스택) → 스택의 열린 PR 전부 판정. 대상에 merge 된 PR → 빼고 판정, 닫힌 PR → 막음. PR·스택 조회 모두 실패·PR 이 없는 스택·아래 PR 조회 실패·스택 순서가 position 과 어긋남 → 막음. Dependabot 작성 PR 포함(저장소에 `dependabott` 파일이 있어도) → 막음 | `tests/merge-gate.test.sh` |
| TC#100 | FR#11 | 템플릿·adk `CLAUDE.md` 의 merge 게이트 설명에 `gh stack merge` 허용 형태와 막지 못하는 범위(head 고정 없음, 메시지 기본값)가 있음 | (수동) 두 곳 대조 |

## 부록 — 변경 이력

- GH-16: merge 게이트 플래그 허용 목록, 자율 범위 merge 행 문구
- GH-27: 해석 실패 판정을 명령 문자열로 한정
- GH-29: 리다이렉션 연산자·fd 번호·대상을 인자에서 뺌
- GH-61: 해석기의 확장 표시로 merge 인자의 확장 낱말 판정, 낱말 경계 수정 반영
- GH-77: `gh stack merge` 허용 형태와 스택 대상 PR 마다 판정
