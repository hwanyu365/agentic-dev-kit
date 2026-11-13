# agentic-dev-kit

agent 가 SDD + TDD 로 개발하게 하는 프로젝트 틀(`plugins/adk/template/`)과 절차 스킬(`plugins/adk/skills/`)을 담은 Claude Code 플러그인 저장소다.

## 수정 규칙

- 절차를 바꾸면 세 곳을 함께 맞춘다: 템플릿 `CLAUDE.md`, 해당 스킬 `SKILL.md`, `README.md` 의 명령 표
- 템플릿 자리표시자를 추가·삭제하면 `plugins/adk/skills/init/SKILL.md` 의 자리표시자 표와 `plugins/adk/skills/init/update.md` 의 "읽는 곳" 표를 함께 고친다
  - 자리표시자는 `{{NAME}}` 형식이다. YAML 안에서는 주석 줄이나 block scalar(`run: |`) 안에 둬서 치환 전에도 파싱되게 한다
- 리뷰 기준을 바꾸면 `plugins/adk/template/.github/workflows/claude-review.yml` 의 prompt 와 `plugins/adk/skills/ship/review.md` 를 함께 고친다
- 템플릿에는 특정 프로젝트의 경로·이름·이슈 번호를 넣지 않는다. 사례는 `docs/benchmark.md` 나 적용 예 저장소로 보낸다
- 새 방법론 요소를 들일 때는 `docs/benchmark.md` 에 출처·이유·위치를 적고, 들이지 않기로 한 것도 이유와 함께 남긴다
- `plugins/adk/template/docs/rules_spec.md` 사본은 사용자 전역 규칙(`E:\01_dev\_docs\rules_spec.md`)과 같은 내용을 유지한다. 특정 프로젝트 사례는 양쪽 모두 넣지 않는다
- 스킬 안의 다른 스킬 참조는 `/adk:<이름>` 전체 이름으로 쓴다

## 검증

```sh
claude plugin validate .
sh tests/merge-gate.test.sh
sh tests/pre-commit.test.sh
sh tests/spec-trace.test.sh
sh tests/verify.test.sh
sh tests/review-format.test.sh
sh tests/readonly-agent.test.sh
sh tests/skill-size.test.sh
sh tests/render.test.sh
sh tests/mutation.test.sh
sh tests/runtime.test.sh
sh tests/probe.test.sh
```

- 템플릿 YAML(`plugins/adk/template/.github/**/*.yml`)이 치환 전에도 파싱되는지 확인한다
- PR·main push 마다 `.github/workflows/test.yml` 이 위 검증을 돌린다. 검증 명령을 바꾸면 이 workflow 도 함께 고친다
  - `tests/*.test.sh` 는 ubuntu gawk·ubuntu mawk·macOS awk 에서 돈다
  - 필수 check 는 집계 job `test` 하나다. job 을 더하면 `test` 의 `needs` 에 넣는다
- 보안 경계 조건(커밋·merge 차단, 읽기 전용 agent 제한)을 고치거나 더하면 `tests/mutations.tsv` 도 고친다
  - 전체 실행은 `sh tests/mutation.sh . tests/mutations.tsv` (행마다 테스트를 다시 돌려 오래 걸린다 → CI `mutation` job 이 돈다)
- 버전은 `plugins/adk/.claude-plugin/plugin.json` 의 `version` 을 올린다 (사용자 쪽 `plugin update` 기준)
  - 태그 `v{version}` 은 main push 때 `test.yml` 의 `tag` job 이 단다. 손으로 달지 않는다

## 배포

main 에 merge 된 version 이 곧 배포다. 적용 저장소는 adk 의 검증 환경이 아니다.

- adk 변경은 adk 안에서 확인한 뒤 merge 한다. 확인할 수단이 없으면 배포 전에 그 수단부터 만든다
- 이슈의 닫는 조건에 "적용 저장소에서 관측" 을 쓰지 않는다
- 확인하지 못한 항목이 남은 변경은 `version` 을 올리지 않는다
- `version` 을 올린 PR 은 `test.yml` 의 `runtime` job 이 Claude Code 와 시험 저장소(`hwanyu365/agentic-dev-kit-test`, private)로 렌더한 틀의 세션 시작 hook·deny 규칙·trust 전후 allow·리뷰 워크플로·리뷰 job 의 격리(하위 셸 자격 증명 scrub, 저장소 밖 읽기 거부)를 확인한다 (`tests/runtime.sh`)
  - 시험 저장소의 main 은 매 실행마다 렌더 결과로 덮인다. 손으로 고치지 않는다
  - secret: adk `CLAUDE_CODE_OAUTH_TOKEN`·`ADK_TEST_TOKEN`(시험 저장소 한정 fine-grained PAT), 시험 저장소 `CLAUDE_CODE_OAUTH_TOKEN`

## GIT

- 커밋 메시지·문서 작성은 사용자 전역 규칙을 따른다
- 커밋·PR 은 저장소 소유자 지시가 있을 때 한다
