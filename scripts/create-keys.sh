#!/usr/bin/env bash
# Explicit first-time key setup: Fiber CKB key + Lightning wallet.
# Does not run on every start — only when the operator asks (make create-keys).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KEY_PATH="data/fiber/ckb/key"
MAC_PATH="data/lnd/data/chain/bitcoin/testnet/admin.macaroon"

echo "=== Fiber CCH Hub — create keys ==="
echo ""

# --- .env ---
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example."
  echo "Edit .env and set FIBER_SECRET_KEY_PASSWORD and LND_WALLET_PASSWORD"
  echo "(not change-me), then run: make create-keys"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

if [[ -z "${FIBER_SECRET_KEY_PASSWORD:-}" || "$FIBER_SECRET_KEY_PASSWORD" == "change-me" ]]; then
  echo "FAIL Set FIBER_SECRET_KEY_PASSWORD in .env (not change-me)."
  exit 1
fi
if [[ -z "${LND_WALLET_PASSWORD:-}" || "$LND_WALLET_PASSWORD" == "change-me" ]]; then
  echo "FAIL Set LND_WALLET_PASSWORD in .env (not change-me)."
  exit 1
fi
echo "OK   .env passwords set"

mkdir -p data/fiber/ckb data/cch data/lnd
cp config/fiber/config.yml data/fiber/config.yml
cp config/cch/config.yml data/cch/config.yml

# --- Fiber / CKB key ---
if [[ -f "$KEY_PATH" ]]; then
  echo "OK   Fiber key already exists at $KEY_PATH (leaving it alone)"
else
  echo "Creating Fiber CKB private key at $KEY_PATH ..."
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 >"$KEY_PATH"
  else
    python3 - <<'PY'
from pathlib import Path
import secrets
Path("data/fiber/ckb/key").write_text(secrets.token_hex(32) + "\n")
PY
  fi
  chmod 600 "$KEY_PATH"
  echo "OK   Fiber key written (64 hex chars, mode 600)"
  echo "     Back this file up. Never commit it to git."
fi

if command -v ckb-cli >/dev/null 2>&1; then
  echo ""
  echo "Your CKB testnet address (fund this from the faucet):"
  ckb-cli util key-info --privkey-path "$KEY_PATH" 2>/dev/null || true
else
  echo ""
  echo "TIP Install ckb-cli to print your faucet address:"
  echo "    https://github.com/nervosnetwork/ckb-cli/releases"
  echo "    ckb-cli util key-info --privkey-path $KEY_PATH"
fi

# --- Lightning wallet ---
echo ""
SEED_FILE="data/lnd/cipher-seed.txt"
if [[ -f "$MAC_PATH" ]]; then
  echo "OK   LND wallet already exists — syncing CCH credentials..."
  ./scripts/lnd-wallet.sh sync
  if [[ ! -f "$SEED_FILE" ]]; then
    echo ""
    echo "WARNING: no seed file at $SEED_FILE (wallet was created without saving one)."
    echo "To mint a new wallet and print 24 words:"
    echo "  make down && rm -rf data/lnd && make create-keys"
  fi
else
  echo "Creating Lightning wallet (Bitcoin testnet)..."
  echo ""
  ./scripts/lnd-wallet.sh create
fi

echo ""
echo "=== Keys ready ==="
echo "  Fiber key:  $KEY_PATH"
echo "  LND data:   data/lnd/"
echo "  CCH creds:  data/cch/lnd/"
echo ""
echo "Next:  ./start.sh"
echo "Guide: docs/SELF_HOSTING.md"
echo "Backup data/ and your LND seed before funding."
