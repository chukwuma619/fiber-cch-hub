.PHONY: doctor bootstrap pull up down logs ps smoke-stage1 stage1 help

help:
	@echo "Fiber CCH Hub (Docker fnn)"
	@echo ""
	@echo "  make doctor        Stage 0 — check Docker + pull pinned image"
	@echo "  make bootstrap     Create .env, data dirs, testnet CKB key"
	@echo "  make pull          Pull nervos/fiber image"
	@echo "  make up            Start Fiber + standalone CCH"
	@echo "  make smoke-stage1  Stage 1 exit gate"
	@echo "  make stage1        bootstrap + up + smoke-stage1"
	@echo "  make logs          Tail compose logs"
	@echo "  make down          Stop stack"

doctor:
	./scripts/doctor.sh

bootstrap:
	./scripts/bootstrap.sh

pull:
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	docker pull "$${FIBER_IMAGE:-nervos/fiber:v0.9.0}"

up: bootstrap
	docker compose up -d
	@echo "Fiber RPC: http://127.0.0.1:$${FIBER_RPC_PORT:-8227}"
	@echo "CCH RPC:   http://127.0.0.1:$${CCH_RPC_PORT:-8327}"

down:
	docker compose down

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

smoke-stage1:
	./scripts/smoke-stage1.sh

stage1: doctor up smoke-stage1
