#!/bin/sh
# 플러그인 hooks/review-format.sh 검사: SubagentStop 입력(JSON 원문)을 바꿔 끼워 종료 코드를 비교한다.
h=$(cd "$(dirname "$0")/.." && pwd)/plugins/adk/hooks/review-format.sh
fail=0
# JSON 원문 그대로다: \n 은 두 글자(줄바꿈 escape)다.
head='HEAD: 0123456789abcdef0123456789abcdef01234567'
hw='\n## ⚠️ HW / 런타임 확인 필요\n없음.'
body='\n## 개요\n- x\n## 이전 항목\n없음.\n## 🔴 Blocking (merge 전 수정 필수)\n없음.\n## 🟡 Should Fix (merge 전 확인 권장)\n없음.\n## 🟢 Nits (follow-up 가능)\n없음.'
end='\n## 결론\n- merge 가능 \"따옴표\" 포함'
j() { printf '{"session_id":"s","stop_hook_active":%s,"agent_type":"adk:reviewer","last_assistant_message":"%s"}' "$1" "$2"; }
t() { # 기대종료코드 설명 입력
  printf '%s' "$3" | sh "$h" 2>/dev/null; rc=$?
  [ $rc -eq "$1" ] || { echo "FAIL $2: 기대 $1, 실제 $rc"; fail=1; }
}
t 0 "양식 맞음" "$(j false "$head$body$hw$end")"
t 0 "키 뒤 공백" "{\"stop_hook_active\": false, \"last_assistant_message\": \"$head$body$hw$end\"}"
t 2 "결론 빠짐" "$(j false "$head$body$hw")"
t 2 "HW 절 빠짐" "$(j false "$head$body$end")"
t 2 "첫 줄이 HEAD 아님" "$(j false "리뷰 결과\n$head$body$hw$end")"
t 2 "짧은 SHA" "$(j false "HEAD: 0123abc$body$hw$end")"
t 0 "이미 한 번 되돌림" "$(j true "리뷰 결과")"
t 0 "메시지 없음" '{"stop_hook_active":false}'
msg=$(j false "x" | sh "$h" 2>&1 >/dev/null)
case "$msg" in *"첫 줄 HEAD"*"## 결론"*) ;; *) echo "FAIL 빠진 항목 안내: $msg"; fail=1 ;; esac
[ $fail -eq 0 ] && echo PASS || exit 1
