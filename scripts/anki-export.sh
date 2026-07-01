#!/usr/bin/env bash
# anki-export.sh —— 扫 quiz/*.md + notes/**/Descriptors :: 行 → Anki 包
# 依赖: genanki (pip install genanki), rg
# implements SPEC §3.2, §5.1
set -euo pipefail

# 优先用 venv（含 genanki），否则回退系统 python3
if [ -x .venv/bin/python ]; then
  PYTHON=.venv/bin/python
else
  PYTHON=python3
fi

"$PYTHON" - <<'PY'
import os, re, glob, hashlib, sys
try:
    import genanki
except ImportError:
    raise SystemExit("pip install genanki 先")

MODEL = genanki.Model(
    1091735101, "aistudy-quiz",
    fields=[{"name":"Q"},{"name":"A"},{"name":"Topic"}],
    templates=[{"name":"Card1","qfmt":"{{Q}}","afmt":"{{FrontSide}}<hr>{{A}}"}])

DECK = genanki.Deck(2059400110, "aistudy")

def h(s):
    """SPEC §5.1 确定性 anki_id：sha1 前 8 位 → int，&0x7fffffff 防溢出"""
    return int(hashlib.sha1(s.encode("utf-8")).hexdigest()[:8], 16) & 0x7fffffff

# ---- 词典白名单（SPEC §3.2：描述子必须来自 templates/descriptors/<domain>.md）----
def load_whitelist():
    keys = set()
    for dictpath in glob.glob("templates/descriptors/*.md"):
        try:
            txt = open(dictpath, encoding="utf-8").read()
        except FileNotFoundError:
            continue
        m = re.search(r"^## 受控描述子\s*\n(.*?)(\n## |\Z)", txt, re.S | re.M)
        block = m.group(1) if m else txt
        for line in block.splitlines():
            mm = re.match(r"^(\S+)\s*::", line.strip())
            if mm:
                keys.add(mm.group(1))
    return keys

WHITELIST = load_whitelist()
if not WHITELIST:
    sys.stderr.write("警告: 词典为空（templates/descriptors/*.md 无受控描述子），所有 descriptor 行将被跳过\n")

# ---- frontmatter 工具（行级操作，禁全量序列化，SPEC §10）----
FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S | re.M)

def fm_get(text, field):
    m = FM_RE.search(text)
    if not m: return None
    mm = re.search(rf"^{field}:\s*(.*)$", m.group(1), re.M)
    return mm.group(1).strip() if mm else None

def fm_set_anki_id(path, anki_id):
    """仅在 frontmatter 内行级替换 anki_id 行；无则追加到 frontmatter 末尾"""
    txt = open(path, encoding="utf-8").read()
    m = FM_RE.search(txt)
    if not m:
        sys.stderr.write(f"跳过回写 {path}: 无 frontmatter\n")
        return
    fm = m.group(1)
    new_fm, n = re.subn(rf"^anki_id:.*$", f"anki_id: {anki_id}", fm, flags=re.M)
    if n == 0:
        new_fm = fm.rstrip("\n") + f"\nanki_id: {anki_id}\n"
    new_txt = txt[:m.start(1)] + new_fm + txt[m.end(1):]
    open(path, "w", encoding="utf-8").write(new_txt)

def extract_block(text, h2):
    m = re.search(rf"^## {re.escape(h2)}\s*\n(.*?)(\n## |\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else ""

# descriptor 行：key:: concept → value（支持 → 和 ->）
DESC_RE = re.compile(r"^(.+?)::\s*(.+?)\s*(?:→|->)\s*(.+)$")

# ---- notes：Descriptors :: 行成卡 ----
note_cards = 0
for p in glob.glob("notes/**/*.md", recursive=True):
    if os.path.basename(p) == "README.md":
        continue
    txt = open(p, encoding="utf-8").read()
    slug = fm_get(txt, "slug")
    if not slug:
        slug = os.path.basename(p)[:-3]
        sys.stderr.write(f"提示 {p}: 无 slug 字段，用文件名兜底\n")
    subject = fm_get(txt, "subject") or ""
    desc_block = extract_block(txt, "Descriptors")
    first_id = None
    for line in desc_block.splitlines():
        line = line.strip()
        if not line or line.startswith("<!--"):
            continue
        dm = DESC_RE.match(line)
        if not dm:
            continue
        key, concept, value = dm.group(1).strip(), dm.group(2).strip(), dm.group(3).strip()
        if key not in WHITELIST:
            sys.stderr.write(f"跳过 {p}: 描述子 '{key}' 不在词典白名单\n")
            continue
        aid = h(f"{slug}::{key}")
        if first_id is None:
            first_id = aid  # frontmatter anki_id 存首个 descriptor 的 hash（代表性锚点）
        n = genanki.Note(model=MODEL, fields=[f"{concept} - {key}", value, subject], guid=aid)
        DECK.add_note(n)
        note_cards += 1
    if first_id is not None:
        fm_set_anki_id(p, first_id)

# ---- quiz：题目↔标准答案成卡（稳定 guid，不回写 frontmatter，quiz 无 anki_id 字段）----
quiz_cards = 0
for p in glob.glob("quiz/*.md"):
    if os.path.basename(p) == "README.md":
        continue
    txt = open(p, encoding="utf-8").read()
    q = extract_block(txt, "题目")
    a = extract_block(txt, "标准答案 / 评分 rubric")
    if not q:
        continue
    stem = os.path.basename(p)[:-3]
    aid = h(f"quiz::{stem}")
    topic = stem.rsplit("-", 1)[0]
    n = genanki.Note(model=MODEL, fields=[q, a, topic], guid=aid)
    DECK.add_note(n)
    quiz_cards += 1

pkg = "aistudy.apkg"
genanki.Package(DECK).write_to_file(pkg)
print(f"→ {pkg}  ({len(DECK.notes)} cards: {note_cards} from notes, {quiz_cards} from quiz)")
PY
