# agentic-dev-kit — merge 게이트 플래그

## 1. 개요

- 문서 정보: 작성 2026-11-14 / 기준 커밋 `c17de0c` (origin/main) / 이슈 GH#16, GH#27, GH#29, GH#61
- 기능: 템플릿 `.claude/hooks/merge-gate.sh` 가 `gh pr merge` 의 플래그를 허용 목록으로 거른다
- 목적 (Why)
  - 게이트는 대상 PR·`--match-head-commit` 만 해석하고 나머지 `-*` 를 건너뛴다 → `--admin`·`--auto` 를 붙인 merge 가 통과한다
  - 자율 범위 `merge` 의 allow `Bash(gh pr merge --squash:*)` 는 접두사 일치라 뒤에 붙은 플래그도 묻지 않고 실행된다
  - `--admin`: 브랜치 보호를 건너뛴다. 보호가 없거나 관리자 강제가 꺼진 저장소는 게이트가 유일한 경계다
  - `--auto`: 판정 시점과 실제 merge 시점이 분리된다 → 판정 뒤 상태 변화를 게이트가 보지 못한다

## 2. 목표 및 범위

- In Scope: 게이트의 플래그 허용 목록, 템플릿 `CLAUDE.md` 자율 범위 `merge` 행 문구 (GH#16 2·3)
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
  - gh 하위 명령 자리: 첫 낱말의 확장, 첫 낱말이 `pr` 일 때 둘째 낱말의 확장, 둘째 낱말의 `$`·백틱을 막는다 → `gh api` 경로의 질의 문자열 `?` 는 glob 표시가 붙어도 막지 않는다 (REST 직접 호출은 Out of Scope)
  - `gh pr merge` 인자의 따옴표 밖 확장 낱말은 자리와 무관하게 막는다 (값 자리의 `-b $X` 도 쪼개져 `--admin` 이 될 수 있다)
  - 따옴표 안 확장 낱말은 값 자리(`-b "$BODY"`)면 통과한다. 대상 PR 자리면 FR#1 대로 해석하지 못해 막는다
  - gh 하위 명령 자리의 확장 판정에 brace·glob 을 더한다
  - 해석기의 낱말 경계(커밋 게이트 스펙 FR#10)는 두 게이트가 같다 → `2> >(cat) --admin` 의 `--admin` 이 merge 인자로 남는다
- `FR#4` [요구사항] `merge` 행 "저장소 소유자 지시 후" 열 값이 "먼저 묻는 예외" 목록과의 관계를 한 번에 읽히게 적는다.

## 6. 동작 로직 및 정책

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 허용 목록 [FR#1] | `--admin`·`--auto` 만 막는 차단 목록 | gh 가 플래그를 더하면 차단 목록은 조용히 뚫린다. 막는 장치는 허용 목록이 원칙 |
| D2 | 짧은 옵션 묶음(`-sd`)은 막는다 [FR#1] | 묶음을 풀어 글자마다 판정 | 묶음 안의 값 옵션(`-sb x`) 해석이 gh 와 갈릴 수 있다. agent 는 풀어 쓰면 된다 |

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

## 부록 — 변경 이력

- GH-16: merge 게이트 플래그 허용 목록, 자율 범위 merge 행 문구
- GH-27: 해석 실패 판정을 명령 문자열로 한정
- GH-29: 리다이렉션 연산자·fd 번호·대상을 인자에서 뺌
- GH-61: 해석기의 확장 표시로 merge 인자의 확장 낱말 판정, 낱말 경계 수정 반영
