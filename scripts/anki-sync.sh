#!/usr/bin/env bash
# anki-sync.sh —— 读 Anki 复习 CSV → vault mastery 升降 + drift 标记
# implements SPEC §5.1
# 用法: bash scripts/anki-sync.sh review.csv
# 依赖: 无（纯 stdlib）。优先用 .venv python，否则 python3
set -euo pipefail

CSV="${1:-}"
if [ -z "$CSV" ]; then
  echo "用法: bash scripts/anki-sync.sh <review.csv>" >&2
  exit 1
fi
[ -f "$CSV" ] || { echo "文件不存在: $CSV" >&2; exit 1; }

if [ -x .venv/bin/python ]; then PYTHON=.venv/bin/python; else PYTHON=python3; fi

"$PYTHON" - "$CSV" <<'PY'
import csv, re, glob, hashlib, os, sys
from datetime import date

csv_path = sys.argv[1]

def h(s):
    return int(hashlib.sha1(s.encode("utf-8")).hexdigest()[:8], 16) & 0x7fffffff

FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S | re.M)
DESC_RE = re.compile(r"^(.+?)::\s*(.+?)\s*(?:→|->)\s*(.+)$")

def load_whitelist():
    keys = set()
    for d in glob.glob("templates/descriptors/*.md"):
        try: txt = open(d, encoding="utf-8").read()
        except FileNotFoundError: continue
        m = re.search(r"^## 受控描述子\s*\n(.*?)(\n## |\Z)", txt, re.S | re.M)
        block = m.group(1) if m else txt
        for line in block.splitlines():
            mm = re.match(r"^(\S+)\s*::", line.strip())
            if mm: keys.add(mm.group(1))
    return keys

WL = load_whitelist()

def fm_get(text, field):
    m = FM_RE.search(text)
    if not m: return None
    mm = re.search(rf"^{field}:\s*(.*)$", m.group(1), re.M)
    return mm.group(1).strip() if mm else None

def extract_block(text, h2):
    m = re.search(rf"^## {re.escape(h2)}\s*\n(.*?)(\n## |\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else ""

# 建 hash → note 路径 映射（每 note 的每个 descriptor 各一 hash）
h2path = {}
for p in glob.glob("notes/**/*.md", recursive=True):
    if os.path.basename(p) == "README.md": continue
    txt = open(p, encoding="utf-8").read()
    slug = fm_get(txt, "slug") or os.path.basename(p)[:-3]
    for line in extract_block(txt, "Descriptors").splitlines():
        line = line.strip()
        if not line or line.startswith("<!--"): continue
        dm = DESC_RE.match(line)
        if not dm: continue
        key = dm.group(1).strip()
        if key not in WL: continue
        h2path[str(h(f"{slug}::{key}"))] = p

# 读 CSV，按 note_id 聚合并按 review_date 排序
from collections import defaultdict
reviews = defaultdict(list)
with open(csv_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        nid = row["note_id"].strip()
        try:
            ivl = int(row["interval"])
            ease = float(row["ease"])
            reviews[nid].append((row["review_date"], ivl, ease))
        except (KeyError, ValueError):
            continue
for nid in reviews:
    reviews[nid].sort(key=lambda r: r[0])

def write_note(path, new_mastery, last_rev, drift):
    txt = open(path, encoding="utf-8").read()
    m = FM_RE.search(txt)
    if not m: return
    fm = m.group(1)
    fm2, n = re.subn(rf"^mastery:.*$", f"mastery: {new_mastery}", fm, flags=re.M)
    fm2, _ = re.subn(rf"^last_reviewed:.*$", f"last_reviewed: {last_rev}", fm2, flags=re.M)
    new_txt = txt[:m.start(1)] + fm2 + txt[m.end(1):]
    if drift and "<!-- drift -->" not in new_txt:
        new_txt = new_txt.rstrip("\n") + "\n<!-- drift -->\n"
    open(path, "w", encoding="utf-8").write(new_txt)

changed = 0
for nid, rows in reviews.items():
    path = h2path.get(nid)
    if not path:
        continue  # CSV 里的卡不在 vault（非本 vault 的卡），跳过
    txt = open(path, encoding="utf-8").read()
    cur = fm_get(txt, "mastery")
    try:
        cur_m = int(cur) if cur not in (None, "") else 0
    except ValueError:
        cur_m = 0
    last_rev, ivl, ease = rows[-1]
    drift = len(rows) >= 2 and rows[-1][2] < 1.5 and rows[-2][2] < 1.5
    if drift:
        new_m = max(0, cur_m - 1)
    elif ivl >= 21 and cur_m < 3:
        new_m = 3
    elif ivl >= 7 and cur_m < 2:
        new_m = 2
    else:
        if not drift:
            continue  # 无变化也跳过（不更新 last_reviewed 以免噪音 diff）
        new_m = cur_m
    if new_m == cur_m and not drift:
        continue
    write_note(path, new_m, last_rev, drift)
    print(f"{'drift' if drift else 'sync'} {path}: mastery {cur_m}→{new_m}, last_reviewed={last_rev}")
    changed += 1

print(f"→ {changed} notes 更新")
PY
