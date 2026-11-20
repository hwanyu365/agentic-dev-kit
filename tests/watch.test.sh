#!/bin/sh
# TC#88 /adk:watch 첫 라운드는 감시 전에 달린 리뷰·코멘트를 빠짐없이 읽어야 한다.
# gh api 는 --paginate 가 없으면 30건까지만 돌려준다 → 긴 PR 의 뒤 페이지 지적이 첫 라운드에서 빠진다.
r=${1:-$(cd "$(dirname "$0")/.." && pwd)}
f="$r/plugins/adk/skills/watch/SKILL.md"
fail=0
[ -f "$f" ] || { echo "FAIL TC#88 $f 없음"; exit 1; }
start=$(awk '/^## 1\./{f=1} /^## 2\./{f=0} f' "$f")
cmd() { printf '%s\n' "$start" | grep -F 'gh api' | grep -F -e '--paginate' | grep -F "repos/{owner}/{repo}/$1"; }
for e in 'pulls/<번호>/reviews:submitted_at' 'pulls/<번호>/comments:created_at' 'issues/<번호>/comments:created_at'; do
  cmd "${e%%:*}" | grep -F "${e##*:} >= \"<기준 시각>\"" >/dev/null \
    || { echo "FAIL TC#88 첫 라운드 수집에 --paginate 로 읽고 ${e##*:} >= 로 기준 시각 이후를 거르는 ${e%%:*} 없음"; fail=1; }
done
cmd 'issues/<번호>/comments' | grep -F '리뷰 대응' | grep -F '.created_at' >/dev/null \
  || { echo "FAIL TC#88 기준 시각을 --paginate 로 읽은 \"리뷰 대응\" 코멘트의 작성 시각에서 정하지 않음"; fail=1; }
! grep -qF 'date -u' "$f" \
  || { echo "FAIL TC#88 기준 시각을 로컬 시계(date -u)로 찍음 → GitHub 서버 시각과 비교하면 같은 초·시계 차이 구간이 빠진다"; fail=1; }
printf '%s\n' "$start" | grep -qF '처리한 id' \
  || { echo "FAIL TC#88 수집 대상에서 처리한 id 를 빼지 않음 → 자기 글과 이미 조사한 항목이 매번 대상이 된다"; fail=1; }
recollect=$(awk '/^## 2\./{s=1} /^## 3\./{s=0} s && /^[0-9]+\. /{f=/재수집/} s && f' "$f")
printf '%s\n' "$recollect" | grep -qF '같은 기준 시각' \
  || { echo "FAIL TC#88 라운드 뒤 재수집이 같은 기준 시각으로 1의 수집을 다시 돌리지 않음"; fail=1; }
for e in 'pulls/<번호>/comments' 'issues/<번호>/comments'; do
  cmd "$e" | grep -F 'updated_at >= "<기준 시각>"' >/dev/null     || { echo "FAIL TC#88 $e 수집이 updated_at 을 보지 않음 → 처리한 뒤 수정된 코멘트가 대상이 되지 않는다"; fail=1; }
done
printf '%s
' "$start" | grep -F '리뷰 대응' | grep -F '.created_at' | grep -qF '| sort'   && { echo "FAIL TC#88 기준 시각 조회를 sort 에 파이프로 이어 오류가 빈 결과로 가려짐"; fail=1; }
printf '%s
' "$start" | grep -qF '답글이 만든'   || { echo "FAIL TC#88 처리한 id 정의(답글이 만든 리뷰 포함)가 없음"; fail=1; }
printf '%s
' "$recollect" | grep -qF '1의 수집'   || { echo "FAIL TC#88 재수집이 1의 수집을 다시 돌리지 않음"; fail=1; }
[ "$fail" = 0 ] && echo PASS
exit "$fail"
