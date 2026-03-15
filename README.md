# Reproducible Linux Dev Server

This repo bootstraps and manages a personal Linux development server. The host is configured with Ansible, application services run in Docker, and the intended workflow is to rebuild the machine from Git rather than hand-configure it over SSH.

Use it when you want to:

- bring up a fresh Fedora, Ubuntu, or Debian server quickly
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

- you are on a fresh or mostly clean Fedora, Ubuntu, or Debian server
- you can run commands as `root`
- GitHub is reachable from the machine so the repo can be cloned
- host ports `80` and `443` are available
- you will set runtime secrets before expecting Docker Compose to succeed

Optional environment variables:

- `TAILSCALE_AUTHKEY` to join the machine to Tailscale during Ansible setup
- `RESTIC_REPOSITORY` and `RESTIC_PASSWORD` for backups

## Bootstrap A Fresh Server

Run the bootstrap script as `root`. It installs dependencies, clones the repo into `/opt/server-config`, runs Ansible, and starts the Docker stack.

`postgres` requires `POSTGRES_PASSWORD`. Set it before bootstrap or `docker compose up -d` will fail.

```bash
export POSTGRES_PASSWORD='replace-this'
export CODE_SERVER_PASSWORD='replace-this-too'
curl -fsSL https://raw.githubusercontent.com/linuxlewis/server-config/main/bootstrap/bootstrap.sh | \
  REPO_URL=https://github.com/linuxlewis/server-config.git bash
```

Useful overrides:

```bash
REPO_BRANCH=main INSTALL_DIR=/opt/server-config bash bootstrap/bootstrap.sh
```

## Persist Runtime Configuration

After bootstrap, create `docker/.env` so future Compose runs do not depend on whatever happens to be in your shell.

```bash
cd /opt/server-config
cp docker/.env.example docker/.env
```

Set at least:

- `POSTGRES_PASSWORD`
- `CODE_SERVER_PASSWORD`

The example file lives at [`docker/.env.example`](docker/.env.example).

## Day-To-Day Workflow

Most changes follow this loop:

1. Edit Ansible, Compose, or config files in this repo.
2. Re-run Ansible from `ansible/`.
3. Re-run Docker Compose from `docker/` if service definitions changed.
4. Verify the affected service.

Common commands:

```bash
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff

cd /opt/server-config/docker
docker compose up -d
docker compose ps
docker compose logs -f caddy
```

If you want Tailscale configured during an Ansible run:

```bash
export TAILSCALE_AUTHKEY='tskey-auth-...'
cd /opt/server-config/ansible
ansible-playbook -i inventory.ini server.yml --diff
```

## What Gets Installed

Ansible configures:

- a `dev` user with Docker access
- base packages such as `git`, `tmux`, `htop`, `curl`, `jq`, and `fail2ban`
- Docker CE and the Compose plugin
- Tailscale, Cloudflare tooling, and basic firewall rules
- persistent data directories under `/opt/services`
- a daily `server-config-update.timer` that pulls `main` and re-runs the playbook

The Docker stack currently includes:

- `caddy` on `80` and `443`
- `code-server` on `127.0.0.1:8080`
- `postgres` with data in `/opt/services/postgres`
- `redis` with data in `/opt/services/redis`

## Validate Changes Locally

These checks are lightweight, but they catch most syntax and templating mistakes before you touch a real server:

```bash
cd ansible
ansible-playbook -i inventory.ini server.yml --syntax-check
ansible-playbook -i inventory.ini server.yml --check --diff

cd ../docker
docker compose --env-file .env.example config -q

cd ..
bash -n bootstrap/bootstrap.sh scripts/backup.sh scripts/restore.sh
```

They do not replace testing on a disposable machine.

## Backup And Restore

Backups use [restic](https://restic.net/) and include `/home`, `/opt/services`, and a PostgreSQL dump written to `/opt/backups/postgres_dump.sql`.

Set:

- `RESTIC_REPOSITORY`
- `RESTIC_PASSWORD`

Then run:

```bash
./scripts/backup.sh
./scripts/restore.sh
./scripts/restore.sh <snapshot-id>
```

## Gotchas

- Run bootstrap as `root`; the script exits otherwise.
- The bootstrap script does not create `docker/.env` for you.
- The inventory targets `localhost`, so this repo is meant to run on the server itself by default.
- `code-server` binds to `127.0.0.1:8080`, so expose it intentionally through your network setup.
- The auto-update systemd timer pulls `main` every day. If you test changes on another branch, do not assume the machine will stay there unless you change that behavior.
