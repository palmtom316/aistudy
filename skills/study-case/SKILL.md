---
name: study-case
description: 出一道综合题/案例分析/病历题（多步、多知识点、可拆分步给分），写入 cases/ 并回链知识点。考前案例题主力，建造师案例题重头。强制 rubric source 校验。
user-invocable: true
argument-hint: "[科目/主题]"
---

# study-case

# implements SPEC §3.5, §5.2, §5.3

出综合题/案例，写入 `cases/<exam>-<YYYYMMDD>.md`，严格按 `templates/case.md` schema。

## 强制约束

1. **多步多知识点**：综合题须拆 ≥2 步、牵涉 ≥2 个 note；区别于 `study-quiz`（单点题、一调一题）。
2. **rubric 可量化**：`## 标准答案 / 评分 rubric` 必须按步骤给分（"步骤一 4 分；关键点漏 X 扣 Y"），不接受"答对给满分"式 rubric。
3. **source 强制校验**（SPEC §5.2）：`source` 必填且可追溯（真题年份题号 / `materials/.../<year>/file.md:pNNN` / `LLM-generated; reviewed YYYY-MM-DD`）。**缺 source 则 abort，不许入库**。
4. **回链**：`links: [notes/<domain>/<subject>/<中文文件名>.md]` 必填（D-6.1 中文文件名）。
5. **状态字段**：`correct=null / last_attempted=<today> / score 留空`。
6. **不留空现场**：题目写完后打印给用户，等用户答完再回来评分；不替用户填 `## 我的答案`。
7. **先读 note**：先用 `rg --files notes | rg '/<topic>\\.md$'` 定位真实 note 路径，再 `read` 确认题目落在已建知识点覆盖范围内，不超纲、不引用笔记里没有的资料。

## 评分后动作（用户答完后回来）

1. 把用户答案填进 `## 我的答案`。
2. 按 rubric 分步给分，填 `correct: true/false`、`score: "得/总"`、`last_attempted: today`。
3. **回写 notes**（SPEC §5.2 信任链）：
   - 任一关键步答错 → `links` 指向的知识点 `mastery` **降一级**（封底 0），`last_reviewed: today`，`## 错因 / 复习触发` 写明哪步崩了。
   - 全对 → `correct: true` **仅作 hint，不自动升 mastery**。提示："确认掌握请手动升 mastery，或等 anki-sync"。
4. journal append（SPEC §5.3，**跨平台 mkdir 锁**）：
   ```
   # 清理 >60s 的残留锁（skill 崩溃后兜底）
   if [ -d journal/.lock ] && [ $(( $(date +%s) - $(stat -f %m journal/.lock 2>/dev/null || stat -c %Y journal/.lock 2>/dev/null || echo 0) )) -gt 60 ]; then rmdir journal/.lock 2>/dev/null || true; fi
   mkdir journal/.lock 2>/dev/null || sleep 1 && mkdir journal/.lock 2>/dev/null
   # 得到锁后 append；失败则重试 ≤3 次
   echo "- $(date +%H:%M) | <slug> | <correct/null> | <drift?>" >> journal/$(date +%F).md
   rmdir journal/.lock
   ```
   行格式见 §3.6。首行 `# <date> 复习日志` 已存在则不动，不存在则先建（用 `templates/journal.md`）。
5. 触发提示：若 `correct=false`，提示用户 `make drill` 置顶复练。

## 不做的事

- 不出单点题（那是 `study-quiz`）。
- 不出无 rubric 的开放题。
- 不替用户答题、不替用户升 mastery（correct:true 只 hint）。
- 不接受无 source 的 rubric。
