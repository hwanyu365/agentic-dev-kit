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
  cmd "${e%%:*}" | grep -F "${e##*:} > \"<기준 시각>\"" >/dev/null \
    || { echo "FAIL TC#88 첫 라운드 수집에 --paginate 로 읽고 ${e##*:} 로 기준 시각 뒤를 거르는 ${e%%:*} 없음"; fail=1; }
done
cmd 'issues/<번호>/comments' | grep -F '리뷰 대응' | grep -F '.created_at' >/dev/null \
  || { echo "FAIL TC#88 기준 시각을 --paginate 로 읽은 \"리뷰 대응\" 코멘트의 작성 시각에서 정하지 않음"; fail=1; }
recollect=$(awk '/^## 2\./{s=1} /^## 3\./{s=0} s && /^[0-9]+\. /{f=/재수집/} s && f' "$f")
printf '%s\n' "$recollect" | grep -qF 'date -u +%Y-%m-%dT%H:%M:%SZ' \
  || { echo "FAIL TC#88 라운드 뒤 재수집의 수집 시각을 UTC Z 형식(date -u +%Y-%m-%dT%H:%M:%SZ)으로 찍지 않음"; fail=1; }
[ "$fail" = 0 ] && echo PASS
exit "$fail"
