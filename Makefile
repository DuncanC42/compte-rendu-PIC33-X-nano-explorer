# =============================================================
#  Makefile — Raccourcis de build
#  Usage : make html | make pdf | make all | make open
# =============================================================

.PHONY: html pdf all open clean watch tp

# Un PDF par TP (fichier de content/).
#   make tp               -> tous les TP
#   make tp FILE=03-gpio  -> un seul TP (nom du fichier sans .md)
tp:
	bash scripts/build.sh split $(FILE)

html:
	bash scripts/build.sh html

pdf:
	bash scripts/build.sh pdf

all:
	bash scripts/build.sh all

open:
	bash scripts/build.sh html --open

clean:
	rm -f output/*.html output/*.pdf

watch:
	@echo "Surveillance des fichiers (requires 'entr')..."
	find content partials config assets -type f | entr -r bash scripts/build.sh html --open