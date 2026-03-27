#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Ghost Blog Service Status                                                 │
# │  Usage: ./script/check-status.sh <dev|prod>                                      │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV_NAME="${1:-}"

if [ -z "$ENV_NAME" ]; then
  echo "Usage: ./script/check-status.sh <dev|prod>"
  exit 1
fi

case "$ENV_NAME" in
  dev)  ENV_DIR="$PROJECT_ROOT/environment/development" ;;
  prod) ENV_DIR="$PROJECT_ROOT/environment/production" ;;
  *)    echo "✗  Invalid environment: $ENV_NAME (use 'dev' or 'prod')"; exit 1 ;;
esac

if [ ! -f "$ENV_DIR/.env" ]; then
  echo "✗  .env not found. Environment not configured."
  exit 1
fi

echo "📊 Ghost Blog Status ($ENV_NAME)"
echo "─────────────────────────────────────"
echo ""

docker compose -f "$ENV_DIR/docker-compose.yml" --env-file "$ENV_DIR/.env" ps

echo ""

# ── Show backup info ──────────────────────────────────────────────────────────
BACKUP_DIR="$ENV_DIR/backups"
if [ -d "$BACKUP_DIR" ]; then
  BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" 2>/dev/null | wc -l)
  LATEST=$(find "$BACKUP_DIR" -name "*.tar.gz" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  echo "💾 Backups: $BACKUP_COUNT total"
  if [ -n "$LATEST" ]; then
    echo "   Latest:  $(basename "$LATEST")"
  fi
else
  echo "💾 Backups: none"
fi
