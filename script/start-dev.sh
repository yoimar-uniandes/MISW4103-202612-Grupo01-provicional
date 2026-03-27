#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Start Ghost Blog — Development                                            │
# │  Usage: ./script/start-dev.sh [--build] [--detach]                               │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environment/development"

# ── Parse arguments ───────────────────────────────────────────────────────────
BUILD_FLAG=""
DETACH_FLAG=""

for arg in "$@"; do
  case $arg in
    --build)  BUILD_FLAG="--build" ;;
    --detach) DETACH_FLAG="-d" ;;
    *)        echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Ensure .env exists ────────────────────────────────────────────────────────
if [ ! -f "$ENV_DIR/.env" ]; then
  echo "⚠  .env not found. Copying from example.env..."
  cp "$ENV_DIR/example.env" "$ENV_DIR/.env"
  echo "✓  .env created at $ENV_DIR/.env"
  echo "   Review and adjust values before first run."
  echo ""
fi

# ── Create volume directories ─────────────────────────────────────────────────
mkdir -p "$ENV_DIR/volumes/ghost-dev/content"
mkdir -p "$ENV_DIR/volumes/mysql-dev/data"

# ── Start services ────────────────────────────────────────────────────────────
echo "🚀 Starting Ghost Blog (development)..."
echo ""

docker compose -f "$ENV_DIR/docker-compose.yml" --env-file "$ENV_DIR/.env" up $BUILD_FLAG $DETACH_FLAG

if [ -n "$DETACH_FLAG" ]; then
  echo ""
  echo "✓  Ghost Blog is running in background."
  echo "   Blog:  http://localhost:2368"
  echo "   Admin: http://localhost:2368/ghost"
  echo ""
  echo "   Logs:  ./script/view-logs.sh dev"
  echo "   Stop:  ./script/stop-services.sh dev"
fi
