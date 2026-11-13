#!/bin/sh
# 런타임 관문: version 을 올린 변경만 Claude Code 를 띄워 렌더한 틀의 세션·리뷰 동작을 확인한다 → 배포 전에 adk 가 직접 확인한다.
# 사용: runtime.sh <기준 ref>. 현재 디렉터리의 저장소에서 기준 ref 와 작업 트리의 plugin.json version 을 비교한다.
# 필요한 env: CLAUDE_CODE_OAUTH_TOKEN(claude -p), ADK_TEST_TOKEN(시험 저장소 push·PR·run 조회). 출력 전문은 public 로그에 내지 않는다.
A=$(cd "$(dirname "$0")/.." && pwd)
p=plugins/adk/.claude-plugin/plugin.json
ver() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1; }

base=${1-}
git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "기준 ref '$base' 를 찾지 못함" >&2; exit 1; }
old=$(git show "$base:$p" 2>/dev/null | ver); new=$(ver < "$p")
[ -n "$old" ] && [ -n "$new" ] || { echo "version 을 읽지 못함 (기준 '$old', 현재 '$new')" >&2; exit 1; }
if [ "$old" = "$new" ]; then echo "::notice::version 불변($new) → 런타임 관문 건너뜀"; exit 0; fi
echo "version $old → $new: 런타임 관문 실행"
[ -n "${CLAUDE_CODE_OAUTH_TOKEN-}" ] && [ -n "${ADK_TEST_TOKEN-}" ] || { echo "::error::version 을 올린 변경인데 secret(CLAUDE_CODE_OAUTH_TOKEN·ADK_TEST_TOKEN)이 없음 → 런타임 확인 불가" >&2; exit 1; }

TB=${ADK_TEST_REPO:-hwanyu365/agentic-dev-kit-test}
CLAUDE=${ADK_CLAUDE:-claude}
w=$(mktemp -d)
fail=0
ok() { echo "ok   $1"; }
ng() { echo "FAIL $1"; fail=1; }

# 1. claude -p 시나리오: 렌더한 저장소에서 세션 시작 hook 과 deny 규칙
ADK_RENDER_OWNER_REPO=$TB sh "$A/tests/render.sh" "$w/s" >/dev/null || { echo "렌더 실패" >&2; exit 1; }
cd "$w/s" && git init -q && git config user.email t@t && git config user.name t && git add -A && git commit -qm i || exit 1
cl() { m=$1; shift; "$CLAUDE" -p "$1" --permission-mode "$m" --output-format json </dev/null >"$w/claude.$2.json" 2>"$w/claude.$2.err"; }
# 실패 원인만 남긴다: 오류 여부, 거부된 도구 호출, 결과 앞부분. 대화 전문은 내지 않는다.
why() { jq -r '"     is_error=\(.is_error) subtype=\(.subtype) denials=\([.permission_denials[]?.tool_input.command] | tostring)\n     result: \(.result // "" | .[0:200])"' "$w/claude.$1.json" 2>/dev/null || head -c 300 "$w/claude.$1.err"; }

cl default "Reply with the single word OK." start
[ "$(git config --get core.hooksPath)" = .githooks ] && ok "세션 시작 hook 이 hook 경로를 .githooks 로 설정" || { ng "세션 시작 hook 이 hook 경로를 설정하지 않음"; why start; }

# 기본 모드는 git 에 쓰는 명령을 허용 규칙과 무관하게 승인 대기로 둔다 → 대조군이 성립하도록 우회 모드에서 deny 가 막는지 본다
sh .claude/hooks/verify.sh >/dev/null 2>&1 || ng "렌더 저장소 verify.sh 실패"
n0=$(git rev-list --count HEAD)
cl bypassPermissions "Run exactly this shell command with the Bash tool and nothing else: git commit --allow-empty -m allowed" allow
n1=$(git rev-list --count HEAD)
# 대조군: deny 에 걸리지 않는 커밋은 실제로 실행된다 → 아래 deny 확인이 '아무 명령도 돌지 않아서' 통과하는 것을 막는다
[ "$n1" -eq $((n0 + 1)) ] && ok "우회 모드의 일반 커밋은 실행됨 (대조군)" || { ng "우회 모드의 일반 커밋이 실행되지 않음 → deny 확인이 공허함"; why allow; }
cl bypassPermissions "Run exactly this shell command with the Bash tool and nothing else: git commit --allow-empty --no-verify -m denied" deny
[ "$(git rev-list --count HEAD)" -eq "$n1" ] && ok "우회 모드에서도 deny 규칙이 --no-verify 커밋을 막음" || { ng "--no-verify 커밋이 실행됨"; why deny; }

# 2. 시험 저장소: 렌더 결과를 main 에 두고 시험 PR 에서 리뷰가 head 마다 요약을 남기는지
export GH_TOKEN=$ADK_TEST_TOKEN
# 단계가 실패하면 그 단계와 오류 끝부분을 남기고 멈춘다 (secret 값은 Actions 가 로그에서 가린다)
st() { d=$1; shift; "$@" >"$w/st.log" 2>&1 || { echo "FAIL 시험 저장소: $d"; tail -n 5 "$w/st.log"; exit 1; }; }
st "클론" git -c credential.helper= clone -q "https://x-access-token:$ADK_TEST_TOKEN@github.com/$TB.git" "$w/tb"
cd "$w/tb" || exit 1
git config user.email adk-runtime@users.noreply.github.com && git config user.name adk-runtime
st "새 main 준비" git checkout -q --orphan main-new
git rm -rqf . >/dev/null 2>&1
st "렌더" env ADK_RENDER_OWNER_REPO="$TB" sh "$A/tests/render.sh" "$w/r"
cp -R "$w/r/." . && git add -A
st "렌더 커밋" git commit -qm "adk ${GITHUB_SHA:-local} 렌더"
st "main 갱신" git push -qf origin HEAD:main
br="probe-$(date +%s)"
git checkout -q -b "$br" && mkdir -p probe && printf '# probe\n\n- 첫 head\n' > probe/notes.md && git add -A
st "probe 커밋" git commit -qm "probe 1"
st "probe push" git push -q origin "$br"
st "시험 PR 열기" gh pr create -R "$TB" --base main --head "$br" --title "adk 런타임 관문 $br" --body "adk 런타임 관문 시험 PR. 끝나면 닫는다."
pr=$(sed -n 's#.*/pull/\([0-9][0-9]*\)$#\1#p' "$w/st.log")
[ -n "$pr" ] || { echo "FAIL 시험 저장소: PR 번호를 읽지 못함"; tail -n 5 "$w/st.log"; exit 1; }
trap 'gh pr close -R "$TB" "$pr" --delete-branch >/dev/null 2>&1; rm -rf "$w"' EXIT

# head 의 claude-review run 이 끝나길 기다리고, 성공했는지와 그 head 의 Claude 요약이 있는지 본다
review() {
  sha=$1; i=0; id=""
  while [ $i -lt 120 ]; do
    l=$(gh run list -R "$TB" --workflow claude-review.yml --commit "$sha" --json databaseId,status,conclusion -q '.[0] | "\(.databaseId) \(.status) \(.conclusion)"' 2>/dev/null)
    case "$l" in *" completed "*) id=${l%% *}; c=${l##* }; break ;; esac
    i=$((i + 1)); sleep 15
  done
  [ -n "$id" ] || { ng "$2: $sha 의 claude-review run 이 30분 안에 끝나지 않음"; return; }
  echo "     run https://github.com/$TB/actions/runs/$id"
  [ "$c" = success ] || { ng "$2: claude-review run 결론 $c"; return; }
  k=$(gh api "repos/$TB/issues/$pr/comments" --paginate -q "[.[] | select(.performed_via_github_app.slug == \"claude\" and (.body | startswith(\"HEAD: $sha\")))] | length")
  [ "${k:-0}" -ge 1 ] && ok "$2: head $sha 의 Claude 리뷰 요약 있음" || ng "$2: head $sha 의 Claude 리뷰 요약 없음"
}
review "$(git rev-parse HEAD)" "첫 리뷰"
printf -- '- 두 번째 head\n' >> probe/notes.md
st "반영 커밋" git commit -qam "probe 2"
st "반영 push" git push -q origin "$br"
review "$(git rev-parse HEAD)" "재리뷰"

exit "$fail"
