# merge 게이트와 스택

`/adk:ship` 2·4-b 와 `/adk:watch` 4 의 세부 절차다.

## merge 게이트 (`gh pr merge`)

- `gh pr merge` 직전 hook(`.claude/hooks/merge-gate.sh`)이 CI 통과, 현재 head 의 리뷰 요약, 그 요약의 Blocking 0건을 다시 확인하고 아니면 막는다. `/adk:ship` 4-b 명령의 플래그 밖(`--admin`·`--auto` 등)을 붙이면 막는다.
  - hook 은 Should Fix 를 보지 않는다 → Should Fix 는 조사로 반박한 항목이 섞여 있어 기계로 셀 수 없다. `/adk:ship` 4-b 의 조회로 확인한다.
  - 요약 작성자는 `github` 이면 Claude App, `local` 이면 세션의 gh 계정만 인정한다. Dependabot PR 은 `/adk:deps` 가 처리한다.
  - `--match-head-commit` 이 검사한 head 와 같아야 한다 → 검사 뒤 끼어든 push 는 gh 가 거부한다.
  - 막히면 원인을 고치거나 보고한다. `gh api` 로 merge 하는 등 hook 을 우회하지 않는다.

## 스택

- 다른 열린 PR 에 의존하는 PR 은 `gh stack` 으로 스택에 묶는다 → base 만 앞 PR 의 브랜치로 지정한 PR 은 스택으로 인정되지 않아 스택 merge 가 동작하지 않는다.
  - `gh-stack` 확장이 없으면(`gh stack --help` 실패) `gh extension install github/gh-stack` 을 안내하고 멈춘다.
  - 새로 만들 때: `gh stack submit --auto` → 새 PR 은 draft 다. 이미 있는 PR 은 `gh stack link <아래 PR> <위 PR>` 로 묶는다.
  - 스택의 base 는 기본 브랜치다 → `gh stack link` 는 맨 아래 PR 의 base 를 기본 브랜치로 바꾼다.
- ready·리뷰·CI 판정은 PR 마다 `/adk:ship` 3·4 그대로다.
- merge 는 `gh stack merge <PR 번호> --squash --yes` 로 한다 → 아래 PR 부터 그 PR 까지 함께 merge 된다. 스택 PR 에는 `gh pr merge` 를 쓰지 않는다 (GitHub 이 거부한다).
  - merge 게이트가 merge 될 PR 마다 CI 통과, 현재 head 요약, Blocking 0건을 확인한다. 번호가 없거나 squash 가 아니거나 허용 목록(`--squash`·`--merge-method squash`·`--merge-method=squash`·`-y`·`--yes`) 밖 플래그가 있으면 막는다.
  - Should Fix 와 사람 승인(`/adk:ship` 3-5)은 hook 이 보지 않는다 → merge 될 PR 마다 조회로 확인한다.
  - 검사한 head 와 merge 되는 head 를 묶을 수 없다 → 확인과 merge 사이에 push 하지 않는다. 커밋 메시지는 지정할 수 없어 GitHub 기본값이 된다.
- 스택 전체가 승인된 뒤 새 지적이 오면 저장소 소유자에게 두 선택지를 보고하고 지시를 기다린다: 스택을 다시 쌓아 반영·재승인 / 먼저 merge 하고 남은 지적은 후속 PR 하나로 처리.
- 다시 쌓아(`gh stack rebase`·`gh stack push`) 승인이 풀린 PR 은 지적이 없던 PR 이어도 재리뷰를 요청한다 ([human-review.md](human-review.md) "순서").
