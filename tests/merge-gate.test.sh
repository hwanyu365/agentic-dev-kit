#!/bin/sh
# 템플릿 .claude/hooks/merge-gate.sh 의 merge 명령 해석 검사 (네트워크 없이 --parse 로).
g=$(cd "$(dirname "$0")/.." && pwd)/plugins/add/template/.claude/hooks/merge-gate.sh
fail=0
t() { # 기대값 JSON
  got=$(printf '%s' "$2" | sh "$g" --parse 2>&1); rc=$?
  if [ "$1" = deny ]; then [ $rc -eq 2 ] || { echo "FAIL(deny 기대) $2 → $got"; fail=1; }
  else [ $rc -eq 0 ] && [ "$got" = "$1" ] || { echo "FAIL($1) $2 → $got"; fail=1; }; fi
}
t '11 abc1234' '{"tool_input":{"command":"gh pr merge 11 --squash --match-head-commit abc1234 --body \"- gh pr merge 직전 hook\n- PR 24 개 중 22 개\""}}'
t '- abc1234' '{"tool_input":{"command":"gh pr merge --squash --delete-branch --subject \"chore: 12 건\" --body \"gh pr merge 24\" --match-head-commit abc1234"}}'
t '8 -' '{"tool_input": {"command": "gh pr merge https://github.com/o/r/pull/8 --squash"}}'
t '12 x' '{"tool_input":{"command":"cd ../wt && gh pr merge 12 --match-head-commit=x && echo \"gh pr merge 99\""}}'
t '12 -' '{"tool_input":{"command":"gh pr merge 12\t--squash"}}'
t '12 -' '{"tool_input":{"command":"gh pr merge 12 --body '"'"'a 99 b'"'"' --squash"}}'
t deny '{"tool_input":{"command":"gh pr merge --squash *"}}'
t deny '{"tool_input":{"command":"gh pr merge feat/GH-9 --squash"}}'
t deny '{"tool_input":{"command":"gh pr merge -R other/repo 12"}}'
t deny '{"tool_input":{"command":"gh pr merge 12 13"}}'
t '12 abcdef0' '{"tool_input":{"command":"gh pr merge --squash 12 --delete-branch --match-head-commit abcdef0 --subject \\"x\\""}}'
t deny '{"tool_input":{}}'
[ $fail -eq 0 ] && echo PASS || exit 1

# 판정: gh 를 흉내 내는 stub 을 PATH 앞에 둔다. 코멘트 jq 필터는 실제 gh 의 jq 로 돌린다 → gh 인증이 없으면 실패로 끝낸다.
real=$(command -v gh) || { echo "FAIL 판정: gh 없음 → 판정을 검사하지 못함"; exit 1; }
"$real" auth status >/dev/null 2>&1 || { echo "FAIL 판정: gh 미인증 → 판정을 검사하지 못함"; exit 1; }
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
mkdir -p "$r/bin" "$r/repo"
cat > "$r/bin/gh" <<'GH'
#!/bin/sh
case "$1 $2" in
  "pr view") echo "12 abc1234def" ;;
  "pr checks") exit "${FAKE_CHECKS:-0}" ;;
  "api user") echo me ;;
  api\ repos/*) exec "$REAL_GH" api rate_limit --jq "$FAKE_COMMENTS as \$d | \$d | $5" ;;
  *) echo "stub: 모르는 호출 $*" >&2; exit 1 ;;
esac
GH
chmod +x "$r/bin/gh"
(cd "$r/repo" && git init -q)
bot='user:{login:"claude[bot]",type:"Bot"},performed_via_github_app:{slug:"claude"}'
usr='user:{login:"me",type:"User"},performed_via_github_app:null'
oth='user:{login:"evil",type:"User"},performed_via_github_app:null'
ok='"HEAD: abc1234def\n## 개요\n## 🔴 Blocking (merge 전 수정 필수)\n\n없음.\n\n## 🟡 Should Fix\n### [S1] x\n"'
bl='"HEAD: abc1234def\n## 🔴 Blocking (merge 전 수정 필수)\n\n### [B1] 크래시\n"'
old='"HEAD: 0000000000\n## 🔴 Blocking\n\n없음.\n"'
j() { # 기대종료코드 모드(github|local) mh 코멘트들 [checks]
  rm -rf "$r/repo/.github"; [ "$2" = github ] && mkdir -p "$r/repo/.github/workflows" && : > "$r/repo/.github/workflows/claude-review.yml"
  got=$(cd "$r/repo" && printf '{"tool_input":{"command":"gh pr merge --squash 12 --match-head-commit %s"}}' "$3" |
    PATH="$r/bin:$PATH" REAL_GH="$real" FAKE_COMMENTS="[$4]" FAKE_CHECKS="${5:-0}" sh "$g" 2>&1); rc=$?
  [ $rc -eq "$1" ] || { echo "FAIL 판정($1) $2 mh=$3 → $rc $got"; fail=1; }
}
j 0 github abc1234 "{$bot,body:$ok}"
j 2 github abc1234 "{$bot,body:$bl}"
j 0 github abc1234 "{$bot,body:$bl},{$bot,body:$ok}"
j 2 github abc1234 "{$usr,body:$ok}"
j 2 github abc1234 "{$bot,body:$old}"
j 2 github abc9999 "{$bot,body:$ok}"
j 2 github abc12 "{$bot,body:$ok}"
j 2 github abc1234 "{$bot,body:$ok}" 1
j 0 local abc1234 "{$usr,body:$ok}"
j 2 local abc1234 "{$usr,body:$bl},{$oth,body:$ok}"
quoted='"HEAD: abc1234def\n## 개요\n```md\n## 🔴 Blocking (merge 전 수정 필수)\n없음.\n```\n## 🔴 Blocking (merge 전 수정 필수)\n### [B1] 실제 지적\n"'
j 2 github abc1234 "{$bot,body:$quoted}"
[ $fail -eq 0 ] && echo PASS-판정 || exit 1
