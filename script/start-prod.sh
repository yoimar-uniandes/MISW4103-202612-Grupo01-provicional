#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Start Ghost Blog — Production                                             │
# │  Usage: ./script/start-prod.sh [--build]                                         │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environment/production"

# ── Parse arguments ───────────────────────────────────────────────────────────
BUILD_FLAG=""

for arg in "$@"; do
  case $arg in
    --build) BUILD_FLAG="--build" ;;
    *)       echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Validate .env ─────────────────────────────────────────────────────────────
if [ ! -f "$ENV_DIR/.env" ]; then
  echo "✗  .env not found at $ENV_DIR/.env"
  echo "   Run: cp $ENV_DIR/example.env $ENV_DIR/.env"
  echo "   Then fill in ALL required values."
  exit 1
fi

# ── Validate required variables ───────────────────────────────────────────────
REQUIRED_VARS=(
  "GHOST_URL"
  "MYSQL_ROOT_PASSWORD"
  "MYSQL_PASSWORD"
)

MISSING=()
source "$ENV_DIR/.env"

for var in "${REQUIRED_VARS[@]}"; do
  value="${!var:-}"
  if [ -z "$value" ] || [[ "$value" == *"yourdomain"* ]]; then
    MISSING+=("$var")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "✗  Missing or unconfigured required variables:"
  for var in "${MISSING[@]}"; do
    echo "   - $var"
  done
  echo ""
  echo "   Edit $ENV_DIR/.env and fill in all required values."
  exit 1
fi

# ── Create volume directories ─────────────────────────────────────────────────
mkdir -p "$ENV_DIR/volumes/ghost-prod/content"
mkdir -p "$ENV_DIR/volumes/mysql-prod/data"
mkdir -p "$ENV_DIR/backups"

# ── Start services ────────────────────────────────────────────────────────────
echo "🚀 Starting Ghost Blog (production)..."
echo ""

docker compose -f "$ENV_DIR/docker-compose.yml" --env-file "$ENV_DIR/.env" up -d $BUILD_FLAG

echo ""
echo "✓  Ghost Blog is running."
echo "   Blog:  $GHOST_URL"
echo "   Admin: $GHOST_URL/ghost"
echo ""
echo "   Logs:  ./script/view-logs.sh prod"
echo "   Stop:  ./script/stop-services.sh prod"
