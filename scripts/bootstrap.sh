#!/usr/bin/env bash
# Ensure local .env, data dirs, configs, and a CKB key exist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit secrets before production use."
fi

mkdir -p data/fiber/ckb data/cch data/lnd data/bitcoind

# Sync tracked configs into runtime data dirs (single volume mount per container).
cp config/fiber/config.yml data/fiber/config.yml
cp config/cch/config.yml data/cch/config.yml
cp config/bitcoind/bitcoin.conf data/bitcoind/bitcoin.conf

KEY_PATH="data/fiber/ckb/key"
if [[ ! -f "$KEY_PATH" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 >"$KEY_PATH"
  else
    python3 - <<'PY'
import secrets
from pathlib import Path
Path("data/fiber/ckb/key").write_text(secrets.token_hex(32) + "\n")
PY
  fi
  chmod 600 "$KEY_PATH"
  echo "Generated testnet CKB key at $KEY_PATH (keep private)."
fi

echo "Bootstrap complete."
