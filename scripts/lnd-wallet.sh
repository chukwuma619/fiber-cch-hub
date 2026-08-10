#!/usr/bin/env bash
# LND wallet: create (first time) or unlock + sync creds for CCH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-sync}"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

PASSWORD="${LND_WALLET_PASSWORD:-change-me}"
NETWORK=testnet
MAC="data/lnd/data/chain/bitcoin/testnet/admin.macaroon"
CERT="data/lnd/tls.cert"

if [[ -d data/lnd/data/chain/bitcoin/regtest ]]; then
  echo "FAIL found regtest LND data in data/lnd."
  echo "Remove data/lnd, then run: make lnd-wallet"
  exit 1
fi

mkdir -p data/lnd

lncli() {
  docker exec fiber-cch-hub-lnd lncli \
    --network="$NETWORK" \
    --lnddir=/root/.lnd \
    --rpcserver=localhost:10009 \
    "$@"
}

wait_tls() {
  local i
  for i in $(seq 1 90); do
    if docker exec fiber-cch-hub-lnd test -f /root/.lnd/tls.cert 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "FAIL lnd: tls.cert not ready"
  docker logs --tail=40 fiber-cch-hub-lnd || true
  return 1
}

sync_cch_creds() {
  if [[ ! -f "$MAC" || ! -f "$CERT" ]]; then
    echo "FAIL missing LND creds at $CERT / $MAC"
    find data/lnd -type f 2>/dev/null | head -20
    exit 1
  fi
  mkdir -p data/cch/lnd
  cp "$CERT" data/cch/lnd/tls.cert
  cp "$MAC" data/cch/lnd/admin.macaroon
  chmod 644 data/cch/lnd/tls.cert data/cch/lnd/admin.macaroon
}

echo "Starting Bitcoin testnet LND (Neutrino)..."
docker compose up -d --remove-orphans lnd
wait_tls

if lncli getinfo >/dev/null 2>&1; then
  echo "OK   LND wallet ready"
  lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
  sync_cch_creds
  echo "LND creds synced to data/cch/lnd/"
  exit 0
fi

if printf '%s\n' "$PASSWORD" | lncli unlock --stdin >/dev/null 2>&1; then
  sleep 2
  if lncli getinfo >/dev/null 2>&1; then
    echo "OK   LND unlocked"
    lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
    sync_cch_creds
    echo "LND creds synced to data/cch/lnd/"
    exit 0
  fi
fi

if [[ "$MODE" != "create" ]]; then
  echo "FAIL LND wallet not found or wrong password."
  echo "First time? Run: make create-keys"
  echo "Guide: docs/SELF_HOSTING.md"
  exit 1
fi

echo ""
echo "=========================================="
echo " Creating a NEW Lightning wallet"
echo " WRITE DOWN the 24-word seed when shown!"
echo "=========================================="
echo ""

if ! printf '%s\n%s\nn\n' "$PASSWORD" "$PASSWORD" | lncli create 2>&1 | tee /tmp/lnd-create.log; then
  cat /tmp/lnd-create.log || true
fi

for i in $(seq 1 60); do
  if lncli getinfo >/dev/null 2>&1; then
    echo ""
    echo "OK   LND wallet created"
    lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
    sync_cch_creds
    echo ""
    echo "Save your seed phrase from the output above."
    echo "Next: ./start.sh  (or make up)"
    exit 0
  fi
  printf '%s\n' "$PASSWORD" | lncli unlock --stdin >/dev/null 2>&1 || true
  sleep 2
done

echo "FAIL LND wallet creation timed out"
docker logs --tail=60 fiber-cch-hub-lnd || true
exit 1
