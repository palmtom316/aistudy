# scripts/

确定性运维脚本。**这些不该塞进 skill**——脚本快、稳、零成本。

| 脚本 | 作用 | 依赖 |
|---|---|---|
| `prep.sh` | PDF/PPT → OCR → 归档到 `materials/<domain>/<subject>/<year>/` | MinerU（推荐）或 PaddleOCR |
| `anki-export.sh` | 扫 notes `## Descriptors` `::` 行 + `quiz/*.md` → `aistudy.apkg`；回写稳定 `anki_id`（guid） | `genanki` |
| `anki-sync-export.sql` | 从 Anki `collection.anki2` 导出复习 CSV（`anki_guid,review_date,interval,ease`） | sqlite3（Anki 需关闭） |
| `anki-sync.sh` | 读 CSV → vault mastery 升降 + `<!-- drift -->` 标记/清理 | 无（纯 stdlib） |
| `taxonomy-check.sh` | 扫 notes tags，拒收非受控词汇（§6.2 MVP 表） | 无（纯 stdlib） |
| `compress-images.sh` | attachments/ 图片压到 1600px/300KB | imagemagick |

## 判据

- 输入确定、输出确定 → 脚本。
- 需要判断/表达/收敛 LLM 行为 → skill（见 `skills/`）。

## Anki 闭环

```
make anki               # vault → Anki（生成卡 + 回写 anki_id）
# 在 Anki 里复习
sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv
bash scripts/anki-sync.sh review.csv   # Anki → vault（mastery 升降 + drift 标记刷新）
```
