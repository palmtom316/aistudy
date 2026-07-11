#!/usr/bin/env bash
# validate-content.sh —— 信任链 / schema 校验
# implements SPEC §5.2（source 强制）、§3.2（descriptor 白名单）、frontmatter 必填
set -euo pipefail

if [ -x .venv/bin/python ]; then PYTHON=.venv/bin/python; else PYTHON=python3; fi

"$PYTHON" - <<'PY'
import re, glob, os, sys

FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S | re.M)
DESC_RE = re.compile(r"^(.+?)::\s*(.+?)\s*(?:→|->)\s*(.+)$")

NOTE_REQUIRED = ["domain", "subject", "topic", "slug", "core", "mastery", "source", "tags"]
QUIZ_REQUIRED = ["source", "tags"]
CASE_REQUIRED = ["source", "tags"]

def load_whitelist():
    keys = set()
    for d in glob.glob("templates/descriptors/*.md"):
        try:
            txt = open(d, encoding="utf-8").read()
        except FileNotFoundError:
            continue
        m = re.search(r"^## 受控描述子\s*\n(.*?)(\n## |\Z)", txt, re.S | re.M)
        block = m.group(1) if m else txt
        for line in block.splitlines():
            mm = re.match(r"^(\S+)\s*::", line.strip())
            if mm:
                keys.add(mm.group(1))
    return keys

WL = load_whitelist()

def fm_get(fm, field):
    m = re.search(rf"^{field}:\s*(.*)$", fm, re.M)
    return m.group(1).strip() if m else None

def source_values(fm):
    raw = fm_get(fm, "source")
    if raw is None:
        return []
    raw = raw.strip()
    if not raw or raw in ("[]", "null", "~"):
        return []
    items = re.findall(r'["\']([^"\']+)["\']', raw)
    if items:
        return [i.strip() for i in items if i.strip()]
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        return [p.strip().strip("\"'") for p in inner.split(",") if p.strip()]
    return [raw]

def extract_block(text, h2):
    m = re.search(rf"^## {re.escape(h2)}\s*\n(.*?)(\n## |\Z)", text, re.S | re.M)
    return m.group(1).strip() if m else ""

def parse_descriptor(line):
    dm = DESC_RE.match(line)
    if not dm:
        return None
    left, middle, value = dm.group(1).strip(), dm.group(2).strip(), dm.group(3).strip()
    if left in WL and middle not in WL:
        return left
    if middle in WL and left not in WL:
        return middle
    if left in WL and middle in WL:
        return "__ambiguous__"
    return None

errors = []
checked = 0

def check_file(path, required_fields, *, require_source=True, check_descriptors=False):
    global checked
    checked += 1
    txt = open(path, encoding="utf-8").read()
    m = FM_RE.search(txt)
    if not m:
        errors.append(f"{path}: 无 frontmatter")
        return
    fm = m.group(1)
    for field in required_fields:
        if fm_get(fm, field) is None:
            errors.append(f"{path}: 缺 frontmatter 字段 {field}")
    if require_source and not source_values(fm):
        errors.append(f"{path}: source 为空（SPEC §5.2）")
    if check_descriptors:
        seen = set()
        for line in extract_block(txt, "Descriptors").splitlines():
            line = line.strip()
            if not line or line.startswith("<!--"):
                continue
            key = parse_descriptor(line)
            if key is None:
                errors.append(f"{path}: descriptor 不在白名单或格式错误: {line}")
                continue
            if key == "__ambiguous__":
                errors.append(f"{path}: descriptor 行歧义: {line}")
                continue
            if key in seen:
                errors.append(f"{path}: 重复 descriptor key '{key}'")
            seen.add(key)

for p in sorted(glob.glob("notes/**/*.md", recursive=True)):
    if os.path.basename(p) == "README.md":
        continue
    check_file(p, NOTE_REQUIRED, require_source=True, check_descriptors=True)

for p in sorted(glob.glob("quiz/*.md")):
    if os.path.basename(p) == "README.md":
        continue
    check_file(p, QUIZ_REQUIRED, require_source=True)

for p in sorted(glob.glob("cases/*.md")):
    if os.path.basename(p) == "README.md":
        continue
    check_file(p, CASE_REQUIRED, require_source=True)

if errors:
    print(f"❌ content 校验失败（{len(errors)} 项，已扫 {checked} 文件）:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
print(f"✅ content 校验通过（{checked} 文件）")
PY
