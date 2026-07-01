---
domain:              # 建造师
subject:             # 建造师.机电实务
chapter:             # 第X章 / 第X节
topic:               # 中文知识点全称（显示名 = 文件名，D-6.1）
slug:                # ASCII slug，仅 [a-z0-9-]，供脚本/URL 引用
type:                # diagram | case-pattern | concept
core: false          # true | false —— 大纲核心点
difficulty: 1        # 1-5
mastery: 0           # 0 未学 / 1 看过 / 2 能做题 / 3 能讲清楚
exam_freq: 0         # int，默认 0；无数据时 drill 忽略（SPEC §3.4）
last_reviewed:       # YYYY-MM-DD | null
effective_date:      # 法规/指南生效日；非法规类留 null
superseded_by:       # [[slug]] 或 null；过期时指向新版本 note
anki_id:             # int | null；anki-export 回写（SPEC §5.1）
has_image: false     # true | false
related: []          # wikilink 数组，例 ["[[中文文件名]]"]
source: []           # 回链数组，每项 "materials/建造师/机电实务/<year>/file.md:p123"
tags: []             # 受控词汇表：domain/建造师 + subject/建造师.机电实务（SPEC §6.2）
---

# {{topic}}

<!-- 触发条件（SPEC §3.3）：涉及多道工序时启用本子模板；descriptor 区块仍保留为 Anki 记忆点。 -->

## 工序流程图
<!-- 用 mermaid 画工序/网络图。节点 = 工序，边 = 先后/依赖。
     禁在 prompt 里写"画图"二字（会触发图片生成）。 -->

```mermaid
graph TD
    A[工序一] --> B[工序二]
    B --> C[工序三]
    B --> D[工序四]
    C --> E[验收]
    D --> E
```

## 规范条文
<!-- 每道工序对应的规范条款号 + 原文摘录。法规类 note 同步填 frontmatter effective_date。 -->

- **GB XXXXX-YYYY §X.X**：条文摘录
- **GB XXXXX-YYYY §X.X**：条文摘录

## 技术参数
<!-- 定量指标：偏差、数值、阈值。每项需能在 source 回链到出处。 -->

| 项目 | 标准 | 备注 |
|---|---|---|
|  |  |  |

## 易错点

## Descriptors
<!-- 必填（SPEC §3.2）。描述子必须来自 templates/descriptors/建造师.md 词典。
     anki-export.sh 扫描所有 :: 行自动成卡（正反两张）。 -->
工序:: 描述子 → 步骤一→步骤二→步骤三
规范条文:: 描述子 → GB XXXXX-YYYY §X.X

## 自测一题
<!-- 必填：应用验证区块，与 Descriptors 共存。
     Descriptors 管"记没记住"（Anki 数据源），自测题管"会不会用"（回写 mastery）。 -->
