# add-project

ADD(Agent Driven Development) 프로젝트 틀과 절차 스킬을 담은 Claude Code 플러그인.

- 사람: 요구사항, 결정, 리뷰
- agent: 스펙, 테스트, 구현, 검증, PR, 릴리스
- 장치: 스펙 주도 TDD, 로컬과 CI 가 같은 단일 검증 명령, 프로젝트별 성숙도·자율 범위

적용 예: [hwanyu365/argos](https://github.com/hwanyu365/argos) (Android + Firebase, v1.0.0)
참고한 방법론과 채택 이유: [docs/benchmark.md](docs/benchmark.md)

## 설치

private 저장소라 git 이 묻지 않고 인증할 수 있어야 한다 (Claude Code 는 git 을 비대화식으로 실행한다).

- HTTPS: `gh auth login` → `gh auth setup-git` 으로 credential helper 에 저장
- GitHub SSH 키가 없으면 `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` 을 설정한다 → 세션 안의 `/plugin` 설치와 `plugin update` 는 HTTPS 로 다시 시도하지 않는다

```sh
claude plugin marketplace add hwanyu365/add-project
claude plugin install add@add-project
```

- 갱신: `claude plugin marketplace update add-project` → `claude plugin update add@add-project` (자동 갱신은 기본으로 꺼져 있다)
- 플러그인 hook: 세션 시작 시 main 클론의 `.add/handoff.md` 를 컨텍스트에 넣고, 아래 두 agent 의 Bash 를 조회 명령으로 제한하고, `add:reviewer` 의 반환 양식을 검사하고, 컨텍스트 압축 때 ADD 진행 상태(이슈·리뷰 항목·소유자 결정)를 요약에 남기게 한다
- 플러그인 agent: `add:reviewer`(local 리뷰), `add:spec-verifier`(스펙 대조)
  - 편집 도구(Edit·Write)가 없고, Bash 는 hook 이 허용 목록으로 제한함: git·gh 조회, 읽기 도구, 자체 검사·검증 래퍼만 통과
  - 판정은 셸이 실제로 넘기는 단어(따옴표·backslash 를 푼 것)로 함. 목록 밖의 명령과 확장(`$`·중괄호·glob)·치환·괄호·파일 리다이렉트·셸 감싸기는 모두 막음
  - 허용한 명령의 파일 쓰기·명령 실행 옵션은 이름 앞부분으로 막음 (git `--out*`·`--ext*`·`--op*`·`--upl*`·`--exec*`, `git grep -O`, `gh api` 의 쓰기 플래그·URL·`--hostname`, gh `--web`, gh 의 URL 인자, `-R`/`--repo` 는 위치와 관계없이 OWNER/REPO 만(짧은 옵션 묶음 안의 `R` 은 막음), `repo view` 의 인자는 허용 글자와 `/` 하나만, `git fetch` 는 원격 이름과 `:`·`+` 없는 ref 만). 이 목록은 각 명령의 옵션 문서와 대조한 범위다 → 허용 명령을 늘리거나 도구가 옵션을 추가하면 다시 대조한다
  - 인자를 다시 확장하는 셸 내장(`printf -v`·`test -v`)은 목록에 넣지 않음
  - 남는 로컬 쓰기: `git fetch` 의 FETCH_HEAD·원격 추적 ref·객체 (기본 refspec 기준. `remote.*.fetch` 를 로컬 브랜치로 잡은 저장소에서는 로컬 ref 도 바뀜), `git status`·`git describe --dirty` 의 index 갱신
  - 자체 검사(`sh tests/*.test.sh`)와 검증 래퍼(`sh .claude/hooks/verify.sh`)는 저장소 코드를 그대로 실행함 → 그 코드가 하는 일은 hook 의 제한 밖이고, `cd` 로 옮긴 다른 저장소의 것도 실행됨. 이 범위는 agent 지침이 기준이다
  - `cd`·`git -C` 로 옮긴 저장소의 git 설정이 실행하는 명령(`core.fsmonitor`, external diff 등)도 hook 범위 밖이다 → 같은 이유로 agent 지침이 기준이다
- Claude Code v2.1.295 이상: 템플릿의 차단 hook 은 `onFailure: "block"` 으로 hook 실패·시간 초과도 막는다. 그보다 낮은 버전은 이 필드를 모르므로 실패가 통과로 끝난다
- [MountainUnicorn/add](https://github.com/MountainUnicorn/add) 와 함께 설치하면 `/add:*` 명령 이름이 겹친다. 하나만 설치한다.

## 사용 흐름

```mermaid
flowchart LR
  I[요청 또는 GitHub Issue] --> S["/add:spec"] --> T["/add:tdd"] --> V["/add:verify"] --> P["/add:ship"]
  S -->|chore| V
  P -->|자율 범위 pr| R[리뷰 보고 → 지시 → 반영 → merge]
  P -->|자율 범위 merge| M[리뷰 반영 → squash merge]
  R & M --> L["/add:release"]
```

| 명령 | 하는 일 |
| --- | --- |
| `/add:init` | 현재 저장소에 틀을 복사하고 자리표시자(스택, 검증 명령, 성숙도, 자율 범위, 리뷰 방식 등)를 인터뷰로 채움 |
| `/add:spec [이슈]` | 워크트리·브랜치 생성·기준선 검증 → `docs/spec_{function}.md` 갱신, 요구사항 ID·TC 부여, `[확인필요]` 0건. 이슈가 없으면 확인받고 생성 |
| `/add:tdd` | TC 로 테스트 먼저(Red) → 최소 구현(Green) → 정리. 같은 TC 수정이 3번 실패하면 멈춤. 리뷰 지적은 같은 입력이 들어오는 자리를 전수로 세고 테스트부터 |
| `/add:verify` | 검증 명령 + 스펙 항목별 구현 위치·TC·Then 단언 대조와 diff → 스펙 역대조(대화 이력 없는 subagent) + 보안 경계 mutation 표 + 차단 장치의 이전 버전 비교 + 변경 범위 점검. chore 는 대조 생략 |
| `/add:ship` | 커밋(막는 장치를 바꾸면 push 전 사전 리뷰) → draft PR → CI·리뷰 조사 → 후속 건 이슈 등록(`pr` 은 후보 보고) → 반복 지적은 규칙화 이슈로 → 멈춤 판정(B·S 는 재리뷰 2라운드까지, Nits 만 남으면 merge 가능) → 자율 범위에 따라 보고 또는 merge |
| `/add:release <버전>` | 자동 테스트가 없는 TC 확인 → 태그 → 릴리스 워크플로 확인 → 배포 후 확인 목록 |
| `/add:handoff` | main 클론의 `.add/handoff.md` 에 현재 상태 기록 |

## 프로젝트에 생기는 것

| 경로 | 역할 |
| --- | --- |
| `CLAUDE.md` | 규칙 원본: 원칙, 절차, 검증 명령, 성숙도, 자율 범위, GIT, 문서·주석 |
| `docs/specification.md` | 색인 + 공통 제약 |
| `docs/spec_{function}.md` | 기능별 스펙 (§1~§7) |
| `docs/rules_spec.md` | 스펙 작성 규칙 |
| `.claude/settings.json` | 자율 범위 `pr` 에 필요한 권한, 비밀 파일 Read 거부, 커밋 직전 hook (비밀 파일, 검증 뒤 변경), merge 게이트 hook. hook 이 실패해도 막음 |
| `.claude/hooks/merge-gate.sh` | `gh pr merge` 직전에 CI 통과, 현재 head 의 리뷰 요약(작성자 확인), Blocking 0건, `--match-head-commit` 을 확인하고 아니면 막음 |
| `.claude/hooks/verify.sh` | 추적성 검사 + 검증 명령. 통과한 작업 트리를 기록하고, 커밋 직전에 달라졌으면 막음 |
| `.github/workflows/ci.yml` | 비밀 파일 가드 + 추적성 검사 + 검증 명령 |
| `.github/spec-trace.sh` | 스펙 ↔ TC ↔ 테스트 이름 대조 (누락, 고아 TC, `[확인필요]`, 형식 위반, 테스트 삭제 경고). 성숙도 `poc` 는 보고만 |
| `.github/secret-files.regex` | 커밋되면 안 되는 파일 목록. CI 가드와 `.claude/settings.json` 의 커밋 직전 hook 이 함께 읽음 |
| `.github/workflows/claude.yml` | 이슈·PR 의 `@claude` (소유자·협업자만, 리뷰·질의응답 전용으로 커밋·push 차단). 리뷰 `github` 일 때만 |
| `.github/workflows/claude-review.yml` | PR 자동 리뷰 (같은 저장소 브랜치만, 양식 고정). 리뷰 `github` 일 때만. `local` 이면 `/add:ship` 이 로컬 subagent 로 리뷰 |
| `.github/workflows/release.yml` | `v*` 태그 → 검증 → 산출물 → GitHub Release |
| `.github/ISSUE_TEMPLATE/`, `pull_request_template.md` | 스토리·인수 조건, 재현 절차, chore, PR 검증 항목 |

### 자율 범위

| 값 | agent 가 묻지 않고 하는 일 |
| --- | --- |
| `pr` (기본) | draft PR, CI, 리뷰 조사·보고까지. 반영·merge 는 지시 후 |
| `merge` | 리뷰 반영·squash merge 까지 |

어느 쪽이든 스펙에 없는 결정, 비용, 클라우드·Secrets, 운영 데이터, 자율 범위·성숙도의 변경은 먼저 묻는다.

## 저장소 구조

```
.claude-plugin/marketplace.json   # 마켓플레이스 → plugins/add
plugins/add/
  .claude-plugin/plugin.json
  skills/<명령>/SKILL.md
  agents/                         # 읽기 전용 리뷰·스펙 대조 agent
  hooks/                          # handoff 주입, 읽기 전용 agent 의 원격 쓰기 차단, 리뷰 양식 검사, 압축 시 보존 항목
  template/                       # /add:init 이 복사하는 프로젝트 틀
docs/benchmark.md
```
