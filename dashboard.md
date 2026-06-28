# 学习仪表盘

> 在 Obsidian 中打开本文件，Dataview 插件会渲染以下查询。
> CLI 下看就是一堆代码块，正常。

## 🔴 核心点却没掌握（最高优先级）

```dataview
TABLE difficulty, exam_freq, last_reviewed
FROM "notes"
WHERE core = true AND mastery <= 1
SORT exam_freq DESC, difficulty DESC
```

## 🟠 高频考点却没掌握（真题命中率）

```dataview
TABLE topic, exam_freq, last_reviewed
FROM "notes"
WHERE exam_freq >= 2 AND mastery <= 1
SORT exam_freq DESC
```

## 🟡 孤立知识点（图谱断点）

```dataview
TABLE topic, related
FROM "notes"
WHERE length(related) = 0
```

## 🟢 该复盘了（间隔 > 7 天）

```dataview
TABLE topic, last_reviewed
FROM "notes"
WHERE last_reviewed != null AND date(today) - date(last_reviewed) > dur(7 days)
SORT last_reviewed ASC
```

## 📊 全局掌握度

```dataview
TABLE length(rows) AS 数量
FROM "notes"
GROUP BY mastery
```

## ✅ 待重做的错题

```datawiew
TABLE topic, last_attempted
FROM "quiz"
WHERE correct = false
SORT last_attempted DESC
```
