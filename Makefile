.PHONY: prep outline quiz case tikz drill dashboard anki taxonomy sync review help

FILE ?=
SUBJECT ?=
TOPIC ?=

help:
	@echo "make prep FILE=课件.pdf              OCR + 归档"
	@echo "make outline SUBJECT=科目            大纲梳理 skill"
	@echo "make quiz TOPIC=知识点               单点出题 skill"
	@echo "make case SUBJECT=科目               综合题/案例 skill"
	@echo "make tikz \"电路描述\"                画电路图 skill"
	@echo "make drill                           今日复习计划"
	@echo "make dashboard                       打开仪表盘"
	@echo "make anki                            导出 Anki 包（Descriptors + quiz）"
	@echo "make taxonomy                        校验 notes tags 受控词汇"
	@echo "make sync                            对账 Anki drift（study-sync）"
	@echo "make review                          周/月复盘（study-review）"

prep:
	@test -n "$(FILE)" || { echo "FILE= required"; exit 1; }
	bash scripts/prep.sh "$(FILE)"

outline:
	@test -n "$(SUBJECT)" || { echo "SUBJECT= required"; exit 1; }
	@echo "→ 在 pi 中: /skill study-outline $(SUBJECT)"

quiz:
	@test -n "$(TOPIC)" || { echo "TOPIC= required"; exit 1; }
	@echo "→ 在 pi 中: /skill study-quiz \"$(TOPIC)\""

case:
	@test -n "$(SUBJECT)" || { echo "SUBJECT= required"; exit 1; }
	@echo "→ 在 pi 中: /skill study-case $(SUBJECT)"

tikz:
	@echo "→ 在 pi 中: /skill study-tikz \"$(MAKECMDGOALS)\""

drill:
	@echo "→ 在 pi 中: /skill study-drill"

dashboard:
	@open dashboard.md || xdg-open dashboard.md

anki:
	bash scripts/anki-export.sh

taxonomy:
	bash scripts/taxonomy-check.sh

sync:
	@echo "→ 在 pi 中: /skill study-sync（列出 drift/未导出项，提示跑 anki-sync）"
	@echo "  手动拉复习数据:"
	@echo "    sqlite3 -csv -header ~/Anki/collection.anki2 < scripts/anki-sync-export.sql > review.csv"
	@echo "    bash scripts/anki-sync.sh review.csv"

review:
	@echo "→ 在 pi 中: /skill study-review 周 7"
