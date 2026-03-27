#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Backup Ghost Blog — MySQL dump + Ghost content                            │
# │  Usage: ./script/create-backup.sh <dev|prod>                                      │
# │                                                                            │
# │  Creates a timestamped backup archive containing:                          │
# │    - MySQL database dump (.sql.gz)                                         │
# │    - Ghost content directory (themes, images, settings)                    │
# │                                                                            │
# │  Backups are stored in: environment/<env>/backups/                         │
# │  Old backups are purged after BACKUP_RETENTION_DAYS (default: 30).         │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Parse environment ─────────────────────────────────────────────────────────
ENV_NAME="${1:-}"

if [ -z "$ENV_NAME" ]; then
  echo "Usage: ./script/create-backup.sh <dev|prod>"
  exit 1
fi

case "$ENV_NAME" in
  dev)  ENV_DIR="$PROJECT_ROOT/environment/development" ;;
  prod) ENV_DIR="$PROJECT_ROOT/environment/production" ;;
  *)    echo "✗  Invalid environment: $ENV_NAME (use 'dev' or 'prod')"; exit 1 ;;
esac

# ── Load environment ──────────────────────────────────────────────────────────
if [ ! -f "$ENV_DIR/.env" ]; then
  echo "✗  .env not found at $ENV_DIR/.env"
  exit 1
fi

source "$ENV_DIR/.env"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$ENV_DIR/backups"
BACKUP_NAME="ghost-backup_${ENV_NAME}_${TIMESTAMP}"
BACKUP_WORK_DIR="$BACKUP_DIR/$BACKUP_NAME"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

MYSQL_CONTAINER="ghost-mysql-dev"
[ "$ENV_NAME" = "prod" ] && MYSQL_CONTAINER="ghost-mysql-prod"

mkdir -p "$BACKUP_WORK_DIR"

echo "📦 Starting backup ($ENV_NAME) — $TIMESTAMP"
echo ""

# ── Step 1: MySQL dump ────────────────────────────────────────────────────────
echo "  [1/3] Dumping MySQL database..."

docker exec "$MYSQL_CONTAINER" mysqldump \
  -u root \
  -p"${MYSQL_ROOT_PASSWORD}" \
  --single-transaction \
  --routines \
  --triggers \
  --databases "${MYSQL_DATABASE}" \
  2>/dev/null | gzip > "$BACKUP_WORK_DIR/database.sql.gz"

DB_SIZE=$(du -sh "$BACKUP_WORK_DIR/database.sql.gz" | cut -f1)
echo "        ✓ Database dump: $DB_SIZE"

# ── Step 2: Ghost content ────────────────────────────────────────────────────
echo "  [2/3] Archiving Ghost content..."

CONTENT_PATH="${GHOST_CONTENT_PATH:-./volumes/ghost-${ENV}/content}"

if [[ "$CONTENT_PATH" == ./* ]]; then
  CONTENT_PATH="$ENV_DIR/${CONTENT_PATH#./}"
fi

if [ -d "$CONTENT_PATH" ]; then
  tar -czf "$BACKUP_WORK_DIR/ghost-content.tar.gz" -C "$(dirname "$CONTENT_PATH")" "$(basename "$CONTENT_PATH")" 2>/dev/null
  CONTENT_SIZE=$(du -sh "$BACKUP_WORK_DIR/ghost-content.tar.gz" | cut -f1)
  echo "        ✓ Ghost content: $CONTENT_SIZE"
else
  echo "        ⚠ Ghost content directory not found at $CONTENT_PATH (skipped)"
fi

# ── Step 3: Create final archive ─────────────────────────────────────────────
echo "  [3/3] Creating backup archive..."

tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME" 2>/dev/null
rm -rf "$BACKUP_WORK_DIR"

TOTAL_SIZE=$(du -sh "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo "✓  Backup complete: ${BACKUP_NAME}.tar.gz ($TOTAL_SIZE)"
echo "   Location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"

# ── Purge old backups ─────────────────────────────────────────────────────────
PURGED=$(find "$BACKUP_DIR" -name "ghost-backup_${ENV_NAME}_*.tar.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l)

if [ "$PURGED" -gt 0 ]; then
  echo "   🗑  Purged $PURGED backup(s) older than ${RETENTION_DAYS} days."
fi
