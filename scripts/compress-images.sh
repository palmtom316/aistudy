#!/usr/bin/env bash
# compress-images.sh —— attachments/ 图片压缩到 1600px/300KB
# implements SPEC §8
# 依赖: imagemagick (convert/identify)。缺失则提示并退出。
#
# 规则：
#   1. 长边缩到 1600px（短边按比例）
#   2. JPEG/WEBP 质量 80 起步，仍 >300KB 逐级降到 60
#   3. PNG：strip + 8-bit；仍 >300KB 转 jpg 兜底（保留透明失败则警告）
#   4. 原图按相对路径备份到 attachments/.original/（gitignore）；压缩版原地写回
#   5. 跳过 <300KB 且 ≤1600px 的图（无需处理）
set -euo pipefail

# 选 magick（v7）或 convert（v6）
if command -v magick >/dev/null 2>&1; then
    CONVERT_CMD=(magick)
    IDENTIFY_CMD=(magick identify)
elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then
    CONVERT_CMD=(convert)
    IDENTIFY_CMD=(identify)
else
    echo "❌ 缺 imagemagick。macOS: brew install imagemagick；Linux: apt install imagemagick" >&2; exit 1
fi

MAX_DIM=1600
MAX_BYTES=$((300*1024))

# 跨平台文件大小（字节）：macOS 用 stat -f%z，Linux 用 stat -c%s
file_bytes() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo 0
}

mkdir -p attachments/.original

shopt -s nullglob globstar
count=0; skip=0
for f in attachments/**/*.{jpg,jpeg,png,gif,webp,bmp}; do
  [ -f "$f" ] || continue
  # 长边像素
  dim=$("${IDENTIFY_CMD[@]}" -format '%w %h' "$f" 2>/dev/null | awk '{print ($1>$2?$1:$2)}')
  dim=${dim:-0}
  bytes=$(file_bytes "$f")
  if [ "$dim" -le "$MAX_DIM" ] && [ "$bytes" -le "$MAX_BYTES" ]; then
    skip=$((skip+1)); continue
  fi
  # 原图备份（保留相对路径；已备份过则不覆盖原图）
  bak="attachments/.original/${f#attachments/}"
  mkdir -p "$(dirname "$bak")"
  if [ ! -e "$bak" ]; then
    cp -p "$f" "$bak"
  fi
  ext=$(echo "${f##*.}" | tr 'A-Z' 'a-z')
  tmp="${f%.*}.tmp.${ext}"
  case "$ext" in
    jpg|jpeg|webp)
      q=80
      while [ "$q" -ge 60 ]; do
        "${CONVERT_CMD[@]}" "$f" -resize "${MAX_DIM}x${MAX_DIM}>" -quality "$q" "$tmp"
        s=$(file_bytes "$tmp")
        if [ "$s" -le "$MAX_BYTES" ]; then break; fi
        q=$((q-10))
      done
      mv "$tmp" "$f"
      ;;
    png)
      "${CONVERT_CMD[@]}" "$f" -resize "${MAX_DIM}x${MAX_DIM}>" -strip -depth 8 "$tmp"
      s=$(file_bytes "$tmp")
      if [ "$s" -gt "$MAX_BYTES" ]; then
        # 保留 PNG 引用：继续降质，不转 JPG，避免 md 断链
        echo "  ⚠ PNG >300KB，继续降质但保留 PNG 扩展名: $f" >&2
        "${CONVERT_CMD[@]}" "$f" -resize "${MAX_DIM}x${MAX_DIM}>" -strip -depth 8 -colors 256 "$tmp"
        s2=$(file_bytes "$tmp")
        if [ "$s2" -gt "$MAX_BYTES" ]; then
          echo "  ⚠ PNG 仍 >300KB，已缩到 ${MAX_DIM}px 并 strip: $f" >&2
        fi
        mv "$tmp" "$f"
      else
        mv "$tmp" "$f"
      fi
      ;;
    gif|bmp)
      # 透明/动画保不住，只 resize
      "${CONVERT_CMD[@]}" "$f" -resize "${MAX_DIM}x${MAX_DIM}>" "$tmp"
      mv "$tmp" "$f"
      ;;
  esac
  nb=$(file_bytes "$f")
  echo "✓ $f  (${dim}px/$((bytes/1024))KB → ${MAX_DIM}pxmax/$((nb/1024))KB，原图 .original/)"
  count=$((count+1))
done

echo "→ 压缩 $count 张，跳过 $skip 张（已在限内）"
