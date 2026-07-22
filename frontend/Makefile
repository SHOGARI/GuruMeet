SHELL := /bin/bash

-include .env
export

FRONTEND_PORT ?= 3000

.PHONY: help
help:
	@printf "%s\n" "frontend 開発コマンド"
	@printf "%s\n" ""
	@printf "%s\n" "初期設定:"
	@printf "%s\n" "  make install      Flutter の依存関係を取得"
	@printf "%s\n" ""
	@printf "%s\n" "ローカル起動:"
	@printf "%s\n" "  make dev          web-server を FRONTEND_PORT で起動"
	@printf "%s\n" "  make dev-chrome   Chrome を FRONTEND_PORT で起動"
	@printf "%s\n" ""
	@printf "%s\n" "品質確認:"
	@printf "%s\n" "  make format       Dart format を実行"
	@printf "%s\n" "  make analyze      Flutter analyze を実行"
	@printf "%s\n" "  make test         Flutter test を実行"

.PHONY: install
install:
	flutter pub get

.PHONY: dev
dev:
	flutter run -d web-server --web-hostname 0.0.0.0 --web-port $(FRONTEND_PORT)

.PHONY: dev-chrome
dev-chrome:
	flutter run -d chrome --web-port $(FRONTEND_PORT)

.PHONY: format
format:
	flutter format .

.PHONY: analyze
analyze:
	flutter analyze

.PHONY: test
test:
	flutter test
