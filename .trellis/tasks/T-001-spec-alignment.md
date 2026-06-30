# T-001: SPEC 对齐与实现补全计划

> 创建：2026-06-30  
> 起因：审查报告 `audit-report-2026-06-30.md` 核实通过，7 P0 / 4 P1 / 3 P2  
> 目标：把模板、skill、dashboard、目录结构拉齐到 SPEC，并实现缺失组件

## 已完成的 SPEC 修订（2026-06-30）

| 条款 | 修订内容 |
|---|---|
| §3.1 | `source` 明确为数组，每项格式 `materials/<domain>/<subject>/<year>/file.md:p123`；`related` 明确 wikilink 数组格式；新增字段计数 18 |
| §3.2 | 新增 `## Descriptors` 与 `## 自测一题` 共存说明：前者管 Anki 记忆点，后者管应用验证 |
| §7 | 新增字数约束归属说明：400 字是 study-outline skill 级约束，非 SPEC 约束 |
| §5.4 | 新增周/月复盘机制（study-review）（2026-06-30 MVP 决策追加）|
| §7 | skills 清单追加 study-review 行（2026-06-30 MVP 决策追加）|

## MVP 范围决策（2026-06-30 续）

| 项 | 决策 |
|---|---|
| 执行范围 | 4 域同推 → **单域 MVP：一级建造师·机电实务**。先跑通闭环再扩域 |
| 模型 | **单模型 glm-5.2**，不做对比测试 |
| 教材 | **用户自管**：minerU OCR 后上传 `materials/建造师/机电实务/<year>/`，不进任务清单 |
| subject 命名 | `建造师.机电实务`（缩短自"机电工程管理与实务"）|
| study-review | **进一期**（非二期）。护栏：只读结构化字段（mastery/correct/journal 行/last_reviewed），不读 note 正文 |
| SPEC §1 | 范围不动（4 域愿景保持），MVP 范围只体现在本计划文档 |
| dashboard | MVP 只验 A 总览 + C 建造师节 + F 法规时效 + G Anki drift；B/D/E 留结构空查询 |

---

## 任务清单

### 阶段一：P0 模板与 skill 对齐（✅ 已完成）

- T-001-A 重写 templates/note.md（18 字段 + Descriptors 区块）✅
- T-001-B 重写 templates/quiz.md（source 改回链数组）✅
- T-001-C 修正 study-quiz：答对不自动升 mastery + source abort 校验 ✅
- T-001-D study-drill：grep→rg + exam_freq 20% 检测 ✅
- T-001-E 重写 dashboard.md 按 §9 七节 + 修 datawiew 拼写 ✅
- T-001-F 创建 cases/ journal/ attachments/ templates/{descriptors,structural}/ ✅（2026-06-30 补建 descriptors/、structural/ 空目录+.gitkeep，原只建了 4 个根目录）

### 阶段二：P1 对齐与补全（✅ 已完成）

- T-001-G 4 个 skill 加 SPEC 条款引用 ✅
- T-001-H study-outline tag 前缀对齐 §6.2（domain/ subject/ system/ course/）✅

### 阶段三：新组件实现（⚠️ 需用户显式批准后开工）

> 以下任务为 NEW 实现，不属于"修订 spec/计划"范畴。用户确认前不执行。  
> MVP 范围已裁剪到建造师.机电实务单域。

#### T-002 实现缺失 skills（MVP 裁剪版）
- **依赖**：D-6.1 决策（已锁：中文文件名）；T-004 词典、T-005 模板、T-003a anki-export 增强（Anki 闭环关键路径，先于 study-case）
- **MVP 清单（3 个）**：
  - study-case（综合题/案例，建造师案例题重头）—— implements SPEC §5.2, §5.3
  - study-sync（提示跑 anki-sync，对账 drift）—— implements SPEC §5.1, §5.3。**注**：此 skill 刻意做薄——跑脚本属确定性操作（§2），skill 只负责呈现 drift 项 / 提示复盘，是"表达走 skill"分层的体现，不折叠进 study-drill。
  - study-review（周/月复盘）—— implements SPEC §5.4, §5.2, §5.3；护栏：只读结构化字段
- **defer（非 MVP 域）**：study-diagram-{cpa,建造师,医学,生物}
  - 注：study-diagram-建造师 原列 MVP，现 defer——procedure-flow 模板能手写 mermaid 先顶着，skill 化等验证后看是否值得
- **状态**：pending（待批准）

#### T-003 实现缺失 scripts（MVP 全做）
- **清单（3 脚本 + 1 增强，均为 domain-agnostic）**：
  - **T-003a anki-export.sh 增强**（⭐ 关键路径，先于 T-002 study-case）：现版本只扫 quiz/，补扫 notes `## Descriptors` 的 `::` 行（SPEC §3.2）。无此增强则 Anki 闭环断——没卡生成、没复习、没 sync 回写。依赖 T-004 词典定义 descriptor 格式。
  - T-003b anki-sync.sh（依赖 §5.1 逻辑，Anki 复习日志 → vault mastery 升降）
  - T-003c taxonomy-check.sh（扫 notes tag，拒收非受控词汇；MVP 只认 `domain/建造师` + `subject/建造师.机电实务`）
  - T-003d compress-images.sh（attachments 入库前压缩到 1600px/300KB）
- **状态**：pending（待批准）

#### T-004 创建 descriptors 词典（MVP 单份）
- **依赖 SPEC**：§3.2
- **MVP 清单**：`templates/descriptors/建造师.md` 一份受控描述子词典
- **defer**：cpa / 医学 / 生物 词典
- **状态**：pending（待批准）

#### T-005 创建 structural 子模板（MVP 单份）
- **依赖 SPEC**：§3.3
- **MVP 清单**：`templates/structural/procedure-flow.md`（工序+规范条文）
- **defer**：journal-entry / differential-table / pathway-graph
- **状态**：pending（待批准）

---

## 执行顺序建议

```
T-001-A..H        阶段一/二 ✅ 已完成
   ↓
T-004 建造师词典  ┐ 下游先建（词典是 skill/anki-export 的输入）
T-005 procedure-flow ┘ 模板是 study-outline 触发目标
   ↓
T-003a anki-export 增强 ⭐ Anki 闭环关键路径，先于 study-case
   ↓
T-002 study-case / study-sync / study-review（3 skills）
   ↓
T-003b/c/d anki-sync / taxonomy-check / compress-images
   ↓
用户上传教材后跑闭环验证
```

**边界**：阶段一/二属"对齐现有文件到 SPEC"，已完成。阶段三属"新组件实现"，需用户显式批准后开工，不擅自执行。

## 完成判据

- [x] SPEC §3.1 / §3.2 / §7 三处修订已落盘（✅ 2026-06-30）
- [x] SPEC §5.4 复盘机制 + §7 study-review 行追加（✅ 2026-06-30 MVP 决策）
- [x] T-001-A~H 全部 done
- [x] D-6.1 已决策：中文文件名
- [x] D-6.4 已决策：年度子目录
- [x] MVP 范围收窄决策落盘（单域建造师.机电实务 / glm-5.2 / 教材自管 / study-review 进一期）
- [ ] T-002（3 skills）/ T-003（3 脚本+增强）/ T-004（建造师词典）/ T-005（procedure-flow）待用户批准后推进
