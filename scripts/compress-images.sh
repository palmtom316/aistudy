#!/usr/bin/env bash
# compress-images.sh —— attachments/ 图片压缩到 1600px/300KB
# implements SPEC §8
# 依赖: imagemagick (convert/identify/mogrify)。缺失则提示并退出。
set -euo pipefail

command -v convert >/dev/null 2>&1 || { echo "❌ 缺 imagemagick（convert）。装: sudo apt install imagemagick" >&2; exit 1; }
command -v identify >/dev/null 2>&1 || { echo "❌ 缺 imagemagick（identify）" >&2; exit 1; }

MAX_W=1600
MAX_KB=300
count=0
skip=0

shopt -s nullglob globstar
for f in attachments/**/*.{jpg,jpeg,png,gif,webp,bmp}; do
  [ -f "$f" ] || continue
  w=$(identify -format "%w" "$f" 2>/dev/null || echo 0)
  kb=$(( $(stat -c%s "$f") / 1024 ))
  if [ "$w" -le "$MAX_W" ] && [ "$kb" -le "$MAX_KB" ]; then
    skip=$((skip+1)); continue
  fi
  # 原地覆盖：resize 到最大宽 1600，再压质量
  tmp="${f}.compressed"
  convert "$f" -resize "${MAX_W}x${MAX_W}\>" -quality 85 "$tmp"
  mv "$tmp" "$f"
  echo "✓ $f  (${w}px/${kb}KB → 压缩)"
  count=$((count+1))
done

echo "→ 压缩 $count 张，跳过 $skip 张（已在限内）"
