#!/usr/bin/env bash
# Validate .env passwords and Fiber CKB key before starting the hub.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env — run: cp .env.example .env"
  echo "Then set passwords. Guide: docs/SELF_HOSTING.md"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

fail=0

require_password() {
  local name=$1
  local value=$2
  local placeholder=$3

  if [[ -z "$value" || "$value" == "$placeholder" ]]; then
    echo "FAIL Set $name in .env (not empty, not the example placeholder)."
    fail=1
  fi
}

require_password FIBER_SECRET_KEY_PASSWORD "${FIBER_SECRET_KEY_PASSWORD:-}" "change-me"
require_password LND_WALLET_PASSWORD "${LND_WALLET_PASSWORD:-}" "change-me"

KEY_PATH="data/fiber/ckb/key"
if [[ ! -f "$KEY_PATH" ]]; then
  echo "FAIL Missing CKB private key at $KEY_PATH"
  echo "Run: make create-keys   (or docs/SELF_HOSTING.md)"
  fail=1
else
  key_line=$(tr -d '[:space:]' <"$KEY_PATH")
  if [[ "$key_line" == 0x* ]]; then
    key_line="${key_line#0x}"
  fi
  if [[ ! "$key_line" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "FAIL $KEY_PATH must be one line, 64 hex characters (no 0x prefix)."
    fail=1
  fi
fi

if [[ $fail -ne 0 ]]; then
  exit 1
fi
