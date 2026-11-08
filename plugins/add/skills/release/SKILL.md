---
name: release
description: 버전 태그를 만들어 릴리스 워크플로를 실행하고, 배포 결과와 배포 후 확인 목록을 보고한다. 저장소 소유자가 배포를 지시했을 때 쓴다.
argument-hint: "<버전, 예: 1.2.0>"
disable-model-invocation: true
---

# /add:release

## 1. 상태 조회

- `git fetch --tags` 후 `main` 이 원격과 같은지, 열린 PR 중 이번 릴리스에 들어가야 하는 것이 없는지 조회한다.
- `main` 의 최신 CI 가 통과인지 확인한다.
- 버전 형식은 `v{major}.{minor}.{patch}`. 저장소 소유자가 준 번호를 쓰고, 없으면 지난 태그 이후 변경으로 제안한다 (기능 추가 → minor, 수정만 → patch).

## 1-1. 자동 테스트가 없는 TC

- `sh .github/spec-trace.sh` 의 `M MANUAL` 행(비고가 `(통합` / `(수동)` 인 TC)을 목록으로 낸다 → 테스트가 통과해도 이 TC 들은 확인된 것이 아니다.
- 성숙도 `alpha` 이상이면 TC 마다 이번 릴리스 대상 커밋에서 확인한 방법과 결과를 받는다. 확인하지 않은 TC 가 남으면 태그를 만들지 않고 보고한다 (CLAUDE.md 성숙도 표 "실기기·통합 확인").
- `poc` 는 목록만 보고한다.

## 2. 노트

- `git log <지난 태그>..origin/main --oneline` 과 merge 된 PR 목록으로 사용자 관점 변경 요약을 만든다. 첫 릴리스면 `git log origin/main --oneline` 전체로 만든다.
- 사용자가 할 일(재설치, 권한 재허용, 설정 변경)이 있으면 맨 위에 둔다.

## 3. 태그

- 노트를 보여 주고 확인을 받은 뒤 `git tag v<버전> origin/main` → `git push origin v<버전>`
- `gh run watch` 로 Release 워크플로를 끝까지 본다. 실패하면 로그 요약과 원인을 보고하고, 태그를 지우거나 다시 만들지는 묻는다.
- 성공하면 확인받은 노트로 바꾼다: `gh release edit v<버전> --notes-file <노트 파일>` → 워크플로의 자동 노트에는 "사용자가 할 일" 이 없다.

## 4. 배포 후 확인

- 성숙도(`CLAUDE.md`)에 따른 확인 목록을 낸다.
  - beta 이상: 핵심 사용자 흐름, 설정·권한 유지, 이전 버전에서의 업데이트
  - ga: 위 + 롤백 방법
- 실기기·운영 환경 확인은 사용자 환경에서만 가능한 것과 agent 가 직접 확인한 것을 나눠 적는다.
- 검증용으로 설치한 debug 산출물이 실사용 환경에 남아 있으면 지울지 묻는다.
