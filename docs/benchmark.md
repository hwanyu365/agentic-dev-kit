# 참고한 방법론

agentic-dev-kit 은 argos(Android + Firebase, v1.0.0 까지 agent 주도 개발)에서 실제로 쓴 절차를 기준으로, 아래 방법론에서 효과가 분명한 것만 더했다.
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
| [Claude Code best practices](https://code.claude.com/docs/en/best-practices) | 대화 이력 없는 subagent 로 diff 리뷰·스펙 대조 | 구현한 agent 는 자기 코드를 근거로 판단함. GitHub 에서 Claude 를 쓸 수 없는 저장소에서도 merge 전 리뷰를 남김. 읽기만 하므로 역할 간 인계가 없음 | ship 3단계 (리뷰 `local`), verify 2단계 |
| [Claude Code hooks](https://code.claude.com/docs/en/hooks) | 매번 지켜야 하는 것은 hook 으로 | 비밀 파일 커밋 차단, 검증 뒤 변경된 커밋 차단, merge 게이트(CI·현재 head 리뷰 요약·Blocking 0건), handoff 읽기를 모델 판단에 맡기지 않음. 적용 저장소에서 리뷰 대상 PR 24개 중 22개가 마지막 리뷰 전에 merge 됐다. 차단 hook 은 `onFailure: block` → hook 이 실패·시간 초과돼도 통과시키지 않음. CI 가드는 최종 방어선으로 유지 | 템플릿 `.claude/settings.json` PreToolUse·`.claude/hooks/`, 플러그인 `hooks/hooks.json` SessionStart |
| Claude Code best practices, Codex | 같은 교정을 두 번 하면 규칙으로 올림 | 적용 저장소에서 "비동기 결과 미확인", "TC 는 있으나 시나리오를 검증하지 않음" 같은 지적이 PR 을 넘어 반복됐다. 기계로 막을 수 있으면 hook·CI, 아니면 CLAUDE.md 한 줄 | ship 3-3, 리뷰 기준의 `(반복)` 표시 |
| [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) | 역할별 agent 를 도구 제한으로 정의 | 리뷰·스펙 대조는 읽기만 해야 함. 범용 agent 는 편집 도구를 쥐고 있음. frontmatter 로는 Bash 를 명령 단위로 막지 못해 PreToolUse hook 이 agent_type 으로 가려 허용 목록의 조회 명령만 통과시키고(거부 목록은 모르는 변형이 통과해 리뷰마다 보강이 이어졌다), 반환 양식은 SubagentStop hook 이 검사 | 플러그인 `agents/`, `hooks/readonly-agent.sh`·`review-format.sh` |
| Claude Code best practices | 무인 실행에 멈추는 조건을 둠 (`--max-turns`, 시간 상한, 반복 실패 시 중단) | 끝나지 않는 CI 실행과 추측 수정의 반복을 막음 | `claude.yml`·`claude-review.yml`, tdd Green |
| Kiro | 버그 수정에 "바뀌지 않아야 할 동작" 을 함께 적음 | 재현 테스트만으로는 고치면서 생기는 회귀를 막지 못함 | 버그 이슈 양식, spec 1단계 |
| 이 저장소의 PR 리뷰 실적 | 멈춤 기준, 막는 장치의 push 전 사전 리뷰·입력 자리 전수 나열·이전 버전 비교, 허용 목록 원칙 | 한 PR 의 리뷰가 10라운드 이어졌다. Nits 반영이 재리뷰를 부르고, 지적된 한 자리만 고쳐 다음 자리가 다음 라운드에 나오고, 허용 목록을 거부 목록으로 바꾸거나 예외를 넣어 원래 막던 입력이 다시 풀렸다. 사전 리뷰와 이전 버전 비교를 시작한 뒤 우회가 push 전에 잡혔다 | ship 1-1·3-4, tdd "지적 반영", verify 2-3, 템플릿 CLAUDE.md 원칙 |
| [Claude Code Code Review](https://code.claude.com/docs/en/code-review-pull-requests.md), [code-review 플러그인](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/code-review) | 기존 결함 분리, 재리뷰는 이전 리뷰 이후 변경분만, Nits 상한, 규칙 위반은 원문 인용·동작 주장은 `파일:라인`, linter·일부러 끈 규칙·변경 밖 일반 품질 제외 | 기존 결함과 바뀌지 않은 코드의 새 지적이 Should Fix 로 올라오면 고친 것과 무관하게 재리뷰가 이어짐. 이름으로 짐작한 지적 하나가 왕복 한 번을 씀 | `skills/ship/review.md`, `claude-review.yml` prompt (재리뷰 변경분 한정은 local 리뷰만. CI 리뷰는 이전 HEAD 를 받지 않음) |
| [Qodo PR-Agent](https://github.com/qodo-ai/pr-agent/blob/main/pr_agent/settings/pr_reviewer_prompts.toml) | 덜 심각한 지적은 구체적 트리거 시나리오가 있을 때만 | 오탐이 몰리는 곳은 "재현하지 못한 결함 가능성" 이 들어가는 Should Fix. (추정) 항목에 실패 시나리오를 요구 | 같음 |
| [gstack](https://github.com/garrytan/gstack) `/review`, [pr-review-toolkit](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/pr-review-toolkit) | 테스트·검사 약화를 하나씩 이름으로 보고, 주석이 코드와 맞는지 | Red 테스트 삭제만 보면 기존 테스트의 skip·timeout 확대·snapshot 갱신·suppression 이 통과함. 틀린 주석은 agent 가 사실로 읽음 | 같음 |
| [MountainUnicorn/add](https://github.com/MountainUnicorn/add) | 플러그인 저장소 자체 CI (validate·자체 검사) | 검증 명령이 로컬에서만 돌면 검증 없이 merge 될 수 있고, 공개 후 외부 PR 은 확인할 수단이 없음. ubuntu 의 `sh`·`awk` 에서도 같은 결과인지 확인됨 | 루트 `.github/workflows/test.yml` |
| [superpowers](https://github.com/obra/superpowers), [Claude Code skills](https://code.claude.com/docs/en/skills) | 스킬 본문 크기 상한 테스트, 특정 상황에서만 쓰는 절차를 같은 폴더의 참조 파일로 분리 | 압축 뒤 스킬마다 앞 5,000 토큰만 다시 붙는다 → 긴 스킬은 뒤쪽 절(merge 조건 등)이 압축 뒤 사라짐. 분리한 파일은 해당 단계에서 읽음 | `tests/skill-size.test.sh`, `skills/ship/{human-review,followup}.md`, `skills/init/update.md`, `skills/ship/review.md` "사전 리뷰" |

## 채택하지 않음

| 출처 | 항목 | 이유 |
| --- | --- | --- |
| MountainUnicorn/add | test-writer / implementer / reviewer 다중 agent 역할 분리 | 단일 agent + CI Claude 리뷰로 충분했음. 역할 간 인계 비용이 더 큼 |
| MountainUnicorn/add | roadmap / milestone / cycle, telemetry, dashboard | 이슈·UC 우선순위가 같은 역할. 관리 문서가 낡으면 agent 가 사실로 믿음 |
| MountainUnicorn/add | away / back 모드 | 자율 범위(`pr`/`merge`) 설정이 같은 경계를 상시로 정함 |
| GitHub Spec Kit | `tasks.md` | 이슈가 작업 단위. 이중 관리가 됨 |
| Kiro | `design.md` 분리 | rules_spec §0.7: 설계 결정은 스펙 §6 에 둬야 요구사항과 근거가 함께 고쳐짐 |
| Kiro | EARS 표기 | Given-When-Then 이 그대로 TC 가 되어 같은 역할 |
| GitHub branch protection | 미해결 리뷰 대화를 merge 차단 요건으로 두기 | 지적 하나하나가 차단 요건이 되고, 반영 push 가 리뷰를 다시 깨워 라운드가 끝나지 않음. 적용 저장소에서 한 PR 이 아홉 라운드를 돌고 마지막엔 지적이 서로를 되돌렸다 |
| GitHub branch protection | 재승인이 생기는 저장소에서 브랜치 최신 요구 | PR 하나가 merge 될 때마다 열린 PR 전부가 rebase·push → 승인 해제 → 재승인 대기가 된다. 적용 저장소에서 켠 직후 1줄짜리 PR merge 로 리뷰 중이던 PR 5건이 모두 rebase 대상이 되어 소유자가 껐다. 합친 결과는 기본 브랜치 push CI 가 확인한다. 재승인이 없는 저장소는 그대로 켠다 (`/adk:init` 5) |
| [claude-code-action](https://github.com/anthropics/claude-code-action) | `@claude` 에게 코드 수정 위임 | push 의 actor 가 bot 으로 기록되어 워크플로가 승인 대기가 되고 리뷰는 bot actor 로 거부됨. 사람이 매번 승인해야 하므로 자율 범위 `merge` 가 끊긴다. 결과물 품질과는 무관 |
| [AGENTS.md](https://agents.md) | 도구 중립 규칙 파일 | OpenAI Codex 에서 시작한 형식. Claude Code 만 쓰므로 CLAUDE.md 하나로 충분. 다른 agent 를 들이면 CLAUDE.md 내용을 AGENTS.md 로 옮기고 CLAUDE.md 에서 `@AGENTS.md` 로 import |
| claude-plugins-official code-review, Qodo PR-Agent | 신뢰도 점수(0–100) | 리뷰어가 스스로 매긴 값이라 검증되지 않음. (재현함)/(원문 확인)/(추정) 근거 표시가 같은 역할을 더 구체적으로 함 |
| [Trail of Bits 감사 보고서](https://github.com/trailofbits/publications), [Conventional Comments](https://conventionalcomments.org/) | 감사 보고서식 항목 필드(심각도·난이도·유형·권고 단기/장기), praise·question 등 코멘트 라벨 | 리뷰 양식의 뼈대(등급·판정·라운드 추적)가 업계 관행과 큰 차이가 없음. 필드를 늘리면 PR 마다 출력만 길어지고 merge 판정은 같음 |
| Qodo PR-Agent | 리뷰 난이도 점수, PR 분할 제안 | 소규모 저장소에서 merge 판정의 입력이 되지 않음 |
| [superpowers](https://github.com/obra/superpowers) v7 | 스펙 builder check: 대화 이력 없는 subagent 가 스펙만 읽고 구현 전에 물어야 할 것을 나열 | 스펙마다 subagent 실행 사용량이 늘어남. `[확인필요]` 0건 점검과 `/adk:verify` 의 스펙 대조가 같은 빈칸을 구현 전·후에 잡음 |
| MountainUnicorn/add, [Factory.ai](https://docs.factory.ai/agent-driven-development) | "ADD(Agent Driven Development)" 명칭 | 정착된 용어가 아니고 쓰는 곳마다 뜻이 다름(다중 agent 협업, agent 의 내부 루프). 소프트웨어 공학에서 정착된 ADD 는 SEI 의 [Attribute-Driven Design](https://en.wikipedia.org/wiki/Attribute-driven_design). 내용은 SDD + TDD 와 게이트 강제이므로 그 용어로 소개 |
