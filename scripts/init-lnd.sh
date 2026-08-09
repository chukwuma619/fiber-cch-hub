#!/usr/bin/env bash
# Create the hub LND wallet (Bitcoin regtest) and sync creds into data/cch/lnd/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

PASSWORD="${LND_WALLET_PASSWORD:-change-me-lnd}"
NETWORK=regtest

mkdir -p data/lnd data/bitcoind

btccli() {
  docker exec fiber-cch-hub-bitcoind bitcoin-cli \
    -regtest \
    -rpcuser=fiber \
    -rpcpassword=fiber \
    "$@"
}

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

ensure_wallet() {
  echo "Waiting for LND TLS..."
  wait_tls

  if lncli getinfo >/dev/null 2>&1; then
    echo "OK   LND wallet ready"
    lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
    return 0
  fi

  if printf '%s\n' "$PASSWORD" | lncli unlock --stdin >/tmp/lnd-unlock.out 2>&1; then
    sleep 2
    if lncli getinfo >/dev/null 2>&1; then
      echo "OK   LND unlocked"
      return 0
    fi
  fi

  echo "Creating LND wallet..."
  if ! printf '%s\n%s\nn\n' "$PASSWORD" "$PASSWORD" | lncli create >/tmp/lnd-create.out 2>&1; then
    echo "INFO create output:"
    cat /tmp/lnd-create.out || true
  fi

  local i
  for i in $(seq 1 60); do
    if lncli getinfo >/dev/null 2>&1; then
      echo "OK   LND getinfo"
      lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
      return 0
    fi
    printf '%s\n' "$PASSWORD" | lncli unlock --stdin >/dev/null 2>&1 || true
    sleep 2
  done

  echo "FAIL LND: getinfo timed out"
  docker logs --tail=60 fiber-cch-hub-lnd || true
  return 1
}

echo "Starting bitcoind + LND..."
docker compose up -d bitcoind
for i in $(seq 1 60); do
  if docker compose ps bitcoind 2>/dev/null | grep -q healthy; then
    break
  fi
  sleep 2
done

if ! btccli getwalletinfo >/dev/null 2>&1; then
  btccli createwallet "cch" >/dev/null || btccli loadwallet "cch" >/dev/null || true
fi
HEIGHT=$(btccli getblockcount)
if [[ "$HEIGHT" -lt 101 ]]; then
  echo "Mining 101 regtest blocks..."
  ADDR=$(btccli getnewaddress)
  btccli generatetoaddress $((101 - HEIGHT)) "$ADDR" >/dev/null
fi
echo "bitcoind height=$(btccli getblockcount)"

docker compose up -d lnd
ensure_wallet

ADDR=$(btccli getnewaddress)
btccli generatetoaddress 6 "$ADDR" >/dev/null
sleep 2

MAC=data/lnd/data/chain/bitcoin/regtest/admin.macaroon
CERT=data/lnd/tls.cert
if [[ ! -f "$MAC" || ! -f "$CERT" ]]; then
  echo "FAIL missing LND creds at $CERT / $MAC"
  find data/lnd -type f | head -40
  exit 1
fi

mkdir -p data/cch/lnd
cp "$CERT" data/cch/lnd/tls.cert
cp "$MAC" data/cch/lnd/admin.macaroon
chmod 644 data/cch/lnd/tls.cert data/cch/lnd/admin.macaroon

echo "LND init complete (creds synced to data/cch/lnd/)."
