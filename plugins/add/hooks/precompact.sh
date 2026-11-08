#!/bin/sh
# ADD 저장소에서만 압축 요약에 남길 진행 상태를 지시한다 → 압축 뒤에도 같은 이슈·리뷰 상태에서 이어간다.
grep -q '^## 자율 범위' "$(git rev-parse --show-toplevel 2>/dev/null)/CLAUDE.md" 2>/dev/null || exit 0
cat <<'MD'
진행 상태를 요약에 그대로 남긴다.
- 이슈 번호, 브랜치, 워크트리 경로, 진행 단계(spec / tdd / verify / ship)
- 이번에 추가·변경한 스펙 ID 와 Red 에서 만든 테스트 목록
- PR 번호, 현재 head SHA, 리뷰 라운드와 항목 ID 별 상태(반영 SHA / 미반영 근거 / 이슈 / 소유자 결정 대기)
- 저장소 소유자가 세션에서 내린 결정·지시와 답을 기다리는 질문
- 실행하지 못한 검증과 확인하지 못한 것
MD
