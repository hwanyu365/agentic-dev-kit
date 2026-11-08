#!/bin/sh
# 템플릿 .github/spec-trace.sh 검사: 템플릿 양식 스펙 + 결함을 심은 fixture 저장소에서 기대 출력과 비교한다.
set -eu
st=$(cd "$(dirname "$0")/.." && pwd)/plugins/add/template/.github/spec-trace.sh
r=$(mktemp -d); trap 'rm -rf "$r"' EXIT
cd "$r"; git init -q; git config user.email t@t; git config user.name t
mkdir docs src
cat > docs/spec_pay.md <<'MD'
## 3. 요구사항
- `US#1` 사용자로서 결제를 원한다 [요구사항] → FR#1~FR#2
- `US#2` 사용자로서 환불을 원한다 [요구사항] → FR#3
- `FR#1` 결제한다 [요구사항]
- `FR#2` 영수증 [요구사항]
- `FR#3` 환불 [확인필요] 정책 미정
- `NFR#1` 3초 안 [요구사항]
```
Given `FR#9` 코드블록 안은 정의가 아니다
```
## 4. 데이터 및 API 스펙
- `API#1` POST /pay
## 6. 동작 로직 및 정책
| 결정 | 선택 | 기각한 대안 | 근거 |
| --- | --- | --- | --- |
| `D#1` | a | b | c |
## 7. 테스트 및 검증 기준
| TC | 시나리오 | 대상 | 비고 |
| --- | --- | --- | --- |
| `TC#1` | 결제 | [FR#1, API#1] | |
| `TC#2` | 영수증 | [FR#2] | |
| `TC#3` | 지연 | [NFR#1] | (통합 — other/repo) |
| `TC#4` | 없는 대상 | [FR#7] | |
| `TC#5` | 대상 없음 | §4 | |
| `TC#7` | 화면 | [FR#2] | (수동) 화면 확인 |
## 부록. 변경 이력
- GH-1: [확인필요] 해소 (부록은 검사하지 않음)
MD
printf 'test("TC#1 결제", ()=>{})\ntest("TC#2 영수증", ()=>{})\ntest("TC#4 x", ()=>{})\ntest("TC#5 y", ()=>{})\n' > src/pay.test.js
git add -A; git commit -qm base
sed -i 's/test("TC#2 영수증", ()=>{})//' src/pay.test.js
printf 'test("TC#6 고아", ()=>{})\n' > src/new.test.js
sed -i 's/3초 안 \[요구사항\]/3초 안 [확인필요] 측정 방법 미정/' docs/spec_pay.md
got=$(sh "$st" -b HEAD | sed "s/ $(git rev-parse HEAD) / BASE /" || true)
want='E NO_TC docs/spec_pay.md:3 US#2
E NO_TC docs/spec_pay.md:6 FR#3
E NO_TEST docs/spec_pay.md:21 TC#2
E ORPHAN_TC src/new.test.js:1 TC#6
E TC_NO_TARGET docs/spec_pay.md:24 TC#5
E UNCONFIRMED docs/spec_pay.md:7 -
E UNDEF_REF docs/spec_pay.md:23 FR#7
M MANUAL docs/spec_pay.md:22 TC#3
M MANUAL docs/spec_pay.md:25 TC#7
W NO_TC docs/spec_pay.md:16 D#1
W TEST_REMOVED BASE TC#2 영수증
W UNCONFIRMED_OLD docs/spec_pay.md:6 -'
[ "$got" = "$want" ] && echo PASS || { echo FAIL; echo "$want" > w; echo "$got" > g; diff w g || true; exit 1; }
sh "$st" >/dev/null && { echo "FAIL: 결함이 있는데 exit 0"; exit 1; }
printf '## 성숙도: `poc`\n' > CLAUDE.md
sh "$st" >/dev/null || { echo "FAIL: poc 인데 실패"; exit 1; }
echo PASS-exit

# 여러 스펙 파일: 공통 제약 참조, TC·ID 중복, 들여쓴 [확인필요], 공백 있는 파일명, 테스트 이름 변경
r2=$(mktemp -d); trap 'rm -rf "$r" "$r2"' EXIT
cd "$r2"; git init -q; git config user.email t@t; git config user.name t
mkdir docs src
cat > docs/specification.md <<'MD'
# s
## 공통 제약
- `NFR#1` 응답 3초 [요구사항]
- `BR#2` 규칙 [요구사항]
- "[확인필요] 는 모두 해소했다" 같은 메타 문장
MD
cat > "docs/spec_b c.md" <<'MD'
## 3. 요구사항
- `FR#1` 하나 [요구사항]
  - 한도: [확인필요] 정책 미정
- `FR#1` 중복 [요구사항]
## 7. 테스트
| TC | 대상 | 비고 |
| --- | --- | --- |
| `TC#1` | [FR#1, NFR#1] | |
| `TC#1` | [FR#1] | |
MD
printf 'test("TC#1 x", ()=>{})\n' > src/b.test.js
got=$(sh "$st" | sort || true)
want=$(printf '%s\n' 'E DUP_ID docs/spec_b c.md:4 FR#1' 'E DUP_TC docs/spec_b c.md:9 TC#1' 'E NO_TC docs/specification.md:4 BR#2' 'E UNCONFIRMED docs/spec_b c.md:3 -' 'W UNCONFIRMED_MENTION docs/specification.md:5 -' | sort)
[ "$got" = "$want" ] && echo PASS-multi || { echo FAIL-multi; printf '%s\n' "$want" > w; printf '%s\n' "$got" > g; diff w g || true; exit 1; }
git add -A; git commit -qm base
sed -i 's/TC#1 x/TC#1 y/' src/b.test.js
sh "$st" -b HEAD | grep -q "^W TEST_NAME_GONE $(git rev-parse HEAD) TC#1 x" && echo PASS-rename || { echo FAIL-rename; exit 1; }

# 참조 줄: 들여쓴 글머리·백틱 없는 글머리의 ID 는 정의가 아니다
r3=$(mktemp -d); trap 'rm -rf "$r" "$r2" "$r3"' EXIT
cd "$r3"; git init -q; mkdir docs src
cat > docs/spec_a.md <<'MD'
## 3. 요구사항
- `FR#1` 하나 [요구사항]
- `FR#2` 환불 [요구사항]
  - FR#1 과 같은 한도를 쓴다
  - `FR#3` 을 이어서 정한다
## 6. 정책
- FR#2 는 3회 재시도
## 7. 테스트
| TC | 대상 | 비고 |
| --- | --- | --- |
| `TC#1` | [FR#1, FR#2] | |
MD
printf 'test("TC#1 x", ()=>{})\n' > src/a.test.js
got=$(sh "$st")
[ -z "$got" ] && echo PASS-ref || { echo "FAIL-ref: $got"; exit 1; }

# 정의 자리의 형식 위반: 백틱 빠짐·공백 두 칸은 조용히 빠지지 않고 E
cat > docs/spec_a.md <<'MD'
## 3. 요구사항
- `FR#1` 하나 [요구사항]
- FR#2 둘 [요구사항] [확인필요]
-  `FR#3` 셋 [요구사항]
* FR#4 넷 [요구사항]
-`FR#5` 다섯 [요구사항]
- **FR#6** 여섯 [요구사항]
1. `FR#7` 일곱 [요구사항]
- [FR#8] 여덟 [요구사항]

*FR#1* 은 기울임으로 시작한 참조 문단이다
## 7. 테스트
| TC | 대상 | 비고 |
| --- | --- | --- |
| `TC#1` | [FR#1] | |
MD
got=$(sh "$st") && rc=0 || rc=$?
want='E BAD_DEF docs/spec_a.md:3 -
E BAD_DEF docs/spec_a.md:4 -
E BAD_DEF docs/spec_a.md:5 -
E BAD_DEF docs/spec_a.md:6 -
E BAD_DEF docs/spec_a.md:7 -
E BAD_DEF docs/spec_a.md:8 -
E BAD_DEF docs/spec_a.md:9 -
W UNCONFIRMED_MENTION docs/spec_a.md:3 -'
[ "$got" = "$want" ] && [ $rc -eq 1 ] && echo PASS-baddef || { echo "FAIL-baddef rc=$rc: $got"; exit 1; }

# -b 범위: 여러 줄 hunk 의 줄마다 새 줄로 센다
r4=$(mktemp -d); trap 'rm -rf "$r" "$r2" "$r3" "$r4"' EXIT
cd "$r4"; git init -q; git config user.email t@t; git config user.name t; mkdir docs src
cat > docs/spec_a.md <<'MD'
## 3. 요구사항
- `FR#1` 하나 [요구사항] [확인필요] 원래 있던 것
- `FR#2` 둘 [요구사항]
## 7. 테스트
| TC | 대상 | 비고 |
| --- | --- | --- |
| `TC#1` | [FR#1, FR#2] | |
MD
echo 'test("TC#1 x", ()=>{})' > src/a.test.js
git add -A; git commit -qm base
cat > docs/spec_a.md <<'MD'
## 3. 요구사항
- `FR#1` 하나 [요구사항] [확인필요] 원래 있던 것
- `FR#2` 둘 [요구사항]
- `FR#3` 셋 [요구사항]
- `FR#4` 넷 [확인필요] hunk 첫 줄이 아닌 자리에 새로 추가
- `FR#5` 다섯 [요구사항]
## 7. 테스트
| TC | 대상 | 비고 |
| --- | --- | --- |
| `TC#1` | [FR#1, FR#2, FR#3, FR#4, FR#5] | |
MD
got=$(sh "$st" -b HEAD 2>&1) && rc=0 || rc=$?
want='E UNCONFIRMED docs/spec_a.md:5 -
W UNCONFIRMED_OLD docs/spec_a.md:2 -'
[ "$got" = "$want" ] && [ $rc -eq 1 ] && echo PASS-hunk || { echo "FAIL-hunk rc=$rc: $got"; exit 1; }
git add -A; git commit -qm add
# 지운 줄 바로 앞 줄(FR#4)에 [확인필요] 가 있다 → 삭제 hunk 를 한 줄로 세면 E 로 바뀐다
sed -i '/^- `FR#5`/d; s/, FR#5//' docs/spec_a.md
got=$(sh "$st" -b HEAD 2>&1) && rc=0 || rc=$?
want='W UNCONFIRMED_OLD docs/spec_a.md:2 -
W UNCONFIRMED_OLD docs/spec_a.md:5 -'
[ "$got" = "$want" ] && [ $rc -eq 0 ] && echo PASS-hunk-del || { echo "FAIL-hunk-del rc=$rc: $got"; exit 1; }
