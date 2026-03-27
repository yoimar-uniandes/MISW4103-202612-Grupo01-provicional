#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Stop Ghost Blog Services                                                  │
# │  Usage: ./script/stop-services.sh <dev|prod> [--remove-volumes]                     │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Parse environment ─────────────────────────────────────────────────────────
ENV_NAME="${1:-}"
VOLUMES_FLAG=""

if [ -z "$ENV_NAME" ]; then
  echo "Usage: ./script/stop-services.sh <dev|prod> [--remove-volumes]"
  exit 1
fi

shift
for arg in "$@"; do
  case $arg in
    --remove-volumes) VOLUMES_FLAG="-v" ;;
    *)                echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

case "$ENV_NAME" in
  dev)  ENV_DIR="$PROJECT_ROOT/environment/development" ;;
  prod) ENV_DIR="$PROJECT_ROOT/environment/production" ;;
  *)    echo "✗  Invalid environment: $ENV_NAME (use 'dev' or 'prod')"; exit 1 ;;
esac

# ── Stop services ─────────────────────────────────────────────────────────────
echo "⏹  Stopping Ghost Blog ($ENV_NAME)..."

docker compose -f "$ENV_DIR/docker-compose.yml" --env-file "$ENV_DIR/.env" down $VOLUMES_FLAG

echo "✓  Ghost Blog ($ENV_NAME) stopped."

if [ -n "$VOLUMES_FLAG" ]; then
  echo "   ⚠  Docker volumes have been removed."
fi
