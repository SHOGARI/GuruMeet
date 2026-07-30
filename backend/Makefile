COMPOSE = docker compose --env-file .env -f compose.yaml

.PHONY: check-env dev logs down reset-db migrate db-shell cleanup-temporary-groups

check-env:
	cd .. && python3 scripts/check_local_env.py --scope backend

dev: check-env
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f api

down:
	$(COMPOSE) down

reset-db: check-env
	$(COMPOSE) down -v
	$(COMPOSE) up -d --build

migrate:
	$(COMPOSE) run --rm api alembic upgrade head

db-shell:
	$(COMPOSE) exec db psql -U $${POSTGRES_USER} -d $${POSTGRES_DB}

cleanup-temporary-groups:
	$(COMPOSE) run --rm api python -m app.tasks.cleanup_temporary_groups
