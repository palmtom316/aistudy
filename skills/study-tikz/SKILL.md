---
name: study-tikz
description: 用 circuitikz/tikz 在 Obsidian 中绘制电路图与数据图表，经 TikZJax 插件渲染。禁图片生成、禁"画图"字眼、强制 LaTeX 直出。
user-invocable: true
argument-hint: "[电路/图描述]"
---

# study-tikz

输出可直接粘进 Obsidian（TikZJax 插件）的 circuitikz / tikz 代码块。

## 强制约束

1. **用语禁忌**：回复里不许出现"画图"、"绘制图片"、"生成图"等可能触发图片生成的字眼。描述动作用"写 tikz 代码"、"给出 circuitikz 源码"。
2. **独立答疑**：本 skill 不掺和其他任务，专注一段 tikz 源码。
3. **格式固定**：必须以 ```` ```latex ```` 代码块包裹，开头 `\usepackage{circuitikz}` 或 `\usepackage{tikz}`，包 `\begin{document}...\end{document}`，正文 `\begin{circuitikz}...\end{circuitikz}` 或 `\begin{tikzpicture}...\end{tikzpicture}`。
4. ** american voltages 默认**：电路图统一 `[american voltages]`，除非用户指定欧式。
5. **节点标号**：晶体管、电源、关键节点必须有 label，便于笔记里引用 `$M_1$`、`$V_{DD}$`。
6. **复杂度上限**：单段代码 ≤ 50 行。超了建议拆成两段，先拆再写。
7. **不答公式题**：用户问公式/计算时拒绝，让用户改用 study-quiz。

## 失败处理

TikZJax 对复杂电路容易渲染失败。若用户反馈渲染挂了：
- 优先简化（去掉 decorative 标注、减少嵌套）
- 拆成两张子图
- 不建议改用 png 截图，违背"矢量、可编辑、进版本控制"的初衷

## 输出后

提示用户：把代码块直接放进对应 `notes/<topic>.md` 的 `## 关键公式 / 电路` 区块。
