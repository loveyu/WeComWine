SHELL := /bin/bash

PROJECT := wecom-wine-flatpak
VERSION := $(shell tr -d '[:space:]' < VERSION)
DIST_DIR ?= dist
SOURCE_DATE_EPOCH ?= 0
ARCHIVE := $(DIST_DIR)/$(PROJECT)-$(VERSION).tar.gz

.PHONY: all check install-user flatpak-bundles dist clean

all: check

check:
	@bash -n scripts/*.sh
	@bash -n scripts/install-release.sh.in
	@test "$$(find patches/wine-portal -maxdepth 1 -type f -name '*.patch' | wc -l)" -eq 16
	@if find . -path './.git' -prune -o -type f \
		\( -iname '*.exe' -o -iname '*.msi' -o -iname '*.dll' -o -iname '*.bundle' -o -iname '*.flatpak' \) \
		-print -quit | grep -q .; then \
		echo '错误：仓库中不能包含安装包或二进制发行制品' >&2; exit 1; \
	fi
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then git diff --check; fi

install-user: check
	@./scripts/install-user.sh

flatpak-bundles: check
	@./scripts/package-flatpaks.sh

dist: check
	@mkdir -p "$(DIST_DIR)"
	@set -o pipefail; tar \
		--exclude='./.git' \
		--exclude='./dist' \
		--exclude='./artifacts' \
		--exclude='./logs' \
		--sort=name \
		--mtime="@$(SOURCE_DATE_EPOCH)" \
		--owner=0 --group=0 --numeric-owner \
		--transform="s,^\.$$,$(PROJECT)-$(VERSION)," \
		--transform="s,^\./,$(PROJECT)-$(VERSION)/," \
		-cf - . | gzip -n > "$(ARCHIVE)"
	@sha256sum "$(ARCHIVE)" > "$(ARCHIVE).sha256"
	@printf '已生成 %s\n' "$(ARCHIVE)"

clean:
	@find "$(DIST_DIR)" -maxdepth 1 -type f \
		\( -name '$(PROJECT)-*.tar.gz' -o -name '$(PROJECT)-*.tar.gz.sha256' \) \
		-delete 2>/dev/null || true
