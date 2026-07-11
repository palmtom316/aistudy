#!/usr/bin/env bash
# prep.sh —— 资料入库管线：OCR → 归档到 materials/
# 用法:
#   bash scripts/prep.sh 课件.pdf [SUBJECT]
#   DOMAIN=建造师 SUBJECT=建造师.机电实务 bash scripts/prep.sh 课件.pdf
# 依赖: mineru (推荐) 或 paddleocr (fallback)
# implements SPEC §6.4 (materials/<domain>/<subject>/<year>/)
set -euo pipefail

FILE="${1:?FILE required}"
DOMAIN="${DOMAIN:-建造师}"
SUBJECT="${SUBJECT:-${2:-}}"
STAMP=$(date +%Y%m%d)
YEAR=$(date +%Y)
OUTDIR=""
DEST=""

cleanup() {
  if [ -n "${OUTDIR:-}" ] && [ -d "${OUTDIR:-}" ]; then
    rm -rf "$OUTDIR"
  fi
  # 仅清理本次新建且仍为空的目标目录，避免半成品残留
  if [ -n "${DEST:-}" ] && [ -d "$DEST" ]; then
    rmdir "$DEST" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [ -z "$SUBJECT" ]; then
  echo "用法: bash scripts/prep.sh <文件> <SUBJECT>" >&2
  echo "  或: DOMAIN=建造师 SUBJECT=建造师.机电实务 bash scripts/prep.sh <文件>" >&2
  echo "  或: make prep FILE=<文件> SUBJECT=建造师.机电实务" >&2
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "文件不存在: $FILE" >&2
  exit 1
fi

# SUBJECT="建造师.机电实务" + DOMAIN="建造师" → 路径 "机电实务"
# SUBJECT="机电实务" → 路径 "机电实务"
# SUBJECT="建造师.机电实务.安装" → 路径 "机电实务/安装"
subject_path_from() {
  local domain="$1" subject="$2" rest="$2"
  if [[ "$subject" == "$domain".* ]]; then
    rest="${subject#${domain}.}"
  elif [[ "$subject" == "$domain/"* ]]; then
    rest="${subject#${domain}/}"
  fi
  if [ -z "$rest" ]; then
    echo "SUBJECT 解析后为空: $subject" >&2
    exit 1
  fi
  echo "${rest//.//}"
}

SUBJECT_PATH="$(subject_path_from "$DOMAIN" "$SUBJECT")"
BASENAME="$(basename "$FILE")"
STEM="${BASENAME%.*}"
EXT="$(printf '%s' "${BASENAME##*.}" | tr 'A-Z' 'a-z')"
if [ -x .venv/bin/python ]; then PYTHON=.venv/bin/python; else PYTHON=python3; fi

OUTDIR="$(mktemp -d "materials/.ocr-tmp.XXXXXX")"
MD=""
SOURCE_PDF=""

# 1. OCR
if command -v mineru >/dev/null 2>&1; then
  echo "→ MinerU OCR: $FILE"
  # mineru -o 期望目录而非 .md 文件；产出在 $OUTDIR/<stem>/auto/<stem>.md
  mineru -p "$FILE" -o "$OUTDIR" || {
    echo "MinerU failed" >&2; exit 1; }
  MD=$(find "$OUTDIR" -name '*.md' -type f | head -1)
  if [ -z "$MD" ]; then
    echo "MinerU 未产出 .md 文件" >&2; exit 1; fi
  mv "$MD" "$OUTDIR/${STEM}.md"
  find "$OUTDIR" -mindepth 1 -maxdepth 1 ! -name "${STEM}.md" -exec rm -rf {} +
  MD="$OUTDIR/${STEM}.md"
  if [[ "$EXT" == "pdf" ]]; then SOURCE_PDF="$FILE"; fi
elif command -v paddleocr >/dev/null 2>&1; then
  echo "→ PaddleOCR: $FILE (无公式识别，建议改用 MinerU)" >&2
  "$PYTHON" -c "
import sys
from paddleocr import PaddleOCR
ocr = PaddleOCR(use_angle_cls=True, lang='ch')
result = ocr.ocr(sys.argv[1], cls=True)
lines = []
for page in result or []:
    for line in (page or []):
        lines.append(line[1][0])
print('\n\n'.join(lines))
" "$FILE" > "$OUTDIR/${STEM}.md" || exit 1
  MD="$OUTDIR/${STEM}.md"
  if [[ "$EXT" == "pdf" ]]; then SOURCE_PDF="$FILE"; fi
else
  if [[ "$EXT" != "md" ]]; then
    echo "未找到 mineru / paddleocr，且输入不是 .md，拒绝把二进制文件当 markdown 入库: $FILE" >&2
    exit 1
  fi
  echo "未找到 mineru / paddleocr，按已有 markdown 归档" >&2
  cp "$FILE" "$OUTDIR/${STEM}.md"
  MD="$OUTDIR/${STEM}.md"
fi

# 2. 归档（SPEC §6.4: materials/<domain>/<subject>/<year>/）
DEST="materials/${DOMAIN}/${SUBJECT_PATH}/${YEAR}/"
mkdir -p "$DEST"
TARGET_MD="${DEST}${STEM}-${STAMP}.md"
cp "$MD" "$TARGET_MD"
if [ -n "$SOURCE_PDF" ]; then
  TARGET_PDF="${DEST}${STEM}-${STAMP}.pdf"
  cp "$SOURCE_PDF" "$TARGET_PDF"
  echo "→ 归档 PDF: $TARGET_PDF"
fi
echo "→ 归档 MD: $TARGET_MD"
echo "→ 下一步: make outline SUBJECT=$SUBJECT"

# 成功后取消 cleanup 中的 DEST/OUTDIR 删除（DEST 已有内容，rmdir 会自然失败；OUTDIR 仍清理）
DEST=""
