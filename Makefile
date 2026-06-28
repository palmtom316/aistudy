.PHONY: prep outline quiz tikz drill dashboard anki help

FILE ?=
SUBJECT ?=
TOPIC ?=

help:
	@echo "make prep FILE=课件.pdf              OCR + 归档"
	@echo "make outline SUBJECT=科目            大纲梳理 skill"
	@echo "make quiz TOPIC=知识点               出题 skill"
	@echo "make tikz \"电路描述\"                画电路图 skill"
	@echo "make drill                           今日复习计划"
	@echo "make dashboard                       打开仪表盘"
	@echo "make anki                            导出 Anki 包"

prep:
	@test -n "$(FILE)" || { echo "FILE= required"; exit 1; }
	bash scripts/prep.sh "$(FILE)"

outline:
	@test -n "$(SUBJECT)" || { echo "SUBJECT= required"; exit 1; }
	@echo "→ 在 pi 中: /skill study-outline $(SUBJECT)"

quiz:
	@test -n "$(TOPIC)" || { echo "TOPIC= required"; exit 1; }
	@echo "→ 在 pi 中: /skill study-quiz \"$(TOPIC)\""

tikz:
	@echo "→ 在 pi 中: /skill study-tikz \"$(MAKECMDGOALS)\""

drill:
	@echo "→ 在 pi 中: /skill study-drill"

dashboard:
	@open dashboard.md || xdg-open dashboard.md

anki:
	bash scripts/anki-export.sh
