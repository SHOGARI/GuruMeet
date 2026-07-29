SHELL := /bin/bash

.PHONY: check-env
check-env:
	python3 scripts/check_local_env.py

.PHONY: check-env-backend
check-env-backend:
	python3 scripts/check_local_env.py --scope backend

.PHONY: check-env-frontend
check-env-frontend:
	python3 scripts/check_local_env.py --scope frontend
