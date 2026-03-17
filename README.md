# Reproducible Debian Dev Server

This repo bootstraps and manages a personal Debian development server. The host is configured with Ansible, application services run with Docker Compose, and the intended workflow is to rebuild the machine from Git instead of hand-configuring it over SSH.

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
- `ANSIBLE_EXTRA_VARS` to pass additional variables into the bootstrap playbook run
- `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` for backups

## Quick Start

Every block below is intended to be copy-pasteable as-is after you replace the sample values.

### Bootstrap a fresh Debian server

Use this when you want the shortest path while still keeping the command block copy-pasteable:

```bash
sudo -i
export SERVER_USERNAME='dev'
export CODE_SERVER_PASSWORD='replace-this-password'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
cd /opt/server-config/docker
docker compose ps
```

This installs bootstrap dependencies, prompts for any missing values, clones the repo into `/opt/server-config`, writes `docker/.env`, runs [`ansible/server.yml`](ansible/server.yml), and starts the Docker Compose stack.

### Unattended bootstrap

Use this when you want a fully copy-pasteable bootstrap with no prompts:

```bash
sudo -i
export REPO_URL='https://github.com/linuxlewis/server-config.git'
export REPO_BRANCH='main'
export INSTALL_DIR='/opt/server-config'
export SERVER_USERNAME='dev'
export CODE_SERVER_PASSWORD='replace-this-password'
export TAILSCALE_AUTHKEY='tskey-auth-...'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
cd /opt/server-config/docker
docker compose ps
```

### Bootstrap from an existing clone

Use this if `/opt/server-config` already exists on the server and you want to reuse that checkout:

```bash
sudo -i
cd /opt/server-config
export SERVER_USERNAME='dev'
export CODE_SERVER_PASSWORD='replace-this-password'
bash bootstrap/bootstrap.sh --repo-url https://github.com/linuxlewis/server-config.git --branch main --dir /opt/server-config
cd /opt/server-config/docker
docker compose ps
```

### Manual setup

Use this when you want each step broken out explicitly instead of using the bootstrap script:

```bash
sudo -i
git clone https://github.com/linuxlewis/server-config.git /opt/server-config
cd /opt/server-config
cat > docker/.env <<'EOF'
SERVER_USERNAME=dev
CODE_SERVER_PASSWORD=replace-this-password
EOF
export SERVER_USERNAME='dev'
cd ansible
ansible-playbook -i inventory.ini server.yml --diff
cd /opt/server-config/docker
docker compose up -d
docker compose ps
```

### Optional Tailscale auto-join

Set the auth key before running Ansible:

```bash
sudo -i
export TAILSCALE_AUTHKEY='tskey-auth-...'
export SERVER_USERNAME='dev'
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff
```

### Optional firewall

The playbook leaves `ufw` disabled by default to avoid interfering with Tailscale access. If you want it enabled:

```bash
sudo -i
cd /opt/server-config/ansible
export SERVER_USERNAME='dev'
ansible-playbook -i inventory.ini server.yml --diff --extra-vars enable_firewall=true
```

When enabled, the role allows both `OpenSSH` and inbound traffic on `tailscale0` before turning `ufw` on.

### User-managed npm CLI tools

The `dev` role installs Node.js LTS and configures the primary user for per-user npm globals in `~/.npm-global`. Ansible does not install Node-based CLI tools anymore, so each user can manage their own versions without `sudo`.

After logging in as that user, install tools with:

```bash
npm install -g @openai/codex @bitwarden/cli openclaw
```

## Day-To-Day Workflow

Most changes follow this loop:

1. edit Ansible, Compose, or config files in this repo
2. re-run Ansible from `ansible/`
3. re-run Docker Compose from `docker/` if service definitions changed
4. verify the affected service

Update the machine from the checked-out repo:

```bash
cd /opt/server-config
git pull --ff-only
export SERVER_USERNAME='dev'
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
export SERVER_USERNAME='dev'
ansible-playbook -i inventory.ini server.yml --diff
```

If you only changed Docker Compose or container config:

```bash
cd /opt/server-config/docker
docker compose up -d
docker compose ps
```

## Common Commands

### Re-apply server configuration

```bash
cd /opt/server-config/ansible
export SERVER_USERNAME='dev'
ansible-playbook -i inventory.ini server.yml --diff
```

### Validate the Ansible playbook

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --syntax-check
```

### Run the Ansible test harness

Install the local tooling with `uv`, then run linting and Molecule from repo root:

```bash
cd /opt/server-config
uv sync --group dev
uv run ansible-galaxy collection install -r ansible/requirements.yml
uv run ansible-playbook -i ansible/inventory.ini ansible/server.yml --syntax-check
uv run ansible-lint --profile=min ansible/server.yml
cd ansible
uv run molecule test --all
```

### Restart the application stack

```bash
cd /opt/server-config/docker
docker compose up -d
docker compose ps
```

### Stop the application stack

```bash
cd /opt/server-config/docker
docker compose down
```

## Configuration

### Environment file

Create the Docker environment file:

```bash
cd /opt/server-config
cp docker/.env.example docker/.env
${EDITOR:-vi} docker/.env
```

Current variables:

| Variable | Description |
|----------|-------------|
| `SERVER_USERNAME` | Linux username Ansible creates and Docker uses for the workspace mount |
| `CODE_SERVER_PASSWORD` | Password for `code-server` |

Example:

```bash
cat > /opt/server-config/docker/.env <<'EOF'
SERVER_USERNAME=dev
CODE_SERVER_PASSWORD=replace-this-password
EOF
```

## Services

| Service | Access | Description |
|---------|--------|-------------|
| `code-server` | `http://SERVER_IP:8080` through local port binding or via Caddy | VS Code in the browser |
| `caddy` | ports `80` and `443` | Reverse proxy and TLS termination |

## What Gets Installed

Ansible configures:

- a primary user with Docker access
- base packages such as `git`, `tmux`, `htop`, `curl`, `jq`, and `fail2ban`
- Docker CE and the Compose plugin
- Tailscale, Cloudflare tooling, and optional firewall rules
- persistent data directories under `/opt/services`
- Node.js LTS and user-level npm globals support

The Docker stack currently includes:

- `caddy` on `80` and `443`
- `code-server` on `127.0.0.1:8080`

## Repository Structure

```text
.
├── ansible/
│   ├── inventory.ini
│   ├── requirements.yml
│   ├── server.yml
│   └── roles/
│       ├── base/
│       ├── dev/
│       ├── docker/
│       └── networking/
├── bootstrap/
│   └── bootstrap.sh
├── configs/
│   ├── caddy/
│   └── system/
├── docker/
│   ├── compose.yml
│   └── .env.example
└── scripts/
    ├── backup.sh
    └── restore.sh
```

## Validate Changes Locally

These checks are lightweight, but they catch most syntax and templating mistakes before you touch a real server:

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --syntax-check

cd /opt/server-config
bash -n bootstrap/bootstrap.sh scripts/backup.sh scripts/restore.sh

cd /opt/server-config/docker
docker compose --env-file .env.example config -q
```

If you have the dev tooling installed, you can also run:

```bash
cd /opt/server-config
uv run ansible-lint --profile=min ansible/server.yml
cd ansible
uv run molecule test --all
```

These checks do not replace testing on a disposable machine.

## Backups

Backups use `restic` and include `/home` and `/opt/services`.

### Run a backup

```bash
export RESTIC_REPOSITORY="/mnt/backup"
export RESTIC_PASSWORD="replace-this-password"
cd /opt/server-config
./scripts/backup.sh
```

### Restore the latest backup

```bash
export RESTIC_REPOSITORY="/mnt/backup"
export RESTIC_PASSWORD="replace-this-password"
cd /opt/server-config
./scripts/restore.sh
```

### Restore a specific snapshot

```bash
export RESTIC_REPOSITORY="/mnt/backup"
export RESTIC_PASSWORD="replace-this-password"
cd /opt/server-config
./scripts/restore.sh <snapshot-id>
```

Retention policy:

- 7 daily snapshots
- 4 weekly snapshots
- 6 monthly snapshots

## Recovery

On a replacement Debian machine:

```bash
sudo -i
export CODE_SERVER_PASSWORD='replace-this-password'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
export RESTIC_REPOSITORY="/mnt/backup"
export RESTIC_PASSWORD="replace-this-password"
cd /opt/server-config
./scripts/restore.sh
```

## CI

GitHub Actions validates infrastructure changes with:

- `ansible-playbook --syntax-check` for `ansible/server.yml`
- `ansible-lint --profile=min ansible/server.yml`
- `molecule test --all` for the Ansible Molecule scenarios
- `bash -n` and `shellcheck` for `bootstrap/bootstrap.sh`
- bootstrap argument-parsing checks
- a Debian integration run of bootstrap in CI mode
