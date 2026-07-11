#!/usr/bin/env bash
# smoke-test.sh —— 本地回归：语法 + 信任链 + prep 路径 + multi-card sync
# 用法: bash scripts/smoke-test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
if [ -x .venv/bin/python ]; then PYTHON=.venv/bin/python; else PYTHON=python3; fi

pass=0
fail=0
assert() {
  local name="$1"; shift
  if "$@"; then
    echo "PASS  $name"
    pass=$((pass+1))
  else
    echo "FAIL  $name" >&2
    fail=$((fail+1))
  fi
}

echo "== bash -n =="
bash -n scripts/*.sh
assert "bash -n" true

echo "== taxonomy + content =="
bash scripts/taxonomy-check.sh >/dev/null
bash scripts/validate-content.sh >/dev/null
assert "make-check-equivalent" true

echo "== anki export (notes+quiz) =="
out=$(bash scripts/anki-export.sh)
echo "$out"
echo "$out" | grep -q "from quiz" 
assert "anki-export has quiz cards" bash -c 'echo "$0" | grep -q "from quiz" && echo "$0" | grep -Eq "[1-9][0-9]* from notes"' "$out"

echo "== prep path (no double domain) =="
sample="/tmp/aistudy-smoke-$$.md"
echo "smoke body" > "$sample"
bash scripts/prep.sh "$sample" "建造师.机电实务" >/tmp/aistudy-smoke-prep.out
dest=$(rg -o 'materials/[^ ]+\.md' /tmp/aistudy-smoke-prep.out | head -1)
assert "prep dest under 机电实务 not 建造师/建造师" bash -c '[[ "$0" == materials/建造师/机电实务/* ]]' "$dest"
assert "prep dest exists" test -f "$dest"
# cleanup prep artifact
rm -f "$dest"
rmdir "$(dirname "$dest")" 2>/dev/null || true

echo "== prep rejects binary without OCR =="
fake="/tmp/aistudy-smoke-$$.pdf"
"$PYTHON" -c "open('$fake','wb').write(b'%PDF-1.4 smoke')"
if bash scripts/prep.sh "$fake" "建造师.机电实务" >/tmp/aistudy-smoke-prep-fail.out 2>&1; then
  assert "prep reject pdf" false
else
  assert "prep reject pdf" true
fi

echo "== export rejects empty source quiz =="
mkdir -p quiz
badq="quiz/smoke-no-source.md"
cat > "$badq" <<'EOF'
---
topic: smoke
slug: smoke-no-source
source: []
tags: ["domain/建造师", "subject/建造师.机电实务"]
---
## 题目
Q
## 标准答案 / 评分 rubric
A
EOF
if bash scripts/anki-export.sh >/tmp/aistudy-smoke-export-fail.out 2>&1; then
  assert "export reject empty source" false
else
  assert "export reject empty source" true
fi
rm -f "$badq"

echo "== multi-card sync aggregates once =="
note="notes/建造师/机电实务/电缆敷设.md"
cp "$note" /tmp/aistudy-smoke-note.bak
"$PYTHON" - <<'PY'
import csv, hashlib, re, subprocess
from pathlib import Path
slug = "dian-lan-fu-she"
def h(s):
    return int(hashlib.sha1(s.encode()).hexdigest()[:8], 16) & 0x7fffffff
guids = [str(h(f"{slug}::{k}")) for k in ["参数", "规范条文", "工序"]]
csv_path = "/tmp/aistudy-smoke-review.csv"
with open(csv_path, "w", encoding="utf-8", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["anki_guid", "review_date", "interval", "ease"])
    w.writeheader()
    w.writerow({"anki_guid": guids[0], "review_date": "2026-07-01", "interval": 1, "ease": 1.2})
    w.writerow({"anki_guid": guids[0], "review_date": "2026-07-10", "interval": 1, "ease": 1.1})
    w.writerow({"anki_guid": guids[1], "review_date": "2026-07-11", "interval": 30, "ease": 2.5})
    w.writerow({"anki_guid": guids[2], "review_date": "2026-07-09", "interval": 3, "ease": 2.0})
note = Path("notes/建造师/机电实务/电缆敷设.md")
txt = note.read_text(encoding="utf-8")
txt = re.sub(r"^mastery:.*$", "mastery: 2", txt, flags=re.M)
txt = re.sub(r"\n?<!-- drift -->\n?", "\n", txt)
note.write_text(txt, encoding="utf-8")
out = subprocess.check_output(["bash", "scripts/anki-sync.sh", csv_path], text=True)
assert "1 notes 更新" in out, out
assert "cards=3" in out, out
body = note.read_text(encoding="utf-8")
assert re.search(r"^mastery: 1$", body, re.M), body
assert "<!-- drift -->" in body
print(out)
PY
assert "multi-card aggregate" true
mv /tmp/aistudy-smoke-note.bak "$note"

echo "== restore gates =="
bash scripts/taxonomy-check.sh >/dev/null
bash scripts/validate-content.sh >/dev/null
bash scripts/anki-export.sh >/dev/null

echo
echo "smoke summary: pass=$pass fail=$fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "ALL SMOKE PASSED"
