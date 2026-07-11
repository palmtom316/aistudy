# scripts/

确定性运维脚本。**这些不该塞进 skill**——脚本快、稳、零成本。

| 脚本 | 作用 | 依赖 |
|---|---|---|
| `prep.sh` | PDF/PPT/MD → OCR(可选) → 归档到 `materials/<domain>/<subject>/<year>/`；PDF 与 md 并存 | MinerU（推荐）或 PaddleOCR；`.md` 可无 OCR |
| `anki-export.sh` | 扫 notes `## Descriptors` `::` 行 + `quiz/*.md` → `aistudy.apkg`；回写首卡 `anki_id`；拒无 source quiz / 重复 key | `genanki` |
| `anki-sync-export.sql` | 从 Anki `collection.anki2` 导出复习 CSV（`anki_guid,review_date,interval,ease`） | sqlite3（Anki 需关闭） |
| `anki-sync.sh` | 读 CSV → **按 note path 聚合** mastery 升降 + `<!-- drift -->` 标记/清理 | 无（纯 stdlib） |
| `taxonomy-check.sh` | 扫 notes/quiz/cases tags，拒收非受控词汇（§6.2 MVP 表） | 无（纯 stdlib） |
| `validate-content.sh` | source / 必填 frontmatter / descriptor 白名单与重复 key | 无（纯 stdlib） |
| `compress-images.sh` | attachments/ 图片压到 1600px/300KB（保留扩展名，避免 md 断链） | imagemagick |
| `smoke-test.sh` | prep / taxonomy / content / anki-export / multi-card sync 回归 | bash + python3 |

## 判据

- 输入确定、输出确定 → 脚本。
- 需要判断/表达/收敛 LLM 行为 → skill（见 `skills/`）。

## Anki 闭环

```
make check              # taxonomy + 信任链
make anki               # vault → Anki（生成卡 + 回写首卡 anki_id）
# 在 Anki 里复习
sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv
bash scripts/anki-sync.sh review.csv   # Anki → vault（按 path 聚合 mastery/drift）
make smoke              # 本地快速回归
```

## 多卡 note 语义

- 一篇 note 的每个 descriptor key 对应一张 Anki 卡（guid = `sha1(slug::key)`）。
- frontmatter `anki_id` **只存首卡 guid**，用于「是否已 export」扫描。
- `anki-sync` 用全部 descriptor 重建 guid→path 映射，再按 path 聚合写回；不会因 CSV 行序互相覆盖。
