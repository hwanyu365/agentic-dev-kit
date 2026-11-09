---
name: init
description: 현재 저장소에 SDD + TDD 프로젝트 틀(CLAUDE.md, 스펙 골격, CI·Claude 워크플로, 이슈·PR 템플릿)을 복사하고 자리표시자를 인터뷰로 채운다. 새 프로젝트를 이 틀로 시작하거나 기존 저장소에 도입할 때 쓴다. --update 는 이미 적용된 저장소를 현재 템플릿에 맞춘다.
argument-hint: "[--quick | --update]"
disable-model-invocation: true
---

# /adk:init

- `--update` 면 1~5 대신 6을 한다. 3·4·5 는 6 이 가리킨 부분만 쓴다.

## 1. 사전 확인

- git 저장소 루트인지, 작업 트리가 깨끗한지 확인한다. 아니면 멈추고 알린다.
- `${CLAUDE_PLUGIN_ROOT}/template/` 의 파일 목록을 대상 경로와 비교한다.
  - 이미 있는 파일은 덮어쓰지 않는다. 충돌 목록을 보여 주고 파일마다 병합·건너뛰기를 묻는다.
- 기존 코드가 있으면 스택·검증 명령·테스트 위치를 코드에서 먼저 읽어 기본값으로 쓴다 (빌드 파일, CI 설정, 테스트 디렉터리).

## 2. 인터뷰

- 시작 전에 질문 수와 예상 시간을 알린다.
- 한 번에 하나만 묻고, 각 질문에 기본값 또는 권장안을 붙인다. `--quick` 이면 코드에서 확정한 값은 묻지 않는다.
- 사용자가 이해하지 못했다고 하면 쉬운 말로 다시 설명하고 선택지로 다시 묻는다. 기본값을 동의로 간주하지 않는다.

| 자리표시자 | 질문 | 기본값 |
| --- | --- | --- |
| `{{PROJECT}}` | 프로젝트 이름 | 저장소 이름 |
| `{{SUMMARY}}` | 한 줄 설명 (누가, 무엇을, 왜) | — |
| `{{OWNER_REPO}}` | GitHub `owner/repo` | `gh repo view --json nameWithOwner` |
| `{{STACK}}` | 언어·프레임워크·주요 의존성과 선택 이유 | 코드에서 읽은 값 |
| `{{VERIFY_CMD}}` | 로컬과 CI 가 같이 돌릴 검증 명령 (lint + 타입 + 테스트). `CLAUDE.md`·`ci.yml`·`.claude/hooks/verify.sh` 에 들어간다 | 스택 관례 |
| `{{VERIFY_ALLOWED_TOOLS}}` | 검증 명령의 Claude 권한 패턴 | `&&` 로 이은 하위 명령마다 정확히 일치하는 `Bash(<하위 명령>)` 하나씩 (앞부분 와일드카드는 publish·install 까지 연다) |
| `{{TEST_LOCATION}}` | 테스트 파일 위치 규칙 | 소스 옆 `{file}.test.*` (사용자 전역 규칙이 있으면 그것), 스택이 강제하면 그 경로와 이유 |
| `{{SECRET_FILES_REGEX}}` | 기본 목록(`.env`, 키 파일, 서비스 계정 키) 밖에 커밋되면 안 되는 스택 설정 파일의 정규식 | 없으면 줄 삭제 |
| `{{CI_SETUP}}` | CI 런타임 준비 step (setup-java, setup-node 등) | 스택 관례 |
| `{{RELEASE_CMD}}` | 태그 시 산출물 빌드·배포 명령 | 없으면 step 삭제 |
| `{{MATURITY}}` | poc / alpha / beta / ga | alpha |
| `{{AUTONOMY}}` | pr (리뷰 반영·merge 는 지시 후) / merge (merge 까지 자동) | pr |
| `{{REVIEWER}}` | GitHub 에서 Claude(`@claude`·자동 리뷰)를 쓸 수 있는지 → github / local (로컬 세션의 subagent 리뷰) | github |

## 3. 적용

- 템플릿을 복사하고 자리표시자를 치환한다.
  - `{{STACK}}` 이 여러 항목이면 첫 항목이 `- {{STACK}}` 줄을 대신하고, 나머지는 같은 깊이의 글머리로 잇는다.
  - `{{CI_SETUP}}` 은 YAML 주석 줄 `# {{CI_SETUP}}` 전체를 step 들로 바꾼다. 들여쓰기는 주변 step 에 맞춘다.
  - `{{RELEASE_CMD}}` 가 `name`·`env` 를 가진 step 여러 개면 `- run: |` 와 `{{RELEASE_CMD}}` 두 줄을 그 step 들로 바꾼다.
  - `{{CI_SETUP}}`·`{{RELEASE_CMD}}` 로 들어가는 step 의 action 은 템플릿 step 과 같이 커밋 SHA 로 고정하고 버전을 주석으로 단다 → 태그는 옮겨질 수 있다.
  - `{{VERIFY_ALLOWED_TOOLS}}` 는 `.claude/settings.json` 에서는 항목 여러 개, `claude.yml` 에서는 쉼표로 이어 쓴다.
  - `{{SECRET_FILES_REGEX}}` 는 `.github/secret-files.regex` 에 한 줄에 하나씩 넣는다. 빈 줄을 남기지 않는다 → 빈 패턴은 모든 파일에 맞는다.
  - `.github/secret-files.regex` 에 맞는 파일은 `.gitignore` 와 `.claude/settings.json` deny 의 `Read(<glob>)` 에도 넣는다.
  - `claude.yml` 의 `{{CI_SETUP}}` step 에는 `if: steps.secret.outputs.ok == 'true'` 를 붙인다.
  - dependabot 에 스택의 `package-ecosystem` 을 `github-actions` 항목과 같은 형식(월 1회, 생태계마다 group 하나)으로 추가한다.
  - `{{AUTONOMY}}` 는 CLAUDE.md 자율 범위 표와 대체 글머리에서 고르지 않은 값의 행·줄을 지운다. "리뷰 조사 (두 값 공통)" 은 남긴다.
  - `merge` 면 `.claude/settings.json` allow 에 `Bash(gh pr ready:*)`, `Bash(gh pr merge --squash:*)`, `Bash(git worktree remove:*)` 를 더한다.
  - `{{REVIEWER}}` 는 CLAUDE.md "리뷰" 에서 고르지 않은 값의 글머리를 지운다. `local` 이면 `claude.yml`·`claude-review.yml` 을 복사하지 않고, CLAUDE.md GIT 절의 `@claude` 글머리 묶음도 지운다.
- `docs/spec_{function}.md.example` 은 첫 UC 스펙을 쓸 때 복사하도록 그대로 둔다.

## 4. 확인

- `git grep -n -I '{{'` 결과가 0건이어야 한다 (GitHub Actions 의 `${{ }}` 는 제외). `-I` 로 바이너리를 뺀다.
- `sh .claude/hooks/verify.sh` 를 한 번 실행하고 출력을 보여 준다. 실패하면 원인을 보고하고 멈춘다.
  - 기존 스펙이 있으면 추적성 검사가 형식(`docs/rules_spec.md` §2.3) 위반을 낼 수 있다 → 위반 목록을 보여 주고, 스펙을 고칠지 성숙도를 `poc` 로 둘지 묻는다.
    - 고치기로 하면 형식 이전은 이 적용과 별도 이슈·PR 로 먼저 한다 → TC 번호 변경은 테스트 이름까지 바뀌어 틀 적용과 섞으면 리뷰할 수 없다.
    - 형식 이전 PR 은 같은 스펙 파일을 고치는 열린 PR 이 있는지 먼저 조회한다.
    - 형식 이전 PR 은 플러그인 템플릿의 `spec-trace.sh` 를 로컬에서 `-b origin/main` 으로 돌려 E 0건을 확인한다 → 그 PR 의 CI 에는 새 검사기가 아직 없다. 범위는 템플릿 `verify.sh` 와 같게 둔다 → `-b` 없이 돌리면 범위 밖에 원래 있던 `[확인필요]` 까지 E 가 된다.
    - 저장소의 옛 검사기가 새 형식을 막으면 형식 이전 PR 에 검사기 교체를 함께 넣는다.
    - 틀 적용 PR 은 draft 로 올려 두고, 형식 이전이 merge 된 뒤 rebase 해서 검증을 통과시킨다.
  - 테스트가 하나도 없어서 실패하는 것이면 스모크 테스트 하나를 만들어 통과시킨다. 스펙이 없으므로 `TC#n` 이름 규칙의 예외이고, 첫 스펙의 TC 테스트가 생기면 지운다.
- 비밀 파일 정규식이 예시 파일명(`.env`, `release.jks`, `service-account.json`)을 잡고 일반 파일(`README.md`)은 잡지 않는지 `printf ... | grep -Ef .github/secret-files.regex` 로 확인한다.

## 5. 사람이 할 일 목록 출력

- `main` 브랜치 보호: CI job 필수, PR 로만 merge, 관리자 포함 (`gh api` 로 대신 설정할지 묻는다)
  - 브랜치가 최신인지 요구하는 설정은 켠다 → 낡은 CI 결과로 merge 되는 것을 막는다.
  - `github` 리뷰면 `claude-review.yml` 의 `review` job 도 필수 check 로 둔다 → 브라우저에서 merge 해도 리뷰 실패·진행 중이면 막힌다.
  - 브랜치 보호를 쓸 수 없는 저장소(private 무료 플랜: `gh api repos/{owner}/{repo}/branches/main/protection` 이 403)는 이 항목을 건너뛴다 → 설정을 시도하지 않고, merge 조건은 merge 게이트 hook 만 확인한다고 알린다.
  - **미해결 리뷰 대화를 merge 차단 요건으로 만드는 설정은 켜지 않는다.** 지적 하나하나가 차단 요건이 되고, 반영 push 가 리뷰를 다시 깨워 라운드가 끝나지 않는다. 지적은 조사해 판단하고 근거를 남긴다.
  - 커밋 이력을 선형으로 강제하는 설정도 켜지 않는다 → squash 로 올리는 것은 관례로 지키면 되고, 그 설정은 rebase 를 막지 못해 반쪽이다.
- Dependabot 알림과 보안 업데이트 켜기 (Settings → Advanced Security). 무료 플랜 private 저장소도 켤 수 있다 (`gh api -X PUT repos/{owner}/{repo}/vulnerability-alerts`, `.../automated-security-fixes` 로 대신 설정할지 묻는다)
  - `dependabot.yml` 은 버전 따라가기만 한다 → 취약점 알림·수정 PR 은 이 설정이 있어야 온다.
- Secrets: 릴리스용 비밀값. `github` 리뷰면 `CLAUDE_CODE_OAUTH_TOKEN` (`claude setup-token`) 도
- `github` 리뷰면 Claude GitHub App 설치
- 커밋은 저장소의 자율 범위 규칙을 따른다. 아직 규칙이 적용되기 전이므로 첫 커밋은 사용자에게 확인받는다.

## 6. 갱신 (`--update`)

- [update.md](update.md) 를 읽고 그 순서를 따른다.
