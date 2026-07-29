SHELL := /bin/bash

-include .env
export

FRONTEND_PORT ?= 3000
GURUMEET_API_BASE_URL ?= http://localhost:8000
GURUMEET_INVITE_BASE_URL ?= http://localhost:3000
GURUMEET_ENABLE_MOCKS ?= true
DART_DEFINES = \
	--dart-define=GURUMEET_ENABLE_MOCKS=$(GURUMEET_ENABLE_MOCKS) \
	--dart-define=GURUMEET_API_BASE_URL=$(GURUMEET_API_BASE_URL) \
	--dart-define=GURUMEET_INVITE_BASE_URL=$(GURUMEET_INVITE_BASE_URL)

.PHONY: help
help:
	@printf "%s\n" "frontend 開発コマンド"
	@printf "%s\n" ""
	@printf "%s\n" "初期設定:"
	@printf "%s\n" "  make install      Flutter の依存関係を取得"
	@printf "%s\n" ""
	@printf "%s\n" "ローカル起動:"
	@printf "%s\n" "  make check-env    .env と dart-define 用の値を確認"
	@printf "%s\n" "  make dev          .env を dart-define に渡して web-server を起動"
	@printf "%s\n" "  make dev-chrome   .env を dart-define に渡して Chrome を起動"
	@printf "%s\n" ""
	@printf "%s\n" "品質確認:"
	@printf "%s\n" "  make format       Dart format を実行"
	@printf "%s\n" "  make analyze      Flutter analyze を実行"
	@printf "%s\n" "  make test         Flutter test を実行"

.PHONY: install
install:
	flutter pub get

.PHONY: check-env
check-env:
	cd .. && python3 scripts/check_local_env.py --scope frontend

.PHONY: dev
dev: check-env
	flutter run -d web-server --web-hostname 0.0.0.0 --web-port $(FRONTEND_PORT) $(DART_DEFINES)

.PHONY: dev-chrome
dev-chrome: check-env
	flutter run -d chrome --web-port $(FRONTEND_PORT) $(DART_DEFINES)

.PHONY: format
format:
	flutter format .

.PHONY: analyze
analyze:
	flutter analyze

.PHONY: test
test:
	flutter test
