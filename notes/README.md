# notes/

知识点原子笔记。一个文件一个知识点，文件名 = 知识点全称。

frontmatter 字段是整个系统的核心——dashboard.md 的 Dataview 查询全靠它们。

## 必填字段速查

| 字段 | 何时更新 |
|---|---|
| `core` | 建笔记时（study-outline） |
| `difficulty` | 建笔记时自评 |
| `mastery` | 答错时由 study-quiz / study-case 自动降一级；升级只走 anki-sync 或人审 |
| `exam_freq` | 整理真题时手填 |
| `last_reviewed` | study-quiz 答对时更新为 today |
| `related` | 建笔记时关联同章节知识点 |
