COMPOSE = docker compose -f docker/compose.yaml

.PHONY: dev logs down

dev:
	$(COMPOSE) up -d --build

logs:
	$(COMPOSE) logs -f api

down:
	$(COMPOSE) down
