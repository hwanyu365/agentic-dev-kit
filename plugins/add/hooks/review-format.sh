#!/bin/sh
# add:reviewer 가 끝날 때 반환한 요약이 리뷰 양식을 지켰는지 본다. 빠진 것이 있으면 exit 2 로 다시 쓰게 한다.
# merge 게이트는 첫 줄 HEAD 와 Blocking 절을 읽으므로 양식이 틀리면 리뷰를 다시 받아야 한다 → 여기서 먼저 잡는다.
# 문자열을 꺼내지 않고 JSON 원문에서 찾는다 → 원문에서 줄바꿈은 \n 두 글자다.
in=$(cat)
# 이미 한 번 되돌려 보냈으면 그대로 끝낸다 → 고칠 수 없는 경우에 끝없이 돌지 않는다.
printf '%s' "$in" | grep -qE '"stop_hook_active" *: *true' && exit 0
printf '%s' "$in" | grep -q '"last_assistant_message"' || exit 0
nl='\n'
miss=""
printf '%s' "$in" | grep -qE '"last_assistant_message" *: *"HEAD: [0-9a-f]{40}[^0-9a-f]' || miss="첫 줄 HEAD: <40자 head SHA> (merge 게이트는 40자 SHA 로 요약을 찾는다)"
for h in '## 개요' '## 이전 항목' '## 🔴 Blocking' '## 🟡 Should Fix' '## 🟢 Nits' '## ⚠️ HW / 런타임 확인 필요' '## 결론'; do
  # 바이트로 비교한다 → 4바이트 이모지 제목이 로캘에 따라 맞지 않는 것을 피한다.
  printf '%s' "$in" | LC_ALL=C grep -qF -- "$nl$h" || miss="$miss, $h"
done
[ -z "$miss" ] && exit 0
echo "리뷰 양식에서 빠진 것: ${miss#, } → 양식대로 요약 전체를 다시 반환한다" >&2
exit 2
