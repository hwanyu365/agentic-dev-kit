# agentic-dev-kit — 브랜치 최신 요구 선택

## 1. 개요

- 문서 정보: 작성 2026-11-15 / 기준 커밋 `d4d80d0` (origin/main) / 이슈 GH#31
- 기능: `/adk:init` 이 브랜치 최신 요구(브랜치 보호·ruleset 의 strict)를 인터뷰로 고르게 하고, 고른 값을 `CLAUDE.md` 에 남겨 `--update` 가 읽는다
- 목적 (Why)
  - init 은 재승인이 없는 저장소에서 묻지 않고 strict 를 켠다.
  - 켜면 PR 하나가 merge 될 때마다 열린 PR 전부가 BEHIND → rebase·CI 재실행 대기다. Dependabot PR 이 쌓이면 한 건씩 반복된다.

## 2. 목표 및 범위

- In Scope: 자리표시자 `{{BRANCH_STRICT}}`, init 질문 표·5 절, `update.md` 6-1·6-3, `tests/render.sh`, README
- Out of Scope: 브랜치 보호·ruleset 을 agent 가 직접 바꾸는 것 → 지금처럼 "사람이 할 일" 로 안내하고 `gh api` 로 대신 할지 묻는다

## 3. 요구사항

- `FR#1` [요구사항] init 은 `{{BRANCH_STRICT}}` 를 `켬`/`끔` 으로 묻는다. 기본값은 `끔` 이고, 5 의 재승인 판정과 merge queue 안내를 함께 보여 준다.
- `FR#2` [요구사항] 고른 값은 템플릿 `CLAUDE.md` GIT 절의 `main` 브랜치 보호 줄에 `브랜치 최신 요구: \`{{BRANCH_STRICT}}\`` 로 남는다.
- `FR#3` [요구사항] `--update` 는 그 줄에서 값을 읽고, 없으면 브랜치 보호·ruleset 의 현재 strict 값을 기본값으로 묻는다. 6-3 은 고른 값과 현재 설정이 다르면 "사람이 할 일" 에 넣는다.
- `NFR#1` [요구사항] 템플릿 자리표시자는 init 질문 표와 `update.md` 읽는 곳 표에 모두 있어야 한다 → 검사로 고정한다.

## 6. 동작 로직 및 정책

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 자리표시자로 남김 [FR#2] | `--update` 마다 저장소 설정 조회 | 고른 값과 현재 설정을 비교할 기준이 생긴다. 설정 조회는 플랜·권한에 따라 실패한다 |
| D2 | 재승인 없는 저장소의 기본값 `끔` [FR#1] (저장소 소유자 결정 2026-11-15) | `켬` | 열린 PR 대기가 merge 마다 반복된다. 합친 결과는 merge 뒤 `main` push CI 가 잡는다 |

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#47 | FR#2 NFR#1 | 렌더 `CLAUDE.md` 에 `브랜치 최신 요구: \`끔\``, 템플릿의 모든 자리표시자가 `update.md` 읽는 곳 표에 있음 | `tests/render.test.sh` |
| TC#48 | FR#1 FR#3 | init 질문 표·5 절·`update.md` 6-1·6-3·README 가 같은 값과 판정을 적음 | (수동) 대조 |

## 부록 — 변경 이력

- GH-31: 브랜치 최신 요구를 인터뷰로 선택
