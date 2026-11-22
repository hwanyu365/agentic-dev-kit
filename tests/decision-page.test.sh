#!/bin/sh
# 결정 페이지 틀(plugins/adk/skills/decide/templates/decision-page.html)의 로직과 구조를 검사한다.
R=$(cd "$(dirname "$0")/.." && pwd)
P=$R/plugins/adk/skills/decide/templates/decision-page.html
fail=0
[ -f "$P" ] || { echo "FAIL 틀 없음: $P"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "FAIL node 없음"; exit 1; }

node - "$P" <<'EOF' || fail=1
const fs = require('fs');
const vm = require('vm');
const html = fs.readFileSync(process.argv[2], 'utf8');
const m = html.match(/<script>([\s\S]*?)<\/script>/);
let fail = 0;
const t = (name, ok, got) => { if (ok) return; fail = 1; console.log(`FAIL ${name}${got === undefined ? '' : ' → ' + JSON.stringify(got)}`); };
if (!m) { console.log('FAIL 인라인 script 없음'); process.exit(1); }
const ctx = {};
vm.createContext(ctx);
try { vm.runInContext(m[1], ctx); } catch (e) { console.log('FAIL DOM 없이 script 실행 실패: ' + e.message); process.exit(1); }
const { summarize, restore } = ctx;
t('summarize 함수 없음', typeof summarize === 'function');
t('restore 함수 없음', typeof restore === 'function');
if (fail) process.exit(1);

const a = { id: 'D1', name: '저장 버튼', value: '아래 고정', recommended: '아래 고정' };
const b = { id: 'D2', name: '오류 문구', value: '그대로', recommended: '원인 표시' };
const c = { id: 'D3', name: '빈 목록', value: '안내 문구', recommended: '안내 문구' };

let s = summarize([a, c]);
t('TC#111 전부 권장이면 첫 줄이 권장대로', s.split('\n')[0] === '권장대로', s);
t('TC#111 줄 형식과 블록 순서', s === '권장대로\nD1 저장 버튼: 아래 고정 (권장)\nD3 빈 목록: 안내 문구 (권장)', s);
s = summarize([a, b, c]);
t('TC#111 하나라도 다르면 권장대로 없음', !s.includes('권장대로'), s);
t('TC#111 권장 아님 표시', s === 'D1 저장 버튼: 아래 고정 (권장)\nD2 오류 문구: 그대로 (권장 아님)\nD3 빈 목록: 안내 문구 (권장)', s);
s = summarize([c, a]);
t('TC#111 ID 순이 아닌 입력도 블록 순서대로', s === '권장대로\nD3 빈 목록: 안내 문구 (권장)\nD1 저장 버튼: 아래 고정 (권장)', s);
t('TC#111 결정 없는 블록은 넣지 않음', summarize([a, { id: 'D4', name: '머리말', value: null, recommended: null }]) === summarize([a]));

const vals = ['원인 표시', '그대로'];
t('TC#112 저장값이 선택지에 있으면 그 값', restore(() => '그대로', vals, '원인 표시') === '그대로');
t('TC#112 저장값 없음 → 권장안', restore(() => null, vals, '원인 표시') === '원인 표시');
t('TC#112 선택지 밖 저장값 → 권장안', restore(() => '없어진 안', vals, '원인 표시') === '원인 표시');
t('TC#112 저장소 오류 → 권장안', restore(() => { throw new Error('denied'); }, vals, '원인 표시') === '원인 표시');
process.exit(fail);
EOF

python3 -I - "$P" <<'EOF' || fail=1
import re, sys
from html.parser import HTMLParser
sys.stdout.reconfigure(encoding='utf-8')

ORDER = ['h2', 'problem', 'compare', 'changes', 'decision']

class P(HTMLParser):
    def __init__(self):
        super().__init__()
        self.items = []
        self.cur = None
        self.depth = 0
        self.toc = {}
        self.ext = []
        self.in_style = False
        self.style = ''
        self.sides = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = (a.get('class') or '').split()
        for k in ('src', 'href'):
            v = a.get(k)
            if v and not v.startswith('#'):
                self.ext.append(f'{tag} {k}={v}')
        if tag == 'style':
            self.in_style = True
        if tag == 'a' and (a.get('href') or '').startswith('#') and self.cur is None:
            self.toc[a['href'][1:]] = 'has-decision' in cls
        if tag == 'section' and 'item' in cls:
            self.cur = {'id': a.get('id'), 'seq': [], 'radios': [], 'none': False, 'reason': '', 'changes': [], 'none_text': ''}
            self.label = None
            self.in_none = False
            self.items.append(self.cur)
            self.depth = 0
        if self.cur is None:
            return
        if tag == 'section':
            self.depth += 1
        if tag == 'h2':
            self.cur['seq'].append('h2')
        for k in ('problem', 'compare', 'changes', 'decision'):
            if k in cls:
                self.cur['seq'].append(k)
        if 'compare' in cls:
            self.cur['sides'] = []
        for k in ('before', 'after'):
            if k in cls:
                self.cur.setdefault('sides', []).append(k)
        if 'no-decision' in cls:
            self.cur['none'] = True
            self.in_none = True
        if 'reason' in cls:
            self.in_reason = True
        if tag == 'li' and self.cur['seq'] and self.cur['seq'][-1] == 'changes':
            self.cur['changes'].append(set(cls) & {'add', 'mod', 'del'})
        if tag == 'label':
            self.label = {'rec': False}
        if tag == 'span' and 'rec' in cls and self.label is not None:
            self.label['rec'] = True
        if tag == 'input' and a.get('type') == 'radio':
            a['_label'] = self.label
            self.cur['radios'].append(a)

    def handle_endtag(self, tag):
        if tag == 'style':
            self.in_style = False
        if tag == 'label':
            self.label = None
        if tag == 'p':
            self.in_none = False
            self.in_reason = False
        if self.cur is not None and tag == 'section':
            self.depth -= 1
            if self.depth == 0:
                self.cur = None

    def handle_data(self, d):
        if self.in_style:
            self.style += d
        if self.cur is not None and getattr(self, 'in_reason', False):
            self.cur['reason'] += d
        if self.cur is not None and self.in_none:
            self.cur['none_text'] += d

p = P()
p.feed(open(sys.argv[1], encoding='utf-8').read())
fail = 0
def t(name, ok, got=None):
    global fail
    if not ok:
        fail = 1
        print(f'FAIL {name}' + ('' if got is None else f' → {got}'))

dec = [i for i in p.items if not i['none']]
none = [i for i in p.items if i['none']]
t('TC#113 결정 블록이 둘 이상', len(dec) >= 2, len(dec))
t('TC#113 결정 없는 블록 예시가 있음', len(none) >= 1)
for i in dec:
    t(f"TC#113 {i['id']} 순서 제목·문제·비교·바뀌는 점·결정", i['seq'] == ORDER, i['seq'])
    t(f"TC#113 {i['id']} 기존·변경안 나란히", i.get('sides') == ['before', 'after'], i.get('sides'))
    names = {r.get('name') for r in i['radios']}
    t(f"TC#113 {i['id']} 라디오 그룹 하나", len(names) == 1 and len(i['radios']) >= 2, names)
    checked = [r for r in i['radios'] if 'checked' in r]
    rec = [r for r in i['radios'] if 'data-recommended' in r]
    t(f"TC#113 {i['id']} checked 하나", len(checked) == 1, len(checked))
    t(f"TC#113 {i['id']} 권장안 하나이고 기본 선택", len(rec) == 1 and checked == rec)
    t(f"TC#113 {i['id']} 권장 표시는 권장안 라벨에만", [bool(r['_label'] and r['_label']['rec']) for r in i['radios']] == ['data-recommended' in r for r in i['radios']])
    t(f"TC#113 {i['id']} 권장 이유 한 줄", i['reason'].startswith('권장 이유: ') and len(i['reason']) > len('권장 이유: '), i['reason'])
    t(f"TC#113 {i['id']} 바뀌는 점마다 추가·변경·삭제 구분", i['changes'] and all(len(c) == 1 for c in i['changes']), i['changes'])
for i in none:
    t(f"TC#113 {i['id']} 결정할 것 없음 표시", i['none_text'].strip() == '결정할 것 없음', i['none_text'])
    t(f"TC#113 {i['id']} 결정 없는 블록에 라디오 없음", not i['radios'] and 'decision' not in i['seq'], i['seq'])
for i in p.items:
    t(f"TC#113 {i['id']} 목차에 있음", i['id'] in p.toc)
    if i['id'] in p.toc:
        t(f"TC#113 {i['id']} 목차 결정 구분", p.toc[i['id']] == (not i['none']))
t('TC#113 외부 src·href 없음', not p.ext, p.ext)
st = re.sub(r'\s+', ' ', p.style)
t('TC#113 스타일에 외부 참조 없음', '@import' not in st and 'url(' not in st)
t('TC#113 다크 모드 변수', re.search(r'prefers-color-scheme: dark\) \{[^}]*--bg:', st) is not None)
t('TC#113 기존·변경안 같은 폭 2열', re.search(r'\.compare \{[^}]*grid-template-columns: 1fr 1fr', st) is not None)
t('TC#113 좁은 폭에서 1열', re.search(r'@media \(max-width: \d+px\) \{ \.compare \{ grid-template-columns: 1fr; \}', st) is not None)
sys.exit(fail)
EOF

[ "$fail" = 0 ] && echo PASS
exit "$fail"
