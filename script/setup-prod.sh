#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Setup Ghost Blog — Production Environment                                 │
# │  Interactive wizard that configures environment/production/.env             │
# │  Usage: ./script/setup-prod.sh                                             │
# └──────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_ROOT/environment/production"
ENV_FILE="$ENV_DIR/.env"
EXAMPLE_FILE="$ENV_DIR/example.env"

# ── Helpers ──────────────────────────────────────────────────────────────────

print_header() {
  echo ""
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│  Ghost Blog — Configuracion de Produccion                   │"
  echo "└──────────────────────────────────────────────────────────────┘"
  echo ""
}

prompt_value() {
  local prompt_text="$1"
  local default_value="${2:-}"
  local result

  if [ -n "$default_value" ]; then
    read -rp "  $prompt_text [$default_value]: " result
    echo "${result:-$default_value}"
  else
    while true; do
      read -rp "  $prompt_text: " result
      if [ -n "$result" ]; then
        echo "$result"
        return
      fi
      echo "  ✗ Este campo es obligatorio."
    done
  fi
}

prompt_secret() {
  local prompt_text="$1"
  local result

  while true; do
    read -srp "  $prompt_text: " result
    echo "" >&2
    if [ -n "$result" ]; then
      echo "$result"
      return
    fi
    echo "  ✗ Este campo es obligatorio." >&2
  done
}

prompt_secret_confirm() {
  local prompt_text="$1"
  local pass1 pass2

  while true; do
    read -srp "  $prompt_text: " pass1
    echo "" >&2
    if [ -z "$pass1" ]; then
      echo "  ✗ Este campo es obligatorio." >&2
      continue
    fi
    read -srp "  Confirmar $prompt_text: " pass2
    echo "" >&2
    if [ "$pass1" = "$pass2" ]; then
      echo "$pass1"
      return
    fi
    echo "  ✗ Las contrasenas no coinciden. Intenta de nuevo." >&2
  done
}

# ── Main ─────────────────────────────────────────────────────────────────────

print_header

# Warn if .env already exists
if [ -f "$ENV_FILE" ]; then
  echo "  ⚠  Ya existe un archivo .env en:"
  echo "     $ENV_FILE"
  echo ""
  read -rp "  ¿Deseas sobrescribirlo? (s/N): " overwrite
  if [[ ! "$overwrite" =~ ^[sS]$ ]]; then
    echo ""
    echo "  Configuracion cancelada."
    exit 0
  fi
  echo ""
fi

# Ensure example.env exists
if [ ! -f "$EXAMPLE_FILE" ]; then
  echo "  ✗ No se encontro example.env en $ENV_DIR"
  exit 1
fi

# ── Ghost Configuration ─────────────────────────────────────────────────────

echo "── Ghost ────────────────────────────────────────────────────────"
echo ""
GHOST_URL=$(prompt_value "URL publica del blog" "http://localhost:2368")
GHOST_PORT=$(prompt_value "Puerto del host" "2368")
echo ""

# ── MySQL Configuration ─────────────────────────────────────────────────────

echo "── MySQL ────────────────────────────────────────────────────────"
echo ""
MYSQL_DATABASE=$(prompt_value "Nombre de la base de datos" "ghost_prod")
MYSQL_USER=$(prompt_value "Usuario MySQL" "ghost_user")

echo ""
echo "  (Se generaran contrasenas aleatorias si presionas Enter)"
echo ""

read -rp "  ¿Generar contrasenas MySQL automaticamente? (S/n): " auto_mysql
if [[ "$auto_mysql" =~ ^[nN]$ ]]; then
  MYSQL_ROOT_PASSWORD=$(prompt_secret_confirm "Contrasena root de MySQL")
  MYSQL_PASSWORD=$(prompt_secret_confirm "Contrasena del usuario MySQL")
else
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
  MYSQL_PASSWORD=$(openssl rand -base64 32)
  echo "  ✓ Contrasenas MySQL generadas automaticamente."
fi
echo ""

# ── Mail Configuration ──────────────────────────────────────────────────────

echo "── Correo SMTP (requerido para login e invitaciones) ──────────"
echo ""
echo "  Proveedores comunes:"
echo "    1) Gmail         (smtp.gmail.com:587)"
echo "    2) Mailgun       (smtp.mailgun.org:465)"
echo "    3) Amazon SES    (endpoint regional:465)"
echo "    4) Otro"
echo ""
read -rp "  Selecciona proveedor [1-4]: " mail_choice

case "${mail_choice:-4}" in
  1)
    MAIL_HOST="smtp.gmail.com"
    MAIL_PORT="587"
    MAIL_SECURE="true"
    echo ""
    echo "  ℹ  Gmail requiere una App Password (no tu contrasena normal)."
    echo "     Generala en: https://myaccount.google.com/apppasswords"
    echo ""
    ;;
  2)
    MAIL_HOST="smtp.mailgun.org"
    MAIL_PORT="465"
    MAIL_SECURE="true"
    echo ""
    ;;
  3)
    MAIL_HOST=$(prompt_value "Endpoint SES (ej: email-smtp.us-east-1.amazonaws.com)")
    MAIL_PORT="465"
    MAIL_SECURE="true"
    echo ""
    ;;
  *)
    echo ""
    MAIL_HOST=$(prompt_value "Host SMTP")
    MAIL_PORT=$(prompt_value "Puerto SMTP" "587")
    MAIL_SECURE=$(prompt_value "Conexion segura (true/false)" "true")
    echo ""
    ;;
esac

MAIL_USER=$(prompt_value "Email / usuario SMTP")
MAIL_PASSWORD=$(prompt_secret "Contrasena SMTP (App Password si usas Gmail)")
echo ""
MAIL_FROM=$(prompt_value "Direccion remitente (ej: 'Ghost Blog <noreply@tudominio.com>')" "'Ghost Blog <$MAIL_USER>'")
echo ""

# ── Write .env ───────────────────────────────────────────────────────────────

cat > "$ENV_FILE" << ENVEOF
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │  Ghost Blog Service — Production Environment                               │
# │  Generated by setup-prod.sh on $(date '+%Y-%m-%d %H:%M:%S')                          │
# │                                                                            │
# │  ⚠  NEVER commit the .env file to version control.                        │
# │  ⚠  Use strong, unique passwords for all credentials.                     │
# └──────────────────────────────────────────────────────────────────────────────┘

# ── Node Environment ──────────────────────────────────────────────────────────
NODE_ENV=production

# ── Ghost Configuration ───────────────────────────────────────────────────────
GHOST_IMAGE=ghost:5-alpine
GHOST_PORT=$GHOST_PORT
GHOST_URL=$GHOST_URL

# ── MySQL Configuration ──────────────────────────────────────────────────────
MYSQL_IMAGE=mysql:8.0
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD

# ── Volumes (host paths) ─────────────────────────────────────────────────────
GHOST_CONTENT_PATH=./volumes/ghost-prod/content
MYSQL_DATA_PATH=./volumes/mysql-prod/data

# ── Backup Configuration ─────────────────────────────────────────────────────
BACKUP_PATH=./backups
BACKUP_RETENTION_DAYS=30

# ── Mail (REQUIRED for production — newsletters, invitations, etc.) ──────────
MAIL_TRANSPORT=SMTP
MAIL_HOST=$MAIL_HOST
MAIL_PORT=$MAIL_PORT
MAIL_SECURE=$MAIL_SECURE
MAIL_USER=$MAIL_USER
MAIL_PASSWORD=$MAIL_PASSWORD
MAIL_FROM=$MAIL_FROM
ENVEOF

echo "── Resultado ────────────────────────────────────────────────────"
echo ""
echo "  ✓ Archivo .env creado en:"
echo "    $ENV_FILE"
echo ""
echo "  ✓ Configuracion:"
echo "    Ghost URL:    $GHOST_URL"
echo "    Base de datos: $MYSQL_DATABASE"
echo "    SMTP:         $MAIL_USER → $MAIL_HOST:$MAIL_PORT"
echo ""
echo "  Siguiente paso:"
echo "    ./script/start-prod.sh"
echo ""
