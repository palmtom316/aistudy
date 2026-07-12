# aistudy

把"ChatGPT + Obsidian 突击复习"工作流系统化的一套学习操作系统。

## 架构（三层各归各位）

```
vault (仓库根 = Obsidian vault)
├── materials/   原始资料（OCR 后的 md）
├── notes/       知识点原子笔记（一个知识点一文件，含 ## Descriptors → Anki 卡源）
├── quiz/        单点题（descriptor 级）
├── cases/       综合题/案例
├── highlights/  PDF 划线缓冲（PDF++ 划线 → study-extract → notes）
├── journal/     复习日志（skill append）
├── dashboard.md Dataview 诊断仪表盘
├── templates/   note / quiz / case / journal / descriptors / structural
├── skills/      LLM 侧行为 SOP（outline / extract / quiz / case / drill / sync / review）
├── scripts/     确定性运维脚本（OCR / Anki 导出&同步 / 校验 / 压缩）
└── docs/        项目文档（SPEC / PLAN / 审查 / 评审）
```

判据：**确定性操作走脚本，判断与表达走 skill，阅读与答题坐 Obsidian。**

## 快速开始

```bash
make prep FILE=课件.pdf SUBJECT=建造师.机电实务   # OCR + 归档到 materials/建造师/机电实务/<year>/
# 若已有 OCR 后的 markdown：make prep FILE=课件.md SUBJECT=建造师.机电实务
make outline SUBJECT=建造师.机电实务   # 跑 study-outline skill → notes/
# 读 PDF 时用 PDF++ 划线 → 粘到 highlights/<书名>.md → 跑：
# study-extract highlights/教材.md     # 划线聚类 → note 草稿（人审后落库）
make quiz TOPIC="电缆敷设"       # 单点题
make case SUBJECT=建造师.机电实务  # 综合题/案例
make drill                    # 读 dashboard 清单 → 今日复习计划
make anki                     # 导出 Descriptors + quiz → Anki 包
make check                    # taxonomy + source/descriptor 信任链校验
make smoke                    # 本地回归（prep 路径 / export / multi-card sync）
make taxonomy                 # 仅校验 tags 受控词汇
make sync                     # 提示对账 Anki drift（study-sync）
make review                   # 周/月复盘
```

MVP 单域：一级建造师·机电实务。法律见 [`docs/SPEC.md`](docs/SPEC.md)，施工图见 [`docs/PLAN.md`](docs/PLAN.md)。更多文档索引见 [`docs/README.md`](docs/README.md)。

学习时打开 Obsidian 指向本仓库根目录，`dashboard.md` 是入口。

## 字段约定

笔记 frontmatter（核心字段）：

| 字段 | 取值 | 用途 |
|---|---|---|
| `core` | true/false | 大纲核心点 |
| `difficulty` | 1-5 | 自评难度 |
| `mastery` | 0-3 | 0未学 / 1看过 / 2能做题 / 3能讲清楚 |
| `exam_freq` | int | 往年真题出现次数 |
| `last_reviewed` | date | 间隔触发用 |
| `related` | [[wikilink]] | 知识图谱边 |

诊断层靠这四个状态字段；没有它们，dashboard 查不出来东西。

## 不要做的事

- 不要自建 web 前端——Obsidian 已经是前端。
- 不要把 OCR / Anki 导出塞进 skill——脚本更快更稳。
- 不要让 LLM 随手加 tag——taxonomy 在 templates/ 里定死。
- 不要在画图 prompt 里写"画图"二字——会触发图片生成。
