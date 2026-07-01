# aistudy PLAN — MVP 施工图

> 唯一施工文档。法律见 `SPEC.md`。本文件覆盖：任务清单、依赖、执行顺序、验收判据、闭环验证。
> 2026-07-01 合并：原 T-001 任务清单 + audit 行动项 + journal 决策 + 闭环验证程序。

## 0. 范围与基线

- **MVP 域**：一级建造师·机电实务（单域）。`subject=建造师.机电实务`，`domain=建造师`。
- **模型**：glm-5.2（单模型）。
- **教材**：用户自管。minerU OCR 后上传 `materials/建造师/机电实务/<year>/`，不进任务清单。
- **阶段一/二（T-001-A~H 对齐）**：✅ 已完成（templates/note.md、quiz.md 重写；study-quiz/drill/outline/tikz 加 SPEC 引用 + rg；dashboard §9 七节；目录补建）。
- **阶段三（新组件）**：本文档主体，需用户显式批准后开工。

## 1. 任务清单

### T-004 descriptors 词典（MVP 单份）
- 依赖：SPEC §3.2
- 产物：`templates/descriptors/建造师.md`
- 内容：受控描述子词典，枚举 `定义/工序/参数/规范条文/作用/要求` 等 key + 用途说明 + 示例行。
- 状态：pending

### T-005 structural 子模板（MVP 单份）
- 依赖：SPEC §3.3
- 产物：`templates/structural/procedure-flow.md`
- 内容：18 字段 frontmatter + mermaid 工序图占位 + 规范条文区 + `## Descriptors`（工序:: → 步骤链；规范条文:: → 条文）。
- 状态：pending

### T-templates 缺失模板补齐（2026-07-01 补，随阶段三）
- 依赖：SPEC §3.5 / §3.6
- 产物：
  - `templates/case.md`（§3.5 schema）
  - `templates/journal.md`（§3.6 journal 行格式占位）
- 状态：pending（轻量，与 T-004/T-005 同批做）

### T-003a anki-export.sh 增强（⭐ 关键路径，先于 T-002）
- 依赖：T-004 词典；SPEC §3.2 / §5.1
- 改造点：
  1. 现版只扫 `quiz/*.md`；补扫 `notes/**/*.md` 的 `## Descriptors` `::` 行。
  2. 描述子 key 必须在 `templates/descriptors/建造师.md` 内，否则 warn 并跳过。
  3. anki_id 用 §5.1 确定性 hash（`slug + descriptor_key`）；quiz 卡用 `quiz::slug::n`。
  4. 把 anki_id 同时设为 genanki note 的 `guid`（防重复）并回写 frontmatter `anki_id`。
  5. 卡字段：Front=`[概念] - [描述子]`，Back=`值`，Topic=`subject`。
- 状态：pending

### T-003b anki-sync.sh + anki-sync-export.sql
- 依赖：T-003a（anki_id 已回写）；SPEC §5.1
- 产物：
  - `scripts/anki-sync-export.sql`（§5.1 SQL，导出 `note_id,review_date,interval,ease` CSV）
  - `scripts/anki-sync.sh`（python：读 CSV → 按 note_id 对齐 anki_id → 行级 RegExp 改写 mastery/last_reviewed + 末尾 drift 注释）
- 状态：pending

### T-003c taxonomy-check.sh
- 依赖：SPEC §6.2 MVP 受控取值表
- 产物：扫 `notes/**/*.md`，校验 tags 仅含 `domain/建造师` + `subject/建造师.机电实务`；违例报文件+tag，exit 1。
- 状态：pending

### T-003d compress-images.sh
- 依赖：SPEC §8（imagemagick）
- 产物：扫 `attachments/**`，>1600px 或 >300KB 的图用 `convert -resize 1600x1600\> -quality 85` 压缩（原地覆盖）。
- 状态：pending

### T-002 skills（3 个，依赖 T-004/T-005/T-templates/T-003a）
- **study-case**（implements §3.5, §5.2, §5.3）：综合题出题→入库 cases/→强制 rubric source→评分回写（correct:false 降 mastery，true 仅 hint）→journal append（mkdir 锁）。
- **study-sync**（implements §5.1, §5.3）：扫 `<!-- drift -->` 与缺 `anki_id` 的 note，列出 + 提示跑 `anki-sync-export.sql`/`anki-sync.sh`。刻意做薄，不折叠进 study-drill（§2 分层）。
- **study-review**（implements §5.4, §3.6, §5.2）：读 journal N 天 + correct 分布 + mastery 分布 → 生成 `journal/<YYYY-MM-DD>-review.md` → 调 study-quiz/case 对薄弱点出题。**护栏：只读结构化字段，不读 note 正文**。
- 状态：pending

### T-docs 配套文档对齐（轻量，收尾）
- `scripts/README.md`：补 anki-sync-export.sql / anki-sync.sh / taxonomy-check.sh / compress-images.sh 行。
- `Makefile`：补 `sync` / `review` / `case` / `taxonomy` 目标。
- `README.md`：快速开始示例换成建造师.机电实务；删 `prompts/` 架构行（与 SPEC §4 对齐）。
- 状态：pending

## 2. 执行顺序

```
T-004 建造师词典  ┐
T-005 procedure-flow ┘ 下游先建（词典/模板是 skill 与 anki-export 的输入）
T-templates case.md/journal.md  ┘ 同批
   ↓
T-003a anki-export 增强 ⭐ Anki 闭环关键路径，先于 study-case
   ↓
T-002 study-case / study-sync / study-review
   ↓
T-003b/c/d anki-sync / taxonomy-check / compress-images
   ↓
T-docs 配套文档对齐
   ↓
§3 闭环验证
```

## 3. 闭环验证（MVP 验收判据）

用户上传至少 1 份教材 OCR 后，或用 1 篇 mock note 跑：

1. **建笔记**：`make outline SUBJECT=建造师.机电实务` → 生成 ≥1 篇 note（含 `## Descriptors` `::` 行 + 18 字段 + 中文文件名）。校验 frontmatter 字段数=18、tags 落 §6.2 MVP 表。
2. **taxonomy**：`bash scripts/taxonomy-check.sh` → exit 0。
3. **出题**：`make quiz TOPIC=...` + study-case 出 1 道综合题 → 校验 `source` 非空、rubric 含 source、journal append 了一行。
4. **Anki 导出**：`make anki` → 生成 `aistudy.apkg`；note frontmatter `anki_id` 已回写且非空；同一 note 跑两次 export，anki_id 不变（确定性）。
5. **Anki 复习回写**：在 Anki 里复习后导出 CSV（`sqlite3 ... < scripts/anki-sync-export.sql > review.csv`），`bash scripts/anki-sync.sh review.csv` → 对应 note 的 mastery 按规则升降、drift 项出现 `<!-- drift -->`、`last_reviewed` 更新。
6. **drift 呈现**：跑 study-sync → 列出 drift 项 + 缺 anki_id 项。
7. **复盘**：跑 study-review → 生成 `journal/<date>-review.md`，内容仅来自结构化字段（抽查：不引用 note 正文原句）。
8. **dashboard**：Obsidian 打开 `dashboard.md`，§A/§C/§F/§G/§H 五节能渲染出非空结果。

全部通过 = MVP 闭环达成，可扩域。

## 4. 完成判据总表

- [x] 阶段一/二（T-001-A~H）已完成
- [x] D-6.1 / D-6.4 / MVP 范围 / 模型 / study-review / anki_id 策略 / CSV 来源 / 文档合并 全部锁定
- [ ] T-004 / T-005 / T-templates（词典 + procedure-flow + case/journal 模板）
- [ ] T-003a anki-export 增强（含 anki_id 回写 + 确定性）
- [ ] T-002 study-case / study-sync / study-review
- [ ] T-003b anki-sync-export.sql + anki-sync.sh
- [ ] T-003c taxonomy-check.sh
- [ ] T-003d compress-images.sh
- [ ] T-docs scripts/README + Makefile + README 对齐
- [ ] §3 闭环验证 8 步全过
