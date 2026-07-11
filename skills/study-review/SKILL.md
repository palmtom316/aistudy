---
name: study-review
description: 周/月复盘：读 journal N 天 + quiz/cases 的 correct 分布 + mastery 分布，生成总结文档并对薄弱点调用 study-quiz/case 出题。护栏——只读结构化字段，不读 note 正文。
user-invocable: true
argument-hint: "[周|月] [N天]"
---

# study-review

# implements SPEC §5.4, §3.6, §5.2, §5.3

周/月末触发，读近 N 天结构化数据，生成 `journal/<YYYY-MM-DD>-review.md`，并对薄弱点出题。

## 护栏（硬约束，不可绕过）

- **只读结构化字段**：mastery / last_reviewed / quiz&cases 的 correct / journal 行。**禁止读 note 正文自由文本**做总结依据——底层 note 有 bug 时表现为数据缺失，而非被总结成看似正确的结论（SPEC §5.4）。
- 所有统计来自 `rg` 结果，不靠模型记忆。

## 数据来源

1. **journal 近 N 天**（默认 7，月复盘 30）：
   只读 `journal/YYYY-MM-DD.md`（排除 `*-review.md`），按文件名日期过滤近 N 天：
   ```bash
   N=${N:-7}
   for f in journal/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
     [ -f "$f" ] || continue
     base=$(basename "$f" .md)
     # 近 N 天：用 date 比较；macOS date -j / GNU date -d 兼容由 agent 本地选择
     echo "$f"
   done | while read -r f; do rg -n "correct=false|\\| false" "$f" || true; done
   ```
   统计每 slug 的 correct=false 频次。**禁止** `rg -A999 "^# " journal/` 扫全历史。
2. **mastery 分布**：`rg "^mastery: [0-3]" notes/ -g '!README.md'` → 按 mastery 0/1/2/3 计数。
3. **correct 分布**：`rg "^correct: (true|false)" quiz/ cases/ -g '!README.md'` → 对/错计数。
4. **低掌握 core 项**：`rg -l "core: true" notes/ -g '!README.md' | xargs rg --files-without-match "mastery: [23]"` → core 但没掌握（注意：`rg -L` 是 `--follow` 不是 files-without-match，必须用 `--files-without-match`，见 SPEC §6.3）。

## 输出

生成 `journal/<YYYY-MM-DD>-review.md`（schema 见 §3.6）：

```
# <YYYY-MM-DD> 周/月复盘
## 进度概览
- 总 note 数 / mastery 分布（0:x 1:x 2:x 3:x）
- 近 N 天答题：对 x / 错 x
- core 未掌握：x 项
## 薄弱点（按 correct=false 频次 + mastery≤1 排序）
- <topic>  错 x 次  mastery=<n>
- ...
## 下周期建议
- 重点复练上述薄弱点
- ...
## 本轮出题清单
（见下方"出题"动作）
```

## 出题（对薄弱点）

1. 取薄弱点 top ≤5。
2. 逐个调用 `study-quiz` / `study-case` 出题：
   - mastery≤1 且 core → study-case 出综合题
   - mastery≤1 非core → study-quiz 出单点题
3. **source 强制校验仍生效**（§5.2）：出题环节走 study-quiz/case 既有约束，缺 source 则 abort，不入库。
4. 出的题 slug 列表填进 review 文档 `## 本轮出题清单`。
5. 错题经 §5.3 journal → `study-drill` 置顶复练，无需新机制。

## 不做的事

- 不读 note 正文做"这个知识点错因是…"的总结（只看 correct/mastery 数字）。
- 不自己升 mastery（升 mastery 只走 Anki sync 或人审）。
- 不跳过 source 校验出题。
