# agentic-dev-kit — 리뷰 흐름 (review flow)

## 1. 개요

- 문서 정보: 작성 2026-11-14 / 기준 커밋 `c3a8faa` (origin/main) / 이슈 GH#25, GH#61, GH#70
- 기능: 자율 범위·리뷰 방식마다 PR 의 리뷰·ready·merge 흐름을 정하고, pr 모드의 팀원 리뷰 대응을 감시 스킬로 처리한다
- 목적 (Why)
  - 사람 리뷰 저장소에서 ready 가 merge 직전 → 팀원이 리뷰하는 내내 PR 이 draft("작업 중")로 보인다.
  - draft 를 유지하는 이유가 템플릿·스킬에 없다.
  - pr 모드는 리뷰 대응마다 소유자 지시가 필요하다 → 팀원 리뷰를 감시·처리하는 수단이 없다.
  - `local` 리뷰는 사전 리뷰(ship 1-1)와 PR 뒤 리뷰가 같은 head 를 두 번 리뷰할 수 있다.

## 2. 목표 및 범위

- In Scope
  - 템플릿 `CLAUDE.md` 자율 범위·리뷰 절, `/adk:ship`·`/adk:init` 절차, README 명령 표
  - 새 스킬 `/adk:watch`
- Out of Scope
  - merge 게이트(`merge-gate.sh`) 판정 조건 → 그대로 둔다
  - `claude-review.yml` 의 리뷰 기준·트리거 → 그대로 둔다
  - 적용 저장소의 갱신 → 각 저장소 세션이 `/adk:init --update` 로 한다

## 3. 요구사항

- `US#1` [요구사항] 저장소 소유자로서, 팀원 리뷰가 있는 저장소에서 리뷰 대응을 매번 지시하지 않도록, agent 가 PR 을 감시해 반영·회신·merge 까지 처리하기를 원한다. → FR#4, FR#6, FR#7
- `US#2` [요구사항] 저장소 소유자로서, Claude GitHub App 을 쓸 수 없는 저장소에서도 같은 흐름을 쓰도록, 리뷰 방식만 바꿔 리뷰를 로컬에서 받기를 원한다. → FR#2, FR#3
- `US#3` [요구사항] 팀원으로서, 리뷰할 PR 을 알아보도록, 리뷰·CI 를 통과한 PR 만 ready 로 보기를 원한다. → FR#3
- `FR#1` [요구사항] 자율 범위의 정의는 팀원 리뷰 유무다.
  - `pr`: 팀원 리뷰가 있는 저장소. merge 조건에 현재 head 의 팀원 승인이 들어간다.
  - `merge`: 팀원 리뷰가 없는 저장소. agent 가 리뷰를 확인하고 직접 merge 한다.
  - `/adk:init` 은 자율 범위를 "팀원 리뷰가 있는가" 로 묻는다.
- `FR#2` [요구사항] 리뷰 방식(`{{REVIEWER}}`)마다 PR 전 단계가 다르다. 방식은 `/adk:init` 과 `/adk:init --update` 에서 고른다.
  - `github`: 로컬 리뷰를 하지 않는다 → push → draft PR → `claude-review.yml` 리뷰 & CI → 조사·반영
  - `local`: push 전에 대화 이력 없는 subagent 리뷰를 받고 Blocking·Should Fix 0건이 된 뒤 push → draft PR → 같은 head 의 요약을 PR 코멘트로 → CI
    - 막는 장치 변경 여부와 관계없이 매번 받는다.
    - head 가 바뀌는 반영(amend·새 커밋)마다 push 전에 다시 받는다.
  - 두 방식 모두 merge 게이트가 보는 "현재 head 의 리뷰 요약" 이 PR 에 남는다.
- `FR#3` [요구사항] PR 은 draft 로 만들고, 리뷰·CI 를 통과하면 ready 로 바꾼다.
  - 통과 = CI 통과 + 현재 head 요약 존재 + ship 3-4 판정 merge 가능(미해결 Blocking·Should Fix 0건)
  - 템플릿에 draft 의 뜻을 적는다: 팀원에게 보일 준비가 안 된 상태(리뷰 또는 CI 미통과)
  - ready 뒤 head 가 바뀌어도 draft 로 되돌리지 않는다.
- `FR#4` [요구사항] pr 모드의 `/adk:ship` 은 ready 까지 묻지 않고 진행한 뒤 보고하고 멈춘다.
  - ready 전 리뷰(Claude 리뷰·로컬 리뷰)의 지적은 ship 3 의 조사로 사실인 것을 묻지 않고 반영한다. 반영은 기존 커밋 amend + `push --force-with-lease`.
  - 반영이 PRD·스펙 변경을 부르는 지적은 반영하지 않고 확인받는다 (FR#6 과 같은 기준).
  - 미루는 항목은 ship 3-1 대로 이슈로 등록한다 → 후보 보고에서 그치지 않는다.
  - ready 직후 `reviewRequests` 를 조회해 보고에 넣는다. 비어 있으면 리뷰어가 없다고 보고한다 → agent 는 리뷰어를 고르지 않는다.
  - ready 이후 리뷰 대응·merge 는 `/adk:watch` 실행을 소유자 지시로 보고 그 스킬이 한다.
- `FR#5` [요구사항] merge 모드의 `/adk:ship` 은 ready 뒤 merge 게이트를 거쳐 squash merge 하고 정리한다.
  - 반영은 새 커밋이다.
  - ship 3-5 의 사람 리뷰 조회가 해당이면 merge 하지 않고 보고한다 → 팀원 리뷰 저장소인데 자율 범위가 `merge` 로 잡힌 경우다.
- `FR#6` [요구사항] `/adk:watch <PR 번호>` 는 pr 모드 PR 을 감시하며 한 라운드씩 처리한다.
  - 자율 범위가 `pr` 이 아니면 실행하지 않고 알린다.
  - 감시: 새 리뷰·리뷰 코멘트·일반 코멘트, `reviewRequests` 변화, CI 결과를 주기 조회하고 변화가 있으면 한 라운드를 처리한다.
  - 라운드: 조사(ship 3) → 반영(amend + `push --force-with-lease`, `local` 이면 push 전 로컬 재리뷰) → 회신·resolve(FR#7) → "리뷰 대응" 코멘트(ship 3-2) → 지적한 리뷰어마다 재리뷰 요청(ship 3-5)
  - 반영 판단은 조사로 사실인 지적을 권장안대로 처리한다. 후속 건은 ship 3-1 대로 이슈로 등록한다 → 스킬 실행이 권장안 위임이다.
  - 멈추고 보고: 반영이 PRD·스펙 변경을 부르는 지적, 스펙에 없는 결정, 먼저 묻는 예외, ship 3-4 중단 판정, CI 같은 원인 2회 실패
  - merge: 처리할 지적 없음 + ship 3-5 의 승인 조건(현재 head 승인, 대기 중 재리뷰 요청 없음) + CI 통과 + 현재 head 요약 → merge 게이트 → squash merge → ship 5 정리
- `FR#7` [요구사항] 사람 리뷰 스레드는 agent 가 회신한 뒤 resolve 한다.
  - 회신 내용(반영 커밋 SHA / 미반영 근거 / 이슈 번호)은 ship 3-5 그대로다.
  - 템플릿 자율 범위 절은 사용자 전역 규칙이 resolve 주체를 달리 정해도 이 표를 따른다고 적는다 → 특정 전역 규칙 문구는 인용하지 않는다.
- `FR#8` [요구사항] README 명령 표는 `plugins/adk/skills/` 의 스킬마다 한 행을 둔다.
- `FR#9` [요구사항] 템플릿 `.claude/settings.json` allow 에 `gh pr ready`·`gh pr merge --squash`·`git worktree remove` 를 자율 범위와 관계없이 둔다 → 두 값 모두 ready·merge 를 묻지 않고 한다.
  - `gh pr merge` 는 그대로 merge 게이트 hook 을 거친다.
- `FR#10` [요구사항] `/adk:ship` 4-b 의 merge 는 `--delete-branch` 를 붙이지 않고, 5 에서 main 클론 기준으로 워크트리 → 로컬 브랜치 → 남아 있는 원격 브랜치 순으로 지운다 [as-built: 워크트리가 있는 브랜치의 `gh pr merge --delete-branch` 는 merge 뒤 `cannot delete branch … used by worktree` 로 실패]
- `FR#11` [요구사항] 리뷰 job 이 따르는 지시(템플릿·adk `claude-review.yml` prompt, `/adk:ship` review.md)의 `gh pr view` 는 `--json <필드>` 로 읽을 필드를 정한다 → job 의 `permissions` 안에서 동작한다 [as-built: 리뷰 job 에서 `gh pr view --comments` 가 check 상태 조회 중 `Resource not accessible by integration` 으로 실패]
  - 이전 라운드 읽기: `gh pr view <번호> --json body,comments`
  - job `permissions` 는 넓히지 않는다 → `checks: read` 를 더하면 모든 형태가 동작하지만, PR 내용을 읽는 리뷰 job 의 권한을 지시 형태 때문에 넓히지 않는다
- `FR#12` [요구사항] 템플릿·adk 의 `claude-review.yml` 은 `claude_args` 에 `--permission-mode default`, `claude.yml` 은 `--permission-mode acceptEdits` 를 둔다 → `--allowedTools` 밖 호출은 거부된다 [as-built: `claude-code-action` v1.0.273 부터 opt-out 조건이 없으면 세션이 auto mode 로 시작하고, 허용 규칙이 없는 호출을 안전성 검토가 판정한다]
  - action 이 넣는 인자 뒤에 `claude_args` 가 붙는다 → 마지막 `--permission-mode` 가 이긴다
  - `claude.yml` 의 쓰기 도구는 `--disallowedTools` 로 따로 막는다 → acceptEdits 여도 편집하지 않는다
  - 런타임 관문의 격리 확인 워크플로는 템플릿의 권한 모드를 그대로 쓰고, 허용 목록 밖 명령 하나가 거부되는지와 세션 권한 모드를 본다
    - 거부는 실행 결과의 권한 거부 목록(`permission_denials`)으로 판정한다 → 거부 문구는 action 설정에 따라 달라진다 [as-built: v1.0.275 리뷰 job 의 거부 문구는 `This command requires approval`]
    - 권한 모드는 세션 시작 메시지의 `permissionMode` 로 본다 → auto mode 의 검토가 거부한 것과 구분한다
- `NFR#1` [요구사항] FR#1~FR#10 의 흐름 변경은 merge 게이트(`merge-gate.sh`)와 그 테스트·mutation 목록을 바꾸지 않는다 → 흐름 변경이 보안 경계를 바꾸지 않는다.
- `NFR#2` [요구사항] 스킬 본문은 `tests/skill-size.test.sh` 상한 안에 둔다. 넘으면 특정 상황 절차를 같은 폴더 참조 파일로 옮긴다.

## 6. 동작 로직 및 정책

### 흐름

```mermaid
flowchart TB
  subgraph SHIP["/adk:ship"]
    direction LR
    C[커밋] --> RV{리뷰 방식}
    RV -- local --> LR[로컬 리뷰 B·S 0] --> P1[push → draft PR → 요약 코멘트] --> CI[CI]
    RV -- github --> P2[push → draft PR] --> GR[Claude 리뷰 & CI → 조사·반영]
    CI --> RD[ready]
    GR --> RD
  end
  subgraph MODE["자율 범위"]
    direction LR
    RD2[ready] --> A{팀원 리뷰}
    A -- "merge (없음)" --> G1[merge 게이트 → merge → 정리]
    A -- "pr (있음)" --> RP[리뷰 요청 확인 → 보고 ■] --> W["/adk:watch: 조사 → 반영 → 회신·resolve → 재리뷰 요청"] --> AP{승인 + 처리할 것 없음}
    AP -- 아니오 --> W
    AP -- 예 --> G2[merge 게이트 → merge → 정리]
  end
  SHIP ~~~ MODE
```

### 설계 결정

- 리뷰 방식과 자율 범위는 독립 축이다 [요구사항] → Claude App 사용 가능 여부와 팀원 유무는 따로 정해진다.
- `local` 요약은 세션 gh 계정이 쓰므로 agent 가 스스로 요약을 쓸 수 있다 [요구사항] → 소유자가 문제로 보지 않기로 했다(2026-11-14). merge 게이트는 그대로 작성자만 거른다.
- 팀원 승인은 merge 게이트가 아니라 `/adk:watch` 가 확인한다 [요구사항] → 게이트를 바꾸지 않는다(NFR#1). 브랜치 보호가 승인을 요구하면 GitHub 이 최종 경계다.
- `github` 방식은 막는 장치 변경에도 로컬 사전 리뷰를 하지 않는다 [요구사항] → Claude 리뷰만으로 확인한다.

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#16 | FR#8 | `plugins/adk/skills/*/` 마다 README 명령 표에 `/adk:<이름>` 행이 있고, 없는 스킬의 행은 없음 | `tests/readme-commands.test.sh` |
| TC#17 | NFR#2 | 모든 `SKILL.md` 가 상한 이하, 참조 링크 대상 존재 | `tests/skill-size.test.sh` |
| TC#18 | NFR#1 | `merge-gate.sh`·`tests/merge-gate.test.sh`·`tests/mutations.tsv` 가 diff 에 없음, 기존 테스트 통과 | (수동) PR diff 확인 |
| TC#19 | FR#1 FR#2 FR#3 FR#4 FR#5 FR#7 FR#9 | 템플릿 `CLAUDE.md`·ship·init·README 가 같은 흐름을 적음: 자율 범위 정의, 방식별 PR 전 단계, ready 시점·draft 의 뜻, pr 의 멈춤 지점, merge 의 사람 리뷰 해당 시 보고, resolve 대체, allow 의 ready·merge 항목 | (수동) 세 곳 대조 |
| TC#20 | FR#6 | PR 에서 `/adk:watch` 한 라운드: 리뷰 코멘트 → amend·push → 스레드 회신·resolve → 리뷰 대응 코멘트 → 재리뷰 요청이 관측되고, 승인 뒤 merge 게이트를 거쳐 merge | (수동) 시험 저장소에서 `github-actions[bot]` 이 연 PR 에 소유자 계정이 리뷰어로 관측. `Monitor` 로 깨어나는 감시 루프는 관측 대상 아님 |
| TC#21 | FR#6 | `merge` 모드 저장소에서 `/adk:watch` 를 실행하면 감시하지 않고 알림 | (수동) |
| TC#43 | FR#10 | 4-b merge 명령에 `--delete-branch` 없음. 워크트리에서 시작한 브랜치에 `cleanup.md` 명령을 줄마다 실행 → 원격 브랜치가 남은 저장소·자동 삭제 저장소 모두 줄마다 종료 코드 0, 워크트리·로컬·원격 브랜치 없음, `main` 갱신 | `tests/cleanup.test.sh` (임시 bare 원격·워크트리) |
| TC#75 | FR#11 | 템플릿·adk `claude-review.yml` prompt 와 review.md 의 `gh pr view` 마다 `--json` 이 있음 | `tests/review-prompt.test.sh` |
| TC#76 | FR#11 | 렌더한 리뷰 job 과 같은 권한·격리에서 prompt 의 이전 라운드 명령이 성공하고, 대조군의 `gh pr view <번호> --comments` 는 권한 오류로 실패 | `tests/runtime.sh` (version 올림 PR 의 CI `runtime` job), 배포 관문 스펙 FR#5 |
| TC#80 | FR#12 | 템플릿·adk 의 `claude-review.yml` `claude_args` 에 `--permission-mode default`, `claude.yml` 에 `--permission-mode acceptEdits` 가 있고 다른 `--permission-mode` 는 없음 | `tests/review-prompt.test.sh` |
| TC#81 | FR#12 | 격리 확인 워크플로가 템플릿의 `--permission-mode` 를 그대로 두고 허용 목록 밖 명령(`sh probe/outside.sh`)을 시도하게 함. 판정: 실행 출력 표지가 있으면 ran, 권한 거부 목록에 그 호출이 있으면 denied(문구와 무관), 그 밖 오류는 error-other. 세션 시작 메시지의 `permissionMode` 를 mode 로 냄 | `tests/probe.test.sh` |
| TC#82 | FR#12 | 렌더한 리뷰 job 과 같은 권한·격리에서 허용 목록 밖 명령이 denied 이고 mode 가 default | `tests/runtime.sh` (version 올림 PR 의 CI `runtime` job), 배포 관문 스펙 FR#5 |
| TC#22 | FR#2 | `local` 렌더 결과에 `claude-review.yml`·`claude.yml` 없음, `github` 렌더 결과에 있음 | (수동) `/adk:init` 렌더 확인 |
- GH-61: 리뷰 job 지시의 `gh pr view` 를 `--json` 필드 지정으로
- GH-70: 리뷰·`@claude` job 의 권한 모드를 명시해 허용 목록을 엄격하게
