# Reproducible Debian Dev Server

A reproducible Debian dev server where system configuration lives in Git, host setup is managed with Ansible, and services run with Docker Compose.

## Quick Start

### Bootstrap a fresh Debian server

Run this as `root` on the target server:

```bash
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
```

This will:

- install bootstrap dependencies
- prompt for the Linux username
- prompt for the `code-server` password
- optionally prompt for a Tailscale auth key
- clone the repo into `/opt/server-config`
- write `/opt/server-config/docker/.env`
- run `ansible/server.yml`
- start the Docker Compose stack

For unattended installs, set the variables up front:

```bash
export REPO_URL="https://github.com/linuxlewis/server-config.git"
export SERVER_USERNAME="dev"
export CODE_SERVER_PASSWORD="replace-this-password"
export TAILSCALE_AUTHKEY="tskey-auth-..."
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash
```

### Manual setup

Use this when you want the steps broken out explicitly:

```bash
sudo -i
git clone https://github.com/linuxlewis/server-config.git /opt/server-config
cd /opt/server-config

cp docker/.env.example docker/.env
${EDITOR:-vi} docker/.env

export SERVER_USERNAME="dev"

cd ansible
ansible-playbook -i inventory.ini server.yml --diff

cd /opt/server-config/docker
docker compose up -d
docker compose ps
```

### User-managed npm CLI tools

The `dev` role installs Node.js LTS and configures the primary user for per-user npm globals in `~/.npm-global`.
Ansible does not install Node-based CLI tools anymore, so each user can manage their own versions without `sudo`.

After logging in as that user, install tools with:

```bash
npm install -g @openai/codex @bitwarden/cli openclaw
```

### Optional Tailscale auto-join

Set the auth key before running Ansible:

```bash
export TAILSCALE_AUTHKEY="tskey-auth-..."
export SERVER_USERNAME="dev"
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff
```

### Optional firewall

The playbook now leaves `ufw` disabled by default to avoid interfering with Tailscale access.

If you want to enable it, run Ansible with:

```bash
cd /opt/server-config/ansible
export SERVER_USERNAME="dev"
ansible-playbook -i inventory.ini server.yml --diff --extra-vars enable_firewall=true
```

When enabled, the role allows both `OpenSSH` and inbound traffic on `tailscale0` before turning `ufw` on.

## Common Commands

### Re-apply server configuration

```bash
cd /opt/server-config/ansible
export SERVER_USERNAME="dev"
ansible-playbook -i inventory.ini server.yml --diff
```

### Run the Ansible test harness

Install the local tooling with `uv`, then run linting and Molecule from repo root:

```bash
uv sync --group dev
uv run ansible-galaxy collection install -r ansible/requirements.yml
uv run ansible-playbook -i ansible/inventory.ini ansible/server.yml --syntax-check
uv run ansible-lint --profile=min ansible/server.yml
cd ansible && uv run molecule test --all
```

### Validate the Ansible playbook

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --syntax-check
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

### Update the repo on the server

```bash
cd /opt/server-config
git pull origin main

cd /opt/server-config/ansible
export SERVER_USERNAME="dev"
ansible-playbook -i inventory.ini server.yml --diff

cd /opt/server-config/docker
docker compose up -d
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

## Repository Structure

```text
.
├── ansible/
│   ├── inventory.ini
│   ├── requirements.yml
│   ├── server.yml
│   └── roles/
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

## Ansible Roles

- `base`: packages, user setup, SSH hardening, fail2ban, directories
- `docker`: Docker CE and Compose plugin installation
- `dev`: development tooling
- `networking`: Tailscale, cloudflared, firewall rules

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
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | bash

export RESTIC_REPOSITORY="/mnt/backup"
export RESTIC_PASSWORD="replace-this-password"
cd /opt/server-config
./scripts/restore.sh
```

## CI

CI validates infrastructure changes with:

- `ansible-playbook --syntax-check` for `ansible/server.yml`
- `ansible-lint --profile=min ansible/server.yml`
- `molecule test --all` for the Ansible Molecule scenarios
- `bash -n` and `shellcheck` for `bootstrap/bootstrap.sh`
- bootstrap argument parsing checks
- a Debian integration run of bootstrap in CI mode
