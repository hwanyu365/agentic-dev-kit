# merge 뒤 정리

`/adk:ship` 5 의 세부 절차다.

- main 클론에서 워크트리 → 로컬 브랜치 → 원격 브랜치 순으로 지우고 `main` 을 갱신한다.

  ```sh
  git -C <main 클론> worktree remove <워크트리>
  git -C <main 클론> branch -D <브랜치>
  git -C <main 클론> ls-remote --exit-code --heads origin <브랜치> && git -C <main 클론> push origin --delete <브랜치>
  git -C <main 클론> pull --ff-only
  ```

- 4-b 의 merge 에 `--delete-branch` 를 붙이지 않는 이유: gh 가 로컬 브랜치를 먼저 지우는데 그 브랜치가 워크트리에 체크아웃돼 있어 명령이 실패한다 → merge 는 됐는데 실패로 보이고 원격 브랜치가 남는다.
- 저장소가 merge 때 head 브랜치를 자동으로 지우면 원격 브랜치는 이미 없다 → 조회로 확인하고 남아 있을 때만 지운다.
