# aistudy

把"ChatGPT + Obsidian 突击复习"工作流系统化的一套学习操作系统。

## 架构（三层各归各位）

```
vault (仓库根 = Obsidian vault)
├── materials/   原始资料（OCR 后的 md）
├── notes/       知识点原子笔记（一个知识点一文件）
├── quiz/        题目原子（回链知识点）
├── prompts/     prompt 库
├── dashboard.md Dataview 诊断仪表盘
├── templates/   笔记 / quiz / dashboard 模板
├── skills/      LLM 侧行为 SOP（outline / quiz / tikz / drill）
└── scripts/     确定性运维脚本（OCR / 导出 / 调度）
```

判据：**确定性操作走脚本，判断与表达走 skill，阅读与答题坐 Obsidian。**

## 快速开始

```bash
make prep FILE=课件.pdf        # OCR + 归档到 materials/
make outline SUBJECT=数字集成电路设计   # 跑 study-outline skill
make quiz TOPIC="VTC曲线与五个偏置区域"
make tikz "CMOS反相器"
make drill                    # 读 dashboard 清单 → 今日复习计划
make anki                     # 导出 quiz/ 到 Anki 包
```

学习时打开 Obsidian 指向本仓库根目录，dashboard.md 是入口。

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
