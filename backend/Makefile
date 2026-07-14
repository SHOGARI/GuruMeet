COMPOSE = docker compose --env-file .env -f compose.yaml

.PHONY: dev logs down migrate db-shell

dev:
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f api

down:
	$(COMPOSE) down

migrate:
	$(COMPOSE) run --rm api alembic upgrade head

db-shell:
	$(COMPOSE) exec db psql -U $${POSTGRES_USER} -d $${POSTGRES_DB}
