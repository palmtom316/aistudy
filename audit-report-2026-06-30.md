# aistudy SPEC 与实现审核报告

> 审查日期：2026-06-30  
> 审查范围：`.trellis/spec/SPEC.md` + 全部已实现文件 vs SPEC 约束

---

## 总览

SPEC 本身设计完整——三层架构、数据模型、闭环机制、数据卫生都考虑周全。但 **模板（templates）、技能（skills）、仪表盘（dashboard）与 SPEC 存在大量不一致**，需要系统性对齐。

### 实现完成度

| 类别 | SPEC 要求 | 已实现 | 完成率 |
|---|---|---|---|
| Skills | 10 | 4 | 40% |
| Scripts | 5 | 2 | 40% |
| Templates | 6+ | 2 | ~30% |
| 目录结构 | 9 个核心目录 | 5 | 56% |
| Dashboard | 7 节（A-G） | 旧版 6 查询 | 0% |

---

## 🔴 P0 — 阻塞性问题（必须修）

### 1. 模板 frontmatter 与 SPEC §3.1 严重脱节

`templates/note.md` 只有 10 个字段，SPEC 定义了 16+ 个字段。

**缺失字段：**

| 字段 | SPEC 用途 | 影响 |
|---|---|---|
| `domain` | CPA / 建造师 / 医学 / 生物 | dashboard 无法按 domain 分节查询 |
| `slug` | ASCII 文件名 slug | 脚本无法定位文件 |
| `effective_date` | 法规生效日 | 法规时效预警（§9-F）无法工作 |
| `superseded_by` | 过期时指向新版 | 旧版 note 无法被标记 |
| `anki_id` | Anki 同步对账 | anki-sync.sh 无法对账 |
| `has_image` | 是否有附件图片 | 附件管理无法自动化 |

此外 `templates/note.md` 缺少 SPEC §3.2 要求的 `## Descriptors` 区块（`概念:: 描述子 → 值` 格式），该区块是 Anki 自动成卡的数据源。

**修复：** 重写 `templates/note.md`，补齐全部 16+ 字段，增加 `## Descriptors` 区块。

---

### 2. quiz 模板与 SPEC §5.2 冲突

| 对比项 | `templates/quiz.md` 当前 | SPEC §5.2 要求 |
|---|---|---|
| `source` 字段 | `# chatgpt / 真题 / 自编`（标签式） | 具体回链：`真题年份题号 / 教材页码 / LLM-generated; reviewed YYYY-MM-DD` |
| `links` 字段 | 有 | SPEC 要求为 `source` 回链 |
| rubric 来源校验 | 无 | SPEC 强制：缺 source 则 abort |

**修复：** 重写 `templates/quiz.md`，`source` 改为具体回链格式；`links` 保留但 `source` 必须可追溯。

---

### 3. study-quiz skill 违反 SPEC §5.2 信任链

```
// study-quiz/SKILL.md 当前行为：
答对 → mastery 升一级（封顶 3）
答错 → mastery 降一级（封底 0）

// SPEC §5.2 要求：
correct: false → 直接降 mastery    （✓ 一致）
correct: true  → 仅作 hint，不自动升 mastery  （✗ 冲突）
```

SPEC 设计理念：**LLM 判对不可信，升 mastery 只走 Anki sync 或人审**。当前 skill 破坏了这条信任链。

**修复：** `study-quiz/SKILL.md` 第 3 步"答对"逻辑改为：打分后提示用户"若确认正确，请手动将 mastery 升一级"，不自动升。

---

### 4. study-drill skill 用 BSD grep 而非 rg

SPEC §6.3 明确要求："**所有脚本与 skill 用 `rg`（ripgrep）**，不依赖 BSD/gnu grep 差异。"

当前 `study-drill/SKILL.md` 全部使用 `grep`：

```bash
# 当前（错误）
grep -l "core: true" notes/*.md | xargs grep -L "mastery: [23]"
grep -l "exam_freq: [2-9]" notes/*.md
grep -l "correct: false" quiz/*.md

# 应为
rg -l "core: true" notes/
rg -l "exam_freq: ([2-9]|[1-9][0-9]+)" notes/   # 注意 SPEC 修了正则 bug
rg -l "correct: false" quiz/
```

此外 study-drill 缺失 SPEC §3.4 的 exam_freq 全局检测逻辑：当 `exam_freq>0` 的 note < 20% 时，忽略 exam_freq 排序，只用 `core + mastery + last_reviewed`。

**修复：** 全线换 `grep` → `rg`，补充 exam_freq 20% 检测逻辑。

---

### 5. dashboard.md 与 SPEC §9 完全不一致

SPEC §9 定义了 7 节结构，当前 dashboard.md 还是旧版 6 个扁平查询。

| SPEC §9 要求 | 当前状态 |
|---|---|
| §A 总览（各 domain 未掌握数、superseded 数、drift 数） | ❌ 缺失 |
| §B CPA / §C 建造师 / §D 医学 / §E 生物 | ❌ 缺失（只有全局查询） |
| §F 法规时效预警 | ❌ 缺失 |
| §G Anki drift | ❌ 缺失 |
| 查询用 `FROM #domain/xxx` 起手 | ❌ 当前用 `FROM "notes"` |
| 第 54 行拼写 `datawiew` | ❌ 应为 `dataview` |

**修复：** 按 SPEC §9 七节重写 dashboard.md，所有查询改为 tag-based。

---

### 6. 大量目录/文件未创建

| SPEC 要求 | 路径 | 状态 |
|---|---|---|
| 描述子词典 | `templates/descriptors/<domain>.md` | ❌ 不存在 |
| 结构子模板 ×4 | `templates/structural/journal-entry.md` 等 | ❌ 不存在 |
| 综合题/案例 | `cases/` | ❌ 不存在 |
| 复习日志 | `journal/` | ❌ 不存在 |
| 图片附件 | `attachments/` | ❌ 不存在 |
| 笔记按 domain 分类 | `notes/<domain>/<taxonomy原子>/` | ❌ 目录结构未建立 |

**修复：** 批量创建目录和占位文件。

---

### 7. 6 个 skill + 3 个脚本未实现

**未实现 skills：**

| Skill | SPEC 职责 | 优先级 |
|---|---|---|
| `study-case` | 综合题/案例/病历；强制 rubric source | 高 |
| `study-diagram-建造师` | mermaid 工序/网络图 | 中 |
| `study-diagram-医学` | Excalidraw 引导 + 附件标注 | 中 |
| `study-diagram-生物` | mermaid 通路 / tikz 代谢图 | 中 |
| `study-diagram-cpa` | CPA 用，几乎不用 | 低 |
| `study-sync` | 提示跑 anki-sync，对账 drift 项 | 中 |

**未实现 scripts：**

| Script | SPEC 职责 |
|---|---|
| `anki-sync.sh` | Anki 复习日志 → vault mastery 升降 |
| `compress-images.sh` | attachments 入库前压缩到 1600px/300KB |
| `taxonomy-check.sh` | 扫 notes tag，拒绝非受控词汇 |

---

## 🟠 P1 — 重要但不阻塞

### 8. 已实现 skill 文件缺少 SPEC 条款引用

SPEC §7 要求："每个 skill 文件头部必须声明依赖的 SPEC 条款编号（如 `# implements SPEC §3.2, §5.2`），便于变更时定位。"

4 个已实现 skill 全部没有：

| Skill | 应引用的 SPEC 条款 |
|---|---|
| `study-outline` | §3.1, §3.2, §3.3, §6.1, §6.2 |
| `study-quiz` | §5.2, §5.3 |
| `study-drill` | §3.4, §5.3, §6.3 |
| `study-tikz` | （无 SPEC 约束，标注 N/A） |

---

### 9. study-outline skill 的 tag 前缀与 SPEC §6.2 不一致

| 对比 | study-outline SKILL.md | SPEC §6.2 受控词汇 |
|---|---|---|
| 允许前缀 | `subject/`, `chapter/`, `type/` | `domain/`, `subject/`, `system/`, `course/` |

`chapter/` 和 `type/` 不在 SPEC 受控词汇表中。

---

### 10. 两个待否决项未决策

| 待否决项 | 默认立场 | 影响范围 |
|---|---|---|
| §6.1 文件名 | ASCII slug | 所有 note 生成逻辑、wikilink 格式、脚本 |
| §6.4 材料版本 | 年度子目录 | `materials/` 目录结构、source 回链格式 |

**建议：** 尽快决策，否则 skill 实现会卡在"按哪种格式生成"。

---

## 🟡 P2 — 建议

### 11. study-outline 的 400 字限未在 SPEC 中定义

skill 强制限字 400，但 SPEC 未提及。如果这是设计意图，应写入 SPEC；如果不是，skill 应移除该限制。

### 12. `templates/note.md` 的 `## 自测一题` 与 SPEC 的 `## Descriptors` 区块关系未明确

两者功能重叠：自测题是主动回忆，Descriptor 是 Anki 数据源。需明确：是共存两区块，还是合并？建议共存——Descriptor 做记忆提取，自测题做应用验证。

### 13. SPEC `source` 字段格式不明确

SPEC §3.1 写 `source: [materials/.../file.md:p123]`，看起来像数组内嵌字符串，但 §6.4 写法又是 `materials/CPA/税法/2024/教材.md:p123`。template 用数组 `source: []`。需统一。

### 14. SPEC §3.1 字段计数

SPEC 正文列出 16 个字段，数一下实际是 17 个（domain, subject, chapter, topic, slug, type, core, difficulty, mastery, exam_freq, last_reviewed, effective_date, superseded_by, anki_id, has_image, related, source, tags = 18 个）。建议在 SPEC 中明确计数。

---

## 📋 行动计划

| 序号 | 行动 | 优先级 | 预计工作量 |
|---|---|---|---|
| 1 | 重写 `templates/note.md`（补齐 18 字段 + Descriptors 区块） | 🔴 P0 | 小 |
| 2 | 重写 `templates/quiz.md`（source 改为具体回链格式） | 🔴 P0 | 小 |
| 3 | 修正 `study-quiz` mastery 升降逻辑（答对不自动升） | 🔴 P0 | 小 |
| 4 | 重写 `dashboard.md`（按 SPEC §9 七节，tag-based 查询） | 🔴 P0 | 中 |
| 5 | `study-drill` 换 `grep` → `rg`，补 exam_freq 20% 检测 | 🔴 P0 | 小 |
| 6 | 创建缺失目录 + 占位文件 | 🔴 P0 | 小 |
| 7 | 给 4 个已实现 skill 加 SPEC 条款引用 | 🟠 P1 | 小 |
| 8 | 对齐 study-outline 的 tag 前缀到 SPEC §6.2 | 🟠 P1 | 小 |
| 9 | 用户决策 §6.1 和 §6.4 两个待否决项 | 🟠 P1 | 讨论 |
| 10 | 实现 `study-case` skill | 🟠 P1 | 中 |
| 11 | 实现 `anki-sync.sh` | 🟠 P1 | 中 |
| 12 | 实现 `taxonomy-check.sh` | 🟠 P1 | 中 |
| 13 | 实现 `compress-images.sh` | 🟡 P2 | 小 |
| 14 | 实现 diagram 系列 skills | 🟡 P2 | 中 |
| 15 | 实现 `study-sync` skill | 🟡 P2 | 小 |
| 16 | 明确 SPEC 中 source 格式 + 字段计数 | 🟡 P2 | 文档 |
| 17 | 决定 400 字限是否写入 SPEC | 🟡 P2 | 讨论 |

---

## 附录：文件清单

### 已审查文件

| 文件 | 行数 |
|---|---|
| `.trellis/spec/SPEC.md` | 206 |
| `README.md` | 55 |
| `Makefile` | 35 |
| `dashboard.md` | 57 |
| `templates/note.md` | 27 |
| `templates/quiz.md` | 22 |
| `skills/study-outline/SKILL.md` | 56 |
| `skills/study-quiz/SKILL.md` | 44 |
| `skills/study-drill/SKILL.md` | 55 |
| `skills/study-tikz/SKILL.md` | 41 |
| `scripts/README.md` | 16 |
| `scripts/prep.sh` | 存在 |
| `scripts/anki-export.sh` | 存在 |