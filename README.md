# Reproducible Linux Dev Server

A fully reproducible home Linux server where configuration lives in Git, services run in Docker, and a fresh machine can rebuild itself in ~10 minutes.

## Architecture

```
Server
├── Linux OS (Fedora/Ubuntu Server)
├── Bootstrap Script → pulls this repo
├── Ansible → configures system
├── Docker → runs all services
└── Backups → persistent data only
```

**Key principle:** The machine is disposable. Configuration lives in Git.

## Quick Start

### Fresh Install

```bash
# 1. Install base Linux OS (Fedora Server or Ubuntu Server)

# 2. Run bootstrap as root
curl -fsSL <your-repo-url>/bootstrap/bootstrap.sh | \
  REPO_URL=https://github.com/YOUR_USER/server-config.git bash
```

### Manual Setup

```bash
git clone https://github.com/YOUR_USER/server-config.git /opt/server-config
cd /opt/server-config

# Configure environment
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# Set Tailscale auth key (optional)
export TAILSCALE_AUTHKEY="tskey-auth-..."

# Run Ansible
cd ansible && ansible-playbook -i inventory.ini server.yml

# Start services
cd ../docker && docker compose up -d
```

## Repository Structure

```
├── bootstrap/          # Bootstrap script for fresh installs
│   └── bootstrap.sh
├── ansible/            # System configuration
│   ├── inventory.ini
│   ├── server.yml
│   └── roles/
│       ├── base/       # Users, SSH, packages, fail2ban
│       ├── docker/     # Docker CE installation
│       ├── dev/        # Development tools
│       └── networking/ # Tailscale, firewall
├── docker/             # Application services
│   ├── compose.yml
│   └── .env.example
├── configs/            # Service configuration files
│   ├── caddy/          # Reverse proxy config
│   └── system/         # Sysctl tuning
└── scripts/            # Operational scripts
    ├── backup.sh
    └── restore.sh
```

## Services

| Service | URL | Description |
|---------|-----|-------------|
| code-server | `dev.home` | VS Code in the browser |
|PostgreSQL | internal | Database |
| Redis | internal | Cache |
| Caddy | ports 80/443 | Reverse proxy with auto TLS |

## AI CLI Tools

Installed globally on the host via Ansible:

- **Claude Code** — Anthropic's coding CLI (`claude`)
- **OpenClaw** — AI assistant framework (`openclaw`)
- **Codex CLI** — OpenAI's coding agent (`codex`)

## Ansible Roles

- **base** - System packages, user setup, SSH hardening, fail2ban, directory structure
- **docker** - Docker CE and Compose plugin installation
- **dev** - Development tools (Python, Node.js, build tools, Claude Code, OpenClaw, Codex CLI)
- **networking** - Tailscale VPN, firewall rules (firewalld/ufw)

## Backups

Uses [restic](https://restic.net/) for encrypted, deduplicated backups.

```bash
# Set backup target
export RESTIC_REPOSITORY=/mnt/backup   # or s3:bucket/path
export RESTIC_PASSWORD=your-password

# Run backup
./scripts/backup.sh

# Restore from latest
./scripts/restore.sh

# Restore specific snapshot
./scripts/restore.sh <snapshot-id>
```

**What gets backed up:**
- `/home` - User data
- `/opt/services` - Docker persistent volumes
- PostgreSQL database dumps

**Retention:** 7 daily, 4 weekly, 6 monthly snapshots.

## Recovery

If hardware fails:

1. Install Linux
2. Run bootstrap script
3. Restore backups

```bash
# On fresh machine
./bootstrap/bootstrap.sh

# Restore data
export RESTIC_REPOSITORY=/mnt/backup
export RESTIC_PASSWORD=your-password
./scripts/restore.sh
```

## Configuration

### Environment Variables

Copy `docker/.env.example` to `docker/.env` and set:

| Variable | Description |
|----------|-------------|
| `POSTGRES_PASSWORD` | PostgreSQL password (required) |
| `POSTGRES_USER` | PostgreSQL user (default: `dev`) |
| `POSTGRES_DB` | PostgreSQL database (default: `devdb`) |
| `CODE_SERVER_PASSWORD` | VS Code server password (default: `changeme`) |

### Tailscale

Set `TAILSCALE_AUTHKEY` environment variable before running Ansible to auto-join your Tailscale network.

## Future: Cluster Migration

The container-first design enables easy migration to Kubernetes:

```
single node → add nodes → install k3s → convert to K8s manifests
```
