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
from collections import defaultdict

csv_path = sys.argv[1]
REQUIRED_COLUMNS = {"anki_guid", "review_date", "interval", "ease"}

def h(s):
    return int(hashlib.sha1(s.encode("utf-8")).hexdigest()[:8], 16) & 0x7fffffff

FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S | re.M)
DESC_RE = re.compile(r"^(.+?)::\s*(.+?)\s*(?:→|->)\s*(.+)$")
DRIFT_RE = re.compile(r"\n?\s*<!-- drift -->\s*\Z")

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

def parse_descriptor_line(path, line):
    dm = DESC_RE.match(line)
    if not dm:
        return None
    left, middle, value = (dm.group(1).strip(), dm.group(2).strip(), dm.group(3).strip())
    left_is_key = left in WL
    middle_is_key = middle in WL
    if left_is_key and not middle_is_key:
        return left, middle, value
    if middle_is_key and not left_is_key:
        sys.stderr.write(
            f"提示 {path}: 兼容旧 descriptor 格式，建议改成 '{middle}:: {left} → {value}'\n"
        )
        return middle, left, value
    if left_is_key and middle_is_key:
        sys.stderr.write(f"跳过 {path}: descriptor 行歧义（左右两侧都像描述子）: {line}\n")
    return None

# 建 hash → note 路径 映射（每 note 的每个 descriptor 各一 hash）
h2path = {}
for p in glob.glob("notes/**/*.md", recursive=True):
    if os.path.basename(p) == "README.md": continue
    txt = open(p, encoding="utf-8").read()
    slug = fm_get(txt, "slug") or os.path.basename(p)[:-3]
    seen_keys = set()
    for line in extract_block(txt, "Descriptors").splitlines():
        line = line.strip()
        if not line or line.startswith("<!--"): continue
        parsed = parse_descriptor_line(p, line)
        if not parsed: continue
        key, _, _ = parsed
        if key in seen_keys:
            raise SystemExit(f"{p}: 重复 descriptor key '{key}'（同 note 内 key 必须唯一，否则 guid 碰撞）")
        seen_keys.add(key)
        h2path[str(h(f"{slug}::{key}"))] = p

# 读 CSV，按 anki_guid 聚合并按 review_date 排序
reviews = defaultdict(list)
with open(csv_path, encoding="utf-8") as f:
    reader = csv.DictReader(f)
    fieldnames = set(reader.fieldnames or [])
    if not REQUIRED_COLUMNS.issubset(fieldnames):
        if "note_id" in fieldnames and "anki_guid" not in fieldnames:
            raise SystemExit(
                "CSV 缺 anki_guid 列：旧版 SQL 导出的是 Anki notes.id，无法与 vault 的 anki_id 对账。"
                " 请重新运行 scripts/anki-sync-export.sql。"
            )
        missing = ", ".join(sorted(REQUIRED_COLUMNS - fieldnames))
        raise SystemExit(f"CSV 缺列: {missing}")
    for row in reader:
        nid = row["anki_guid"].strip()
        try:
            ivl = int(row["interval"])
            ease = float(row["ease"])
            reviews[nid].append((row["review_date"], ivl, ease))
        except (KeyError, ValueError):
            continue
for anki_guid in reviews:
    reviews[anki_guid].sort(key=lambda r: r[0])

def fm_set(text, field, value):
    new_text, n = re.subn(rf"^{field}:.*$", f"{field}: {value}", text, flags=re.M)
    if n == 0:
        return text.rstrip("\n") + f"\n{field}: {value}\n"
    return new_text

def set_drift_marker(text, drift):
    base = DRIFT_RE.sub("", text).rstrip("\n")
    if drift:
        return base + "\n<!-- drift -->\n"
    return base + "\n"

def write_note(path, new_mastery, last_rev, drift):
    txt = open(path, encoding="utf-8").read()
    m = FM_RE.search(txt)
    if not m: return
    fm = m.group(1)
    fm2 = fm_set(fm, "mastery", new_mastery)
    fm2 = fm_set(fm2, "last_reviewed", last_rev)
    new_txt = txt[:m.start(1)] + fm2 + txt[m.end(1):]
    new_txt = set_drift_marker(new_txt, drift)
    open(path, "w", encoding="utf-8").write(new_txt)

def card_is_drift(rows):
    return len(rows) >= 2 and rows[-1][2] < 1.5 and rows[-2][2] < 1.5

def card_target_mastery(cur_m, rows, drift):
    last_rev, ivl, ease = rows[-1]
    if drift:
        return max(0, cur_m - 1)
    if ivl >= 21 and cur_m < 3:
        return 3
    if ivl >= 7 and cur_m < 2:
        return 2
    return cur_m

# 按 path 聚合所有匹配卡，避免多 descriptor 卡互相覆盖
by_path = defaultdict(list)
matched_cards = 0
for anki_guid, rows in reviews.items():
    path = h2path.get(anki_guid)
    if not path:
        continue
    matched_cards += 1
    by_path[path].append((anki_guid, rows))

changed = 0
for path, card_rows in sorted(by_path.items()):
    txt = open(path, encoding="utf-8").read()
    cur = fm_get(txt, "mastery")
    try:
        cur_m = int(cur) if cur not in (None, "") else 0
    except ValueError:
        cur_m = 0
    current_drift = "<!-- drift -->" in txt

    # note.drift = any(card.drift)
    note_drift = any(card_is_drift(rows) for _, rows in card_rows)
    # 最新 review_date 作为 last_reviewed
    last_rev = max(rows[-1][0] for _, rows in card_rows)

    # mastery 聚合：降级优先；升级取最强 interval 目标，但单轮最多 ±1
    targets = [card_target_mastery(cur_m, rows, card_is_drift(rows)) for _, rows in card_rows]
    if any(t < cur_m for t in targets) or note_drift:
        new_m = max(0, cur_m - 1)
    else:
        strongest = max(targets) if targets else cur_m
        if strongest > cur_m:
            new_m = min(3, cur_m + 1)
        else:
            new_m = cur_m

    should_write = note_drift or current_drift != note_drift or new_m != cur_m
    if not should_write:
        continue
    write_note(path, new_m, last_rev, note_drift)
    print(f"{'drift' if note_drift else 'sync'} {path}: mastery {cur_m}→{new_m}, last_reviewed={last_rev}, cards={len(card_rows)}")
    changed += 1

if reviews and matched_cards == 0:
    sys.stderr.write(
        "警告: CSV 中没有任何 anki_guid 匹配当前 vault；请确认使用最新的 scripts/anki-sync-export.sql 重新导出。\n"
    )

print(f"→ {changed} notes 更新（聚合 {matched_cards} 张匹配卡）")
PY
