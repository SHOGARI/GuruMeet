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
	@printf "%s\n" "  make build-frontend       Flutter Web assets を build"
	@printf "%s\n" "  make check                Worker の型チェック"
	@printf "%s\n" "  make predeploy            frontend build と Worker 型チェック"
	@printf "%s\n" ""
	@printf "%s\n" "デプロイ:"
	@printf "%s\n" "  make deploy-staging       develop / staging の状態を stg.gurumeet.net へ deploy"
	@printf "%s\n" "  make deploy-production    main / production の状態を gurumeet.net へ deploy"
	@printf "%s\n" ""
	@printf "%s\n" "ローカル開発:"
	@printf "%s\n" "  make dev-staging          staging 設定で wrangler dev を起動"
	@printf "%s\n" ""
	@printf "%s\n" "リソース:"
	@printf "%s\n" "  make r2-list              R2 bucket 一覧を表示"
	@printf "%s\n" "  make secret-staging       staging 用 DATABASE_URL を登録"
	@printf "%s\n" "  make secret-production    production 用 DATABASE_URL を登録"
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
deploy-staging: build-frontend-staging check
	cd $(APP_WORKER_DIR) && npm run deploy:staging

.PHONY: deploy-production
deploy-production: build-frontend-production check
	cd $(APP_WORKER_DIR) && npm run deploy:production

.PHONY: dev-staging
dev-staging:
	cd $(APP_WORKER_DIR) && npm run dev:staging

.PHONY: r2-list
r2-list:
	cd $(APP_WORKER_DIR) && npx wrangler r2 bucket list

.PHONY: secret-staging
secret-staging:
	cd $(APP_WORKER_DIR) && npx wrangler secret put DATABASE_URL --env staging
	cd $(APP_WORKER_DIR) && npx wrangler secret put HOTPEPPER_API_KEY --env staging
	cd $(APP_WORKER_DIR) && npx wrangler secret put PARTICIPANT_TOKEN_HASH_SECRET --env staging
	cd $(APP_WORKER_DIR) && npx wrangler secret put INTERNAL_TASK_SECRET --env staging

.PHONY: secret-production
secret-production:
	cd $(APP_WORKER_DIR) && npx wrangler secret put DATABASE_URL --env production
	cd $(APP_WORKER_DIR) && npx wrangler secret put HOTPEPPER_API_KEY --env production
	cd $(APP_WORKER_DIR) && npx wrangler secret put PARTICIPANT_TOKEN_HASH_SECRET --env production
	cd $(APP_WORKER_DIR) && npx wrangler secret put INTERNAL_TASK_SECRET --env production

.PHONY: tail-staging
tail-staging:
	cd $(APP_WORKER_DIR) && npx wrangler tail gurumeet-staging

.PHONY: tail-production
tail-production:
	cd $(APP_WORKER_DIR) && npx wrangler tail gurumeet
