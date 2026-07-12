# aistudy 全项目技术审查报告

- **审查日期**：2026-07-11
- **范围**：仓库全部可执行逻辑与规格（scripts / skills / templates / dashboard / sample note / SPEC·PLAN / Makefile）
- **方式**：静态通读 + 对照 SPEC + 本地命令复现
- **基线**：当前工作区（相对既有 2026-07-06 报告再做独立复审）
- **文件变更**：本报告落盘前未修改业务代码；审查过程中清理了失败 `prep` 留下的错误 `materials/建造师/` 目录树

## 1. 项目画像

| 维度 | 结论 |
|---|---|
| 定位 | 「ChatGPT + Obsidian 突击复习」系统化的 **学习操作系统**（vault 即前端） |
| 形态 | 非典型 Web 应用；**Markdown 数据 + Bash/Python 确定性脚本 + LLM Skill SOP** |
| 代码量 | 约 1.2k 行有效脚本/模板/skill（不含 venv） |
| MVP 域 | 一级建造师 · 机电实务 |
| 运行验证 | `bash -n scripts/*.sh` ✅ · `make taxonomy` ✅ · `make anki` ✅（3 卡）· `make prep FILE=课件.pdf` ❌ |

架构分层是对的：

```
确定性（scripts）  ←→  判断/表达（skills）  ←→  阅读/答题（Obsidian）
```

这比「全塞进 agent prompt」或「自建前端」更可维护。问题集中在 **入库链路、Anki 回写、校验是否落到脚本**，而不是概念设计。

---

## 2. 验证命令与结果

```bash
bash -n scripts/*.sh
make taxonomy
make anki
make prep FILE=课件.pdf
make prep FILE=课件.pdf SUBJECT=建造师.机电实务
git status --short
```

结果摘要：

| 命令 | 结果 |
|---|---|
| `bash -n scripts/*.sh` | ✅ |
| `make taxonomy` | ✅ 1 文件合规 |
| `make anki` | ✅ 3 cards from notes, 0 from quiz |
| `make prep FILE=课件.pdf` | ❌ SUBJECT 缺失 |
| `make prep FILE=课件.pdf SUBJECT=建造师.机电实务` | ❌ 路径变成 `materials/建造师/建造师/机电实务/...`；无 OCR 时把 PDF 当 md `mv`，且未落 PDF 原件 |
| 失败 `prep` 副作用 | 曾污染出错误目录树 `materials/建造师/建造师/...`（审查时已清理） |

样例 note `电缆敷设.md` 三 descriptor 对应 guid：

```text
参数     → 1588257828 (= frontmatter anki_id)
规范条文 → 179682697
工序     → 16703686
```

---

## 3. 架构与设计评价

### 3.1 优点（应保留）

1. **职责边界清晰**  
   OCR / Anki 导出同步 / tag 校验走脚本；出题、大纲、复盘走 skill；UI 用 Obsidian。符合 SPEC §2。

2. **数据模型可诊断**  
   `core / mastery / exam_freq / last_reviewed / related / source` 支撑 dashboard 与 drill，状态机比「纯笔记堆」可运维得多。

3. **Descriptors 词典 + 白名单**  
   `templates/descriptors/建造师.md` + `anki-export` 白名单，避免 LLM 乱造描述子，Anki 卡源可控。

4. **frontmatter 行级改写**  
   禁用全量 YAML 序列化，git diff 友好（SPEC §10）。

5. **信任链设计意图正确**  
   quiz/case 必须有 source；`correct:false` 降 mastery，`correct:true` 不自动升——符合考试场景的保守策略。

6. **Skill 有护栏意识**  
   study-review「只读结构化字段」、study-extract「人审 gate」、study-sync「刻意做薄」都是正确工程取舍。

### 3.2 系统性风险

| 风险 | 说明 |
|---|---|
| **规格执行分叉** | 大量约束只写在 skill 文本里，脚本侧无 gate → LLM 一偏就破信任链 |
| **note 级状态 vs card 级事实** | 一篇 note 多 descriptor = 多 Anki 卡，但 mastery/drift 仍是 note 级标量 → 聚合语义未定义清楚 |
| **文档与 Makefile 漂移** | README 快速开始与真实 CLI 参数不一致 → 入口即坏 |
| **测试空缺** | 无单元/集成测试；闭环靠人工 `make`，回归全靠肉眼 |

---

## 4. 缺陷清单（按严重度）

### P0 — 阻断主流程 / 可能损坏数据

#### P0-1 `prep` 主链路与 SPEC/README 三方不一致

**证据**

- `README.md` 写的是 `make prep FILE=课件.pdf`
- `Makefile` 只把 `FILE` 传给 `scripts/prep.sh`
- `scripts/prep.sh` 无 `SUBJECT` 直接 exit 1

即使传入 `SUBJECT=建造师.机电实务`：

```bash
DOMAIN=建造师
SUBJECT_PATH=建造师/机电实务   # ${SUBJECT//.//}
DEST=materials/${DOMAIN}/${SUBJECT_PATH}/...
# → materials/建造师/建造师/机电实务/<year>/   ❌
# SPEC §6.4 期望：materials/建造师/机电实务/<year>/
```

**连带问题**

| 点 | 代码行为 | SPEC 期望 |
|---|---|---|
| PDF 原件 | 只 `mv` OCR md | PDF + md 并存 |
| 无 OCR 工具 | 假设输入已是 md，`mv` PDF 到 `*.md` | 应拒绝非 md |
| 临时目录 | `materials/.ocr-tmp-$STAMP`（按日） | 并发冲突；应用 `mktemp -d` |
| PaddleOCR | 裸 `python` | 应与其他脚本一样优先 `.venv/bin/python` |
| 失败路径 | `mkdir -p` 后 `mv` 失败仍留下半成品目录 | 应清理或事务化 |

**建议**

1. `Makefile`：`SUBJECT ?= 建造师.机电实务`，调用 `bash scripts/prep.sh "$(FILE)" "$(SUBJECT)"`
2. subject 路径：`建造师.机电实务` → 去掉 domain 前缀后 `机电实务`，或 `SUBJECT` 只传科目段
3. OCR 成功后 `cp` PDF 原件到目标目录
4. 无 OCR 且扩展名不是 `.md` → 明确报错退出
5. `OUTDIR=$(mktemp -d materials/.ocr-tmp.XXXXXX)`；失败时清理半成品

---

#### P0-2 `anki-sync.sh`：多卡 note 写回互相覆盖

样例 note 有 3 个 descriptor → 3 个不同 `anki_guid`，映射到 **同一 path**。

脚本按 **card（guid）** 循环读写同一文件：

- 卡 A drift → 写 `<!-- drift -->`，mastery -1
- 卡 B 非 drift → `set_drift_marker(..., false)` **清掉 drift**
- 卡 C 再升级/降级 → mastery 被反复改写

**结果依赖 CSV 处理顺序**，可能：

- 错误隐藏 drift
- 一轮 sync 连降多级
- 最后一张卡的 `last_reviewed` 覆盖其余卡的证据

这与 SPEC §5.1「note 级 mastery / drift」语义冲突——规格写了升降规则，但没定义 **多卡聚合**。

**建议**

```text
按 path 聚合所有匹配卡的 reviews
→ note.drift = any(card.drift)
→ note.mastery = 明确策略（建议：降级优先 / 升级取最强 interval 但单轮最多 ±1）
→ 每 note 只 write 一次
```

---

### P1 — 正确性 / 信任链漏洞

#### P1-1 journal 锁示例运算符优先级错误

`skills/study-quiz/SKILL.md` / `skills/study-case/SKILL.md` 中：

```bash
mkdir journal/.lock 2>/dev/null || sleep 1 && mkdir journal/.lock 2>/dev/null
```

等价于 `(mkdir || sleep 1) && mkdir`：  
**第一次 mkdir 成功后仍会执行第二次 mkdir → 必失败。**

应改为带次数上限的 retry + `trap` 清理：

```bash
for i in 1 2 3; do
  if mkdir journal/.lock 2>/dev/null; then
    trap 'rmdir journal/.lock 2>/dev/null || true' EXIT
    break
  fi
  sleep 1
done
[ -d journal/.lock ] || { echo "failed to acquire journal lock" >&2; exit 1; }
```

并确保不存在日志时先写首行 `# <date> 复习日志`。

---

#### P1-2 信任链只靠 skill 文案，脚本不 enforcement

SPEC §5.2：无 source 不许入库。

现实：

- `templates/quiz.md` 默认 `source: []`
- `scripts/anki-export.sh` 只要有 `## 题目` 就打包，**不检查** frontmatter `source` / rubric 内 `source:`
- 无 schema 校验脚本

→ 手工文件或 LLM 漏写 source 仍可进 Anki，信任链在「出题 skill 守规矩」上单点依赖。

**建议**：`anki-export` 对 quiz 强制校验；另增 `scripts/validate-content.sh`（source、rubric、必填 frontmatter、descriptor 白名单重复 key）。

---

#### P1-3 descriptor GUID 碰撞

```python
aid = h(f"{slug}::{key}")  # 同一 note 内同 key 两行 → 同 guid
```

合法内容例如两行 `参数:: A → ...` / `参数:: B → ...` 会在 Anki 侧覆盖/合并异常，sync 也无法区分。

**建议**：note 内 key 唯一则 fail-fast；或 hash 输入含 concept/序数，并改 SPEC。

---

#### P1-4 `taxonomy-check` 假阴性

`parse_tags` 只抓 `prefix/value` 形态：

| 输入 | 结果 |
|---|---|
| `tags: ["foo"]` | 提取空集 → **通过** |
| `tags: []` | 通过 |
| `tags: ["bad tag"]` | 通过 |
| 合法 `domain/建造师` + `subject/...` | 通过 |

SPEC 要求「词典外一律拒收」，实现变成「不像 tag 的直接看不见」。  
MVP 还应要求 notes **至少包含** `domain/建造师` + `subject/建造师.机电实务`。

---

#### P1-5 `compress-images.sh` 的 ImageMagick 探测过严

已支持 `magick identify`，却仍要求裸命令 `identify`：

```bash
command -v identify >/dev/null 2>&1 || { echo "❌ 缺 imagemagick（identify）"; exit 1; }
```

仅装 IM v7、无 `identify` 兼容包装时会 **误报退出**。

---

### P2 — 规格漂移 / 体验与可维护性

| ID | 问题 | 影响 |
|---|---|---|
| P2-1 | PNG>300KB 转 JPG 并 `rm` 原 PNG，**不改 md 引用** | 断图；透明丢失；日志仍按原路径 `file_bytes` 可能显示 0KB |
| P2-2 | quiz guid 实现 `quiz::{stem}`，SPEC 写 `quiz::{slug}::{n}` | 重命名/多题扩展会漂移 |
| P2-3 | dashboard §C 缺「高频未掌握 / 孤立点」；§A/F/G 用 `FROM "notes"` 与 SPEC「`FROM #domain/xxx`」不完全一致 | 诊断能力弱于规格 |
| P2-4 | `study-review` 用 `rg -A999 "^# " journal/`，**未按 N 天过滤** | 复盘被全历史污染 |
| P2-5 | 样例 note「自测一题」空；source 指向不存在的 `materials/.../教材.md:p123` | 新用户照样例生成不合格 note |
| P2-6 | frontmatter `anki_id` 只存 **首张** descriptor guid | 与「每卡一 id」语义并存时，文档/sync 容易误解 |
| P2-7 | 无 `requirements.txt` / 依赖清单 | genanki、MinerU、PaddleOCR、ImageMagick、rg、sqlite3 隐式依赖 |
| P2-8 | `.gitignore` 偏薄 | 建议加 `review.csv`、`materials/.ocr-tmp*`、`mock-exam-*.md`、`.pi-subagents/` 等 |

---

### P3 — 卫生与增强（非阻断）

- skill 调 skill（study-review → study-quiz/case）在 pi 环境依赖编排约定，文档未写清失败回退
- `study-drill` 依赖 CLI `rg` 结果而非 Dataview 渲染，设计正确，但 dashboard 与 drill 两套查询条件可能漂移
- `anki-sync-export.sql` 去掉了 SPEC 示例中的 `GROUP BY`（注释称 r.id 唯一）——合理，但应回写 SPEC 以免「实现≠规格」
- 中文路径策略正确，但全库几乎无集成测试覆盖 quote/编码边界
- 无 CI（taxonomy + anki dry-run + bash -n）

---

## 5. 分模块质量速览

| 模块 | 评级 | 一句话 |
|---|---|---|
| `docs/SPEC.md` | A- | 决策完整、边界清楚；部分条款未落脚本 |
| `Makefile` | C | skill 目标是 echo 指引尚可；`prep` 参数错 |
| `prep.sh` | D | MVP 入库入口坏 + 路径错 + 可能毁文件语义 |
| `anki-export.sh` | B | 白名单、双格式 descriptor、回写 anki_id 扎实；缺 source/重复 key 校验 |
| `anki-sync.sh` | C+ | 单卡逻辑对；多卡 note 语义错误 |
| `anki-sync-export.sql` | A- | 列设计正确（guid 非 notes.id） |
| `taxonomy-check.sh` | C | 能拦部分非法前缀，假阴性多 |
| `compress-images.sh` | C+ | 备份到 `.original/` 好；PNG 转码与 identify 探测有坑 |
| skills（整体） | B+ | SOP 完整、护栏多；锁片段与 review 日期过滤有 bug |
| templates | A- | schema 注释到位，是系统「类型系统」 |
| `dashboard.md` | B- | MVP 骨架在，§C 未按 SPEC 补齐 |
| 样例内容 | C | 能导出 3 卡，但自测/材料不完整 |

---

## 6. 优先修复路线（建议 1–2 个迭代）

### 迭代 A — 修闭环入口（阻塞）

1. 修 `Makefile` + `prep.sh` 路径 / SUBJECT / PDF 保存 / OCR 失败语义
2. `anki-sync` 按 path 聚合写回
3. 修 journal lock 片段（quiz + case）
4. 清理/禁止错误 `materials/**` 半成品残留

**验收**：`make prep FILE=真实.pdf SUBJECT=建造师.机电实务` 落到 `materials/建造师/机电实务/<year>/` 且含 pdf+md；伪造双卡 review CSV 只写一次 mastery/drift 且 any-drift 保留。

### 迭代 B — 把信任链落到代码

1. `validate-content.sh` + `make check`
2. export 拒无 source quiz；拒重复 descriptor key
3. taxonomy 解析全部 tag 字符串 + notes 必含 MVP 双 tag
4. quiz guid 对齐 SPEC 或改 SPEC

### 迭代 C — 诊断与样例硬化

1. dashboard §C 补查询；统一 FROM 策略并改 SPEC 一句
2. study-review 按 `journal/YYYY-MM-DD.md` 过滤
3. 补最小 mock material + 完整自测题
4. `requirements.txt` + 扩展 `.gitignore` + 可选 CI

---

## 7. 总体结论

**这是一个设计密度高于代码量的「个人学习 OS」**：分层、词典、状态字段、Anki 单向回写、rubric 信任链等主线是专业的，SPEC/PLAN 质量明显好于多数 side project。

当前 **不能称为生产可用闭环**，主要因为：

1. **材料入库入口坏掉且路径/原件语义错误**（P0）
2. **Anki→vault 多卡写回会破坏 drift/mastery**（P0）
3. **关键约束停留在 skill 自然语言，未进确定性校验**（P1）

修好迭代 A 后，MVP「笔记 → 卡 → 复习 → mastery 回流 → dashboard/drill」才具备技术上可依赖的底座；迭代 B 之后，才谈得上「信任链可审计」。

---

## 8. 与 2026-07-06 报告的关系

本次独立复审 **确认并复现** 了 2026-07-06 报告中的 P0/P1 主干（prep、sync 覆盖、journal 锁、source 未落脚本、taxonomy 假阴性、GUID 碰撞等），并补充：

- 失败 `prep` 会创建错误目录树（副作用）
- `anki_id` 仅存首卡 guid 与多卡映射的文档风险
- SQL 与 SPEC 示例 GROUP BY 漂移
- ImageMagick / genanki 依赖探测现状

---

## 附录：历史审查摘录（2026-07-06）

以下问题在 2026-07-06 已记录，2026-07-11 仍存在：

1. `prep` SUBJECT 缺失 + 路径双重 domain + PDF 不保存
2. `anki-sync` 多 descriptor 卡写回覆盖
3. journal lock shell 优先级错误
4. source/rubric 无脚本校验
5. descriptor 同 key GUID 碰撞
6. taxonomy 假阴性
7. compress-images PNG→JPG 断链
8. quiz GUID 与 SPEC 不一致
9. dashboard 与 SPEC §9 不完全一致
10. study-review 未按 N 天过滤
11. 样例 note 不完整
12. 依赖清单 / .gitignore 偏薄

---

## 9. 修订状态（2026-07-12）

已按本报告迭代 A/B/C 落地，本地 `make smoke` 全绿。摘要：

| ID | 状态 |
|---|---|
| P0-1 prep 路径/SUBJECT/PDF/OCR | ✅ 已修 |
| P0-2 anki-sync 多卡聚合 | ✅ 已修 |
| P1-1 journal lock | ✅ skill 片段已修 |
| P1-2 source 信任链 | ✅ validate-content + export 拒无 source |
| P1-3 descriptor 重复 key | ✅ export/validate/sync fail-fast |
| P1-4 taxonomy 假阴性 | ✅ 已修 |
| P1-5 ImageMagick identify | ✅ 已修 |
| P2-1 PNG→JPG 断链 | ✅ 保留 PNG 扩展名 |
| P2-2 quiz guid | ✅ `quiz::{slug}::1` |
| P2-3 dashboard §C | ✅ 高频/孤立点 + `#domain` FROM |
| P2-4 study-review 日期过滤 | ✅ 文案已修 |
| P2-5 样例 note/quiz/material | ✅ 已补 |
| P2-6 anki_id 首卡语义 | ✅ SPEC/模板/脚本 README 对齐 |
| P2-7 依赖清单 | ✅ requirements.txt |
| P2-8 .gitignore | ✅ 已扩 |
| P3 CI | ✅ `.github/workflows/smoke.yml` + `make smoke` |

