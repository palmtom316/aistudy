#!/usr/bin/env bash
# taxonomy-check.sh —— 扫 notes/ quiz/ cases/ 的 tag，拒绝非受控词汇
# implements SPEC §6.2 (MVP 受控取值表)
# 依赖: 无（纯 stdlib）。优先 .venv python，否则 python3
set -euo pipefail

if [ -x .venv/bin/python ]; then PYTHON=.venv/bin/python; else PYTHON=python3; fi

"$PYTHON" - <<'PY'
import re, glob, os, sys

FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S | re.M)

# SPEC §6.2 MVP 受控取值表
ALLOWED = {
    "domain/建造师",
    "subject/建造师.机电实务",
}
# 医学上线后会补 system/ course/；MVP 域不用
VALID_PREFIXES = ("domain/", "subject/", "system/", "course/")

def parse_tags(fm):
    # 直接匹配 prefix/value 形态，避开 []" 噪音
    m = re.search(r"^tags:\s*(.*)$", fm, re.M)
    tags = set()
    if m:
        tags |= set(re.findall(r'(\w+/[^\s"\],]+)', m.group(1)))
    # 块式数组：tags:\n  - a\n  - b
    block = re.search(r"^tags:\s*\n((?:\s+-\s.*\n?)+)", fm, re.M)
    if block:
        for ln in block.group(1).splitlines():
            tags |= set(re.findall(r'(\w+/[^\s"\],]+)', ln))
    return tags

bad = []
checked = 0
# SPEC §6.2 受控词汇覆盖所有带 frontmatter tags 的文件：notes + quiz + cases
patterns = []
for pat in ("notes/**/*.md", "quiz/*.md", "cases/*.md"):
    patterns.extend(glob.glob(pat, recursive=True))
for p in sorted(patterns):
    if os.path.basename(p) == "README.md":
        continue
    checked += 1
    txt = open(p, encoding="utf-8").read()
    m = FM_RE.search(txt)
    if not m:
        bad.append((p, ["无 frontmatter"]))
        continue
    tags = parse_tags(m.group(1))
    for t in tags:
        if not t.startswith(VALID_PREFIXES):
            bad.append((p, [f"非法前缀: {t}"]))
        elif t not in ALLOWED:
            bad.append((p, [f"MVP 未受控: {t}（仅认 domain/建造师 + subject/建造师.机电实务）"]))

if bad:
    print(f"❌ taxonomy 校验失败（{len(bad)} 文件）:")
    for p, errs in bad:
        print(f"  {p}")
        for e in errs:
            print(f"    - {e}")
    sys.exit(1)
print(f"✅ taxonomy 通过（{checked} 文件全部合规）")
PY
