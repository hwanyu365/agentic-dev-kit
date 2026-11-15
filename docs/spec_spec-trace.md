# agentic-dev-kit — 추적성 검사 (미확인 태그·테스트 이름)

## 1. 개요

- 문서 정보: 작성 2026-11-15 / 기준 커밋 `4ec0422` (origin/main) / 이슈 GH#33, GH#63
- 기능: 템플릿 `.github/spec-trace.sh` 가 미확인 태그의 변형 표기를 형식 위반으로 낸다
- 용어: 미확인 태그 = `rules_spec.md` §2.3 의 대괄호 안에 `확인필요` 만 쓴 태그. 이 문서는 부록 밖에서 태그 자체를 검사 대상 문자열로 쓰지 않는다 → 검사가 이 문서의 설명을 미확인 항목으로 센다
- 목적 (Why)
  - 검사는 정확한 미확인 태그만 미확인 항목으로 센다.
  - `rules_spec.md` 는 "무엇이 불확실한지와 확인 방법을 함께 적는다" 라고 해 태그 안에 콜론과 설명을 붙여 쓰게 유도한다 → 그런 항목이 성숙도 `poc` 밖에서도 조용히 통과한다.

## 2. 목표 및 범위

- In Scope: `spec-trace.sh` 판정, 템플릿 `docs/rules_spec.md` 의 태그 표기 규칙
- Out of Scope: `확인 필요` 처럼 띄어 쓴 표기 등 `[` 바로 뒤가 `확인필요` 가 아닌 표기

## 3. 요구사항

- `FR#1` [요구사항] 부록 밖의 항목 줄(정의 줄과 그 아래 들여쓴 줄)에 `[` 바로 뒤 `확인필요` 가 있고 그 바로 뒤가 `]` 가 아니면 `E BAD_UNCONFIRMED` 로 낸다.
  - 항목이 아닌 문단 줄은 `W BAD_UNCONFIRMED_MENTION` 이다 → 정상 태그의 `UNCONFIRMED_MENTION` 과 같은 등급이다.
  - `-b` 범위 검사에서 분기점 뒤에 추가·변경되지 않은 줄이면 `W BAD_UNCONFIRMED_OLD` 로 보고만 한다 → 기존 `UNCONFIRMED_OLD` 와 같은 기준이다.
- `FR#2` [요구사항] 템플릿 `docs/rules_spec.md` §2.3 에 미확인 태그는 그대로 쓰고 설명은 태그 밖에 쓴다는 규칙과 예를 둔다.

- `FR#3` [요구사항] 함수 이름이 테스트 이름인 언어의 테스트를 센다. 정의 줄(`def`·`func`·`fn`·`fun`·`void`·`function`·`Task`) 식별자 안의 `tc{n}` 토큰을 `TC#n` 으로 본다.
  - Go 메서드 수신자(`func (s *S) TestTC3X`)는 건너뛰고 이름을 읽는다.
  - 토큰 앞: 식별자 시작, `_`, 또는 소문자·숫자 뒤의 `TC`·`Tc`. 토큰 뒤: `_`·대문자·식별자 끝 → `batch6_x`·`tc10` 은 `TC#6`·`TC#1` 이 아니다.
  - 정의 줄이 아닌 자리의 `tc5_` 는 세지 않는다. 정의 줄이면 테스트 함수인지 가리지 않는다 → 보조 함수 `helper_tc5_…` 도 센다. `rules_spec.md` 가 `tc{n}` 을 테스트 함수 이름에만 쓰게 한다.
  - 번호의 선행 0 은 뺀다 (`tc09` → `TC#9`).
  - `/adk:verify` 의 TC 대조도 같은 규칙으로 찾는다.
  - Red 삭제 검사(`TEST_REMOVED`·`TEST_NAME_GONE`)도 같은 식별자를 `TC#n 식별자` 로 읽는다.
  - `rules_spec.md` §2.1·템플릿 `CLAUDE.md`·`/adk:tdd` 에 이 형식을 적는다.

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#44 | FR#1 | 항목의 태그 안 콜론 설명·공백 설명 → E, 문단의 태그 안 콜론 설명 → W, 정상 태그 → `E UNCONFIRMED` 만, 부록 → 없음, `-b` 의 기존 줄 → W·새 줄 → E | `tests/spec-trace.test.sh` |
| TC#45 | FR#2 | 템플릿 `docs/rules_spec.md` §2.3 에 규칙 문장과 예가 있음 | (수동) 대조 |
| TC#46 | FR#3 | `def test_tc1_login`·`func TestTC2Login`·`func (s *S) TestTc3Method`·`fn tc4_works`·`async Task TC7_Async`·`async def test_TC8_async` → 셈, 일반 코드 `x = tc5_value`·`void batch6_x` → NO_TEST, `test_tc60_other` → `TC#60` (ORPHAN), 지운 정의 → `TEST_REMOVED`, 이름만 바꿈 → `TEST_NAME_GONE` | `tests/spec-trace.test.sh` |

## 부록 — 변경 이력

- GH-33: `[확인필요]` 변형 표기를 형식 위반으로
- GH-32: 정의 줄 식별자의 `tc{n}` 을 TC 로 셈
- GH-63: 저장소 docs/ 로 이전, 미확인 태그 문자열을 용어로 바꿔 씀
