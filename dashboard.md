# 学习仪表盘

> 在 Obsidian 中打开本文件，Dataview 插件会渲染以下查询。
> CLI 下看就是一堆代码块，正常。结构见 SPEC §9。

## §A 总览

```dataview
TABLE length(rows) AS 数量
FROM "notes"
GROUP BY mastery
```

```dataview
TABLE length(rows) AS 未掌握数
FROM "notes"
WHERE mastery <= 1
GROUP BY domain
```

```dataview
TABLE length(rows) AS superseded 数
FROM "notes"
WHERE superseded_by != null
GROUP BY domain
```

```dataview
TABLE length(rows) AS drift 数
FROM "notes"
WHERE contains(file.content, "<!-- drift -->")
GROUP BY domain
```

## §B CPA

```dataview
TABLE topic, difficulty, exam_freq, last_reviewed
FROM #domain/CPA
WHERE core = true AND mastery <= 1
SORT exam_freq DESC, difficulty DESC
```

```dataview
TABLE topic, exam_freq, last_reviewed
FROM #domain/CPA
WHERE exam_freq >= 2 AND mastery <= 1
SORT exam_freq DESC
```

```dataview
TABLE topic, related
FROM #domain/CPA
WHERE length(related) = 0
```

## §C 建造师

```dataview
TABLE topic, difficulty, exam_freq, last_reviewed
FROM #domain/建造师
WHERE core = true AND mastery <= 1
SORT exam_freq DESC, difficulty DESC
```

```dataview
TABLE topic, last_reviewed
FROM #domain/建造师
WHERE last_reviewed != null AND date(today) - date(last_reviewed) > dur(7 days)
SORT last_reviewed ASC
```

## §D 医学

```dataview
TABLE topic, difficulty, exam_freq, last_reviewed
FROM #domain/医学
WHERE core = true AND mastery <= 1
SORT exam_freq DESC, difficulty DESC
```

```dataview
TABLE topic, last_reviewed
FROM #domain/医学
WHERE last_reviewed != null AND date(today) - date(last_reviewed) > dur(7 days)
SORT last_reviewed ASC
```

## §E 生物

```dataview
TABLE topic, difficulty, exam_freq, last_reviewed
FROM #domain/生物
WHERE core = true AND mastery <= 1
SORT exam_freq DESC, difficulty DESC
```

```dataview
TABLE topic, last_reviewed
FROM #domain/生物
WHERE last_reviewed != null AND date(today) - date(last_reviewed) > dur(7 days)
SORT last_reviewed ASC
```

## §F 法规时效预警

```dataview
TABLE topic, effective_date, superseded_by
FROM "notes"
WHERE effective_date != null AND superseded_by = null
AND date(today) - date(effective_date) > dur(365 days)
SORT effective_date ASC
```

## §G Anki drift

```dataview
TABLE topic, anki_id
FROM "notes"
WHERE anki_id = null AND has_image = false
```

```dataview
TABLE topic, anki_id
FROM "notes"
WHERE contains(file.content, "<!-- drift -->")
```

## §H 待重做错题

```dataview
TABLE topic, last_attempted
FROM "quiz"
WHERE correct = false
SORT last_attempted DESC
```
