---
name: study-drill
description: 读 dashboard.md 的诊断清单（core 未掌握 / 高频未掌握 / 该复盘），反向生成今明两天的复习路线图或模拟卷。考前冲刺与日常复盘入口。
user-invocable: true
---

# study-drill

基于 vault 当前状态字段，生成可执行的复习计划。

## 数据来源（必读）

1. `read dashboard.md` 拿到 Dataview 查询意图（CLI 下查询不渲染，但查询条件可读）。
2. `grep -l "core: true" notes/*.md | xargs grep -L "mastery: [23]"` → core 未掌握清单。
3. `grep -l "exam_freq: [2-9]" notes/*.md` → 高频考点清单。
4. `grep -l "correct: false" quiz/*.md` → 待重做错题清单。

不要让 LLM 凭印象判断谁没掌握——**所有优先级来自 grep 结果**，不是模型记忆。

## 输出（直接打印，不写文件）

```
## 今日（YYYY-MM-DD）
- 高优先级（core+mastery≤1，按 exam_freq 排序）：
  - <topic>  → make quiz TOPIC="..."  [预计 15 min]
  - ...
- 错题重做：
  - <quiz>  → 翻 quiz/<file>.md
- 收尾：把今天 date 填进刷新过的 notes 的 last_reviewed

## 明天
- 剩余 core 未掌握
- 间隔 >7 天的复盘项
```

## 模拟卷模式（用户显式说"出模拟卷"时）

1. 取 `core=true` 全集。
2. 每个知识点抽 1 题（优先复用 `quiz/` 里已有的，没有就现场出，遵循 study-quiz 的 rubric 约束）。
3. 输出一份 `mock-exam-<date>.md` 到 vault 根，附评分 rubric 与建议时长。
4. **不替用户答题**，只出卷。

## 强制约束

- 单日计划 ≤ 6 项，超了砍 exam_freq 低的。
- 不许凭空造知识点名——必须来自 `ls notes/`。
- 不许给"复习第一章"这种粗粒度任务——必须落到具体 topic。
