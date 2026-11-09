#!/bin/sh
# adk:reviewer·adk:spec-verifier 의 Bash 를 허용 목록으로 제한한다. 아는 조회 명령만 통과시키고 나머지는 모두 막는다.
# agent frontmatter 로는 Bash 를 명령 단위로 막을 수 없고 플러그인 agent 의 hooks 는 무시된다 → 플러그인 hook 이 agent_type 으로 가린다.
# 판정은 셸이 실제로 넘기는 단어(따옴표·backslash 를 푼 것)로 한다 → 원문 문자열로 보면 따옴표·확장으로 옵션을 숨길 수 있다.
# 확장($, 중괄호, glob)은 아예 막는다 → 막지 않으면 hook 이 본 단어와 셸이 넘기는 단어가 달라진다.
in=$(cat)
printf '%s' "$in" | grep -qE '"agent_type" *: *"adk:(reviewer|spec-verifier)"' || exit 0
# BSD sed 도 읽도록 ERE 로 쓴다 (BRE 의 \| 는 GNU 확장).
cmd=$(printf '%s' "$in" | sed -nE 's/.*"command" *: *"(([^"\\]|\\.)*)".*/\1/p' | head -n 1)

v=$(printf '%s' "$cmd" | awk '
function no(m) { print "DENY " m; bad = 1; exit }
function sep(j,   d) { if (j > n) return 1; d = substr(o, j, 1); return d == " " || d == "\t" || d == ";" || d == "|" || d == "&" || d == "\n" }
function endword() { if (inword) { k++; W[s, k] = cur; C[s] = k } cur = ""; inword = 0; wq = 0 }
function endseg() { endword(); s++; k = 0; C[s] = 0 }
function word_ok_git(gs, x) {
  # git 은 모호하지 않은 긴 옵션 약어를 받으므로 가장 짧게 정해지는 앞부분으로 막는다 (--output·--ext-diff·--open-files-in-pager·--upload-pack·--exec).
  if (x ~ /^--(out|ext|op|upl|exec)/) return 0
  # git grep -O 는 pager 명령을 실행한다. 짧은 옵션 묶음(-nO…) 안에 있어도 막는다.
  if (gs == "grep" && x ~ /^-[^-]*O/) return 0
  return 1
}
{ raw = raw (NR > 1 ? "\n" : "") $0 }
END {
  if (raw == "") no("명령을 읽지 못함")
  # JSON escape 해제. 셸과 해석이 갈릴 수 있는 escape 는 막는다.
  o = ""; m = length(raw)
  for (i = 1; i <= m; i++) {
    c = substr(raw, i, 1)
    if (c == "\\") {
      i++; d = substr(raw, i, 1)
      if (d == "n") c = "\n"; else if (d == "t") c = "\t"; else if (d == "\"" || d == "\\" || d == "/") c = d
      else no("JSON escape \\" d)
    }
    o = o c
  }
  # 셸 규칙으로 단어·조각을 나눈다.
  n = length(o); q = ""; cur = ""; inword = 0; s = 1; k = 0; C[1] = 0
  for (i = 1; i <= n; i++) {
    c = substr(o, i, 1)
    if (q == "\047") { if (c == q) q = ""; else cur = cur c; continue }
    if (q == "\"") {
      if (c == "\"") { q = ""; continue }
      if (c == "\\") { d = substr(o, i + 1, 1); if (d == "$" || d == "`" || d == "\"" || d == "\\" || d == "\n") { if (d != "\n") cur = cur d; i++ } else cur = cur c; continue }
      if (c == "$" || c == "`") no("치환·확장")
      cur = cur c; continue
    }
    if (c == "\\") { d = substr(o, i + 1, 1); i++; if (d != "\n") { cur = cur d; inword = 1; wq = 1 }; continue }
    if (c == "\047" || c == "\"") { q = c; inword = 1; wq = 1; continue }
    if (c == " " || c == "\t") { endword(); continue }
    # 허용하는 리다이렉트는 출력 버리기와 fd 합치기뿐이다. 따옴표를 붙인 "2" 는 셸이 fd 번호로 보지 않는다.
    if (c == ">" && !wq && (!inword || cur == "1" || cur == "2")) {
      if (cur == "2" && substr(o, i, 3) == ">&1" && sep(i + 3)) { cur = ""; inword = 0; i += 2; continue }
      if (cur != "2" && substr(o, i, 3) == ">&2" && sep(i + 3)) { cur = ""; inword = 0; i += 2; continue }
      if (substr(o, i, 10) == ">/dev/null" && sep(i + 10)) { cur = ""; inword = 0; i += 9; continue }
    }
    # bash 는 &> 를 리다이렉트로 읽고 명령을 끊지 않는다 → 구분자로 보면 뒤 단어가 앞 명령의 인자로 숨는다.
    if (c == "&" && substr(o, i + 1, 1) == ">") no("리다이렉트")
    if (c == ";" || c == "|" || c == "&" || c == "\n") { endseg(); continue }
    if (c == ">" || c == "<") no("리다이렉트")
    # git 의 @{u}·HEAD@{1} 은 쉼표·.. 이 없으면 셸이 중괄호 확장을 하지 않는다 → 그 형태만 글자 그대로 받는다.
    if (c == "{" && substr(cur, length(cur), 1) == "@") {
      e = index(substr(o, i), "}")
      if (e > 1 && substr(o, i + 1, e - 2) ~ /^[A-Za-z0-9_:-]*$/) { cur = cur substr(o, i, e); i += e - 1; continue }
    }
    if (c == "$" || c == "`" || c == "(" || c == ")" || c == "{" || c == "}") no("치환·괄호·확장")
    if (c == "*" || c == "?" || c == "[") no("glob")
    if (c == "#" && !inword) no("주석")
    cur = cur c; inword = 1
  }
  if (q != "") no("닫히지 않은 따옴표")
  endword()
  # 조각마다 허용 목록과 대조한다.
  for (t = 1; t <= s; t++) {
    nw = C[t]; if (nw == 0) continue
    w1 = W[t, 1]
    # printf·test 는 넣지 않는다 → bash 내장은 -v 의 배열 첨자를 다시 확장해 작은따옴표 안의 치환도 실행한다.
    if (w1 ~ /^(cd|cat|head|tail|wc|grep|ls|cut|tr|diff|pwd|echo|true|basename|dirname|which)$/) continue
    if (w1 == "sh") {
      if (nw == 2 && (W[t, 2] ~ /^tests\/[A-Za-z0-9_-]+\.test\.sh$/ || W[t, 2] == ".claude/hooks/verify.sh")) continue
      no("sh " W[t, 2])
    }
    if (w1 == "git") {
      j = 2
      while (j <= nw && (W[t, j] == "-C" || W[t, j] == "--no-pager")) j += (W[t, j] == "-C") ? 2 : 1
      sub_ = W[t, j]
      if (sub_ == "fetch") {
        # 원격 이름과 : · + 가 없는 ref 만 받는다. --prune·--tags·tag <이름> 은 로컬 ref 를 지우거나 만든다.
        # 기본 refspec 이면 FETCH_HEAD 와 원격 추적 ref 만 바뀐다. remote.*.fetch 설정에 따라 그보다 넓어질 수 있다.
        for (x = j + 1; x <= nw; x++) {
          a = W[t, x]
          if (a ~ /^(-q|--quiet)$/) continue
          if (a != "tag" && a ~ /^[A-Za-z0-9_][A-Za-z0-9_.\/-]*$/) continue
          no("git fetch " a)
        }
        continue
      }
      if (sub_ !~ /^(log|diff|show|status|grep|ls-files|ls-tree|rev-parse|rev-list|merge-base|blame|range-diff|cat-file|describe|shortlog|for-each-ref|show-ref|diff-tree|name-rev)$/) no("git " sub_)
      for (x = j + 1; x <= nw; x++) if (!word_ok_git(sub_, W[t, x])) no("git " sub_ " " W[t, x])
      continue
    }
    if (w1 == "gh") {
      # 호스트를 지정할 수 있는 자리는 조각 전체에서 본다: URL 인자, -R/--repo 의 값(어느 위치든, = 형태·붙여 쓴 형태 포함).
      # 저장소 지정은 OWNER/REPO 만 받는다 → HOST/OWNER/REPO·URL 은 다른 호스트로 요청을 보낸다.
      for (x = 2; x <= nw; x++) {
        a = W[t, x]; rp = ""
        if (index(a, "://")) no("gh " a)
        if (a == "-R" || a == "--repo") rp = W[t, x + 1]
        else if (a ~ /^--repo=/) rp = substr(a, 8)
        else if (a ~ /^-R./) rp = substr(a, 3)
        # gh 는 짧은 옵션 묶음(-cR …) 안의 R 도 --repo 로 읽는다 → 묶음 안의 R 은 값과 관계없이 막는다.
        else if (a ~ /^-[^-]/ && index(a, "R")) no("gh " a)
        else continue
        if (rp !~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/) no("gh -R " rp)
      }
      j = 2
      if (W[t, j] == "-R" || W[t, j] == "--repo") j += 2; else if (W[t, j] ~ /^--repo=/) j++
      g = W[t, j]; h = W[t, j + 1]
      if (g == "api") {
        for (x = j + 1; x <= nw; x++) {
          a = W[t, x]
          # 전체 URL 과 --hostname 은 임의 호스트로 요청을 보낸다 → 읽은 내용을 밖으로 실어 나를 수 있다.
          if (index(a, "://") || a ~ /^--hostname/) no("gh api " a)
          if (a ~ /^--(method|field|raw-field|input|header)/) no("gh api " a)
          if (a ~ /^-[^-]/ && a ~ /^-[A-Za-z]*[XfFH]/) no("gh api " a)
        }
        continue
      }
      # --web 은 브라우저 프로그램을 실행한다.
      for (x = j + 1; x <= nw; x++) if (W[t, x] ~ /^--web(=|$)/ || W[t, x] ~ /^-[A-Za-z]*w/) no("gh " g " " W[t, x])
      if (g == "pr" && h ~ /^(view|diff|checks|list|status)$/) continue
      if (g == "issue" && h ~ /^(view|list|status)$/) continue
      if (g == "run" && h ~ /^(view|list)$/) continue
      if (g == "workflow" && h ~ /^(view|list)$/) continue
      if (g == "repo" && h == "view") {
        # repo view 의 위치 인자는 HOST/OWNER/REPO·SSH·URL 형식을 받는다 → 옵션·값·-- 뒤 인자를 가리지 않고 모든 단어를 허용 글자와 / 하나만 받는다.
        # 예외를 두지 않는다 → "- 로 시작하면 옵션" 같은 예외는 -- 뒤 인자처럼 그 전제가 깨지는 자리에서 구멍이 된다.
        for (x = j + 2; x <= nw; x++) { a = W[t, x]; if (a !~ /^[A-Za-z0-9_.,=-]+(\/[A-Za-z0-9_.,=-]+)?$/) no("gh repo view " a) }
        continue
      }
      if (g == "release" && h ~ /^(view|list)$/) continue
      if (g == "search" && h ~ /^(prs|issues|code|repos|commits)$/) continue
      no("gh " g " " h)
    }
    no(w1)
  }
  print "OK"
}')
case "$v" in
  OK) exit 0 ;;
esac
echo "읽기 전용 agent 에서 허용하지 않는 명령 (${v#DENY })." >&2
echo "허용: git 조회(log diff show status grep ls-files ls-tree rev-parse rev-list merge-base blame range-diff cat-file describe shortlog for-each-ref show-ref diff-tree name-rev, fetch 는 원격 이름과 : 없는 ref 만), gh 조회(pr view/diff/checks/list/status, issue view/list/status, run·workflow view/list, repo view, release view/list, search, 쓰기 옵션 없는 api, --web 제외), cat head tail wc grep ls cut tr diff pwd echo true basename dirname which cd, sh tests/*.test.sh, sh .claude/hooks/verify.sh" >&2
echo "확장(\$·중괄호·glob)·치환·괄호·파일 리다이렉트·셸 감싸기는 쓰지 않는다. 막힌 확인은 결론에 막힌 이유와 필요한 것을 적는다." >&2
exit 2
