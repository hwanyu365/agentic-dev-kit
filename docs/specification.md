# agentic-dev-kit 스펙

- **프로젝트:** Claude Code agent 가 SDD + TDD 로 개발하게 하는 프로젝트 틀과 절차 스킬
- **작성 규칙:** `plugins/adk/template/docs/rules_spec.md` → 틀이 적용 저장소에 내보내는 원본을 adk 도 그대로 따른다
- **TC 번호:** 기능 파일과 무관하게 저장소 전체에서 이어 붙인다 → 추적성 검사가 번호 하나를 한 정의로 본다

## 작업 기준 색인

| 작업 | 스펙 위치 |
| --- | --- |
| 커밋 게이트가 막는 `git commit` 형태·명령 해석기를 고친다 | `spec_commit-gate.md` §3·§6 |
| merge 게이트의 `gh pr merge` 플래그 판정을 고친다 | `spec_merge-gate.md` §3 |
| Dependabot PR 의 리뷰·merge 판정(`/adk:deps`, merge 게이트)을 고친다 | `spec_dependabot-merge.md` §3·§6 |
| PR 리뷰·ready·merge 흐름(`/adk:ship`·`/adk:watch`, 리뷰 워크플로)을 고친다 | `spec_review-flow.md` §3·§6 |
| 배포 전 검증(`test.yml` 의 job, `tests/runtime.sh`)을 고친다 | `spec_release-gate.md` §3·§6 |
| 추적성 검사(`spec-trace.sh`)의 태그·테스트 이름 판정을 고친다 | `spec_spec-trace.md` §3 |
| `/adk:init` 의 브랜치 최신 요구 선택을 고친다 | `spec_branch-strict.md` §3·§6 |
