# 全项目代码审查报告

- 日期：2026-07-06
- 基线分支：`main`
- 基线提交：`c78c3e1`
- 审查方式：只读审查；子代理因 API 限流失败后改为本会话手动审查
- 文件变更：本报告落盘前未修改项目代码

## 验证命令

```bash
bash -n scripts/*.sh
make taxonomy
make anki
make prep FILE=课件.pdf
git status --short
```

结果摘要：

- `bash -n scripts/*.sh` ✅
- `make taxonomy` ✅
- `make anki` ✅ 生成 3 张卡
- `make prep FILE=课件.pdf` ❌ 与 README 快速开始不一致，实际失败
- `git status --short` ✅ 审查结束时干净

---

## 关键问题

### P0 — `prep` 主流程坏掉，且可能破坏材料归档

证据：

- `README.md:27` 写的是 `make prep FILE=课件.pdf`
- `Makefile:22-24` 只把 `FILE` 传给 `scripts/prep.sh`
- `scripts/prep.sh:16-20` 没有 `SUBJECT` 就直接退出

实际运行结果：

```bash
make prep FILE=课件.pdf
# 用法: bash scripts/prep.sh <文件> <SUBJECT>
# make: *** [prep] Error 1
```

另外，`prep.sh` 路径也和 SPEC 冲突：

- SPEC 要：`materials/建造师/机电实务/<year>/`
- `scripts/prep.sh:22-23` 把 `SUBJECT=建造师.机电实务` 转成 `建造师/机电实务`
- `scripts/prep.sh:63` 再拼 `materials/${DOMAIN}/${SUBJECT_PATH}`
- 实际会变成：`materials/建造师/建造师/机电实务/<year>/`

还有一个更危险的问题：

- SPEC §6.4 要 PDF 原件和 OCR 后 md 并存
- `scripts/prep.sh:62-66` 只移动 OCR md，没有保存 PDF 原件
- `scripts/prep.sh:57-60` 在没有 OCR 工具时假设输入已为 md，但如果输入是 PDF，会把 PDF 直接移动成 `.md`

建议：

1. `Makefile` 给 `SUBJECT ?= 建造师.机电实务`，并调用 `bash scripts/prep.sh "$(FILE)" "$(SUBJECT)"`。
2. `prep.sh` 生成 subject path 时去掉 domain 前缀：`建造师.机电实务 → 机电实务`。
3. OCR 成功后同时 `cp "$FILE"` 到目标目录，保持 PDF 原件。
4. 没有 OCR 工具时，仅允许 `.md` 输入；PDF 应直接报错。

---

### P0/P1 — `anki-sync.sh` 对一篇 note 多张卡的回写会互相覆盖，可能隐藏 drift

证据：

- `scripts/anki-sync.sh:73-85` 为每个 descriptor card 建 `anki_guid → note path`
- `scripts/anki-sync.sh:136-163` 按 card 逐条写同一个 note
- 示例 note `notes/建造师/机电实务/电缆敷设.md:24-27` 有 3 个 descriptor，即 3 张卡

风险：

如果同一篇 note 中：

- 卡 A 连续两次 `ease < 1.5` → 写入 `<!-- drift -->` 并降 mastery
- 卡 B 非 drift，随后处理 → `set_drift_marker(..., false)` 会清掉 drift

最终结果取决于 CSV 卡片处理顺序，可能：

- 错误清除 drift
- 同一 sync 里重复降级或升降交错
- note 级 `mastery` 被多张 descriptor 卡反复改写

建议：

- 先按 `path` 聚合所有卡的 reviews，再对 note 只写一次。
- note drift 应为：任意卡 drift → note drift。
- mastery 升级应取最强证据，降级应有明确规则，避免一轮 sync 连降多级。
- 输出也应按 note 汇总，而不是按 card 重复写文件。

---

### P1 — `study-quiz` / `study-case` 的 journal 锁示例有 shell 逻辑错误

证据：

- `skills/study-quiz/SKILL.md:35-39`
- `skills/study-case/SKILL.md:34-38`

当前片段：

```bash
mkdir journal/.lock 2>/dev/null || sleep 1 && mkdir journal/.lock 2>/dev/null
```

因为 `&&` 和 `||` 左结合，实际等价于：

```bash
(mkdir journal/.lock || sleep 1) && mkdir journal/.lock
```

即使第一次 `mkdir` 成功，也会再执行第二次 `mkdir`，导致失败。skill 按这个执行时会出现锁获取失败或异常退出。

建议改成真实 retry + trap：

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

### P1 — trust chain 只靠 skill 文字约束，脚本不会阻止无 source 的题进入 Anki

SPEC §5.2 要求 quiz/cases rubric 必须有 source，缺 source 不许入库。

但：

- `templates/quiz.md:8` 默认 `source: []`
- `scripts/anki-export.sh:137-146` 只要有 `## 题目` 就导出 quiz 卡
- 没有检查 frontmatter `source`
- 没有检查 rubric 中是否包含 `source:`

风险：任何手工创建或 LLM 失误生成的无来源 quiz 都能被 `make anki` 打包，破坏“rubric 信任链”。

建议：

- `anki-export.sh` 对 quiz 增加校验：
  - frontmatter `source` 非空，或 rubric 内含 `source:`
  - 不满足则 warn + skip，或直接 fail
- 增加 `scripts/validate-content.sh`，集中校验 notes/quiz/cases schema、source、rubric。

---

### P1 — descriptor GUID 可能碰撞，同一 note 重复描述子 key 会丢卡

证据：

- `scripts/anki-export.sh:123` 使用 `h(f"{slug}::{key}")`
- `scripts/anki-export.sh:126-127` 每一行 descriptor 都生成一张 Anki note
- `scripts/anki-sync.sh:84-85` 同样以 `slug + key` 建映射

如果一篇 note 有两行：

```md
参数:: A → ...
参数:: B → ...
```

两张卡 GUID 完全相同。Anki import 时会把它们视为同一 note/guid，造成覆盖或重复处理异常；sync 也无法区分两张卡。

建议二选一：

1. 强制一篇 note 内 descriptor key 唯一，脚本发现重复 key 直接报错。
2. 修改 hash 输入为 `slug + descriptor_key + concept` 或 `slug + descriptor_key + ordinal`，同时更新 SPEC。

---

### P1 — `taxonomy-check.sh` 会漏掉非法 tag，空 tags 也能通过

证据：

- `scripts/taxonomy-check.sh:22-33` 用正则只提取形如 `xxx/yyy` 的 tag
- `scripts/taxonomy-check.sh:50-55` 只校验被提取出来的 tag

因此这些情况可能被误判通过：

```yaml
tags: ["foo"]
tags: ["bad tag"]
tags: []
```

因为 `foo` 不匹配 `\w+/...`，不会进入校验集合。

建议：

- 简单可行：解析 `tags: [...]` 中所有字符串，然后逐个检查。
- 更稳：用 Python 轻量 YAML parser，或写一个明确的受限 YAML tag parser。
- 对 notes 至少要求包含：
  - `domain/建造师`
  - `subject/建造师.机电实务`

---

## 中等问题

### P2 — `compress-images.sh` 可能破坏 Markdown 图片链接

证据：

- `scripts/compress-images.sh:66-75` PNG 超过 300KB 时转成 JPG
- `scripts/compress-images.sh:72` 删除原 PNG
- `scripts/compress-images.sh:83` 仍按原 `$f` 统计大小，此时文件可能已不存在

风险：

- 原本引用 `attachments/x.png` 的笔记会失效
- 透明 PNG 会丢透明度
- 输出日志显示的压缩后大小可能是 0KB

建议：

- 不自动改扩展名；优先保持 PNG。
- 如确需转 JPG，应同步改引用或只输出建议，不删除原文件。
- ImageMagick v7 场景下，`scripts/compress-images.sh:24` 不应强制 `command -v identify`，因为可能只有 `magick identify`。

---

### P2 — quiz GUID 不符合 SPEC/PLAN 的 `quiz::slug::n`

证据：

- SPEC `.trellis/SPEC.md:182`
- PLAN `.trellis/PLAN.md:40`
- 实现 `scripts/anki-export.sh:142-144` 使用 `h(f"quiz::{stem}")`

当前实现没有 `n`，也没有读取 quiz frontmatter slug。虽然“一文件一题”暂时能跑，但和规格不一致，后续多题或重命名会出问题。

建议：

- quiz frontmatter 增加或派生稳定 slug。
- 按 `quiz::{slug}::{n}` 生成 guid。
- 如果坚持一文件一题，也应更新 SPEC/PLAN，避免规格漂移。

---

### P2 — dashboard 与 SPEC §9 不完全一致

证据：

- SPEC `.trellis/SPEC.md:321-328` 要每个 domain 有 core 未掌握、高频未掌握、该复盘、孤立点、错题
- `dashboard.md:57-71` 的 §C 建造师只有 core 未掌握和 7 天复盘
- `dashboard.md:105-127` 的 §F/§G 用 `FROM "notes"`，而 SPEC `.trellis/SPEC.md:327` 写“所有 Dataview 查询用 `FROM #domain/xxx` 起手”

建议：

- 给 §C 补：
  - 高频未掌握
  - 孤立点
  - 错题
- 若总览类查询允许 `FROM "notes"`，应修 SPEC 文字，避免自相矛盾。
- MVP 验收只要求 §A/§C/§F/§G/§H 渲染，但“全项目一致性”建议补齐。

---

### P2 — `study-review` 的“近 N 天”命令实际上没有按 N 天过滤

证据：

- `skills/study-review/SKILL.md:21-25`
- 命令是 `rg -A999 "^# " journal/`

这会读取所有 journal，而不是近 7/30 天。复盘统计会被历史数据污染。

建议：

- 按文件名 `journal/YYYY-MM-DD.md` 过滤日期范围。
- 排除 `*-review.md`。
- 再统计 bullet 行。

---

### P2 — 示例 note 不符合自身 skill 约束

证据：

- `notes/建造师/机电实务/电缆敷设.md:35` `## 自测一题` 为空
- `skills/study-outline/SKILL.md` 要求每篇自测题非空
- `notes/建造师/机电实务/电缆敷设.md:18` source 指向 `materials/建造师/机电实务/2024/教材.md:p123`，仓库中没有对应材料文件

建议：

- mock note 明确标注为 mock，或补一个最小 mock material。
- 补全自测题，避免新用户照样例生成不合格 note。

---

## 低优先级 / repo hygiene

- 缺少 `requirements.txt` 或安装说明。`genanki`、MinerU、PaddleOCR、sqlite3、ImageMagick、ripgrep 都是实际依赖。
- `.gitignore` 建议加入：
  - `.pi-subagents/`
  - `review.csv`
  - `mock-exam-*.md`
  - `materials/.ocr-tmp-*`
- `scripts/prep.sh:13` 用日期作为临时目录，多个同日并发运行会冲突；建议 `mktemp -d`。
- `scripts/prep.sh:45` PaddleOCR 分支使用 `python`，没有复用 `.venv/bin/python` / `python3` 选择逻辑。

---

## 总体结论

项目结构清晰，SPEC/PLAN/skills/templates 的闭环设计很完整；`make taxonomy` 和 `make anki` 当前样例能跑通。但核心风险集中在两条链路：

1. **材料入库链路**：`make prep` 当前与 README 不一致，并且路径/PDF 保存有严重问题。
2. **Anki 回写链路**：一篇 note 多张 descriptor 卡时，sync 的 note 级状态会被 card 级处理覆盖，可能错误隐藏 drift。

建议优先修 P0/P1：`prep.sh + Makefile`、`anki-sync.sh` 聚合写回、journal lock 片段、source/rubric deterministic validation、taxonomy parser。
