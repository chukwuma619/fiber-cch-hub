#!/usr/bin/env bash
# Stage 0 doctor: verify Docker + pinned Fiber image.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
elif [[ -f .env.example ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env.example
  set +a
fi

IMAGE="${FIBER_IMAGE:-nervos/fiber:v0.9.0}"

fail=0
check() {
  local name=$1
  shift
  if "$@"; then
    echo "OK   $name"
  else
    echo "FAIL $name"
    fail=1
  fi
}

check "docker installed" command -v docker >/dev/null

if ! docker info >/dev/null 2>&1; then
  echo "FAIL docker daemon"
  echo ""
  echo "Docker CLI is installed but the daemon is not reachable."
  echo "Start Docker Desktop (or your engine), then re-run: make doctor"
  echo "Context: $(docker context show 2>/dev/null || echo unknown)"
  exit 1
fi
echo "OK   docker daemon"
check "curl installed" command -v curl >/dev/null
check "jq installed" command -v jq >/dev/null
check "compose plugin" docker compose version >/dev/null 2>&1

echo "Pinned image: $IMAGE"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "OK   image present locally"
else
  echo "INFO pulling $IMAGE ..."
  docker pull "$IMAGE"
fi

echo "Fiber version inside image:"
docker run --rm --entrypoint fnn "$IMAGE" --version

if [[ $fail -ne 0 ]]; then
  echo "Doctor found issues."
  exit 1
fi

echo "Doctor passed (Stage 0)."
