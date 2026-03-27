#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Restore Ghost Blog from Backup                                            │
# │  Usage: ./script/restore-backup.sh <dev|prod> <backup-file.tar.gz>                │
# │                                                                            │
# │  ⚠  This will OVERWRITE current database and content.                     │
# │  ⚠  Make sure Ghost is running before restoring.                          │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Parse arguments ───────────────────────────────────────────────────────────
ENV_NAME="${1:-}"
BACKUP_FILE="${2:-}"

if [ -z "$ENV_NAME" ] || [ -z "$BACKUP_FILE" ]; then
  echo "Usage: ./script/restore-backup.sh <dev|prod> <backup-file.tar.gz>"
  exit 1
fi

case "$ENV_NAME" in
  dev)  ENV_DIR="$PROJECT_ROOT/environment/development" ;;
  prod) ENV_DIR="$PROJECT_ROOT/environment/production" ;;
  *)    echo "✗  Invalid environment: $ENV_NAME (use 'dev' or 'prod')"; exit 1 ;;
esac

if [ ! -f "$BACKUP_FILE" ]; then
  if [ -f "$ENV_DIR/backups/$BACKUP_FILE" ]; then
    BACKUP_FILE="$ENV_DIR/backups/$BACKUP_FILE"
  else
    echo "✗  Backup file not found: $BACKUP_FILE"
    exit 1
  fi
fi

# ── Load environment ──────────────────────────────────────────────────────────
source "$ENV_DIR/.env"

MYSQL_CONTAINER="ghost-mysql-dev"
[ "$ENV_NAME" = "prod" ] && MYSQL_CONTAINER="ghost-mysql-prod"

GHOST_CONTAINER="ghost-dev"
[ "$ENV_NAME" = "prod" ] && GHOST_CONTAINER="ghost-prod"

# ── Confirmation ──────────────────────────────────────────────────────────────
echo "⚠  WARNING: This will overwrite the current $ENV_NAME environment."
echo "   Backup: $(basename "$BACKUP_FILE")"
echo ""
read -p "   Type 'RESTORE' to confirm: " CONFIRM

if [ "$CONFIRM" != "RESTORE" ]; then
  echo "   Aborted."
  exit 0
fi

# ── Extract backup ────────────────────────────────────────────────────────────
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo ""
echo "📦 Restoring from backup..."

tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"
BACKUP_INNER=$(ls "$TEMP_DIR")

# ── Step 1: Restore database ─────────────────────────────────────────────────
DB_DUMP="$TEMP_DIR/$BACKUP_INNER/database.sql.gz"

if [ -f "$DB_DUMP" ]; then
  echo "  [1/2] Restoring MySQL database..."
  gunzip -c "$DB_DUMP" | docker exec -i "$MYSQL_CONTAINER" mysql \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    2>/dev/null
  echo "        ✓ Database restored."
else
  echo "  [1/2] ⚠  No database dump found in backup (skipped)."
fi

# ── Step 2: Restore Ghost content ────────────────────────────────────────────
CONTENT_ARCHIVE="$TEMP_DIR/$BACKUP_INNER/ghost-content.tar.gz"
CONTENT_PATH="${GHOST_CONTENT_PATH:-./volumes/ghost-${ENV}/content}"

if [[ "$CONTENT_PATH" == ./* ]]; then
  CONTENT_PATH="$ENV_DIR/${CONTENT_PATH#./}"
fi

if [ -f "$CONTENT_ARCHIVE" ]; then
  echo "  [2/2] Restoring Ghost content..."
  tar -xzf "$CONTENT_ARCHIVE" -C "$(dirname "$CONTENT_PATH")"
  echo "        ✓ Ghost content restored."
else
  echo "  [2/2] ⚠  No content archive found in backup (skipped)."
fi

# ── Restart Ghost to pick up changes ─────────────────────────────────────────
echo ""
echo "  Restarting Ghost..."
docker restart "$GHOST_CONTAINER" > /dev/null 2>&1

echo ""
echo "✓  Restore complete. Ghost is restarting."
