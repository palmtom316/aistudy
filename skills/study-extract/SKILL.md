---
name: study-extract
description: 读 highlights/<book>.md 里 PDF++ 划线缓冲，按主题聚类，生成带 Descriptors + source 回链的 note 草稿。划线→结构化 descriptor 的 LLM 转换层。强制人审后才落库。
user-invocable: true
argument-hint: "[highlights/<书名>.md]"
---

# study-extract

# implements SPEC §3.2, §3.7, §5.2, §6.1, §6.2

把 `highlights/<book>.md` 里的原始划线转成 `notes/` 下的原子笔记草稿。**划线 ≠ 卡**——划线只是"这段重要"，要成卡必须先结构化成 `描述子:: 概念 → 值`（SPEC §3.2），这步是 LLM 的活，本 skill 干这个。划线驱动，不替代 `study-outline`。

## 输入

`highlights/<book>.md`（schema 见 `templates/highlight.md`，SPEC §3.7）。每条划线 = 一段 blockquote + 一行 `source: materials/.../file.pdf:pNNN`（或 `[[...pdf#page=N]]` 形态，skill 兼容两种）。开工前 `ls highlights/` 确认要处理哪本书。

## 输出

`notes/<domain>/<subject>/<中文知识点名>.md` 草稿。**先打印不落库**，用户逐篇点头后才写盘。每篇草稿：

- frontmatter 按 `templates/note.md` 全 18 字段，`source` 字段填划线来的 `materials/.../file.pdf:pNNN`（§5.2 信任链）
- `## Descriptors` 块：从 `templates/descriptors/建造师.md` 词典取描述子，把划线内容结构化为 `描述子:: 概念 → 值`，至少 3 条（§3.2）
- `## 自测一题`：基于该簇划线出一道应用题（不套话题）

## 强制约束（不可绕过）

1. **聚类优先**：同主题/同节/页码邻近的划线归到同一篇 note；零散孤立划线单独成篇或标 `<!-- 存疑 -->` 留待用户处理。不强行合并无关划线。
2. **词典锁死**（§3.2）：descriptor 的描述子必须来自 `templates/descriptors/建造师.md`。词典外一律拒收，不临时发明。需要新描述子先改词典再写 note。
3. **source 强制**（§5.2）：每条 descriptor 的值若来自划线，对应 note 的 `source` 数组必须含那条划线的 `file.pdf:pNNN`。**缺 source 则 abort，不许入库**。
4. **不幻觉**：划线里没有的数值/条文号不补。划线只划了半句，另一句不凭记忆拼。不确定标 `<!-- 存疑 -->`。
5. **不估法规生效日**：法规类 note 的 `effective_date` 不填，留空让用户查（同 study-outline 护栏）。
6. **人审 gate**：草稿打印给用户，用户逐篇确认后才写 `notes/`。**不直接落库**。
7. **taxonomy 锁死**（§6.2）：`tags` 只填 `domain/建造师` + `subject/建造师.机电实务`。不随手加 tag。
8. **文件名中文**（D-6.1）：文件名 = 中文知识点全称 = `topic` 字段值；`slug` 字段填 ASCII。

## 流程

1. `read highlights/<book>.md`，解析所有 blockquote + source 行（兼容 `file.pdf:pN` 与 `[[...pdf#page=N]]` 两种页码形态）。
2. 按页码邻近度 + 内容主题聚类（同节同主题归一起）。打印聚类清单（每簇：涉及页码、主题、划线条数）给用户确认范围。
3. 对每簇：
   a. 定一个中文知识点名（= 文件名）。
   b. `read templates/descriptors/建造师.md` 选合适描述子。
   c. 把划线内容结构化成 `描述子:: 概念 → 值` 行（≥3 条）。
   d. `source` 字段填该簇涉及的所有 `file.pdf:pNNN`。
   e. 出一道 `## 自测一题`。
4. 打印所有草稿全文（不写盘），列清单等用户逐篇确认。
5. 用户确认哪篇就写哪篇到 `notes/建造师/机电实务/`。被否的留 `highlights/<book>.md` 不动，下次再处理。
6. 写盘后提示：
   - `make anki` 生成卡（anki-export.sh 扫 Descriptors）
   - `make quiz TOPIC=<中文文件名>` 出单点题
   - 已处理的划线可在用户确认后从 highlights 文件删除（skill 不自动删，怕丢）。

## 与 study-outline 的区别

| | study-outline | study-extract |
|---|---|---|
| 输入 | 大纲/资料 md（整章梳理） | highlights/<book>.md（PDF 划线缓冲） |
| 粒度来源 | 大纲 core 点 | 划线聚类 |
| 触发场景 | "开始复习某门课" | "读完一章 PDF，划了线" |
| source 格式 | `materials/.../file.md:pNNN`（OCR md） | `materials/.../file.pdf:pNNN`（PDF 原件） |
| 人审 gate | 用户确认 core 清单后批量生成 | 逐篇确认草稿后写盘 |

两者并存：study-outline 管"整章首次建笔记"，study-extract 管"读书时划线回流"。同一知识点可能先被 outline 建过，后又从划线补 descriptor——后者追加进现有 note 的 `## Descriptors` 块，不新建文件（按 `topic`/`slug` 查重）。

## 不做的事

- 不直接落库（人审 gate）。
- 不发明词典外描述子。
- 不补划线里没有的数值/条文。
- 不替 study-outline 干整章梳理的活。
- 不读 note 正文做聚类（只读 highlights 缓冲；与 study-review 同护栏精神：避免底层 note bug 被总结成看似正确的结论）。
- 不自动删已处理划线（怕丢，让用户手动清）。
