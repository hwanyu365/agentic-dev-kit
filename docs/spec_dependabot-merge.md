# agentic-dev-kit — Dependabot PR merge

## 1. 개요

- 문서 정보: 작성 2026-11-14 / 기준 커밋 `c17de0c` (origin/main) / 이슈 GH#34, GH#61
- 기능: 자율 범위 `merge` 저장소에서 세션이 Dependabot PR 을 리뷰하고, patch·minor 이고 Blocking 0 이면 squash merge 한다
- 목적 (Why)
  - 템플릿 `dependabot.yml` 이 Dependabot PR 을 만들지만 틀 안에서 merge 할 경로가 없다.
  - `claude-review.yml` 은 dependabot actor 를 건너뛴다 → 리뷰 요약이 생기지 않는다 → merge 게이트가 세션의 `gh pr merge` 를 막는다.
  - 결과적으로 사람이 브라우저에서 리뷰 없이 merge 한다 (건너뛴 필수 check 는 통과로 친다).

## 2. 목표 및 범위

- In Scope
  - 새 스킬 `/adk:deps`, 템플릿 `CLAUDE.md` 자율 범위 절, README 명령 표
  - merge 게이트(`merge-gate.sh`)의 Dependabot PR 판정, `tests/merge-gate.test.sh`·`tests/mutations.tsv`
- Out of Scope
  - `claude-review.yml` 의 dependabot 제외 → 그대로 둔다 (D1)
  - Dependabot 이 아닌 PR 의 게이트 판정 → 그대로 둔다
  - REST API(contents·git data)로 세션이 브랜치에 만든 커밋 → GitHub 가 committer `web-flow` 로 서명할 수 있고 author 는 요청이 정한다. REST 로 직접 merge 하는 경로와 같이 게이트가 원래 막지 못하는 범위다 → 템플릿 `CLAUDE.md` 의 막지 못하는 범위에 적는다
  - 자율 범위 `pr` 저장소의 Dependabot PR merge → 리뷰 요약·ready 까지만 한다 (FR#6)
  - 적용 저장소의 갱신 → 각 저장소 세션이 `/adk:init --update` 로 한다

## 3. 요구사항

- `US#1` [요구사항] 저장소 소유자로서, Dependabot PR 을 손으로 merge 하지 않도록, 세션이 리뷰하고 문제가 없으면 merge 하기를 원한다. → FR#1~FR#6
- `FR#1` [요구사항] 게이트는 PR 작성자가 `app/dependabot` 이면 Dependabot 판정을 한다. 아래를 모두 만족해야 Dependabot PR 로 본다.
  - 모든 커밋의 작성자가 `dependabot[bot]` 이고 서명이 확인됨(`verification.verified == true`) [as-built: argos#82·#81 의 커밋 조회]
  - 모든 커밋의 committer 가 `web-flow` 다 → GitHub 가 서명한 커밋이다 [as-built: `hwanyu365/agentic-dev-kit-deps-test` #1~#3 커밋 committer `web-flow`·`noreply@github.com`·`verified`]
    - 작성자와 서명 확인만으로는 세션이 author 를 Dependabot 으로 적고 자기 키로 서명한 커밋을 가려내지 못한다
  - 하나라도 어긋나면 막는다 → 사유에 `@dependabot recreate` 를 안내한다.
- `FR#2` [요구사항] 게이트는 Dependabot PR 의 모든 업데이트가 patch·minor 일 때만 통과시킨다.
  - 커밋 메시지의 `updated-dependencies` 항목마다 판정한다 [as-built: argos#81 `update-type: version-update:semver-patch`, #78 `semver-minor`]
  - `update-type` 이 있으면: `version-update:semver-patch`·`version-update:semver-minor` 만 통과
  - `update-type` 이 없으면: 같은 커밋 본문의 `` `{dependency-name}` from A to B `` 또는 `[{dependency-name}](...) from A to B` 에서 A·B 의 첫 숫자 자리가 같을 때만 통과
    - 간접 의존성과 보안 업데이트에서 `update-type` 이 빠진다 [as-built: argos#82 간접, stockpit#7 직접·`dependabot.yml` 없는 저장소]
    - 같은 이름의 `from A to B` 가 여럿이면 모두 통과해야 한다 [as-built: stockpit#6 `fast-uri` 3.1.3→3.1.9, 4.1.0→4.2.3]
  - 항목이 없거나, 버전을 해석하지 못하거나, 그 밖의 값이면 막는다.
- `FR#3` [요구사항] 게이트는 Dependabot PR 이면 리뷰 방식과 관계없이 세션 gh 계정이 쓴 현재 head 요약을 인정한다.
  - CI 통과·`--match-head-commit`·Blocking 0 판정은 다른 PR 과 같다.
  - 리뷰 방식 `github` 에서 Claude App 요약도 그대로 인정한다.
- `FR#4` [요구사항] 게이트는 Dependabot 판정에 쓰는 조회(작성자·커밋)가 실패하면 막는다.
- `FR#5` [요구사항] `/adk:deps [PR 번호]` 는 Dependabot PR 을 하나씩 처리한다. 번호가 없으면 열린 Dependabot PR 전부를 차례로 처리한다.
  - 전제: 자율 범위 `merge`. `pr` 이면 FR#6 대로 한다.
  - 순서: FR#1·FR#2 조건 조회 → CI 통과 확인 → `adk:reviewer` 리뷰(`/adk:ship` review.md 기준) → 요약을 `gh pr comment` 로 남김 → Blocking 0 이면 merge 게이트 → squash merge
  - 다른 작성자 커밋이 있으면 `@dependabot recreate`, 뒤처졌거나 충돌이면 `@dependabot rebase` 를 코멘트하고 새 head 를 기다린다 → 세션이 Dependabot 브랜치에 커밋하지 않는다.
  - 멈추고 보고: major 포함, Blocking·Should Fix 존재, CI 실패, 조건 해석 실패, recreate·rebase 뒤 새 head 가 생기지 않음
  - 템플릿 `CLAUDE.md` 자율 범위 절에 Dependabot PR 은 `/adk:deps` 로 처리한다고 적는다.
- `FR#6` [요구사항] 자율 범위 `pr` 에서 `/adk:deps` 는 리뷰 요약을 남기고 ready 상태를 확인한 뒤 보고하고 멈춘다 → 팀원 리뷰 규칙을 우회하지 않는다.
- `NFR#1` [요구사항] Dependabot 판정을 더한 경계 조건마다 `tests/mutations.tsv` 에 행을 둔다.
- `NFR#2` [요구사항] 게이트 판정은 `tests/*.test.sh` 가 도는 ubuntu gawk·ubuntu mawk·macOS awk 에서 같다.

## 6. 동작 로직 및 정책

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 세션이 리뷰하고 게이트가 세션 요약을 인정 [FR#3] | Dependabot secret 에 토큰을 등록해 `claude-review.yml` 이 리뷰 | 저장소마다 secret 등록 필요. Dependabot 실행의 `id-token: write` 가능 여부를 문서로 확인하지 못함. 시험 저장소가 Dependabot PR 을 만들지 않아 adk 안에서 검증할 수 없음 |
| D2 | Dependabot 조건(작성자·서명·업데이트 종류)을 게이트가 직접 확인 [FR#1 FR#2] | 가이드에만 적음 | `github` 방식에서 세션 요약을 인정하므로, 세션이 브랜치에 push 한 코드를 스스로 승인하는 경로를 게이트에서 막아야 함 |
| D3 | 다른 작성자 커밋은 막고 `@dependabot recreate` 로 지움 [FR#1 FR#5] | main 을 merge 한 커밋은 허용 | merge 커밋도 임의 내용을 담을 수 있음. Dependabot 은 다른 커밋이 더해진 PR 을 rebase 하지 않음 [as-built: GitHub 문서 "Managing pull requests for dependency updates"] |
| D4 | `update-type` 이 없으면 본문 버전의 첫 숫자 자리로 판정 [FR#2] | 항상 멈춤 | 간접 의존성 PR 이 계속 수동으로 남음. 첫 숫자 자리 비교는 `update-type` 의 semver 자리 기준과 같음. `0.x` 의 minor 를 major 로 보지 않음 (agent 기본값) |
| D6 | Dependabot 판정은 세션이 만들 수 없는 필드로 한다: committer `web-flow` + 서명 확인 [FR#1] | 작성자·서명 확인만 | 작성자 이메일과 서명 키는 세션이 정한다. `web-flow` committer 의 서명 확인은 GitHub 키로만 생긴다 |
| D5 | 새 스킬 `/adk:deps` [FR#5] | `/adk:ship`·`/adk:watch` 에 절 추가 | ship 은 세션이 만든 변경, watch 는 `pr` 저장소의 팀원 리뷰 감시가 대상. Dependabot PR 은 진입점이 다름 (agent 기본값) |

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#23 | FR#1 | 작성자 `app/dependabot` + 다른 작성자 커밋 / 서명 미확인 커밋 → 막음, 사유에 `recreate` | `tests/merge-gate.test.sh` |
| TC#74 | FR#1 | 작성자 `dependabot[bot]`·서명 확인이지만 committer 가 `web-flow` 가 아닌 커밋 / committer 없음 → 막음, 사유에 `recreate`. 모든 커밋이 committer `web-flow` → 기존 판정 | `tests/merge-gate.test.sh` |
| TC#24 | FR#2 | `semver-patch`·`semver-minor` → 통과, `semver-major`·항목 없음·모르는 값 → 막음, 여러 항목 중 하나라도 major → 막음 | `tests/merge-gate.test.sh` |
| TC#25 | FR#2 | `update-type` 없음 + 본문 `from 3.1.8 to 3.1.9` → 통과, `from 5.4.21 to 6.4.5` → 막음, 같은 이름 두 줄(`3.1.3→3.1.9`·`4.1.0→4.2.3`) → 통과, 그중 한 줄이 major → 막음, 버전 해석 불가 → 막음 | `tests/merge-gate.test.sh` |
| TC#26 | FR#3 | `github` 방식 + Dependabot PR + 세션 계정 요약 Blocking 0 → 통과, 같은 요약을 다른 계정이 씀 → 막음, Dependabot 이 아닌 PR + 세션 계정 요약 → 막음(기존 판정 유지) | `tests/merge-gate.test.sh` |
| TC#27 | FR#4 | 작성자·커밋 조회 실패 → 막음 | `tests/merge-gate.test.sh` |
| TC#28 | NFR#1 | 추가한 경계 조건의 mutation 이 모두 잡힘 | `tests/mutation.sh` (CI `mutation` job) |
| TC#29 | NFR#2 | TC#23~TC#27·TC#74 이 ubuntu gawk·mawk·macOS awk 에서 통과 | CI `test.yml` |
| TC#30 | FR#5 FR#6 | 템플릿 `CLAUDE.md`·`/adk:deps`·README 가 같은 흐름을 적음: 대상 조건, recreate·rebase, 멈춤 조건, `pr` 의 멈춤 지점 | (수동) 세 곳 대조 |
| TC#68 | FR#1 FR#2 FR#3 FR#5 | 시험 저장소의 실제 Dependabot PR: major → 게이트 차단, 사람 커밋 → `author` 판정·`@dependabot recreate` 로 복구, minor → 리뷰 요약 → 게이트 통과 → squash merge | (수동) `hwanyu365/agentic-dev-kit-deps-test` #1~#3 (GH#35) |

## 부록 — 변경 이력

- GH-34: Dependabot PR 세션 리뷰·merge, merge 게이트 Dependabot 판정
- GH-57: 시험 저장소 대조 TC 번호를 TC#31 → TC#68 (커밋 게이트 스펙 TC#31 과 겹침)
- GH-61: Dependabot 커밋 판정에 committer `web-flow` 를 더함

