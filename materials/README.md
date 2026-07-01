# materials/

原始资料落库处。按 `materials/<domain>/<subject>/<year>/` 年度子目录版本化（SPEC §6.4）。PDF 原件与 OCR 后的 md 并存于同一年度目录：

```
materials/
└── 建造师/机电实务/2024/
    ├── 教材.pdf          # PDF 原件，PDF++ 划线驱动走此（§3.7）
    ├── 教材.md           # minerU OCR 产物，study-outline 整章梳理走此
    ├── 考试大纲.md
    └── 往年真题.md
```

`source:` 字段在 `notes/*.md` 里引用这里的文件名 + 页码/章节，可回链 pdf 或 md：
- `materials/建造师/机电实务/2024/教材.md:p123`（OCR md）
- `materials/建造师/机电实务/2024/教材.pdf:p123`（PDF 原件，划线回流）
