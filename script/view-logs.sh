#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  View Ghost Blog Logs                                                      │
# │  Usage: ./script/view-logs.sh <dev|prod> [service] [--tail N]                   │
# │  Examples:                                                                 │
# │    ./script/view-logs.sh dev                  # all services, follow            │
# │    ./script/view-logs.sh prod ghost           # ghost-prod only, follow         │
# │    ./script/view-logs.sh prod mysql --tail 50 # mysql-prod, last 50 lines      │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Parse arguments ───────────────────────────────────────────────────────────
ENV_NAME="${1:-}"
SERVICE=""
TAIL_LINES="100"

if [ -z "$ENV_NAME" ]; then
  echo "Usage: ./script/view-logs.sh <dev|prod> [service] [--tail N]"
  exit 1
fi

shift
while [ $# -gt 0 ]; do
  case "$1" in
    --tail) TAIL_LINES="$2"; shift 2 ;;
    ghost|mysql) SERVICE="$1-${ENV_NAME}"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

case "$ENV_NAME" in
  dev)  ENV_DIR="$PROJECT_ROOT/environment/development" ;;
  prod) ENV_DIR="$PROJECT_ROOT/environment/production" ;;
  *)    echo "✗  Invalid environment: $ENV_NAME (use 'dev' or 'prod')"; exit 1 ;;
esac

# ── Show logs ─────────────────────────────────────────────────────────────────
docker compose -f "$ENV_DIR/docker-compose.yml" --env-file "$ENV_DIR/.env" logs -f --tail "$TAIL_LINES" $SERVICE
