---
name: study-quiz
description: 给定一个知识点，出一道带评分 rubric 的题，写入 quiz/ 并回链知识点。用于主动回忆循环、巩固掌握度。
user-invocable: true
argument-hint: "[知识点名]"
---

# study-quiz

# implements SPEC §5.2, §5.3

先定位 `notes/**/<topic>.md` 对应的真实 note，再出一道题，写入 `quiz/<topic>-<序号>.md`。

## 强制约束

1. **基于笔记内容出题**：先用 `rg --files notes | rg '/<topic>\\.md$'` 定位 note，再 `read` 该文件；题目必须落在笔记覆盖范围内，不超纲、不引用笔记里没有的资料。
2. **带上 rubric**：`## 标准答案 / 评分 rubric` 区块必须可量化（步骤分、关键点扣分）。
3. **source 强制校验**（SPEC §5.2）：`source` 必填且可追溯（真题年份题号 / 教材页码 / `LLM-generated; reviewed YYYY-MM-DD`）。**缺 source 则 abort，不许入库**。
4. **不留空现场**：题目区块写完后，把题目本身打印给用户，等用户答完再回来评分；不要替用户填 `## 我的答案`。
5. **回链**：`links: [notes/<domain>/<subject>/<中文文件名>.md]` 必填（D-6.1：文件名用中文）。
6. **状态字段**：`status=new / correct=null / last_attempted=<today>`。
7. **难度自适应**：若该知识点 `exam_freq >= 2`，题目难度向真题靠拢；若 `mastery >= 2`，出综合/变形题而非基础题。

## 评分后动作（用户答完后回来）

1. 把用户答案填进 `## 我的答案`。
2. 按 rubric 给分，填 `correct: true/false`、`last_attempted: today`、`status: once/mastered`。
3. **回写 notes**（SPEC §5.2 信任链）：
   - 答错 → `links` 指向的 note `mastery` **降一级**（封底 0），`last_reviewed: today`，`## 错因 / 复习触发` 写明哪一步崩了。
   - 答对 → `correct: true` **仅作 hint，不自动升 mastery**。只更新 `last_reviewed: today`、`status: once`。升 mastery 只走 Anki sync 或人审（提示用户："确认掌握请手动升 mastery，或等 anki-sync"）。
4. 触发提示：若该题 `correct=false`，提示用户 `make drill`。
5. journal append（SPEC §5.3，**跨平台 mkdir 锁**，与 study-case 一致）：
   ```bash
   # 清理 >60s 的残留锁（skill 崩溃后兜底）
   if [ -d journal/.lock ] && [ $(( $(date +%s) - $(stat -f %m journal/.lock 2>/dev/null || stat -c %Y journal/.lock 2>/dev/null || echo 0) )) -gt 60 ]; then
     rmdir journal/.lock 2>/dev/null || true
   fi
   acquired=0
   for i in 1 2 3; do
     if mkdir journal/.lock 2>/dev/null; then
       acquired=1
       trap 'rmdir journal/.lock 2>/dev/null || true' EXIT
       break
     fi
     sleep 1
   done
   [ "$acquired" = 1 ] || { echo "failed to acquire journal lock" >&2; exit 1; }
   JFILE="journal/$(date +%F).md"
   if [ ! -f "$JFILE" ]; then
     printf '# %s 复习日志\n\n' "$(date +%F)" > "$JFILE"
   fi
   echo "- $(date +%H:%M) | <slug> | <correct/null> | <drift?>" >> "$JFILE"
   rmdir journal/.lock
   trap - EXIT
   ```
   行格式见 §3.6。首行 `# <date> 复习日志` 已存在则不动，不存在则先建。

## 不做的事

- 不出"请简述……"这类无 rubric 的开放题。
- 不一次性出多题（一调一题，遵循主动回忆的单点反馈原则）。
