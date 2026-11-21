# agentic-dev-kit — 검증 명령 건너뛰기

## 1. 개요

- 문서 정보: 작성 2026-11-21 / 기준 커밋 `412c72a` (origin/main) / 이슈 GH#87
- 기능: 템플릿 `.claude/hooks/verify.sh` 가 마지막 전체 통과 뒤 바뀐 파일이 모두 저장소가 정한 "테스트 무관" 범위 안이면 검증 명령을 건너뛰고 통과를 기록한다
- 목적 (Why)
  - pre-commit 은 마지막 통과 때의 작업 트리와 다르면 커밋을 막고, `verify.sh` 는 매번 검증 명령 전체를 돌린다.
  - 테스트가 읽지 않는 파일(문서·워크플로 등)만 바꾼 커밋도 전체 테스트를 기다린다 → 그 테스트는 이 변경에 대해 확인해 주는 것이 없다.

## 2. 목표 및 범위

- In Scope: 템플릿 `verify.sh` 의 건너뛰기 판정, 범위 파일 `.github/verify-skip-paths` 와 자리표시자 `{{VERIFY_SKIP_PATHS}}`, init 질문 표·`update.md` 읽는 곳 표, `tests/render.sh`, 템플릿·adk `CLAUDE.md` 원칙·검증 절, `/adk:verify` 1, README 파일 표, `tests/mutations.tsv`
- Out of Scope
  - CI 의 건너뛰기 → CI 는 항상 검증 명령 전체를 돌린다 (D2)
  - 템플릿 `ci.yml`·adk `test.yml` 변경
  - adk 자신의 범위 값 → 비워 둔다. adk 테스트는 템플릿·스킬·README·docs 를 읽으므로 테스트 무관 경로가 없다

## 3. 요구사항

### 3.1 사용자 스토리

- `US#1` 템플릿을 적용한 저장소의 agent 로서, 테스트가 읽지 않는 파일만 바꾼 커밋에서 전체 테스트를 기다리지 않기 위해, `verify.sh` 가 변경 범위에 따라 검증 명령을 건너뛰기를 원한다 [요구사항] → FR#1~FR#6

### 3.2 기능 요구사항

- `FR#1` [요구사항] 건너뛰기 조건이 모두 맞으면 `verify.sh` 는 검증 명령을 돌리지 않고 작업 트리 해시를 기록한다. hook 경로 확인과 추적성 검사는 지금처럼 먼저 돌린다.

  ```
  Given 마지막 전체 통과 트리가 기록돼 있고
    And 그 트리와 지금 작업 트리(미추적 포함) 사이에 바뀐 파일이 1개 이상이고
    And 바뀐 파일이 모두 .github/verify-skip-paths 의 pathspec 에 맞고
    And 바뀐 파일에 .github/verify-skip-paths 와 .claude/hooks/verify.sh 가 없음
  When sh .claude/hooks/verify.sh
  Then 검증 명령을 실행하지 않음, 종료 코드 0
    And 건너뛴 사실·기준 트리·바뀐 파일 목록을 출력
    And 이어서 --check 가 통과
  ```

- `FR#2` [요구사항] 건너뛰기 조건 하나라도 맞지 않거나 판정할 수 없으면 지금처럼 검증 명령 전체를 실행한다 → 판정 실패가 조용한 통과가 되지 않는다.

  ```
  Given 다음 중 하나
    - 범위 밖 파일이 하나라도 바뀜
    - 바뀐 파일이 0개 (마지막 전체 통과 트리와 같음)
    - 전체 통과 기록이 없음 (새 워크트리 포함)
    - 기록된 트리를 git 이 읽지 못함 (손상·gc)
    - .github/verify-skip-paths 가 없거나 유효한 줄이 없음
    - .github/verify-skip-paths 또는 .claude/hooks/verify.sh 가 바뀜
  When sh .claude/hooks/verify.sh
  Then 검증 명령을 실행하고 그 종료 코드를 따름
  ```

- `FR#3` [요구사항] 바뀐 파일은 이름 바꾸기를 감지하지 않고 센다 → 범위 밖 경로에서 범위 안으로 옮긴 파일의 원래 경로도 범위 밖 변경으로 센다.

  ```
  Given 마지막 전체 통과 뒤 src/a 를 docs/a 로 옮김 (docs/ 만 범위)
  When sh .claude/hooks/verify.sh
  Then 검증 명령을 실행
  ```

- `FR#4` [요구사항] 전체 통과 기록은 검증 명령이 통과했을 때만 갱신한다. 건너뛴 실행은 작업 트리 해시(pre-commit 용)만 기록한다 → 기록은 마지막으로 테스트를 돌린 트리를 가리킨다.

  ```
  Given 트리 A 에서 전체 통과, docs 만 바꾼 트리 B 에서 건너뜀
  When B 의 변경을 되돌려 A 와 같은 트리에서 sh .claude/hooks/verify.sh
  Then A 대비 변경 0건이므로 검증 명령을 실행 (FR#2)
  ```

- `FR#5` [요구사항] 범위 파일 `.github/verify-skip-paths` 는 한 줄에 git pathspec 하나다. 매직 시그니처(`:(glob)` 등)는 쓰지 않는다 → 판정이 `:(exclude)` 를 앞에 붙인다. 줄 끝 공백·CR 은 떼고 읽고, 빈 줄과 `#` 으로 시작하는 줄은 무시하고, 형식과 주의 사항은 템플릿 범위 파일의 `#` 줄에 적는다. 템플릿은 자리표시자 `{{VERIFY_SKIP_PATHS}}` 한 줄을 두고, init 은 기본값 "없음"(줄 삭제)으로 묻고, `--update` 는 그 파일의 줄을 읽는다.
- `FR#6` [요구사항] CI 는 건너뛰지 않고 검증 명령 전체를 돌린다. 템플릿·adk `CLAUDE.md` 의 원칙 "검증 명령은 하나다" 에 로컬 건너뛰기의 조건과 전제(범위가 맞을 때만 로컬 통과 = CI 통과)를 적는다.

### 3.3 비기능 요구사항

- `NFR#1` [요구사항] 건너뛰기 조건은 막는 장치의 통과 경로다 → 조건마다 `tests/mutations.tsv` 행을 두고, 조건을 지우면 테스트가 실패해야 한다.
- `NFR#2` [요구사항] 판정은 POSIX sh 와 git 만 쓴다 → gawk·mawk·BSD awk 와 무관하게 같은 결과다.

## 6. 동작 로직 및 정책

### 6.1 판정 [FR#1 FR#2 FR#3 FR#4]

- 전체 통과 기록: `git rev-parse --git-path add-verified-full` (워크트리마다 따로) 에 tree 해시
- 바뀐 파일: `git diff --name-only --no-renames <기록 트리> <지금 tree()>` → 미추적 파일은 `tree()` 가 담는다. 출력과 범위 파일·`verify.sh` 변경 판정에 쓴다
- 범위 밖 파일: `git diff --name-only <기록 트리> <지금 tree()> -- . ':(exclude)<pathspec>'…` → 비어 있어야 건너뜀
  - pathspec 은 이름 바꾸기 감지보다 먼저 적용된다 → 범위 밖에서 옮겨 온 파일의 원래 경로가 남는다 [FR#3]
  - 범위 파일이 없거나 유효 줄이 없으면 제외가 없어 바뀐 파일과 같은 목록 → 건너뛰지 않는다 [FR#2]

### 6.2 설계 결정

| D | 결정 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| D1 | 기준은 마지막 전체 통과 트리 [FR#1 FR#4] (저장소 소유자 결정 2026-11-21) | `origin/main` 분기점 | 분기점 대비면 앞선 커밋이 코드를 바꾼 브랜치는 문서만 고쳐도 다시 전체 실행이다. 이미 테스트한 트리와의 차이만 보면 된다 |
| D2 | CI 는 항상 전체 실행 [FR#6] (저장소 소유자 결정 2026-11-21) | CI 도 같은 판정 | 시간이 아까운 곳은 로컬 커밋이다. CI 는 로컬 기록을 볼 수 없어 D1 기준으로 같은 판정을 낼 수 없다 |
| D3 | 범위는 저장소마다 자리표시자로 정하고 기본값은 없음 [FR#5] (저장소 소유자 결정 2026-11-21) | 막는 장치 경로(`.github/` 등)를 기본 포함 | 장치 테스트가 검증 명령에 있는 저장소에서 테스트 없이 통과한다 |
| D4 | 범위는 git pathspec 허용 목록 [FR#5] | 정규식 (`secret-files.regex` 와 같은 형식) | 앵커 없는 정규식은 의도보다 넓게 맞는다 (`docs` 가 `src/docs_impl.c` 에 맞음). pathspec 은 경로 접두로 맞는다 |
| D5 | 변경 0건은 전체 실행 [FR#2] | 건너뜀 | 새 워크트리 기준선·의존성 갱신 뒤처럼 같은 트리를 다시 검증하려는 실행을 막지 않는다 |
| D6 | 범위 파일·`verify.sh` 가 바뀌면 전체 실행 [FR#1 FR#2] | 범위 판정만 적용 | 범위를 넓히거나 검증 명령을 바꾸는 변경이 자기 자신을 건너뛰게 할 수 없다 |

## 7. 테스트 및 검증 기준

| TC | 대상 | Then | 비고 |
| --- | --- | --- | --- |
| TC#103 | FR#1 FR#5 | 전체 통과 뒤 범위 안 파일만 바꾸면(미추적 포함, 범위 파일의 빈 줄 뒤 pathspec 도 유효) 검증 명령 미실행·0·`--check` 통과·건너뜀·기준 트리·파일 출력, 추적성 검사 실패면 건너뛰지 않고 실패 | `tests/verify.test.sh` |
| TC#104 | FR#2 FR#5 | 범위 밖 변경·변경 0건·기록 없음·기록 손상·범위 파일 없음·유효 줄 없음·범위 파일 변경·`verify.sh` 변경·범위 파일 `#` 줄과 같은 이름의 파일 → 검증 명령 실행, 그 종료 코드를 따름 | `tests/verify.test.sh` |
| TC#105 | FR#3 | 범위 밖 → 범위 안으로 옮긴 파일 → 검증 명령 실행 | `tests/verify.test.sh` |
| TC#106 | FR#4 | A 전체 통과 → B 건너뜀 → B 를 되돌려 A 와 같은 트리 → 검증 명령 실행 | `tests/verify.test.sh` |
| TC#107 | FR#5 | 렌더 결과에 `.github/verify-skip-paths` 가 있고 자리표시자가 남지 않음 | `tests/render.test.sh` |
| TC#108 | FR#5 FR#6 | init 질문 표·`update.md` 읽는 곳 표·템플릿·adk `CLAUDE.md` 원칙·`/adk:verify` 1·README 파일 표·범위 파일 주석이 같은 범위·조건을 적음, `ci.yml` 은 그대로 | (수동) 대조 |
| TC#109 | NFR#1 NFR#2 | 건너뛰기 조건마다 mutation 행이 있고 조건을 지우면 테스트가 실패, ubuntu gawk·mawk·macOS 에서 같은 결과 | (수동) CI `mutation`·`sh` job 결과 확인 |
| TC#110 | FR#5 | CRLF 범위 파일·줄 끝 공백이 붙은 pathspec 도 범위로 읽어 건너뜀, 공백만 있는 줄은 무시 | `tests/verify.test.sh` |

## 부록 — 변경 이력

- GH-87: 테스트 무관 범위만 바뀌면 검증 명령을 건너뜀
- GH-89: 범위 파일 줄 끝 공백·CR 을 떼고 읽음
