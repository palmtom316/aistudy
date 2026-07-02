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

if [ -z "$SUBJECT" ]; then
  echo "用法: bash scripts/prep.sh <文件> <SUBJECT>" >&2
  echo "  或: DOMAIN=建造师 SUBJECT=建造师.机电实务 bash scripts/prep.sh <文件>" >&2
  exit 1
fi

# SUBJECT="建造师.机电实务" → 路径片段 "建造师/机电实务"
SUBJECT_PATH="${SUBJECT//.//}"
BASENAME="$(basename "$FILE")"
STEM="${BASENAME%.*}"

# 1. OCR
if command -v mineru >/dev/null 2>&1; then
  echo "→ MinerU OCR: $FILE"
  OUTDIR="materials/.ocr-tmp-$STAMP"
  mkdir -p "$OUTDIR"
  # mineru -o 期望目录而非 .md 文件；产出在 $OUTDIR/<stem>/auto/<stem>.md
  mineru -p "$FILE" -o "$OUTDIR" || {
    echo "MinerU failed" >&2; rm -rf "$OUTDIR"; exit 1; }
  MD=$(find "$OUTDIR" -name '*.md' -type f | head -1)
  if [ -z "$MD" ]; then
    echo "MinerU 未产出 .md 文件" >&2; rm -rf "$OUTDIR"; exit 1; fi
  mv "$MD" "$OUTDIR/${STEM}.md"
  find "$OUTDIR" -mindepth 1 -maxdepth 1 ! -name "${STEM}.md" -exec rm -rf {} +
  MD="$OUTDIR/${STEM}.md"
elif command -v paddleocr >/dev/null 2>&1; then
  echo "→ PaddleOCR: $FILE (无公式识别，建议改用 MinerU)" >&2
  OUTDIR="materials/.ocr-tmp-$STAMP"
  mkdir -p "$OUTDIR"
  python -c "
import sys
from paddleocr import PaddleOCR
ocr = PaddleOCR(use_angle_cls=True, lang='ch')
result = ocr.ocr(sys.argv[1], cls=True)
lines = []
for page in result or []:
    for line in (page or []):
        lines.append(line[1][0])
print('\n\n'.join(lines))
" "$FILE" > "$OUTDIR/${STEM}.md" || { rm -rf "$OUTDIR"; exit 1; }
  MD="$OUTDIR/${STEM}.md"
else
  echo "未找到 mineru / paddleocr，跳过 OCR（假设输入已为 md）" >&2
  MD="$FILE"
fi

# 2. 归档（SPEC §6.4: materials/<domain>/<subject>/<year>/）
DEST="materials/${DOMAIN}/${SUBJECT_PATH}/${YEAR}/"
mkdir -p "$DEST"
TARGET="${DEST}${STEM}-${STAMP}.md"
mv "$MD" "$TARGET"
# 清理可能残留的临时目录
rm -rf "materials/.ocr-tmp-$STAMP" 2>/dev/null || true
echo "→ 归档: $TARGET"
echo "→ 下一步: make outline SUBJECT=$SUBJECT"
