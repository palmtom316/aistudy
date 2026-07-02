---
domain:              # CPA | 建造师 | 医学 | 生物
subject:             # CPA.会计 | 建造师.市政实务 | 医学.病理学 | ...
chapter:             # 第5章 / 第3节
topic:               # 中文知识点全称（显示名 = 文件名，D-6.1 决策）
slug:                # ASCII slug，仅 [a-z0-9-]，供脚本/URL 引用（文件名用中文）
type:                # concept | formula | case-pattern | diagram
core: false          # true | false —— 大纲核心点
difficulty: 1        # 1-5
mastery: 0           # 0 未学 / 1 看过 / 2 能做题 / 3 能讲清楚
exam_freq: 0         # int，默认 0；无数据时 drill 忽略（SPEC §3.4）
last_reviewed:       # YYYY-MM-DD | null
effective_date:      # 法规/指南生效日；非法规类留 null
superseded_by:       # [[slug]] 或 null；过期时指向新版本 note
anki_id:             # int | null；anki-export 回写的稳定 guid，sync 用来对账
has_image: false     # true | false
related: []          # wikilink 数组，例 ["[[slug-a]]", "[[slug-b|显示名]]"]
source: []           # 回链数组，每项 "materials/<domain>/<subject>/<year>/file.md:p123"
                     # 非教材类写 "LLM-generated; reviewed YYYY-MM-DD"
tags: []             # 受控词汇表，见 SPEC §6.2
---

# {{topic}}

## Descriptors
<!-- 必填：SPEC §3.2。描述子必须来自 templates/descriptors/<domain>.md 词典。
     anki-export.sh 扫描所有 :: 行自动成卡。 -->
描述子:: 概念 → 值

## 定义

## 关键公式 / 电路

## 推导 / 工作原理

## 易错点

## 典型例题

## 自测一题
<!-- 必填：应用验证区块，与 Descriptors 共存。
     Descriptors 管"记没记住"（Anki 数据源），自测题管"会不会用"（回写 mastery）。 -->
