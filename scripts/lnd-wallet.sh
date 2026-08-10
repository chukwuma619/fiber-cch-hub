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
SEED_FILE="data/lnd/cipher-seed.txt"
WALLET_DB="data/lnd/data/chain/bitcoin/testnet/wallet.db"
LND_REST="https://172.30.0.30:8080"

if [[ -d data/lnd/data/chain/bitcoin/regtest ]]; then
  echo "FAIL found regtest LND data in data/lnd."
  echo "Remove data/lnd, then run: make create-keys"
  exit 1
fi

if [[ ${#PASSWORD} -lt 8 ]]; then
  echo "FAIL LND_WALLET_PASSWORD must be at least 8 characters."
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

lnd_rest() {
  local method=$1
  local path=$2
  local data=${3:-}
  if [[ -n "$data" ]]; then
    docker run --rm --network fiber-cch-hub curlimages/curl:8.11.1 \
      -sk -X "$method" "$LND_REST$path" \
      -H 'Content-Type: application/json' \
      -d "$data"
  else
    docker run --rm --network fiber-cch-hub curlimages/curl:8.11.1 \
      -sk -X "$method" "$LND_REST$path"
  fi
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

# Wait until getinfo works, unlock works, or GenSeed is available (fresh node).
wait_wallet_ready() {
  local i seed_json
  for i in $(seq 1 90); do
    if lncli getinfo >/dev/null 2>&1; then
      return 0
    fi
    if printf '%s\n' "$PASSWORD" | docker exec -i fiber-cch-hub-lnd lncli \
      --network="$NETWORK" --lnddir=/root/.lnd --rpcserver=localhost:10009 \
      unlock --stdin >/dev/null 2>&1; then
      sleep 1
      if lncli getinfo >/dev/null 2>&1; then
        return 0
      fi
    fi
    seed_json=$(lnd_rest GET /v1/genseed 2>/dev/null || true)
    if echo "$seed_json" | jq -e '.cipher_seed_mnemonic | type == "array"' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "FAIL LND did not become ready (getinfo / unlock / genseed)"
  docker logs --tail=40 fiber-cch-hub-lnd || true
  return 1
}

sync_cch_creds() {
  # Macaroon may appear slightly after unlock
  local i
  for i in $(seq 1 30); do
    if [[ -f "$MAC" && -f "$CERT" ]]; then
      break
    fi
    sleep 1
  done
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

warn_missing_seed() {
  echo ""
  echo "NOTE This LND wallet already exists and has no saved seed file."
  echo "LND cannot show an old seed again."
  echo "To create a NEW wallet and print a 24-word seed:"
  echo "  make down"
  echo "  rm -rf data/lnd"
  echo "  make create-keys"
  echo ""
}

finish_existing() {
  local label=$1
  echo "OK   $label"
  lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
  sync_cch_creds
  echo "LND creds synced to data/cch/lnd/"
  if [[ ! -f "$SEED_FILE" ]]; then
    warn_missing_seed
  else
    echo "Seed file present: $SEED_FILE"
  fi
  exit 0
}

print_seed() {
  local words=$1
  local count
  count=$(wc -w <<<"$words" | tr -d ' ')
  if [[ "$count" -ne 24 ]]; then
    echo "FAIL expected 24 seed words, got $count"
    return 1
  fi
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo " WRITE DOWN THESE 24 WORDS — shown only at wallet creation"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  local i=1
  # shellcheck disable=SC2086
  for w in $words; do
    printf "  %2d. %s\n" "$i" "$w"
    i=$((i + 1))
  done
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  printf '%s\n' "$words" >"$SEED_FILE"
  chmod 600 "$SEED_FILE"
  echo "Also saved to $SEED_FILE (mode 600)."
  echo "Back it up offline, then delete that file if you want."
  echo ""
}

create_wallet() {
  echo ""
  echo "=========================================="
  echo " Creating a NEW Lightning wallet"
  echo "=========================================="
  echo ""

  if [[ -f "$WALLET_DB" || -f "$MAC" ]]; then
    echo "FAIL LND wallet data already exists under data/lnd/."
    echo "Refusing to create a second wallet in place."
    warn_missing_seed
    exit 1
  fi

  wait_wallet_ready

  if lncli getinfo >/dev/null 2>&1; then
    finish_existing "LND wallet ready (already initialized)"
  fi

  local seed_json words pw_b64 init_payload init_resp
  seed_json=$(lnd_rest GET /v1/genseed)

  if ! echo "$seed_json" | jq -e '.cipher_seed_mnemonic | type == "array"' >/dev/null 2>&1; then
    echo "FAIL GenSeed did not return a mnemonic:"
    echo "$seed_json" | jq . 2>/dev/null || echo "$seed_json"
    echo ""
    if echo "$seed_json" | grep -qi "already unlocked\|already exists\|WalletUnlocker"; then
      echo "An LND wallet is already running. Wipe it to create a fresh one with a visible seed:"
      echo "  make down && rm -rf data/lnd && make create-keys"
    fi
    exit 1
  fi

  words=$(echo "$seed_json" | jq -r '.cipher_seed_mnemonic | join(" ")')
  print_seed "$words"

  pw_b64=$(printf '%s' "$PASSWORD" | base64 | tr -d '\n')
  init_payload=$(echo "$seed_json" | jq -c --arg pw "$pw_b64" \
    '{wallet_password: $pw, cipher_seed_mnemonic: .cipher_seed_mnemonic}')

  echo "Initializing wallet with that seed..."
  init_resp=$(lnd_rest POST /v1/initwallet "$init_payload")
  if echo "$init_resp" | jq -e 'has("error") or (has("code") and .code != 0)' >/dev/null 2>&1; then
    echo "FAIL InitWallet:"
    echo "$init_resp" | jq . 2>/dev/null || echo "$init_resp"
    exit 1
  fi

  local i
  for i in $(seq 1 60); do
    if lncli getinfo >/dev/null 2>&1; then
      echo "OK   LND wallet created"
      lncli getinfo | jq '{identity_pubkey, synced_to_chain, block_height}'
      sync_cch_creds
      echo ""
      echo "Re-print seed anytime with:  cat $SEED_FILE"
      echo "Next: ./start.sh"
      return 0
    fi
    sleep 2
  done

  echo "FAIL wallet created but getinfo timed out"
  docker logs --tail=60 fiber-cch-hub-lnd || true
  exit 1
}

echo "Starting Bitcoin testnet LND (Neutrino)..."
docker compose up -d --remove-orphans lnd
wait_tls
wait_wallet_ready

if lncli getinfo >/dev/null 2>&1; then
  finish_existing "LND wallet ready"
fi

if [[ "$MODE" != "create" ]]; then
  echo "FAIL LND wallet not found or wrong password."
  echo "First time? Run: make create-keys"
  echo "Guide: docs/SELF_HOSTING.md"
  exit 1
fi

create_wallet
