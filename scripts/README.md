# scripts/

确定性运维脚本。**这些不该塞进 skill**——脚本快、稳、零成本。

| 脚本 | 作用 | 依赖 |
|---|---|---|
| `prep.sh` | PDF/PPT → OCR → 归档到 `materials/<subject>/` | MinerU（推荐）或 PaddleOCR |
| `anki-export.sh` | `quiz/*.md` → `aistudy.apkg` | `pip install genanki` |

## 判据

- 输入确定、输出确定 → 脚本。
- 需要判断/表达/收敛 LLM 行为 → skill（见 `skills/`）。
