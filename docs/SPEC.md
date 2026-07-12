# aistudy SPEC

> 本文件是系统的最高约束，亦是唯一规格文档。任何 skill / script / 模板的实现必须与本文件一致；
> 不一致时要么改实现，要么改本文件。README 是导览，SPEC 是法律，PLAN 是施工图。
> 2026-07-01 合并：原 `.trellis/spec/SPEC.md` + audit 报告 + T-001 计划 + journal 决策 + 三处补充（case schema / anki_id 策略 / CSV 来源）。

---

## 1. 定位与范围

- **单用户**长期学习系统。所有状态字段（mastery 等）为单人值，不引入 user 维度。
- **目标领域**：CPA（六科）、注册建造师（含市政/机电实务）、医学生考试、生物学生考试。
- **时间尺度**：长期（月-年级），而非期末突击。SR 节奏按月，drill 不再硬限每日项数。
- **生命周期**：先自用迭代，后开源。不做多租户、不做云同步服务（用 git/obsidian sync）。
- **RemNote 存量**：不迁移。Concept-Descriptor 理念借鉴，格式自由。

## 2. 架构（三层不变）

```
Obsidian (前端：读、答、图谱、Dataview)  ← 用户坐这里
        ↕ 读写 markdown
vault (单一数据源：notes/quiz/cases/journal/...)
        ↕ 操作文件
CLI + scripts (确定性运维)  +  skills (LLM 侧行为)
```

判据：**确定性操作走脚本，判断与表达走 skill，阅读与答题坐 Obsidian。**

## 3. 数据模型

### 3.1 通用 note frontmatter（所有 note 必填，字段冻结）

```yaml
---
domain:              # CPA | 建造师 | 医学 | 生物
subject:             # CPA.会计 | 建造师.市政实务 | 医学.病理学 | ...
chapter:             # 第5章 / 第3节
topic:               # 中文知识点全称（显示名）
slug:                # ASCII 文件名 slug（见 §6.1）
type:                # concept | formula | case-pattern | diagram
core:                # true | false  —— 大纲核心点
difficulty:          # 1-5
mastery:             # 0 未学 / 1 看过 / 2 能做题 / 3 能讲清楚
exam_freq:           # int，默认 0；无数据时 drill 忽略（见 §3.4）
last_reviewed:       # YYYY-MM-DD | null
effective_date:      # 法规/指南生效日；非法规类留 null
superseded_by:       # [[slug]] 或 null；过期时指向新版本 note
anki_id:             # int | null；anki-export 回写的稳定 guid，sync 用来对账（见 §5.1）
has_image:           # true | false
related: []          # wikilink 数组，例 ["[[slug-a]]", "[[slug-b|显示名]]"]
source: []           # 回链数组，每项 "materials/<domain>/<subject>/<year>/file.md:p123"
                     # 非教材类写 "LLM-generated; reviewed YYYY-MM-DD"
tags: []             # 受控词汇表，见 §6.2
---
```

**字段计 18 个**：domain / subject / chapter / topic / slug / type / core / difficulty / mastery / exam_freq / last_reviewed / effective_date / superseded_by / anki_id / has_image / related / source / tags。

**与 `slug` 字段的关系**（D-6.1 决策后）：文件名用中文（`topic` 值），`slug` 字段保留 ASCII 供脚本引用。两者并存：文件名 = 中文知识点名，slug = `[a-z0-9-]` ASCII 标识。

### 3.2 Concept-Descriptor 区块（RemNote 借鉴）

每篇 note 必含 `## Descriptors` 区块，行格式：

```
描述子:: 概念 → 值
```

描述子必须来自 `templates/descriptors/<domain>.md` 词典，**skill 拒绝词典外的描述子**。`anki-export.sh` 扫描所有 `::` 行自动成卡。

**与 `## 自测一题` 的关系**：两者共存不冲突。`## Descriptors` 是 Anki 数据源（提取记忆点，自动成卡）；`## 自测一题` 是应用验证（手动答，回写 mastery）。前者管"记没记住"，后者管"会不会用"。

### 3.3 per-domain 复杂结构子模板

descriptor 装不下的结构走专门模板（在 `templates/structural/`）：

| 领域 | 子模板 | 触发条件 |
|---|---|---|
| CPA | `journal-entry.md`（多步分录序列） | 涉及 3 步以上分录 |
| 医学 | `differential-table.md`（鉴别诊断对比表） | ≥3 个待鉴别项 |
| 生物 | `pathway-graph.md`（信号/代谢通路） | 节点 ≥5 |
| 建造师 | `procedure-flow.md`（工序+规范条文） | 涉及多道工序 |

`study-outline` 在建 note 时判断是否触发子模板；触发则使用子模板，descriptor 区块仍保留作为记忆点 extracts。

### 3.4 exam_freq 处理

- 默认 0，**视为装饰字段**。
- 整理真题阶段手工填；LLM 不许估计。
- `study-drill` 检测到全局 `exam_freq>0` 的 note < 20% 时，**忽略 exam_freq 排序**，只用 `core + mastery + last_reviewed`。
- 避免无数据时优先级空转。

### 3.5 case frontmatter schema（综合题/案例/病历）—— 2026-07-01 补

`study-case` 写入 `cases/<exam>-<YYYYMMDD>.md`，必须按 `templates/case.md` schema：

```yaml
---
exam:               # 一建 | 二建 | CPA综合 | 执业医师 | ...（出题来源/级别）
date:               # YYYYMMDD 做题日
subject:            # 建造师.机电实务 | ...
links: []           # [notes/中文文件名.md] 回链知识点，必填（D-6.1 中文文件名）
difficulty: 1       # 1-5
last_attempted:     # YYYY-MM-DD | null
correct:            # true | false | null
score:              # "得/总"，如 "8/20"；未评留空
source: []          # 回链数组，必填（§5.2）。缺 source 则 study-case abort
tags: []            # 受控词汇表（§6.2）
---
```

正文区块固定为：`## 题目` / `## 我的答案` / `## 标准答案 / 评分 rubric` / `## 错因 / 复习触发`。
rubric 必须可量化（步骤分、关键点扣分），且必含 source 回链（§5.2 信任链）。
与 `quiz/` 的区别：quiz 是单点题（descriptor 级、一调一题）；case 是综合题（多步、多知识点、可拆分步给分）。

### 3.6 journal 与 review 文档 schema —— 2026-07-01 补

**journal 行格式**（§5.3 已定，重申）：
```
- HH:MM | <slug> | <correct/null> | <drift?>
```
`journal/<YYYY-MM-DD>.md` 首行 `# <YYYY-MM-DD> 复习日志`，其后为上述 bullet 行。skill append 时只 append bullet，不动首行。

**review 文档** `journal/<YYYY-MM-DD>-review.md`：
```
# <YYYY-MM-DD> 周/月复盘
## 进度概览
## 薄弱点（按 mastery 分布 + journal correct=false 频次）
## 下周期建议
## 本轮出题清单（调用 study-quiz/case 产生的题 slug 列表）
```
study-review 生成，护栏见 §5.4（只读结构化字段，不读 note 正文）。

### 3.7 highlights 划线缓冲 schema —— 2026-07-01 补

`highlights/<书名>.md` 是 PDF 教材划线的缓冲区，**不是终点**。PDF++ 插件在 PDF 里选字后"copy as markdown"粘贴到本文件，每条划线 = 一段 blockquote + 一行 source 回链（含 pdf 路径 + 页码）：

```
> 被选中的原文
>
> source: materials/建造师/机电实务/2024/教材.pdf:p123
```

也接受 `[[materials/.../教材.pdf#page=123]]` 形态，`study-extract` skill 解析时兼容两种页码写法。

**划线 ≠ 卡**。划线只是"这段重要"，要成卡必须先经 `study-extract` 结构化成 `描述子:: 概念 → 值`（§3.2），再由 `anki-export.sh` 扫描成卡。本缓冲区的价值是保留原始上下文 + 页码回链，让 LLM 转换时有据可依（§5.2 信任链不断）。

schema 见 `templates/highlight.md`。一本书一个文件，文件名 = 书名（中文）。

## 4. 目录结构

```
aistudy/
├── materials/<domain>/<subject>/<year>/        # 原始资料按年度版本化
├── notes/<domain>/<subject>/*.md               # 知识点（MVP 按 subject 分层）
├── quiz/*.md                                    # 单点题（descriptor 级）
├── cases/<exam>-<YYYYMMDD>.md                  # 综合题/案例分析/病历题
├── journal/<YYYY-MM-DD>.md                      # 当日复习日志，skill 自动 append
├── highlights/<书名>.md                         # PDF 划线缓冲（§3.7，study-extract 输入）
├── attachments/<domain>/<subject>/             # 图片附件
├── templates/                                   # note/quiz/case/journal/descriptors/structural/
├── skills/                                      # LLM 侧行为
├── scripts/                                     # 确定性运维
├── dashboard.md                                 # Dataview 诊断
└── docs/{SPEC.md,PLAN.md,...}                   # 本法律 + 施工图 + 审查/评审
```

> 注：`prompts/` 为遗留目录，不进闭环；已从 README 架构图删除，目录本身待清理。

**notes/ 物理摆放规则**：按知识原子本身分类（疾病放 `notes/医学/疾病/`、药物放 `notes/医学/药物/`），系统/课程归属全部交给 tag，**不在目录上做二维切片**。

## 5. 闭环机制

### 5.1 Anki ↔ vault mastery 同步（单向：Anki → vault）

**anki_id 生成策略**（2026-07-01 锁定；2026-07-12 补多卡语义）：每张 Anki 卡有独立稳定 guid；frontmatter `anki_id` 仅作「首卡/主卡」便利字段，**不能**单独表达多 descriptor 卡集合。
```
card_guid = int(sha1(f"{slug}::{descriptor_key}").hexdigest()[:8], 16) & 0x7fffffff
frontmatter.anki_id = 该 note 第一个成功导出的 descriptor 卡 guid
```
- 输入为 frontmatter `slug` + 该 note 触发成卡的描述子 key（一 note 多 descriptor 时，**每行各生一张卡**，每张卡 guid = `slug::该 key`）。
- `anki-export.sh` 生成卡时：每张卡用各自 guid；frontmatter `anki_id` **只回写首张** descriptor 卡 guid（便于「是否已导出」快速扫描）。
- 同一 note 内 **descriptor key 必须唯一**；重复 key 导致 guid 碰撞，export/sync 必须 fail-fast。
- quiz 题卡：`card_guid = int(sha1(f"quiz::{slug}::{n}").hexdigest()[:8], 16) & 0x7fffffff`（n 为该 quiz 文件内第 n 题；单题文件 n=1）。quiz **不写** frontmatter `anki_id`。

**CSV 来源与格式**（2026-07-02 修订；2026-07-12 对齐实现）：sync 不直连 Anki SQLite，改由用户跑一段确定性 SQL 导出 CSV（避免库锁、跨版本 schema 风险）。SQL 写死在 `scripts/anki-sync-export.sql`，产出列：`anki_guid,review_date,interval,ease`：

```sql
SELECT n.guid AS anki_guid,
       strftime('%Y-%m-%d', r.id/1000, 'unixepoch') AS review_date,
       MAX(r.ivl, 0) AS interval,
       r.ease / 1000.0 AS ease
FROM revlog r
JOIN cards c ON r.cid = c.id
JOIN notes n ON c.nid = n.id
ORDER BY n.guid, r.id;
```
- `r.id` 是 revlog 主键，每行唯一，**无需 GROUP BY**（实现文件 `anki-sync-export.sql` 与此一致；旧示例中的 `GROUP BY n.guid, r.id` 已废弃）。
- `anki_guid` = Anki `notes.guid`，即 export 写入的稳定 card guid；**不是** Anki `notes.id`，也**不一定**等于 frontmatter `anki_id`（多卡 note 时只有首卡 guid 写在 frontmatter）。
- `ease` 为小数乘子（Anki permille / 1000），与下方阈值 1.5 口径一致。
- 导出命令：`sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv`（Anki 需关闭以释放库锁）。

**升降规则**（`scripts/anki-sync.sh` 读 CSV，按 `anki_guid` 映射到 vault note path，再 **按 path 聚合**）：
- 映射：对 vault 每个 note 的每个 descriptor 重算 `slug::key` guid，建立 `guid → path`；**不**依赖 frontmatter `anki_id` 做多卡匹配。
- 同一 path 下所有匹配卡先聚合，再写一次 frontmatter：
  - `note.drift = any(card.drift)`；card.drift = 该卡最新两条连续 `ease < 1.5`。
  - `note.mastery`：降级优先（任一卡要求降级或 note.drift → 单轮最多 -1）；否则升级取最强 interval 目标但单轮最多 +1。
  - `last_reviewed` = 匹配卡中最新 `review_date`。
- 单卡目标（聚合前）：
  - `interval ≥ 21` 且 `mastery < 3` → 目标 3。
  - `interval ≥ 7` 且 `mastery < 2` → 目标 2。
  - drift → 目标 `max(0, mastery-1)`。
- 改写仅动 frontmatter 的 `mastery` / `last_reviewed` 两行 + 末尾 drift 注释，其余字节不动（RegExp 行级替换，禁用全量 YAML 序列化）。

vault → Anki 方向靠下次 `anki-export` 重新生成 deck，按 **各卡独立 guid** 更新已有卡，避免重复。
**不追求实时**，每周或考前手动跑一次 sync 即可。

### 5.2 rubric 信任链（人审）

- `quiz/` 与 `cases/` 中每道题的 `## 标准答案 / 评分 rubric` 必须含 `source:` 回链（真题年份题号、教材页码、或 `LLM-generated; reviewed YYYY-MM-DD`）。
- **未回链 source 的题不许入库**——`study-quiz` / `study-case` skill 强制校验，缺 source 则 abort 并提示用户。
- LLM 评分仅作参考。`correct: false` 信号当真（直接降 mastery），`correct: true` 仅作 hint（不自动升 mastery；升 mastery 只走 Anki sync 或人审）。

### 5.3 journal 自动写

- `study-quiz` / `study-case` 评分完成后，向 `journal/<YYYY-MM-DD>.md` append 一行：
  `- HH:MM | <slug> | <correct/null> | <drift?>`
- 写前文件锁，避免多 skill 并发冲突。**平台差异**：Linux 用 `flock`，macOS 无 `flock`，改用 `mkdir`-based 锁（`mkdir journal/.lock` 原子成功者得锁）或 `shlock`。脚本/skill 实现时按平台选择。
- vault 同步冲突时以**本地较新**为准，journal 不做合并（损失一天日志可接受）。
- `study-drill` 读最近 7 天 journal，若发现某 note 反复答错，强制置顶到今日清单。

### 5.4 周/月复盘机制（study-review）

- 触发：周/月末手动或 cron。
- 输入：`journal/` 近 N 天记录 + `quiz/`、`cases/` 的 `correct` 字段分布 + `mastery` 分布。
- 输出：`journal/<YYYY-MM-DD>-review.md`（schema 见 §3.6）。
- 出题：调用 `study-quiz` / `study-case` 对薄弱点出题，source 强制校验（§5.2）仍生效，错题自然入 journal。
- 复练：错题经 §5.3 journal → `study-drill` 置顶复练，无需新机制。
- **护栏**：study-review 只读结构化字段（mastery / correct / journal 行 / last_reviewed），**不读 note 正文自由文本**做总结依据——底层 note 有 bug 时表现为数据缺失而非被总结成看似正确的结论。
- 模型：周/月总结是 LLM 容错高的任务；出题环节走 study-quiz/case 的既有约束。

## 6. 数据卫生条款（硬约束）

### 6.1 文件名

- **中文文件名**（D-6.1 决策）：note 文件名用中文知识点全称，路径 `notes/<domain>/<subject>/<中文文件名>.md`。
- ASCII slug 仍保留在 frontmatter `slug:` 字段，供脚本/URL/跨平台引用；Obsidian wikilink 用 `[[中文文件名]]` 直链，显示名即文件名，无需 `|` 别名。
- **代价**：shell 操作需 quote、git 重命名检测对中文不稳定、跨平台有边界风险。
- **收益**：可读性高、wikilink 简洁、与 `topic:` 字段一致。
- **硬约束**：所有 scripts/skill 操作中文路径时必须加 quote（`rg "..." "notes/医学/疾病/"`），`.gitattributes` 配 `* text=auto` 减少换行符问题。

### 6.2 tag taxonomy（受控词汇表）

只允许四类前缀，词典外 tag 一律拒收：

| 前缀 | 例 | 来源 |
|---|---|---|
| `domain/` | `domain/CPA` | 固定 4 值 |
| `subject/` | `subject/CPA.税法` | per-domain 受控 |
| `system/` | `system/心血管`（医学专用） | 医学受控词汇 |
| `course/` | `course/内科学`（医学专用） | 医学受控词汇 |

CPA/建造师/生物用 `subject/` 即可；医学额外用 `system/` + `course/` 做二维 indexing。

**MVP 受控取值表**（2026-07-01 补，`taxonomy-check.sh` 据此校验）：

| 前缀 | MVP 允许值 | defer |
|---|---|---|
| `domain/` | `domain/建造师` | CPA / 医学 / 生物 |
| `subject/` | `subject/建造师.机电实务` | 其余 subject |
| `system/` | （MVP 域不用） | 医学上线后定义 |
| `course/` | （MVP 域不用） | 医学上线后定义 |

`taxonomy-check.sh` MVP 阶段只认上表两行；其余 tag 一律拒收并报文件名+非法 tag。

### 6.3 grep / ripgrep

- **所有脚本与 skill 用 `rg`（ripgrep）**，不依赖 BSD/gnu grep 差异。
- `exam_freq` 高频过滤正则：`rg "exam_freq: ([2-9]|[1-9][0-9]+)"`（修原 bug，匹配 12/22 等）。
- wikilink 提取：`rg -o '\[\[[^\]]+\]\]'`。

### 6.4 材料版本化

- `materials/<domain>/<subject>/<year>/`，按年度子目录（D-6.4 决策）。
- PDF 原件与 OCR 后的 md 并存于同一年度目录：`materials/建造师/机电实务/2024/教材.pdf` + `materials/建造师/机电实务/2024/教材.md`。note `source` 可回链任一种：`materials/.../教材.md:p123`（OCR md）或 `materials/.../教材.pdf:p123`（PDF 原件，划线驱动走此路径，§3.7）。
- note `source` 必须含年度：`materials/CPA/税法/2024/教材.md:p123`。
- 法规类 note：
  - `effective_date: 2024-01-01`
  - 下一版生效时新建 note，旧 note 的 `superseded_by: [[新slug]]`，dashboard 把 superseded 项标灰。
- 备选"同名文件覆盖 + git 历史"已否决，因其牺牲"同时比对两年教材"能力。

## 7. skills 清单

| skill | 职责 | 状态 |
|---|---|---|
| `study-outline` | 大纲梳理→原子笔记；按 domain 加载 descriptor 词典；触发子模板 | 改造 ✅ |
| `study-quiz` | 单点题（descriptor 级）；强制 source 校验；回写 mastery（仅降不升） | 改造 ✅ |
| `study-case` | 综合题/案例/病历；写入 cases/；强制 rubric source；schema 见 §3.5 | 新增 |
| `study-drill` | grep+rg 驱动的复习计划；读 journal 近 7 天；忽略无数据 exam_freq | 改造 ✅ |
| `study-tikz` | 仅保留供电气/通用继承；CPA/建造师/医学/生物不调用 | 保留 ✅ |
| `study-diagram-cpa` | CPA 用，几乎不用，占位 | defer |
| `study-diagram-建造师` | mermaid 工序/网络图 | defer（procedure-flow 模板手写 mermaid 顶着） |
| `study-diagram-医学` | Excalidraw 引导 + 附件标注，不生成图 | defer |
| `study-diagram-生物` | mermaid 通路 / tikz 代谢图 | defer |
| `study-sync` | 提示跑 anki-sync，对账 drift 项 | 新增（刻意做薄：只呈现/提示，跑脚本属确定性操作走 §2） |
| `study-review` | 周/月复盘：读 journal N 天 + correct 分布 → 总结文档 → 调 study-quiz/case 对薄弱点出题 | 新增 |
| `study-extract` | 读 highlights/<book>.md 划线缓冲 → 聚类 → 生成 note 草稿（带 Descriptors + source 回链）；人审 gate 后落库 | 新增（§3.7，划线驱动，不替代 study-outline） |

**每个 skill 文件头部必须声明依赖的 SPEC 条款编号**（如 `# implements SPEC §3.2, §5.2`），便于变更时定位。

**字数约束归属**：正文 ≤ 400 字（公式/代码不计）是 `study-outline` 的 skill 级约束，非 SPEC 约束。其他 skill 可自由调整。若需全局统一，再提升为本 SPEC 条款。

## 8. scripts 清单

| 脚本 | 职责 | 依赖 | 状态 |
|---|---|---|---|
| `prep.sh` | OCR → materials 归档 | mineru/paddle | ✅ |
| `anki-export.sh` | 扫 descriptor 行 + quiz/ → apkg；回写首卡 anki_id；拒无 source quiz / 重复 key | genanki, python | 增强 |
| `anki-sync-export.sql` | 从 collection.anki2 导出复习 CSV（§5.1 SQL） | sqlite3 | 新增 |
| `anki-sync.sh` | 读 CSV → 按 path 聚合 mastery/drift 写回 | python | 新增 |
| `compress-images.sh` | attachments 入库前压缩到 1600px/300KB | imagemagick | 新增 |
| `taxonomy-check.sh` | 扫 notes/quiz/cases tag，拒绝非受控词汇（§6.2 MVP 表） | python | 新增 |
| `validate-content.sh` | source / 必填 frontmatter / descriptor 白名单与重复 key | python | 新增 |

## 9. dashboard 视图

`dashboard.md` 分节，per-domain 查询 + 总览：

- §A 总览：各 domain 未掌握数、superseded 数、drift 数
- §B CPA / §C 建造师 / §D 医学 / §E 生物：各自 core 未掌握、高频未掌握、该复盘、孤立点、错题
- §F 法规时效预警：`effective_date` 早于 N 天且无 `superseded_by` 的法规类 note
- §G Anki drift：`anki_id` 缺失或 sync 标 drift 的项
- §H 待重做错题：`FROM "quiz" WHERE correct = false`，按 `last_attempted` 倒序；与 §5.3/§5.4 错题复练链呼应

所有 Dataview 查询用 `FROM #domain/xxx` 起手，不依赖目录。
MVP 只验 §A + §C + §F + §G + §H；§B/§D/§E 留结构空查询。

## 10. 不做的事

- 不建 web 前端（Obsidian 即前端）。
- 不自研 SR 调度（信 Anki SM-2/FSRS）。
- 不做 RemNote 迁移。
- 不做多人/云同步服务。
- 不让 LLM 估 exam_freq / 估法规生效日 / 评分升 mastery。
- 不让 LLM 随手加 tag。
- 不接受 quiz/cases 中无 source 的 rubric。
- 不上 git-lfs（暂不）。
- 不用全量 YAML 序列化改写 frontmatter（只行级 RegExp 替换，保 git diff 干净）。

## 11. 决策记录与开放项

### 已决策（锁定）

- **D3 文件名（2026-06-30）**：中文文件名 + frontmatter `slug` 字段（§6.1）。否决纯 ASCII slug 默认立场。
- **D4 材料版本（2026-06-30）**：保持 `materials/<domain>/<subject>/<year>/` 年度子目录（§6.4）。否决同名覆盖。
- **MVP 范围（2026-06-30）**：单域建造师.机电实务先跑通闭环，再扩域。§1 范围（4 域愿景）不动。
- **模型（2026-06-30）**：单模型 glm-5.2，不做对比测试。
- **study-review 进一期（2026-06-30）**：护栏为只读结构化字段，不读 note 正文（§5.4）。
- **anki_id 策略（2026-07-01）**：确定性 sha1 hash（§5.1）。否决 genanki 自分配后回写（二次回写复杂、跨设备不稳定）。
- **anki-sync CSV 来源（2026-07-01）**：sqlite3 跑 SQL 导出 CSV，不直连 Anki 库（§5.1）。否决 addon 依赖（版本不稳）。
- **文档合并（2026-07-01）**：规格只留 `SPEC.md` + `PLAN.md` 两份；audit/journal/T-001 折叠并入，不再单列。

### 开放项

- **E2 exam_freq**：默认装饰字段 + 无数据时 drill 忽略（§3.4）。若认真搞，需补"真题整理 SOP"任务，暂不进 MVP。
