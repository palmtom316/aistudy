#!/usr/bin/env bash
# anki-export.sh —— 把 quiz/*.md 导出为 Anki 包
# 依赖: genanki (pip install genanki)
# 每个 quiz 文件 → 一张卡片：正面=题目，反面=标准答案
set -euo pipefail

python3 - <<'PY'
import os, re, glob, hashlib
try:
    import genanki
except ImportError:
    raise SystemExit("pip install genanki 先")

MODEL = genanki.Model(
    1091735101, "aistudy-quiz",
    fields=[{"name":"Q"},{"name":"A"},{"name":"Topic"}],
    templates=[{"name":"Card1","qfmt":"{{Q}}","afmt":"{{FrontSide}}<hr>{{A}}"}])

DECK = genanki.Deck(2059400110, "aistudy")

def extract(path, h1):
    txt = open(path, encoding="utf-8").read()
    m = re.search(rf"## {h1}\s*\n(.*?)(\n## |\Z)", txt, re.S)
    return (m.group(1).strip() if m else "").replace("$$","$")

for p in glob.glob("quiz/*.md"):
    q, a = extract(p,"题目"), extract(p,"标准答案 / 评分 rubric")
    if not q: continue
    topic = os.path.basename(p).rsplit("-",1)[0]
    note = genanki.Note(model=MODEL, fields=[q, a, topic])
    DECK.add_note(note)

pkg = "aistudy.apkg"
genanki.Package(DECK).write_to_file(pkg)
print(f"→ {pkg}  ({len(DECK.notes)} cards)")
PY
