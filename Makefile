.PHONY: doctor bootstrap preflight create-keys lnd-wallet pull up down logs ps help start

help:
	@echo "Fiber CCH Hub"
	@echo ""
	@echo "  First time?  docs/SELF_HOSTING.md"
	@echo ""
	@echo "  make doctor         Check Docker + Fiber image"
	@echo "  make create-keys    Create Fiber key + Lightning wallet (first time)"
	@echo "  make lnd-wallet     Create / unlock Lightning wallet only"
	@echo "  make up / ./start.sh   Start Fiber + LND + CCH"
	@echo "  make down           Stop stack"
	@echo "  make logs / ps"

doctor:
	./scripts/doctor.sh

bootstrap:
	./scripts/bootstrap.sh

preflight:
	./scripts/preflight.sh

create-keys:
	./scripts/create-keys.sh

lnd-wallet:
	./scripts/lnd-wallet.sh create

pull:
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; \
	docker pull "$${FIBER_IMAGE:-nervos/fiber:0.9.0}"; \
	docker pull "$${LND_IMAGE:-lightninglabs/lnd:v0.18.5-beta}"

start:
	./start.sh

up: start

down:
	docker compose down --remove-orphans

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps
