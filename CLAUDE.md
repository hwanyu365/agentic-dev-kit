# add-project

ADD 프로젝트 틀(`plugins/add/template/`)과 절차 스킬(`plugins/add/skills/`)을 담은 Claude Code 플러그인 저장소다.

## 수정 규칙

- 절차를 바꾸면 세 곳을 함께 맞춘다: 템플릿 `CLAUDE.md`, 해당 스킬 `SKILL.md`, `README.md` 의 명령 표
- 템플릿 자리표시자를 추가·삭제하면 `plugins/add/skills/init/SKILL.md` 의 자리표시자 표도 고친다
  - 자리표시자는 `{{NAME}}` 형식이다. YAML 안에서는 주석 줄이나 block scalar(`run: |`) 안에 둬서 치환 전에도 파싱되게 한다
- 리뷰 기준을 바꾸면 `plugins/add/template/.github/workflows/claude-review.yml` 의 prompt 와 `plugins/add/skills/ship/review.md` 를 함께 고친다
- 템플릿에는 특정 프로젝트의 경로·이름·이슈 번호를 넣지 않는다. 사례는 `docs/benchmark.md` 나 적용 예 저장소로 보낸다
- 새 방법론 요소를 들일 때는 `docs/benchmark.md` 에 출처·이유·위치를 적고, 들이지 않기로 한 것도 이유와 함께 남긴다
- `plugins/add/template/docs/rules_spec.md` 사본은 사용자 전역 규칙(`E:\01_dev\_docs\rules_spec.md`)과 같은 내용을 유지한다. 특정 프로젝트 사례는 양쪽 모두 넣지 않는다
- 스킬 안의 다른 스킬 참조는 `/add:<이름>` 전체 이름으로 쓴다

## 검증

```sh
claude plugin validate .
```

- 템플릿 YAML(`plugins/add/template/.github/**/*.yml`)이 치환 전에도 파싱되는지 확인한다
- 버전은 `plugins/add/.claude-plugin/plugin.json` 의 `version` 을 올린다 (사용자 쪽 `plugin update` 기준)

## GIT

- 커밋 메시지·문서 작성은 사용자 전역 규칙을 따른다
- 커밋·PR 은 저장소 소유자 지시가 있을 때 한다
