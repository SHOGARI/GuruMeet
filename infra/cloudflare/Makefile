SHELL := /bin/bash

APP_WORKER_DIR := app-worker
FRONTEND_DIR := ../../frontend

.PHONY: help
help:
	@printf "%s\n" "Cloudflare 運用コマンド"
	@printf "%s\n" ""
	@printf "%s\n" "初期設定:"
	@printf "%s\n" "  make install              Worker の依存 package を install"
	@printf "%s\n" "  make whoami               現在の Wrangler login / account を表示"
	@printf "%s\n" ""
	@printf "%s\n" "事前確認:"
	@printf "%s\n" "  make build-frontend-staging       staging 用 Flutter Web assets を build"
	@printf "%s\n" "  make build-frontend-production    production 用 Flutter Web assets を build"
	@printf "%s\n" "  make check                Worker の型チェック"
	@printf "%s\n" ""
	@printf "%s\n" "デプロイ:"
	@printf "%s\n" "  GitHub Actions の Cloudflare デプロイ workflow から実行"
	@printf "%s\n" ""
	@printf "%s\n" "ローカル開発:"
	@printf "%s\n" "  make dev-staging          staging 設定で wrangler dev を起動"
	@printf "%s\n" ""
	@printf "%s\n" "リソース:"
	@printf "%s\n" "  make r2-list              R2 bucket 一覧を表示"
	@printf "%s\n" ""
	@printf "%s\n" "ログ:"
	@printf "%s\n" "  make tail-staging         staging Worker のログを追う"
	@printf "%s\n" "  make tail-production      production Worker のログを追う"

.PHONY: install
install:
	cd $(APP_WORKER_DIR) && npm install

.PHONY: whoami
whoami:
	cd $(APP_WORKER_DIR) && npx wrangler whoami

.PHONY: build-frontend-staging
build-frontend-staging:
	cd $(FRONTEND_DIR) && flutter build web --release \
		--dart-define=GURUMEET_ENABLE_MOCKS=false \
		--dart-define=GURUMEET_API_BASE_URL=https://stg.gurumeet.net/api \
		--dart-define=GURUMEET_INVITE_BASE_URL=https://stg.gurumeet.net

.PHONY: build-frontend-production
build-frontend-production:
	cd $(FRONTEND_DIR) && flutter build web --release \
		--dart-define=GURUMEET_ENABLE_MOCKS=false \
		--dart-define=GURUMEET_API_BASE_URL=https://gurumeet.net/api \
		--dart-define=GURUMEET_INVITE_BASE_URL=https://gurumeet.net

.PHONY: check
check:
	cd $(APP_WORKER_DIR) && npm run check

.PHONY: deploy-staging
deploy-staging:
	@printf "%s\n" "GitHub Environment secrets / vars を使うため、deploy は GitHub Actions から実行する。"
	@exit 1

.PHONY: deploy-production
deploy-production:
	@printf "%s\n" "GitHub Environment secrets / vars を使うため、deploy は GitHub Actions から実行する。"
	@exit 1

.PHONY: dev-staging
dev-staging:
	cd $(APP_WORKER_DIR) && npm run dev:staging

.PHONY: r2-list
r2-list:
	cd $(APP_WORKER_DIR) && npx wrangler r2 bucket list

.PHONY: secret-staging
secret-staging:
	@printf "%s\n" "Cloudflare secret の手動登録は通常運用では使わない。"
	@printf "%s\n" "GitHub Environment secrets / vars に登録し、deploy workflow から渡す。"
	@exit 1

.PHONY: secret-production
secret-production:
	@printf "%s\n" "Cloudflare secret の手動登録は通常運用では使わない。"
	@printf "%s\n" "GitHub Environment secrets / vars に登録し、deploy workflow から渡す。"
	@exit 1

.PHONY: tail-staging
tail-staging:
	cd $(APP_WORKER_DIR) && npx wrangler tail gurumeet-staging

.PHONY: tail-production
tail-production:
	cd $(APP_WORKER_DIR) && npx wrangler tail gurumeet
