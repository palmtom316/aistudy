---
name: study-quiz
description: 给定一个知识点，出一道带评分 rubric 的题，写入 quiz/ 并回链知识点。用于主动回忆循环、巩固掌握度。
user-invocable: true
argument-hint: "[知识点名]"
---

# study-quiz

对着 `notes/<topic>.md` 出一道题，写入 `quiz/<topic>-<序号>.md`。

## 强制约束

1. **基于笔记内容出题**：先 `read notes/<topic>.md`，题目必须落在笔记覆盖范围内，不超纲、不引用笔记里没有的资料。
2. **带上 rubric**：`## 标准答案 / 评分 rubric` 区块必须可量化（步骤分、关键点扣分）。
3. **不留空现场**：题目区块写完后，把题目本身打印给用户，等用户答完再回来评分；不要替用户填 `## 我的答案`。
4. **回链**：`links: [[notes/<topic>]]` 必填。
5. **状态字段**：`status=new / correct=null / last_attempted=<today>`。
6. **难度自适应**：若该知识点 `exam_freq >= 2`，题目难度向真题靠拢；若 `mastery >= 2`，出综合/变形题而非基础题。

## 评分后动作（用户答完后回来）

1. 把用户答案填进 `## 我的答案`。
2. 按 rubric 给分，填 `correct: true/false`、`last_attempted: today`、`status: once/mastered`。
3. **回写 notes**：
   - 答对 → `notes/<topic>.md` 的 `mastery` 升一级（封顶 3），`last_reviewed: today`。
   - 答错 → `mastery` 降一级（封底 0），`## 错因 / 复习触发` 写明哪一步崩了。
4. 触发提示：若该题 `correct=false`，提示用户 `make drill`。

## 不做的事

- 不出"请简述……"这类无 rubric 的开放题。
- 不一次性出多题（一调一题，遵循主动回忆的单点反馈原则）。
