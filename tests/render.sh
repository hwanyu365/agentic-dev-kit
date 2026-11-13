#!/bin/sh
# 템플릿을 고정 값으로 렌더한다. /adk:init 은 인터뷰라 결과가 매번 다르므로, CI 는 이 결정적 렌더로 틀 자체를 검사한다.
# 사용: render.sh <출력 디렉터리> | --check-left <디렉터리> | --check-table <템플릿> <init SKILL.md> | --check-parse <디렉터리>
A=$(cd "$(dirname "$0")/.." && pwd)
P='\{\{[A-Z_]+\}\}'

case "${1-}" in
--check-left)
  # GitHub Actions 식 ${{ }} 는 자리표시자가 아니다
  o=$(grep -rnE "(^|[^\$])$P" "$2")
  [ -z "$o" ] && exit 0
  echo "치환되지 않은 자리표시자:" >&2; echo "$o" >&2; exit 1 ;;
--check-table)
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  grep -rhoE "$P" "$2" | sort -u > "$d/tpl"
  grep -E "^\| \`$P\`" "$3" | grep -oE "$P" | sort -u > "$d/tab"
  [ -s "$d/tpl" ] && [ -s "$d/tab" ] || { echo "자리표시자 집합을 읽지 못함" >&2; exit 1; }
  o=$(comm -3 "$d/tpl" "$d/tab")
  [ -z "$o" ] && exit 0
  echo "템플릿에만 있음: $(comm -23 "$d/tpl" "$d/tab" | tr '\n' ' ')" >&2
  echo "init 표에만 있음: $(comm -13 "$d/tpl" "$d/tab" | tr '\n' ' ')" >&2
  exit 1 ;;
--check-parse)
  f=0
  for s in $(find "$2" -type f \( -name '*.sh' -o -path '*/.githooks/*' \)); do
    sh -n "$s" || { echo "셸 파싱 실패: $s" >&2; f=1; }
  done
  py=$(command -v python3 || command -v python) || { echo "python 없음 → YAML·JSON 파싱 불가" >&2; exit 1; }
  # 상대 경로로 넘긴다 → Windows 의 python 은 MSYS 절대 경로(/tmp/...)를 열지 못한다
  (cd "$2" && find . -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.json' \) | PYTHONIOENCODING=utf-8 "$py" -P -c '
import json, sys, yaml
bad = 0
for f in sys.stdin.read().split("\n"):
    if not f: continue
    try:
        s = open(f, encoding="utf-8").read()
        json.loads(s) if f.endswith(".json") else yaml.safe_load(s)
    except Exception as e:
        print("파싱 실패:", f, e, file=sys.stderr); bad = 1
sys.exit(bad)
') || f=1
  exit "$f" ;;
''|-*) echo "사용: $0 <출력 디렉터리>" >&2; exit 2 ;;
esac

out=$1
[ -e "$out" ] && { echo "$out 이 이미 있음" >&2; exit 2; }
mkdir -p "$out" && cp -R "$A/plugins/adk/template/." "$out/" || exit 1

export R_PROJECT="${ADK_RENDER_PROJECT:-fixture}"
export R_OWNER_REPO="${ADK_RENDER_OWNER_REPO:-owner/fixture}"
export R_SUMMARY="렌더 검사용 fixture"
export R_STACK="POSIX sh: 검사 스크립트만 있음"
export R_VERIFY_CMD="true"
export R_VERIFY_ALLOWED_TOOLS="Bash(true)"
export R_TEST_LOCATION="소스 옆 {file}.test.sh"
export R_RELEASE_CMD="echo release"
export R_MATURITY=alpha R_AUTONOMY=pr R_REVIEWER=github

find "$out" -type f | while IFS= read -r f; do
  # 문자열 치환은 index 로 한다 → 값의 정규식 메타문자와 awk 구현 차이를 피한다
  awk '
    function rep(s, k, v,   i, o) { o = ""; while ((i = index(s, k)) > 0) { o = o substr(s, 1, i - 1) v; s = substr(s, i + length(k)) } return o s }
    BEGIN { n = split("PROJECT OWNER_REPO SUMMARY STACK VERIFY_CMD VERIFY_ALLOWED_TOOLS TEST_LOCATION RELEASE_CMD MATURITY AUTONOMY REVIEWER", k, " ") }
    {
      t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (t == "# {{CI_SETUP}}" || t == "{{SECRET_FILES_REGEX}}") next
      s = $0
      for (i = 1; i <= n; i++) s = rep(s, "{{" k[i] "}}", ENVIRON["R_" k[i]])
      print s
    }' "$f" > "$f.adk-tmp" && cat "$f.adk-tmp" > "$f" && rm "$f.adk-tmp" || exit 1
done
