.PHONY: doctor bootstrap pull up down logs ps help

help:
	@echo "Fiber CCH Hub"
	@echo ""
	@echo "  make doctor     Check Docker / curl / jq + Fiber image"
	@echo "  make bootstrap  .env, data dirs, configs, CKB key"
	@echo "  make up         Start bitcoind + LND + Fiber + CCH"
	@echo "  make down       Stop stack"
	@echo "  make logs       Follow compose logs"
	@echo "  make ps         Show container status"
	@echo "  make pull       Pull Fiber + LND images"

doctor:
	./scripts/doctor.sh

bootstrap:
	./scripts/bootstrap.sh

pull:
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	docker pull "$${FIBER_IMAGE:-nervos/fiber:0.9.0}"; \
	docker pull "$${LND_IMAGE:-lightninglabs/lnd:v0.18.5-beta}"; \
	docker pull "$${BITCOIND_IMAGE:-bitcoin/bitcoin:29}"

# LND wallets/macaroons must exist before CCH bind-mounts them
up: bootstrap
	./scripts/init-lnd.sh
	docker compose up -d fiber
	@echo "Waiting for Fiber healthy..."
	@for i in $$(seq 1 60); do \
		docker compose ps fiber | grep -q healthy && break; \
		sleep 2; \
	done
	docker compose up -d cch
	@echo "Fiber RPC: http://127.0.0.1:$${FIBER_RPC_PORT:-8227}"
	@echo "CCH RPC:   http://127.0.0.1:$${CCH_RPC_PORT:-8327}"

down:
	docker compose down

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps
