#!/usr/bin/env bash
# Ensure local .env, data dirs, and a CKB key exist for Stage 1 boot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example — edit FIBER_SECRET_KEY_PASSWORD before production use."
fi

mkdir -p data/fiber/ckb data/cch data/cch-lnd

KEY_PATH="data/fiber/ckb/key"
if [[ ! -f "$KEY_PATH" ]]; then
  # 32-byte hex private key without 0x prefix (Fiber/CKB convention)
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

# Placeholder files so the CCH volume mount exists (Stage 2 replaces with real LND creds)
touch data/cch-lnd/tls.cert data/cch-lnd/admin.macaroon

echo "Bootstrap complete."
