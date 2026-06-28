---
name: study-outline
description: 把上传的考试大纲/资料梳理为 Obsidian 知识点原子笔记。强制原子粒度、限字、必含一题、必填 mastery 状态字段。用于"开始复习某门课"或"批量建笔记"场景。
user-invocable: true
argument-hint: "[科目名]"
---

# study-outline

把资料梳理成 `notes/` 下的原子笔记，每个知识点一篇，严格按 `templates/note.md` 的 schema。

## 强制约束（不可绕过）

1. **原子粒度**：一文件一知识点。宁可 30 篇小文件，不要 1 篇大杂烩。
2. **限字**：正文 ≤ 400 字（公式/代码不计）。超了就拆。
3. **必含自测题**：每篇 `## 自测一题` 区块必须非空。
4. **必填状态字段**：`core / difficulty / mastery=0 / exam_freq / related / source`。缺一不可。
5. **回链**：`source` 必须写明来自哪份材料（文件名 + 页码/章节）。
6. **不幻觉**：资料里没有的公式/数值，要么标 `<!-- 存疑 -->`，要么不写。
7. **taxonomy 锁死**：`tags` 只允许 `subject/`、`chapter/`、`type/` 三类前缀。不许随手发明 tag。

## 输入

用户上传或指明的资料，对应 `materials/` 下的 md 文件。开工前先 `ls materials/` 确认。

## 输出

对每个 core 知识点，写一个文件到 `notes/<topic>.md`，文件名用知识点全称（无空格、无特殊符号，必要时下划线）。

frontmatter 模板见 `templates/note.md`，必须填满。

## 流程

1. 读资料 + 大纲，列出 core 知识点清单（直接打印给用户确认）。
2. 用户点头后，逐个生成 `notes/*.md`。
3. 每篇结尾的自测题要能考到该知识点的"易错点"，不要套话题。
4. 全部生成后，打印一份 `core / 非core` 分类表，提示用户下一步 `make quiz TOPIC=...`。

## 不做的事

- 不生成一篇覆盖整章的大笔记。
- 不替用户写自测题答案。
- 不加 webp/png 截图（电路图交给 `study-tikz`）。
