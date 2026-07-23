COMPOSE = docker compose --env-file .env -f compose.yaml

.PHONY: dev logs down reset-db migrate db-shell cleanup-temporary-groups

dev:
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f api

down:
	$(COMPOSE) down

reset-db:
	$(COMPOSE) down -v
	$(COMPOSE) up -d --build

migrate:
	$(COMPOSE) run --rm api alembic upgrade head

db-shell:
	$(COMPOSE) exec db psql -U $${POSTGRES_USER} -d $${POSTGRES_DB}

cleanup-temporary-groups:
	$(COMPOSE) run --rm api python -m app.tasks.cleanup_temporary_groups
