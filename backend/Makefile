COMPOSE = docker-compose --env-file .env -f compose.yaml

.PHONY: dev logs down

dev:
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f api

down:
	$(COMPOSE) down
