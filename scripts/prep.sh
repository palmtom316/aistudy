#!/usr/bin/env bash
# prep.sh —— 资料入库管线：OCR → 归档到 materials/
# 用法: bash scripts/prep.sh 课件.pdf
# 依赖: mineru (可选 paddle fallback)
set -euo pipefail

FILE="${1:?FILE required}"
SUBJECT="${SUBJECT:-未分类}"
STAMP=$(date +%Y%m%d)

# 1. OCR
if command -v mineru >/dev/null 2>&1; then
  echo "→ MinerU OCR: $FILE"
  OUT="${FILE%.*}-$STAMP"
  mineru -i "$FILE" -o "$OUT.md" || {
    echo "MinerU failed, fallback to paddle"; exit 1; }
  MD="$OUT.md"
elif command -v paddleocr >/dev/null 2>&1; then
  echo "→ PaddleOCR: $FILE (无公式识别，建议改用 MinerU)"
  OUT="${FILE%.*}-$STAMP"
  python -c "import paddleocr; ..." "$FILE" > "$OUT.md" 2>&1 || exit 1
  MD="$OUT.md"
else
  echo "未找到 mineru / paddleocr，跳过 OCR（假设输入已为 md）"
  MD="$FILE"
fi

# 2. 归档
DEST="materials/$SUBJECT/$(basename "$MD")"
mkdir -p "materials/$SUBJECT"
mv "$MD" "$DEST"
echo "→ 归档: $DEST"
echo "→ 下一步: make outline SUBJECT=$SUBJECT"
