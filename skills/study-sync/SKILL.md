---
name: study-sync
description: 对账 Anki 同步状态：列出 drift 项（连续 ease 低）与缺 anki_id 的 note，提示用户跑 anki-sync。刻意做薄——跑脚本属确定性操作（SPEC §2），本 skill 只负责呈现与提示复盘。
user-invocable: true
---

# study-sync

# implements SPEC §5.1, §5.3

扫描 vault 的 Anki 同步状态，把 drift / 未导出项呈现给用户，并提示下一步操作。**不直接跑脚本**（§2 分层：确定性操作走 scripts/，表达走 skill）。

## 数据来源（必读，全部来自 rg，不靠模型记忆）

1. **drift 项**：`rg -l "<!-- drift -->" notes/` → 当前仍处于 drift 的 note（恢复后 anki-sync.sh 会清掉标记）。
2. **未导出项**：`rg --files-without-match "anki_id: [0-9]" notes/ -g '!README.md'` → frontmatter 无 anki_id 的 note（还没跑过 anki-export）。
   - 注意：`anki_id` 只表示**至少导出过一张 descriptor 卡**；多卡 note 的其余卡 guid 不在 frontmatter。
3. **anki_id 缺失分布**：按 subject 汇总数量。

## 输出（直接打印，不写文件）

```
## Anki 同步对账（YYYY-MM-DD）

### drift 项（需重点复盘）
- <topic>  → read "notes/.../<中文文件名>.md"，mastery 已被 sync 降级
  → make quiz TOPIC="..." 重做

### 未导出项（还没生成卡）
- <topic>  → 跑 make anki 补卡

### 下一步操作
1. 若有未导出项：make anki
2. 若需从 Anki 拉复习数据回写 mastery：
   sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv
   bash scripts/anki-sync.sh review.csv
   （Anki 需关闭以释放库锁）
3. 复盘 drift 项后再跑 make drill 置顶
```

## 强制约束

- **不跑脚本**：只读 vault + 打印提示。跑 anki-export/anki-sync 是确定性操作，让用户手动执行（§2）。
- **不读 note 正文**：drift/未导出判断只看 frontmatter `anki_id` 与文件末尾 `<!-- drift -->` 标记（与 study-review 同护栏精神）。
- **不折叠进 study-drill**：study-drill 管今日复习清单，study-sync 管 Anki 闭环对账，职责分离。

## 不做的事

- 不自动调 anki-export.sh / anki-sync.sh。
- 不读 note 正文做"为什么 drift"的总结（那是 study-review 的活，且 study-review 也只读结构化字段）。
