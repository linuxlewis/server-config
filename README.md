# Reproducible Debian Dev Server

This repo bootstraps and manages a personal Debian development server. The host is configured with Ansible, application services run in Docker, and the intended workflow is to rebuild the machine from Git instead of hand-configuring it over SSH.

Use it when you want to:

- bring up a fresh Debian server quickly
- keep host setup and service definitions in version control
- make repeatable changes to the server without configuration drift

## How It Works

The default target is the local machine. [`ansible/inventory.ini`](ansible/inventory.ini) points at `localhost`, so the normal model is:

1. clone this repo on the server
2. run the bootstrap script once
3. re-run Ansible and Docker Compose from the repo whenever you change something

The main entrypoints are:

- [`bootstrap/bootstrap.sh`](bootstrap/bootstrap.sh): fresh-server bootstrap
- [`ansible/server.yml`](ansible/server.yml): main host configuration
- [`docker/compose.yml`](docker/compose.yml): long-running services
- [`scripts/backup.sh`](scripts/backup.sh) and [`scripts/restore.sh`](scripts/restore.sh): restic backup and restore

## Prerequisites

Before you run the happy path, assume:

- you are on a fresh or mostly clean Debian server
- you can run commands as `root`
- GitHub is reachable from the machine so the repo can be cloned
- host ports `80` and `443` are available
- you will set `CODE_SERVER_PASSWORD` before expecting `docker compose up -d` to succeed

Optional environment variables:

- `TAILSCALE_AUTHKEY` to join the machine to Tailscale during Ansible setup
- `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` for backups

## Quick Start

### Fresh Install

Run the bootstrap flow as `root`. It installs dependencies, clones the repo into `/opt/server-config`, runs Ansible, and starts the Docker stack.

```bash
sudo -i
export REPO_URL='https://github.com/linuxlewis/server-config.git'
export REPO_BRANCH='main'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
cd /opt/server-config
cp docker/.env.example docker/.env
printf 'CODE_SERVER_PASSWORD=replace-this\n' > docker/.env
cd docker
docker compose up -d
docker compose ps
```

### Bootstrap From An Existing Clone

Use this if you already copied the repo onto the server and want the bootstrap logic to reuse it.

```bash
sudo -i
cd /opt/server-config
bash bootstrap/bootstrap.sh --repo-url https://github.com/linuxlewis/server-config.git --branch main --dir /opt/server-config
cp docker/.env.example docker/.env
printf 'CODE_SERVER_PASSWORD=replace-this\n' > docker/.env
cd docker
docker compose up -d
docker compose ps
```

### Manual Setup

Use this if you want to run each step yourself instead of piping the bootstrap script.

```bash
sudo -i
git clone https://github.com/linuxlewis/server-config.git /opt/server-config
cd /opt/server-config
cp docker/.env.example docker/.env
printf 'CODE_SERVER_PASSWORD=replace-this\n' > docker/.env
cd ansible
ansible-playbook -i inventory.ini server.yml --diff
cd ../docker
docker compose up -d
docker compose ps
```

If you want Tailscale configured during Ansible setup:

```bash
sudo -i
export TAILSCALE_AUTHKEY='tskey-auth-...'
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff
```

The playbook is applied manually. This repo does not install a cron job or systemd timer to re-run itself automatically.

## Persist Runtime Configuration

Create `docker/.env` after bootstrap so future Compose runs do not depend on whatever happens to be in your shell.

```bash
cd /opt/server-config
cp docker/.env.example docker/.env
${EDITOR:-vi} docker/.env
```

Set:

- `CODE_SERVER_PASSWORD`

The example file lives at [`docker/.env.example`](docker/.env.example).

## Day-To-Day Workflow

Most changes follow this loop:

1. Edit Ansible, Compose, or config files in this repo.
2. Re-run Ansible from `ansible/`.
3. Re-run Docker Compose from `docker/` if service definitions changed.
4. Verify the affected service.

Update the machine from the checked-out repo:

```bash
cd /opt/server-config
git pull --ff-only
cd ansible
ansible-playbook -i inventory.ini server.yml --diff
cd ../docker
docker compose up -d
docker compose ps
docker compose logs -f caddy
```

If you only changed Ansible:

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff
```

If you only changed Docker Compose or container config:

```bash
cd /opt/server-config/docker
docker compose up -d
docker compose ps
```

## What Gets Installed

Ansible configures:

- a `dev` user with Docker access
- base packages such as `git`, `tmux`, `htop`, `curl`, `jq`, and `fail2ban`
- Docker CE and the Compose plugin
- Tailscale, Cloudflare tooling, and Debian UFW rules
- persistent data directories under `/opt/services`
- AI CLI tools such as Claude Code, OpenClaw, and Codex CLI

The Docker stack currently includes:

- `caddy` on `80` and `443`
- `code-server` on `127.0.0.1:8080`

## Repository Structure

```text
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

## Validate Changes Locally

These checks are lightweight, but they catch most syntax and templating mistakes before you touch a real server:

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --syntax-check
ansible-playbook -i inventory.ini server.yml --check --diff

cd /opt/server-config
bash -n bootstrap/bootstrap.sh scripts/backup.sh scripts/restore.sh

cd /opt/server-config/docker
docker compose --env-file .env.example config -q
```

They do not replace testing on a disposable machine.

## CI

GitHub Actions validates infrastructure changes on pull requests and pushes to `main`:

- `ansible-playbook --syntax-check` against `ansible/server.yml`
- `ansible-lint --profile=min ansible/server.yml`
- `bash -n` and `shellcheck` for `bootstrap/bootstrap.sh`
- bootstrap argument-parsing checks
- a Debian Docker integration test that runs bootstrap through the Ansible step in CI mode

## Backup And Restore

Backups use [restic](https://restic.net/) and include `/home` and `/opt/services`.

Set:

- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`

Then run:

```bash
cd /opt/server-config
./scripts/backup.sh
./scripts/restore.sh
./scripts/restore.sh <snapshot-id>
```

Retention is `7` daily, `4` weekly, and `6` monthly snapshots.

## Recovery

If hardware fails:

1. install Debian
2. run bootstrap
3. restore backups

```bash
sudo -i
export REPO_URL='https://github.com/linuxlewis/server-config.git'
export REPO_BRANCH='main'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
export RESTIC_REPOSITORY='/mnt/backup'
export RESTIC_PASSWORD='replace-this'
cd /opt/server-config
./scripts/restore.sh
```

## Gotchas

- Run bootstrap as `root`; the script exits otherwise.
- The bootstrap script supports Debian only.
- The bootstrap script does not create `docker/.env` for you.
- The inventory targets `localhost`, so this repo is meant to run on the server itself by default.
- `code-server` binds to `127.0.0.1:8080`, so expose it intentionally through your network setup.
