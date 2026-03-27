# Ghost Blog Service

Self-hosted [Ghost CMS](https://ghost.org/) deployment using Docker Compose, with separate development and production environments, MySQL 8 as the database backend, and utility scripts for backup, restore, and operations.

---

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Scripts](#scripts)
- [Backup & Restore](#backup--restore)
- [Project Structure](#project-structure)
- [Docker](#docker)
- [License](#license)
- [Authors](#authors)

---

## Architecture

Ghost runs as a Docker container connected to a MySQL 8 instance over an internal bridge network. All persistent data (themes, images, database files) is mounted to the host via bind volumes. See [`doc/INFRASTRUCTURE.md`](doc/INFRASTRUCTURE.md) for the full topology diagram and environment comparison.

---

## Tech Stack

| Concern       | Technology          |
|---------------|---------------------|
| CMS           | Ghost 5 (Alpine)    |
| Database      | MySQL 8.0           |
| Runtime       | Node.js 18 (bundled)|
| Orchestration | Docker Compose      |
| Scripting     | Bash                |

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Bash (WSL2/Linux/macOS)

---

## Getting Started

### Desarrollo vs. Produccion: cual elegir

Si tu objetivo es **explorar, familiarizarte con Ghost o realizar pruebas manuales/automatizadas**, usa el entorno de **desarrollo**. No requiere configuracion de correo y permite crear la cuenta de administrador directamente desde el navegador.

Usa el entorno de **produccion** unicamente cuando necesites simular un despliegue real con envio de correos (invitaciones, restablecimiento de contrasena, magic links para miembros).

### Development (one-click)

```bash
git clone <repository-url>
cd ghost-blog-service

chmod +x script/*.sh

./script/start-dev.sh
```

The script automatically copies `example.env` to `.env` on first run, creates volume directories, and starts Ghost + MySQL.

- **Blog:** http://localhost:2368
- **Admin:** http://localhost:2368/ghost

La primera vez que accedas a http://localhost:2368/ghost, Ghost mostrara un formulario para **crear tu cuenta de administrador** (nombre, email y contrasena a tu eleccion). No se necesita correo real: el email solo se usa como identificador de login.

Si ya creaste la cuenta anteriormente y no recuerdas las credenciales, puedes resetear los volumenes y empezar de cero:

```bash
./script/stop-services.sh dev --remove-volumes
./script/start-dev.sh --detach
```

### Production

La forma mas rapida de configurar produccion es usar el asistente interactivo:

```bash
./script/setup-prod.sh
```

El script te guiara paso a paso para configurar Ghost, MySQL y el correo SMTP. Las contrasenas se ingresan de forma enmascarada y las de MySQL pueden generarse automaticamente.

Una vez completado, inicia los servicios:

```bash
./script/start-prod.sh
```

#### Configuracion manual (alternativa)

Si prefieres configurar manualmente:

```bash
cp environment/production/example.env environment/production/.env
# Edita .env con tu dominio, contrasenas y configuracion de correo
```

#### Configuracion de correo (requerida en produccion)

Ghost en produccion necesita un servidor SMTP real para enviar correos transaccionales (invitaciones de usuario, restablecimiento de contrasena, links de inicio de sesion). Sin esta configuracion **no podras completar el flujo de login ni invitar colaboradores**.

El script `setup-prod.sh` incluye presets para los proveedores mas comunes:

| Proveedor | `MAIL_HOST` | `MAIL_PORT` | Notas |
|-----------|-------------|-------------|-------|
| Gmail | `smtp.gmail.com` | `587` | Requiere [App Password](https://myaccount.google.com/apppasswords) (2FA debe estar activo). No uses tu contrasena normal. |
| Mailgun | `smtp.mailgun.org` | `465` | Usa las credenciales SMTP del dominio configurado en Mailgun. |
| Amazon SES | Tu endpoint SES regional | `465` | Usa las claves SMTP de IAM, no las claves de acceso normales. |

Si necesitas editar la configuracion despues, modifica `environment/production/.env` y reinicia:

```bash
./script/stop-services.sh prod
./script/start-prod.sh
```

> **Referencia oficial:** https://ghost.org/docs/config/#mail

---

## Environment Variables

All variables are defined in `environment/<env>/example.env`. Copy to `.env` and customise.

| Variable                | Required (prod) | Default                    | Description                      |
|-------------------------|-----------------|----------------------------|----------------------------------|
| `NODE_ENV`              | No              | `development`              | `development` or `production`    |
| `GHOST_IMAGE`           | No              | `ghost:5-alpine`           | Docker image for Ghost           |
| `GHOST_PORT`            | No              | `2368`                     | Host port mapping                |
| `GHOST_URL`             | **Yes**         | `http://localhost:2368`    | Public URL of your blog          |
| `MYSQL_IMAGE`           | No              | `mysql:8.0`                | Docker image for MySQL           |
| `MYSQL_ROOT_PASSWORD`   | **Yes**         | *(dev default)*            | MySQL root password              |
| `MYSQL_DATABASE`        | No              | `ghost_dev` / `ghost_prod` | Database name                    |
| `MYSQL_USER`            | No              | `ghost_user`               | MySQL user for Ghost             |
| `MYSQL_PASSWORD`        | **Yes**         | *(dev default)*            | MySQL user password              |
| `MAIL_TRANSPORT`        | Recommended     | --                         | `SMTP`                           |
| `MAIL_HOST`             | Recommended     | --                         | SMTP server hostname             |
| `MAIL_PORT`             | No              | `587`                      | SMTP port                        |
| `MAIL_USER`             | Recommended     | --                         | SMTP auth username               |
| `MAIL_PASSWORD`         | Recommended     | --                         | SMTP auth password               |
| `MAIL_FROM`             | Recommended     | --                         | Sender address for Ghost emails  |
| `BACKUP_RETENTION_DAYS` | No              | `30`                       | Days to keep old backups         |

---

## Scripts

All scripts accept `dev` or `prod` as the first argument to target the corresponding environment.

| Script                | Description                                              |
|-----------------------|----------------------------------------------------------|
| `./script/setup-prod.sh`     | Interactive wizard to configure production `.env`         |
| `./script/start-dev.sh`      | Start development environment (foreground by default)    |
| `./script/start-prod.sh`     | Start production environment (detached, with validation) |
| `./script/stop-services.sh`  | Stop services (`--remove-volumes` to delete data)        |
| `./script/view-logs.sh`      | Follow container logs (optional: service name, `--tail`) |
| `./script/create-backup.sh`  | Create timestamped backup (MySQL dump + Ghost content)   |
| `./script/restore-backup.sh` | Restore from a backup archive                            |
| `./script/check-status.sh`   | Show service health and backup summary                   |

### Examples

```bash
# Start dev in background
./script/start-dev.sh --detach

# View only Ghost logs (last 50 lines)
./script/view-logs.sh dev ghost --tail 50

# Create a production backup
./script/create-backup.sh prod

# Restore from a backup
./script/restore-backup.sh prod ghost-backup_prod_20260327_120000.tar.gz

# Check status
./script/check-status.sh prod

# Stop and remove volumes (destructive)
./script/stop-services.sh dev --remove-volumes
```

---

## Backup & Restore

### What gets backed up

1. **MySQL database** — full dump with `--single-transaction` for consistency
2. **Ghost content** — themes, images, redirects, settings (`/var/lib/ghost/content`)

### Backup location

```
environment/<env>/backups/ghost-backup_<env>_<YYYYMMDD_HHMMSS>.tar.gz
```

### Automatic cleanup

Backups older than `BACKUP_RETENTION_DAYS` (default: 30) are automatically deleted when a new backup is created.

### Scheduling (cron example)

```bash
# Production backup every day at 03:00
0 3 * * * /path/to/ghost-blog-service/script/create-backup.sh prod >> /var/log/ghost-backup.log 2>&1
```

---

## Project Structure

```
ghost-blog-service/
├── doc/
│   └── INFRASTRUCTURE.md          # Topology, networking, persistence, backups
├── environment/
│   ├── development/
│   │   ├── docker-compose.yml     # Dev compose (Ghost + MySQL)
│   │   └── example.env            # Dev environment template
│   └── production/
│       ├── docker-compose.yml     # Prod compose (hardened, with mail + limits)
│       └── example.env            # Prod environment template
├── script/
│   ├── setup-prod.sh              # Interactive production .env configurator
│   ├── start-dev.sh               # One-click dev start
│   ├── start-prod.sh              # One-click prod start (with validation)
│   ├── stop-services.sh           # Stop services
│   ├── view-logs.sh               # View logs
│   ├── create-backup.sh           # MySQL dump + content backup
│   ├── restore-backup.sh          # Restore from backup
│   └── check-status.sh            # Service health overview
├── .gitattributes                 # Line ending normalisation
├── .gitignore                     # Ignore .env, volumes, backups
├── LICENSE                        # GNU GPL v3
└── README.md                      # This file
```

---

## Docker

### Images used

| Service | Image            | Purpose              |
|---------|------------------|----------------------|
| Ghost   | `ghost:5-alpine` | CMS application      |
| MySQL   | `mysql:8.0`      | Relational database  |

### Health checks

Both services include Docker health checks. Ghost waits for MySQL to be healthy before starting (via `depends_on` with `condition: service_healthy`).

### Production hardening

The production compose includes: JSON log rotation (`10m x 5 files`), memory limits (`512 MB` per service), InnoDB buffer pool tuning, `restart: always`, and required environment variable validation via the `start-prod.sh` script.

---

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

---

## Authors

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://aspirantes.uniandes.edu.co/sites/default/files/logo%20uniandes%20colombia%20blanco.png">
  <source media="(prefers-color-scheme: light)" srcset="https://aspirantes.uniandes.edu.co/sites/default/files/logo%20uniandes%20colombia%20negro.png">
  <img src="https://aspirantes.uniandes.edu.co/sites/default/files/logo%20uniandes%20colombia%20negro.png" alt="Universidad de los Andes" width="400">
</picture>

Students at [Universidad de los Andes](https://uniandes.edu.co), Bogotá, Colombia.

| Name | Email |
|------|-------|
| Yoimar Moreno Bertel | y.morenob2@uniandes.edu.co |
| Manfred Ariel Martinez Bastos | ma.martinezb123@uniandes.edu.co |
| Jhon Jairo Rincon Castro | j.rinconc23@uniandes.edu.co |
| Yesid Stevem Piñeros | y.pineros@uniandes.edu.co |
