#!/usr/bin/env bash
# Stage 1 smoke: Fiber node_info + CCH container running.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

FIBER_RPC="http://127.0.0.1:${FIBER_RPC_PORT:-8227}"
CCH_RPC="http://127.0.0.1:${CCH_RPC_PORT:-8327}"

rpc() {
  local url=$1
  local method=$2
  curl -sf "$url" \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"${method}\",\"params\":[]}"
}

echo "Waiting for Fiber RPC at $FIBER_RPC ..."
for _ in $(seq 1 60); do
  if rpc "$FIBER_RPC" "node_info" >/tmp/fiber-cch-hub-node-info.json 2>/dev/null; then
    break
  fi
  sleep 2
done

if [[ ! -s /tmp/fiber-cch-hub-node-info.json ]]; then
  echo "FAIL Fiber node_info timed out"
  docker compose logs --tail=80 fiber || true
  exit 1
fi

if ! jq -e '.result' /tmp/fiber-cch-hub-node-info.json >/dev/null; then
  echo "FAIL Fiber node_info returned error:"
  cat /tmp/fiber-cch-hub-node-info.json
  exit 1
fi

echo "OK   Fiber node_info"
jq -r '.result | {pubkey, version: .version // .fiber_version // "n/a", addresses}' /tmp/fiber-cch-hub-node-info.json 2>/dev/null || true

if ! docker compose ps --status running --services | grep -qx cch; then
  echo "FAIL CCH container is not running"
  docker compose ps
  docker compose logs --tail=120 cch || true
  exit 1
fi
echo "OK   CCH container running"

# CCH may reject unknown methods or fail LND — process liveness is the Stage 1 gate.
# Probe that its RPC port accepts HTTP JSON-RPC traffic.
if curl -sf "$CCH_RPC" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"get_cch_order","params":[{"payment_hash":"0x0000000000000000000000000000000000000000000000000000000000000000"}]}' \
  >/tmp/fiber-cch-hub-cch-probe.json 2>/dev/null; then
  echo "OK   CCH RPC reachable"
  cat /tmp/fiber-cch-hub-cch-probe.json
else
  # Even a JSON-RPC error response means the server is up
  if curl -s "$CCH_RPC" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"get_cch_order","params":[{"payment_hash":"0x0000000000000000000000000000000000000000000000000000000000000000"}]}' \
    | grep -q jsonrpc; then
    echo "OK   CCH RPC reachable (error response is fine for Stage 1)"
  else
    echo "WARN CCH RPC not answering yet — check logs (Stage 1 allows ignore_startup_failure)"
    docker compose logs --tail=80 cch || true
  fi
fi

echo "Stage 1 smoke passed."
