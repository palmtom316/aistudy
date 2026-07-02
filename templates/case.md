---
exam:               # 一建 | 二建 | CPA综合 | 执业医师 | ...（出题来源/级别）
date:               # YYYYMMDD 做题日
subject:            # 建造师.机电实务 | ...
links: []           # [notes/<domain>/<subject>/<中文文件名>.md] 回链知识点，必填（D-6.1 中文文件名）
difficulty: 1       # 1-5
last_attempted:     # YYYY-MM-DD | null
correct:            # true | false | null
score:              # "得/总"，如 "8/20"；未评留空
source: []          # 回链数组，必填（SPEC §5.2）。缺 source 则 study-case abort
tags: []            # 受控词汇表（SPEC §6.2）
---

## 题目
<!-- 综合题/案例分析/病历题。多步、多知识点、可拆分步给分。
     与 quiz/ 的区别：quiz 是单点题（descriptor 级、一调一题）。 -->

## 我的答案

## 标准答案 / 评分 rubric
<!-- 必须可量化：步骤分、关键点扣分。rubric 必须含 source 回链（SPEC §5.2）。
     格式："真题 2023 #5" / "materials/建造师/机电实务/2024/教材.md:p123"
     或 "LLM-generated; reviewed YYYY-MM-DD"。缺 source 则 abort，不许入库。 -->

## 错因 / 复习触发
<!-- 答错时 this->links 的知识点 mastery 应降一级（SPEC §5.2：correct:false 直接降）。
     答对时不自动升 mastery（升 mastery 只走 Anki sync 或人审）。
     study-case 评分后向 journal/<YYYY-MM-DD>.md append 一行（§5.3，mkdir 锁）：
     - HH:MM | <slug> | <correct/null> | <drift?> -->
