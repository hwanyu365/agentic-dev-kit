# 3-5. 사람 리뷰·승인이 필요한 저장소

해당 여부는 `/adk:ship` 3-5 가, 순서는 자율 범위 `pr` 의 팀원 리뷰 대응에서 `/adk:watch` 가 따른다.

## 해당 여부

- 조회로 정한다. 하나라도 맞으면 해당한다.
  - 브랜치 보호의 `required_pull_request_reviews.required_approving_review_count` 가 1 이상 (`gh api repos/{owner}/{repo}/branches/{base}/protection`)
  - ruleset 의 `pull_request` 규칙에서 `required_approving_review_count` 가 1 이상 (`gh api repos/{owner}/{repo}/rules/branches/{base}`)
  - PR 에 bot 이 아닌 계정의 리뷰 요청이나 리뷰가 있음 (`gh pr view <번호> --json reviewRequests,reviews`)
  - 보호·ruleset 조회가 404(설정 없음)나 플랜 미지원 403 이 아닌 이유로 실패하면 해당으로 본다 → 모르는 채로 merge 하지 않는다.

## 순서

- 지적을 반영한 뒤에는 amend·push → 회신·resolve → 재리뷰 요청 순서로 한다.
- amend·push
  - 기존 커밋에 `--amend` → `git push --force-with-lease`. 자율 범위 `merge` 여도 새 커밋을 만들지 않는다 → 리뷰어는 force-push 의 비교 링크로 이번 변경분을 본다.
- 회신
  - inline 지적은 그 스레드에 답글을 단다: 반영 커밋 SHA / 미반영 근거 / 이슈 번호 → 사람 리뷰어는 지적한 자리에서 답을 찾는다.
    - `gh api repos/{owner}/{repo}/pulls/{번호}/comments/{comment_id}/replies -f body=...`. `comment_id` 는 스레드 첫 코멘트다 → 답글에 다는 답글은 API 가 받지 않는다.
  - 리뷰 본문의 지적과 전체 처리 결과는 3-2 의 "리뷰 대응" 코멘트로 남긴다.
  - 답글을 단 스레드는 resolve 한다 → 남은 미해결 스레드가 처리하지 않은 지적이다. 리뷰어는 재리뷰에서 다시 열 수 있다.
    - `gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' -f id=<thread id>`. thread id 는 `gh api graphql` 의 `repository(owner:, name:){pullRequest(number:){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{databaseId}}}}}}` 에서 첫 코멘트의 `databaseId` 가 답글 단 `comment_id` 인 것을 고른다.
- 재리뷰 요청
  - 지적을 남긴 사람 리뷰어마다 `gh api -X POST repos/{owner}/{repo}/pulls/{번호}/requested_reviewers -f 'reviewers[]=<login>'` → 이미 리뷰한 리뷰어도 다시 요청된다.
  - `gh pr view <번호> --json reviewRequests` 로 요청이 걸렸는지 확인한다.
- merge 는 3-4 판정에 더해 승인을 조회로 확인한 뒤에 한다. 리뷰 목록은 `gh api --paginate repos/{owner}/{repo}/pulls/{번호}/reviews --jq '.[] | [.user.login, .state, .commit_id, .submitted_at] | @tsv'` 로 읽는다.
  - `--paginate` 가 없으면 30건까지만 온다. `--jq` 는 페이지마다 따로 적용되므로 리뷰를 한 줄씩 펼쳐 내고, 리뷰어별 집계는 모든 줄을 합친 뒤 `submitted_at` 순으로 한다 → 페이지 안에서 집계하면 다른 페이지의 `CHANGES_REQUESTED` 를 놓친다. `--slurp` 는 `--jq` 와 함께 쓸 수 없다.
  - 리뷰어마다 `APPROVED`·`CHANGES_REQUESTED`·`DISMISSED` 중 가장 최근 것을 그 리뷰어의 최근 리뷰로 본다. `COMMENTED` 는 건너뛴다 → 스레드 답글도 `COMMENTED` 리뷰로 쌓여 승인을 가린다.
  - `reviewRequests` 가 비어 있다 → 재리뷰를 요청한 리뷰어가 아직 답하지 않았으면 merge 하지 않는다.
  - 지적을 남긴 사람 리뷰어(bot 제외 → Claude 리뷰는 3-4 판정으로 본다)마다 최근 리뷰가 `APPROVED` 이고 `commit_id` 가 현재 head 다.
  - 현재 head 의 `APPROVED` 수가 필요 승인 수(`/adk:ship` 3-5 의 보호·ruleset 조회값, 없으면 1) 이상이다 → 브랜치 보호가 이전 승인을 무효로 하지 않으면 반영 전 head 의 승인이 남는다.
