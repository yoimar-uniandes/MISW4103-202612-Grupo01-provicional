# Infrastructure

Overview of the Docker-based infrastructure that supports the Ghost Blog Service across development and production environments.

---

## Service Topology

```
┌──────────────────────────────────────────────────────────────┐
│                  ghost-network-<env>                          │
│                                                              │
│   ┌────────────────────┐        ┌────────────────────────┐   │
│   │                    │        │                        │   │
│   │  ghost-<env>       │───────▶│  mysql-<env>           │   │
│   │  Ghost CMS         │  TCP   │  MySQL 8               │   │
│   │  (Node.js)         │  3306  │  (ghost database)      │   │
│   │                    │        │                        │   │
│   │  :2368             │        │  :3306 (internal)      │   │
│   └────────────────────┘        └────────────────────────┘   │
│           │                              │                   │
│           │ volume mount                 │ volume mount      │
│           ▼                              ▼                   │
│   volumes/ghost-<env>/content    volumes/mysql-<env>/data    │
│   (themes, images, settings)     (MySQL data files)          │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Each environment runs as an isolated Docker Compose project (`ghost-dev` / `ghost-prod`) with its own network, services, and volumes. Both environments can coexist on the same host without conflicts.

---

## Environment Comparison

| Aspect          | Development (`dev`)            | Production (`prod`)                |
|-----------------|--------------------------------|------------------------------------|
| `NODE_ENV`      | `development`                  | `production`                       |
| Restart policy  | `unless-stopped`               | `always`                           |
| MySQL tuning    | Defaults                       | Buffer pool, max connections       |
| Mail            | Disabled (optional)            | SMTP required                      |
| Logging         | Docker default                 | `json-file` with rotation          |
| Resource limits | None                           | 512 MB per service                 |
| Backups         | On-demand                      | Scheduled + retention policy       |

---

## Persistence

All persistent data is stored under `environment/<env>/` using bind-mounted volumes, ensuring clear separation between environments.

```
environment/<env>/
├── volumes/
│   ├── ghost-<env>/content/    ← themes, images, redirects, settings
│   └── mysql-<env>/data/       ← MySQL data files
└── backups/                    ← backup archives
```

| Volume | Service | Content |
|--------|---------|---------|
| `ghost-<env>/content` | Ghost CMS | Themes, images, redirects, settings |
| `mysql-<env>/data` | MySQL 8 | InnoDB data files, binlogs |

---

## Networking

Each environment defines its own bridge network to isolate service communication:

| Environment | Network | Services |
|-------------|---------|----------|
| Development | `ghost-network-dev` | `ghost-dev`, `mysql-dev` |
| Production  | `ghost-network-prod` | `ghost-prod`, `mysql-prod` |

Ghost connects to MySQL over the internal network using the service name as hostname (`mysql-dev` / `mysql-prod`). Only the Ghost port (`2368`) is exposed to the host.

---

## Backup Strategy

Backups are created by `script/create-backup.sh` and restored by `script/restore-backup.sh`.

Each backup archive contains:

1. **MySQL dump** — `mysqldump` with `--single-transaction` for consistency
2. **Ghost content** — full tar of `/var/lib/ghost/content`

Both are compressed into a single `.tar.gz` archive with timestamp. Old backups are automatically purged based on `BACKUP_RETENTION_DAYS` (default: 30 days).

```
environment/<env>/backups/ghost-backup_<env>_<YYYYMMDD_HHMMSS>.tar.gz
```
