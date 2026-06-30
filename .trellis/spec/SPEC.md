# aistudy SPEC

> 本文件是系统的最高约束。任何 skill / script / 模板的实现必须与本文件一致；
> 不一致时要么改实现，要么改本文件。README 是导览，SPEC 是法律。

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

### 3.1 通用 frontmatter（所有 note 必填，字段冻结）

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
anki_id:             # int | null；Anki 卡 ID，sync 用来对账
has_image:           # true | false
related: []          # wikilink 数组，例 ["[[slug-a]]", "[[slug-b|显示名]]"]
source: []           # 回链数组，每项 "materials/<domain>/<subject>/<year>/file.md:p123"
                     # 非教材类写 "LLM-generated; reviewed YYYY-MM-DD"
tags: []             # 受控词汇表，见 §6.2
---
```

**字段计 18 个**：domain / subject / chapter / topic / slug / type / core / difficulty / mastery / exam_freq / last_reviewed / effective_date / superseded_by / anki_id / has_image / related / source / tags。

**与 `slug` 字段的关系**（2026-06-30 D-6.1 决策后）：文件名用中文（`topic` 值），`slug` 字段保留 ASCII 供脚本引用。两者并存：文件名 = 中文知识点名，slug = `[a-z0-9-]` ASCII 标识。

### 3.2 Concept-Descriptor 区块（RemNote 借鉴）

每篇 note 必含 `## Descriptors` 区块，行格式：

```
概念:: 描述子 → 值
```

描述子必须来自 `templates/descriptors/<domain>.md` 词典，**skill 拒绝词典外的描述子**。`anki-export.sh` 扫描所有 `::` 行自动成卡（正反两张）。

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

## 4. 目录结构

```
aistudy/
├── materials/<domain>/<subject>/<year>/        # 原始资料按年度版本化
├── notes/<domain>/<taxonomy原子>/*.md          # 知识点（疾病/药物/概念/...）
├── quiz/*.md                                    # 单点题（descriptor 级）
├── cases/<exam>-<YYYYMMDD>.md                  # 综合题/案例分析/病历题
├── journal/<YYYY-MM-DD>.md                      # 当日复习日志，skill 自动 append
├── attachments/<domain>/<subject>/             # 图片附件
├── templates/                                   # note/quiz/case/journal/descriptors/structural/
├── skills/                                      # LLM 侧行为
├── scripts/                                     # 确定性运维
├── dashboard.md                                 # Dataview 诊断
└── SPEC.md                                      # 本文件
```

**notes/ 物理摆放规则**：按知识原子本身分类（疾病放 `notes/医学/疾病/`、药物放 `notes/医学/药物/`），系统/课程归属全部交给 tag，**不在目录上做二维切片**。

## 5. 闭环机制

### 5.1 Anki ↔ vault mastery 同步（单向：Anki → vault）

- `anki-export.sh` 生成卡时，把 Anki note id 回写到 note frontmatter 的 `anki_id`。
- `scripts/anki-sync.sh` 读取 Anki 导出的复习日志 CSV（card_id, review_date, interval, ease）：
  - `interval ≥ 21 天` 且 `mastery < 3` → 升 `mastery=3`，更新 `last_reviewed`。
  - `interval ≥ 7 天` 且 `mastery < 2` → 升 `mastery=2`。
  - 连续 2 次 `ease < 1.5` → 降 `mastery` 一级，标 `<!-- drift -->`。
- vault → Anki 方向靠下次 `anki-export` 重新生成 deck，按 `anki_id` 更新已有卡，避免重复。
- **不追求实时**，每周或考前手动跑一次 sync 即可。

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
- 输出：`journal/<YYYY-MM-DD>-review.md` 总结文档（进度、薄弱点、下周/月建议）。
- 出题：调用 `study-quiz` / `study-case` 对薄弱点出题，source 强制校验（§5.2）仍生效，错题自然入 journal。
- 复练：错题经 §5.3 journal → `study-drill` 置顶复练，无需新机制。
- **护栏**：study-review 只读结构化字段（mastery / correct / journal 行 / last_reviewed），**不读 note 正文自由文本**做总结依据——底层 note 有 bug 时表现为数据缺失而非被总结成看似正确的结论。
- 模型：周/月总结是 LLM 容错高的任务；出题环节走 study-quiz/case 的既有约束。

## 6. 数据卫生条款（硬约束）

### 6.1 文件名

- **中文文件名**（2026-06-30 用户否决 ASCII slug 默认立场后确定）：note 文件名用中文知识点全称，路径 `notes/<domain>/<class>/<中文文件名>.md`。
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

### 6.3 grep / ripgrep

- **所有脚本与 skill 用 `rg`（ripgrep）**，不依赖 BSD/gnu grep 差异。
- `exam_freq` 高频过滤正则：`rg "exam_freq: ([2-9]|[1-9][0-9]+)"`（修原 bug，匹配 12/22 等）。
- wikilink 提取：`rg -o '\[\[[^\]]+\]\]'`。

### 6.4 材料版本化

- `materials/<domain>/<subject>/<year>/`，按年度子目录。
- note `source` 必须含年度：`materials/CPA/税法/2024/教材.md:p123`。
- 法规类 note：
  - `effective_date: 2024-01-01`
  - 下一版生效时新建 note，旧 note 的 `superseded_by: [[新slug]]`，dashboard 把 superseded 项标灰。
- **已决策（2026-06-30 D-6.4）**：保持年度子目录。备选"同名文件覆盖 + git 历史"被否决，因其牺牲"同时比对两年教材"能力。

## 7. skills 清单

| skill | 职责 | 状态 |
|---|---|---|
| `study-outline` | 大纲梳理→原子笔记；按 domain 加载 descriptor 词典；触发子模板 | 改造 |
| `study-quiz` | 单点题（descriptor 级）；强制 source 校验；回写 mastery（仅降不升） | 改造 |
| `study-case` | 综合题/案例/病历；写入 cases/；强制 rubric source | 新增 |
| `study-drill` | grep+rg 驱动的复习计划；读 journal 近 7 天；忽略无数据 exam_freq | 改造 |
| `study-tikz` | 仅保留供电气/通用继承；CPA/建造师/医学/生物不调用 | 保留 |
| `study-diagram-cpa` | CPA 用，几乎不用，占位 | 新增 |
| `study-diagram-建造师` | mermaid 工序/网络图 | 新增 |
| `study-diagram-医学` | Excalidraw 引导 + 附件标注，不生成图 | 新增 |
| `study-diagram-生物` | mermaid 通路 / tikz 代谢图 | 新增 |
| `study-sync` | 提示跑 anki-sync，对账 drift 项 | 新增 |
| `study-review` | 周/月复盘：读 journal N 天 + correct 分布 → 总结文档 → 调 study-quiz/case 对薄弱点出题 | 新增 |

**每个 skill 文件头部必须声明依赖的 SPEC 条款编号**（如 `# implements SPEC §3.2, §5.2`），便于变更时定位。

**字数约束归属**：正文 ≤ 400 字（公式/代码不计）是 `study-outline` 的 skill 级约束，非 SPEC 约束。其他 skill 可自由调整。若需全局统一，再提升为本 SPEC 条款。

## 8. scripts 清单

| 脚本 | 职责 | 依赖 |
|---|---|---|
| `prep.sh` | OCR → materials 归档 | mineru/paddle |
| `anki-export.sh` | 扫 descriptor 行 + quiz/ → apkg；回写 anki_id | genanki, rg |
| `anki-sync.sh` | Anki 复习日志 → vault mastery 升降 | rg, python |
| `compress-images.sh` | attachments 入库前压缩到 1600px/300KB | imagemagick |
| `taxonomy-check.sh` | 扫 notes tag，拒绝非受控词汇 | rg, python |

## 9. dashboard 视图

`dashboard.md` 改为分节，per-domain 查询 + 总览：

- §A 总览：各 domain 未掌握数、superseded 数、drift 数
- §B CPA / §C 建造师 / §D 医学 / §E 生物：各自 core 未掌握、高频未掌握、该复盘、孤立点、错题
- §F 法规时效预警：`effective_date` 早于 N 天且无 `superseded_by` 的法规类 note
- §G Anki drift：`anki_id` 缺失或 sync 标 drift 的项
- §H 待重做错题：`FROM "quiz" WHERE correct = false`，按 `last_attempted` 倒序；与 §5.3/§5.4 错题复练链呼应

所有 Dataview 查询用 `FROM #domain/xxx` 起手，不依赖目录。

## 10. 不做的事

- 不建 web 前端（Obsidian 即前端）。
- 不自研 SR 调度（信 Anki SM-2/FSRS）。
- 不做 RemNote 迁移。
- 不做多人/云同步服务。
- 不让 LLM 估 exam_freq / 估法规生效日 / 评分升 mastery。
- 不让 LLM 随手加 tag。
- 不接受 quiz/cases 中无 source 的 rubric。
- 不上 git-lfs（暂不）。

## 11. 决策记录与开放项

### 已决策（锁定）

- **D3 文件名（2026-06-30）**：采用中文文件名 + frontmatter `slug` 字段（§6.1）。否决纯 ASCII slug 默认立场。
- **D4 材料版本（2026-06-30）**：保持 `materials/<domain>/<subject>/<year>/` 年度子目录（§6.4）。否决同名覆盖。
- **MVP 范围（2026-06-30）**：单域建造师.机电实务先跑通闭环，再扩域。§1 范围（4 域愿景）不动，MVP 仅见于计划文档。
- **模型（2026-06-30）**：单模型 glm-5.2，不做对比测试。
- **study-review 进一期（2026-06-30）**：护栏为只读结构化字段，不读 note 正文（§5.4）。

### 开放项

- **E2 exam_freq**：默认装饰字段 + 无数据时 drill 忽略（§3.4）。若你想认真搞，需补"真题整理 SOP"任务。
