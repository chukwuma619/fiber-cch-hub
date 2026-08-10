#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./scripts/bootstrap.sh
./scripts/preflight.sh

if [[ ! -f data/lnd/data/chain/bitcoin/testnet/admin.macaroon ]]; then
  echo "Missing LND wallet — run: make create-keys"
  echo "Guide: docs/SELF_HOSTING.md"
  exit 1
fi

./scripts/lnd-wallet.sh sync

docker compose up -d --remove-orphans fiber
echo "Waiting for Fiber healthy..."
for i in $(seq 1 60); do
  if docker compose ps fiber 2>/dev/null | grep -q healthy; then
    break
  fi
  sleep 2
done

docker compose up -d --remove-orphans cch

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

echo "Fiber RPC: http://127.0.0.1:${FIBER_RPC_PORT:-8227}"
echo "CCH RPC:   http://127.0.0.1:${CCH_RPC_PORT:-8327}"
echo "Logs: docker compose logs -f"
