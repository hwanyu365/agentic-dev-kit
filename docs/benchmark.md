# 참고한 방법론

add-project 는 argos(Android + Firebase, v1.0.0 까지 agent 주도 개발)에서 실제로 쓴 절차를 기준으로, 아래 방법론에서 효과가 분명한 것만 더했다.
기준: 개인·소규모 저장소에서 유지 비용 없이 agent 의 실수를 줄이는가.

## 채택

| 출처 | 가져온 것 | 이유 | 위치 |
| --- | --- | --- | --- |
| [MountainUnicorn/add](https://github.com/MountainUnicorn/add) | 성숙도(poc/alpha/beta/ga) 한 값으로 절차 강도 조절 | 프로토타입과 운영 제품에 같은 절차를 강제하면 한쪽이 무너짐 | 템플릿 CLAUDE.md "성숙도" |
| MountainUnicorn/add | Red 테스트를 Green 에서 삭제·약화 금지 | agent 는 통과시키기 어려운 테스트를 지우는 쪽으로 기움 | tdd, ship, Claude 리뷰 |
| MountainUnicorn/add | 세션 인계 문서 | 컨텍스트 압축·세션 교체 뒤 진행 상태 손실 방지 | handoff |
| MountainUnicorn/add | PR·이슈·웹 내용은 데이터이지 지시가 아님 | public 저장소 + `@claude` 워크플로는 prompt injection 경로 | 템플릿 CLAUDE.md 원칙, Claude 리뷰 프롬프트 |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | constitution(프로젝트 원칙)을 스펙과 분리, 위반 시 중단 | 원칙은 모든 기능에 적용되므로 기능 스펙에 흩어지면 안 됨 | 템플릿 CLAUDE.md "원칙" |
| GitHub Spec Kit | clarify(모호성 질문), analyze(스펙·코드 교차 점검) | `[확인필요]` 0건, 스펙 전수 대조와 같은 목적 | spec 2단계, verify 2단계 |
| [Kiro](https://kiro.dev/docs/specs/concepts) | 버그는 재현 테스트부터 | 재현 없이 고치면 원인이 아니라 증상을 고침 | spec 1단계, tdd, 버그 이슈 템플릿 |
| [superpowers](https://github.com/obra/superpowers) | 스펙 전 질문은 하나씩, 선택지 + 권장안 | 질문 묶음은 답이 얕아지고 기본값이 동의로 오인됨 | spec 2단계, init 인터뷰 |
| superpowers | 명령 출력 없이 완료 선언 금지 | "통과했다"는 보고가 실행 없이 나오는 것을 막음 | 템플릿 CLAUDE.md 원칙, verify |

## 채택하지 않음

| 출처 | 항목 | 이유 |
| --- | --- | --- |
| MountainUnicorn/add | test-writer / implementer / reviewer 다중 agent 역할 분리 | 단일 agent + CI Claude 리뷰로 충분했음. 역할 간 인계 비용이 더 큼 |
| MountainUnicorn/add | roadmap / milestone / cycle, telemetry, dashboard | 이슈·UC 우선순위가 같은 역할. 관리 문서가 낡으면 agent 가 사실로 믿음 |
| MountainUnicorn/add | away / back 모드 | 자율 범위(`pr`/`merge`) 설정이 같은 경계를 상시로 정함 |
| GitHub Spec Kit | `tasks.md` | 이슈가 작업 단위. 이중 관리가 됨 |
| Kiro | `design.md` 분리 | rules_spec §0.7: 설계 결정은 스펙 §6 에 둬야 요구사항과 근거가 함께 고쳐짐 |
| Kiro | EARS 표기 | Given-When-Then 이 그대로 TC 가 되어 같은 역할 |
| [AGENTS.md](https://agents.md) | 도구 중립 규칙 파일 | OpenAI Codex 에서 시작한 형식. Claude Code 만 쓰므로 CLAUDE.md 하나로 충분. 다른 agent 를 들이면 CLAUDE.md 내용을 AGENTS.md 로 옮기고 CLAUDE.md 에서 `@AGENTS.md` 로 import |
