#!/usr/bin/env bash
# Ensure .env, data dirs, and configs exist (does not create wallet keys).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env — set passwords, then run: make create-keys"
  echo "Guide: docs/SELF_HOSTING.md"
  exit 1
fi

mkdir -p data/fiber/ckb data/cch data/lnd

cp config/fiber/config.yml data/fiber/config.yml
cp config/cch/config.yml data/cch/config.yml

echo "Bootstrap complete."
