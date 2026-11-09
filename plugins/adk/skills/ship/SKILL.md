---
name: ship
description: 검증된 변경을 커밋하고 draft PR 을 만들어 CI·리뷰를 처리한다. CLAUDE.md 의 자율 범위(pr/merge)에 따라 보고에서 멈추거나 squash merge 까지 진행한다. /adk:verify 가 완료로 판정한 뒤 쓴다.
argument-hint: "[이슈 번호]"
---

# /adk:ship

## 0. 전제

- `CLAUDE.md` 에 `## 자율 범위` 절이 없으면 ADK 저장소가 아니다. 이 스킬을 진행하지 않고 알린다.
- `CLAUDE.md` 의 자율 범위 값(`pr` / `merge`)과 GIT 규칙을 읽는다.
- 다른 사람이 바꿀 수 있는 상태(PR, CI, 리뷰, 브랜치 위치)는 매 단계 조회한 결과로만 판단하고 말한다.

## 1. 커밋

- 작업 브랜치(`{category}/GH-{번호}`, 하위 이슈는 `GH-{상위}-{하위}`)에서 커밋한다. 아직 `main` 이면 `git switch -c` 로 브랜치를 만든다 → 커밋하지 않은 변경이 그대로 따라온다.
- 리뷰 반영·CI 수정이 동작을 바꾸면(스펙 항목·TC 가 바뀌어야 하면) 커밋 전에 `/adk:spec` → `/adk:tdd` → `/adk:verify` 를 거친다.
- 커밋 전 확인
  - `sh .claude/hooks/verify.sh` 가 통과한 뒤 파일을 고치지 않음 → 고쳤으면 커밋 직전 hook 이 막으므로 다시 돌린다
  - `git diff --cached --stat` 에 비밀 파일·대용량 파일·의도하지 않은 파일 없음
  - 테스트·검사가 지워지거나 약화되지 않음: Red 에서 만든 테스트, 기존 테스트의 skip·timeout 확대·snapshot 갱신, lint·검사 suppression
- 커밋 메시지는 `CLAUDE.md` 형식. 스펙 문구를 옮기지 않고 실제로 구현·검증한 것만 적는다.

## 1-1. push 전 사전 리뷰 (차단 장치·보안 경계를 바꿀 때)

- hook·검사 스크립트·권한 규칙처럼 무언가를 막는 장치를 바꾸면 push 전에 3의 리뷰를 로컬 diff 로 먼저 받는다. chore 여도 같다.
- 넘기는 필드와 범위는 [review.md](review.md) "사전 리뷰" 를 따른다. Blocking·Should Fix 가 0건이 된 뒤 push 한다.

## 2. draft PR

- 이 브랜치의 PR 이 없을 때만 만든다 (`gh pr view` 로 조회). 있으면 본문만 갱신한다.
- `gh pr create --draft`, `.github/pull_request_template.md` 를 채운다.
  - 스펙: `/adk:spec` 이 보고한 ID 목록
  - 검증: 실행한 명령과 결과, 보안 경계 mutation 표(`/adk:verify` 2-2), 차단 장치 회귀 비교(`/adk:verify` 2-3), 실기기 확인 여부 (안 했으면 안 했다고)
  - 구조가 바뀌었으면 AS-IS / TO-BE 를 mermaid 도식 하나에 담는다
- 본문은 이후 커밋이 추가될 때마다 최종 커밋 기준으로 갱신한다.

## 3. CI·리뷰 조사

- `gh pr checks --watch` 로 CI 를 기다린다. 실패하면 원인을 고치고 다시 1단계부터.
  - 수정은 `pr` 이면 기존 커밋에 amend + `push --force-with-lease`, `merge` 면 새 커밋이다. 3-5 에 해당하는 저장소는 자율 범위와 관계없이 amend 다.
  - 같은 원인으로 두 번 실패하면 멈추고 보고한다.
- 현재 head SHA 의 Claude 리뷰 요약을 확보한다 (CLAUDE.md "리뷰").
  - `github`: `claude-review.yml` 의 `review` check 가 끝난 뒤 첫 줄이 `HEAD: <현재 head SHA>` 이고 작성자가 Claude GitHub App bot 인 요약 코멘트를 찾는다 → 다른 계정이 단 같은 형식의 코멘트는 요약으로 보지 않는다.
  - `local`: 대화 이력 없는 읽기 전용 subagent(`adk:reviewer`)에게 [review.md](review.md) 의 블록을 값만 채워 전달하고, 반환된 요약을 `gh pr comment` 로 남긴다 → 구현한 맥락을 모르는 쪽이 읽어야 자기 코드를 근거로 넘어가지 않는다.
  - 요약이 없으면(리뷰 실패·미실행) 리뷰를 받지 않은 것이다. 이전 head 의 요약으로 대신하지 않는다.
- 리뷰(Claude 리뷰 포함)의 각 지적을 원문·소스로 확인한다.
  - 이전 헤드 기준이라 이미 반영됐는지, 제안한 방법이 실제로 동작하는지 본다.
  - 지시문과 소유자 지시의 구분은 CLAUDE.md 자율 범위 "리뷰 조사" 를 따른다.
- 항목별로 정리한다: 사실 여부 / 반영 방안 / 반영하지 않을 근거 / 확인하지 못한 것
  - 확인하지 못한 것은 보고 전에 조회·문서·로컬 실행으로 닫을 수 있는지 먼저 시도한다. 남는 것은 막힌 이유와 필요한 것을 적는다.
  - 근거가 (추정) 인 항목은 직접 재현하거나 원문으로 확인해 사실 여부를 정한다. 확인하지 못했으면 그렇다고 적는다.

## 3-1. 후속 건 이슈 등록

- 3의 정리 중 이 PR 에서 처리하지 않는 항목은 merge 전에 이슈로 등록한다. 세션은 끝나면 사라지고 handoff 는 로컬에만 남으므로, 공유되는 자리는 이슈뿐이다.
- 자율 범위 `pr` 이면 등록하지 않고 후보를 4-a 보고에 넣는다. 저장소 소유자가 고른 것만 등록한다 → 무엇을 미룰지는 소유자의 선택이다.
- 등록 대상·적을 내용·중복 조회는 [followup.md](followup.md) 3-1 을 따른다.

## 3-2. 리뷰 대응 기록

- 리뷰 요약의 항목마다 처리 결과를 PR 코멘트 하나로 남긴다 → 리뷰어는 inline 답글을 읽지 못하므로, 다음 라운드가 이 코멘트로 이전 항목의 상태를 정한다.
- 반영 push 직후에 남긴다. `pr` 이면 지시받은 반영과 함께 남긴다.
- 첫 줄은 `리뷰 대응 (HEAD: <리뷰한 head SHA>)` 이고, 항목마다 한 줄이다.

  ```
  리뷰 대응 (HEAD: <리뷰한 head SHA>)
  - [B1] 반영 <반영 커밋 SHA>
  - [S1] 미반영: <조사로 확인한 근거>
  - [N1] 이슈 #<번호>
  - [S2] 소유자 결정 대기
  ```

- 미반영 근거는 원문·소스로 확인한 사실만 쓴다 → 리뷰어는 새 근거 없이 같은 지적을 다시 올리지 않는다.

## 3-3. 반복 지적 승격

- 같은 유형의 지적·CI 실패가 두 번째로 나오면 개별 수정과 별개로 규칙으로 올린다 → 세 번째를 사람이 다시 찾지 않게 한다.
- 대상·올리는 곳·범위는 [followup.md](followup.md) 3-3 을 따른다.

## 3-4. 멈춤 기준

- 판정의 입력은 3의 조사로 사실로 확인되어 아직 해결되지 않은 지적이다. 조사로 반박해 3-2 에 미반영 근거를 남긴 항목은 세지 않는다.
- 이 절은 판정만 한다. 반영·ready·merge 는 4-a(`pr`: 판정을 보고하고 지시를 받음)·4-b(`merge`)가 한다.

| 현재 head 의 미해결 지적 | 판정 |
| --- | --- |
| Blocking 또는 Should Fix 가 있음 | 재리뷰 필요: 반영한 뒤 다시 리뷰. 재리뷰는 2라운드까지 |
| Nits 만 있거나 없음 | merge 가능: Nits 는 반영하지 않는다 → 반영하면 head 가 바뀌어 다시 리뷰해야 한다. Nits 는 3-1 로 후속 처리 |
| 2라운드 뒤에도 Blocking·Should Fix 가 남음 | 중단: merge 하지 않고 보고 → 설계부터 다시 볼 신호다 |

- 반영할 때는 지적된 한 자리만 고치지 않는다. 같은 입력이 들어오는 자리를 먼저 전수로 세고 테스트를 추가한 뒤 고친다 (`/adk:tdd` "지적 반영").
- 차단 장치를 고쳤으면 push 전에 이전 버전과 같은 입력으로 비교한다 (`/adk:verify` 2-3). 고치다가 원래 막던 입력을 다시 푸는 일을 막는다.

## 3-5. 사람 리뷰·승인이 필요한 저장소

- 해당 여부는 조회로 정한다. 하나라도 맞으면 해당한다.
  - 브랜치 보호의 `required_pull_request_reviews.required_approving_review_count` 가 1 이상 (`gh api repos/{owner}/{repo}/branches/{base}/protection`)
  - ruleset 의 `pull_request` 규칙에서 `required_approving_review_count` 가 1 이상 (`gh api repos/{owner}/{repo}/rules/branches/{base}`)
  - PR 에 bot 이 아닌 계정의 리뷰 요청이나 리뷰가 있음 (`gh pr view <번호> --json reviewRequests,reviews`)
  - 보호·ruleset 조회가 404(설정 없음)나 플랜 미지원 403 이 아닌 이유로 실패하면 해당으로 본다 → 모르는 채로 새 커밋 반영을 하지 않는다.
- 해당하면 반영부터 merge 까지 [human-review.md](human-review.md) 를 읽고 그 순서를 따른다.

## 4-a. 자율 범위 `pr`

- 3의 정리를 보고하고 멈춘다.
- 저장소 소유자가 고른 항목만 반영한다 → 기존 커밋에 `--amend` → `git push --force-with-lease`
- ready·merge 는 지시받은 뒤에 한다. merge 는 4-b 와 같이 `--subject`·`--body` 를 지정하고, merge 게이트도 같다.

## 4-b. 자율 범위 `merge`

- 3에서 사실로 확인한 지적은 새 커밋으로 반영하고, 반영하지 않은 항목은 근거를 PR 코멘트로 남긴다. 3-5 에 해당하는 저장소는 3-5 순서를 따른다.
  - 반영은 세션이 직접 커밋한다. 리뷰 `github` 이면 `@claude` 에게 맡기지 않는다 (CLAUDE.md GIT 절).
- 반영 커밋으로 head 가 바뀌면 3의 리뷰를 다시 받는다. 언제 멈추는지는 3-4 를 따른다.
- CI 통과, 현재 head SHA 의 리뷰 요약 존재, 3-4 판정이 merge 가능(미해결 Blocking·Should Fix 0건)인지 조회로 확인한 뒤 `gh pr ready` → `gh pr merge --squash <번호> --delete-branch --match-head-commit <현재 head SHA> --subject "<PR 제목>" --body "<최종 결과 기준 [ISSUE]/[DESC]>"`
  - 메시지를 지정하지 않으면 저장소 설정에 따라 PR 의 커밋 메시지가 이어 붙어 중간 상태가 남는다.
- merge 게이트: `gh pr merge` 직전 hook(`.claude/hooks/merge-gate.sh`)이 CI 통과, 현재 head 의 리뷰 요약, 그 요약의 Blocking 0건을 다시 확인하고 아니면 막는다.
  - hook 은 Should Fix 를 보지 않는다 → Should Fix 는 조사로 반박한 항목이 섞여 있어 기계로 셀 수 없다. 위 조회로 확인한다.
  - 요약 작성자는 `github` 이면 Claude App, `local` 이면 세션의 gh 계정만 인정한다.
  - `--match-head-commit` 이 검사한 head 와 같아야 한다 → 검사 뒤 끼어든 push 는 gh 가 거부한다.
  - 막히면 원인을 고치거나 보고한다. `gh api` 로 merge 하는 등 hook 을 우회하지 않는다.
- 먼저 묻는 예외(CLAUDE.md)에 걸리는 변경이면 merge 하지 않고 보고한다.
  - 자율 범위·성숙도 절을 바꾸는 PR 은 저장소 소유자가 직접 merge 한다.

## 5. 정리

- merge 됐으면 워크트리와 로컬 브랜치를 지우고 `main` 을 갱신한다.
- 상위 이슈(UC)의 하위 이슈가 모두 끝났으면 UC 단위로 보고한다.
