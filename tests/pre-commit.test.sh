#!/bin/sh
# 템플릿 .githooks/pre-commit 검사: 실제 저장소·워크트리에서 git commit 을 돌려, 커밋되는 작업 트리 기준으로 막는지 본다.
W=$(cd "$(dirname "$0")/.." && pwd)/plugins/adk/template
fail=0
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
mkdir -p "$r/m/.claude/hooks" "$r/m/.github" "$r/m/.githooks" "$r/m/docs"
cp "$W/.github/spec-trace.sh" "$r/m/.github/"
grep -v '{{' "$W/.github/secret-files.regex" > "$r/m/.github/secret-files.regex"
cp "$W/.githooks/pre-commit" "$r/m/.githooks/"
cp "$W/.claude/hooks/hooks-path.sh" "$r/m/.claude/hooks/"
awk '{ if ($0 == "{{VERIFY_CMD}}") print "true"; else print }' "$W/.claude/hooks/verify.sh" > "$r/m/.claude/hooks/verify.sh"
printf '# s\n' > "$r/m/docs/specification.md"
cd "$r/m" && git init -q && git config user.email t@t && git config user.name t && git add -A && git commit -qm i && git worktree add -q ../wt -b x || { echo "FAIL 준비"; exit 1; }
t() { [ "$2" = "$3" ] || { echo "FAIL $1: 기대 $3, 실제 $2"; fail=1; }; }
c() { git "$@" >/dev/null 2>&1; echo $?; }
v() { (cd "$1" && sh .claude/hooks/verify.sh >/dev/null 2>&1); echo $?; }

# 세션 시작 hook 이 hook 경로를 설정한다 → verify.sh 를 돌리지 않은 클론도 커밋 검사를 거친다
t "hook 경로 설정 전" "$(git config --get core.hooksPath)" ""
t "세션 시작 hook" "$(sh .claude/hooks/hooks-path.sh >/dev/null 2>&1; echo $?)" 0
t "세션 시작 hook 이 hook 경로 설정" "$(git config --get core.hooksPath)" ".githooks"
echo z > z.txt; git add z.txt
t "검증 없이 커밋" "$(c commit -m z)" 1
git rm -q --cached z.txt; rm z.txt; git config --unset core.hooksPath

# verify.sh 도 hook 경로를 설정하고, 다른 경로면 실패한다
t "검증 통과" "$(v "$r/m")" 0
t "검증이 hook 경로 설정" "$(git config --get core.hooksPath)" ".githooks"
git config core.hooksPath /elsewhere
t "다른 hook 경로면 검증 실패" "$(v "$r/m")" 2
t "다른 hook 경로면 커밋 직전 확인 실패" "$(sh .claude/hooks/hooks-path.sh --check >/dev/null 2>&1; echo $?)" 2
git config core.hooksPath .githooks
# 실행 권한은 Windows 에서 chmod -x 가 듣지 않아 Linux 에서만 검사된다
if chmod -x .githooks/pre-commit 2>/dev/null && [ ! -x .githooks/pre-commit ]; then
  t "실행 권한이 없으면 커밋 직전 확인 실패" "$(sh .claude/hooks/hooks-path.sh --check >/dev/null 2>&1; echo $?)" 2
  v "$r/m" >/dev/null; [ -x .githooks/pre-commit ] || { echo "FAIL 검증이 pre-commit 실행 권한을 되살리지 않음"; fail=1; }
fi

# 커밋되는 작업 트리의 기록으로 판정한다 (명령 형태와 무관)
echo a > a.txt
git add a.txt; t "검증 뒤 변경" "$(c commit -m a)" 1
v "$r/m" >/dev/null
t "검증 뒤 커밋" "$(c commit -m a)" 0
echo b > "$r/wt/b.txt"; git -C "$r/wt" add b.txt
t "main 만 검증 → git -C 워크트리 커밋" "$(c -C ../wt commit -m b)" 1
t "main 만 검증 → alias 로 워크트리 커밋" "$(c -C ../wt -c alias.ci=commit ci -m b)" 1
t "워크트리 검증" "$(v "$r/wt")" 0
t "워크트리 검증 → git -C 워크트리 커밋" "$(c -C ../wt commit -m b)" 0
echo c >> a.txt; v "$r/m" >/dev/null
t "검증 뒤 commit -a (임시 index)" "$(c commit -a -m c)" 0
echo d >> a.txt
t "검증 뒤 변경 → commit -a" "$(c commit -a -m d)" 1
git checkout -q -- a.txt
: > "$r/wt/.env"; v "$r/wt" >/dev/null; echo e > "$r/wt/e.txt"; git -C "$r/wt" add e.txt; v "$r/wt" >/dev/null
t "워크트리 미추적 비밀 파일" "$(c -C ../wt commit -m e)" 1
rm "$r/wt/.env"; v "$r/wt" >/dev/null
t "비밀 파일 제거 뒤" "$(c -C ../wt commit -m e)" 0
mv "$r/wt/.github/secret-files.regex" "$r/sf"; echo f > "$r/wt/f.txt"; git -C "$r/wt" add -A; v "$r/wt" >/dev/null
t "비밀 파일 정규식이 없으면 커밋 차단" "$(c -C ../wt commit -m f)" 1
mv "$r/sf" "$r/wt/.github/secret-files.regex"

# 기존 .git/hooks 가 있으면 hook 경로를 바꾸지 않고 실패한다 → 기존 hook 이 조용히 꺼지지 않는다
mkdir -p "$r/n/.claude/hooks" "$r/n/.githooks" && cp "$r/m/.claude/hooks/"* "$r/n/.claude/hooks/" && cp -r "$r/m/.github" "$r/m/docs" "$r/n/" && cp "$W/.githooks/pre-commit" "$r/n/.githooks/"
(cd "$r/n" && git init -q && printf '#!/bin/sh
exit 0
' > .git/hooks/commit-msg)
t "기존 hook 이 있으면 세션 시작 hook 실패" "$(cd "$r/n" && sh .claude/hooks/hooks-path.sh >/dev/null 2>&1; echo $?)" 2
t "기존 hook 이 있으면 hook 경로 그대로" "$(git -C "$r/n" config --get core.hooksPath)" ""
t "기존 hook 이 있으면 검증 실패" "$(v "$r/n")" 2
# hook 경로가 맞지 않으면 커밋 명령 직전 hook 이 막는다 → pre-commit 이 돌지 않는 클론에서도 커밋이 조용히 통과하지 않는다
t "hook 경로가 틀린 클론의 커밋 직전 확인" "$(cd "$r/n" && sh .claude/hooks/hooks-path.sh --check >/dev/null 2>&1; echo $?)" 2
t "hook 경로가 틀린 클론의 확인은 설정을 바꾸지 않음" "$(git -C "$r/n" config --get core.hooksPath)" ""
mkdir -p "$r/o/.claude/hooks" "$r/o/.githooks" && cp "$r/m/.claude/hooks/hooks-path.sh" "$r/o/.claude/hooks/" && cp "$W/.githooks/pre-commit" "$r/o/.githooks/" && git -C "$r/o" init -q
t "hook 경로가 비어 있는 클론의 커밋 직전 확인" "$(cd "$r/o" && sh .claude/hooks/hooks-path.sh --check >/dev/null 2>&1; echo $?)" 2
t "커밋 직전 확인은 빈 hook 경로를 설정하지 않음" "$(git -C "$r/o" config --get core.hooksPath)" ""
t "hook 경로가 맞는 클론의 커밋 직전 확인" "$(cd "$r/m" && sh .claude/hooks/hooks-path.sh --check >/dev/null 2>&1; echo $?)" 0

# 세션 시작 hook 과 pre-commit 을 건너뛰는 명령의 deny
s="$W/.claude/settings.json"
grep -q 'hooks-path.sh' "$s" || { echo "FAIL settings.json 에 세션 시작 hook(hooks-path.sh) 없음"; fail=1; }
for p in '"if": "Bash(git commit*)"' '"if": "Bash(git * commit*)"'; do
  grep -qF "$p" "$s" || { echo "FAIL settings.json 에 커밋 직전 hook 경로 확인($p) 없음"; fail=1; }
done
grep -qF 'hooks-path.sh --check' "$s" || { echo "FAIL settings.json 에 hooks-path.sh --check 없음"; fail=1; }
for p in 'Bash(git *--no-veri*)' 'Bash(git commit -n*)' 'Bash(git commit * -n *)' 'Bash(git commit * -n)' 'Bash(git * commit -n*)' 'Bash(git * commit * -n *)' 'Bash(git * commit * -n)' 'Bash(*hooksPath*)' 'Bash(*hookspath*)' 'Bash(*HOOKSPATH*)' 'Bash(*GIT_CONFIG*)' 'Bash(git *commit-tree*)' 'Bash(git *hash-object*)'; do
  grep -qF "\"$p\"" "$s" || { echo "FAIL settings.json deny 에 $p 없음"; fail=1; }
done
[ $fail -eq 0 ] && echo PASS || exit 1
