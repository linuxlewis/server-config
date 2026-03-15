#!/usr/bin/env bash
set -euo pipefail

# Reproducible Debian Dev Server - Bootstrap Script
# Usage: curl -fsSL <repo-url>/bootstrap/bootstrap.sh | bash
# Or:    ./bootstrap.sh [--repo-url <url>] [--branch <branch>] [--dir <path>]

REPO_URL="${REPO_URL:-https://github.com/YOUR_USER/server-config.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/server-config}"
SKIP_ANSIBLE="${SKIP_ANSIBLE:-0}"
SKIP_SERVICES="${SKIP_SERVICES:-0}"
ANSIBLE_EXTRA_VARS="${ANSIBLE_EXTRA_VARS:-}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-url)      REPO_URL="$2"; shift 2 ;;
        --branch)        REPO_BRANCH="$2"; shift 2 ;;
        --dir)           INSTALL_DIR="$2"; shift 2 ;;
        --skip-ansible)  SKIP_ANSIBLE=1; shift ;;
        --skip-services) SKIP_SERVICES=1; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() { echo "[bootstrap] $*"; }

detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

install_dependencies() {
    local os
    os=$(detect_os)
    if [ "$os" != "debian" ]; then
        log "Unsupported OS: $os. This bootstrap script supports Debian only."
        exit 1
    fi

    log "Installing dependencies (Debian)..."
    apt-get update
    apt-get install -y \
        git \
        ansible \
        python3-pip \
        curl \
        wget \
        software-properties-common
}

clone_repo() {
    if [ -d "$INSTALL_DIR/.git" ]; then
        log "Repo already exists at $INSTALL_DIR, pulling latest..."
        git -C "$INSTALL_DIR" pull origin "$REPO_BRANCH"
    else
        log "Cloning infrastructure repo..."
        git clone --branch "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    fi
}

run_ansible() {
    local ansible_cmd

    [ "$SKIP_ANSIBLE" = "1" ] && {
        log "Skipping Ansible playbook (--skip-ansible enabled)"
        return
    }

    log "Running Ansible playbook..."
    cd "$INSTALL_DIR/ansible"
    ansible_cmd=(ansible-playbook -i inventory.ini server.yml --diff)

    if [ -n "$ANSIBLE_EXTRA_VARS" ]; then
        ansible_cmd+=(--extra-vars "$ANSIBLE_EXTRA_VARS")
    fi

    "${ansible_cmd[@]}"
}

start_services() {
    [ "$SKIP_SERVICES" = "1" ] && {
        log "Skipping Docker Compose startup (--skip-services enabled)"
        return
    }

    log "Starting Docker Compose stack..."
    cd "$INSTALL_DIR/docker"
    docker compose up -d
}

main() {
    log "Starting bootstrap ($(date))"
    log "OS: $(detect_os)"
    log "Repo: $REPO_URL (branch: $REPO_BRANCH)"
    log "Install dir: $INSTALL_DIR"

    # Must run as root
    if [ "$(id -u)" -ne 0 ]; then
        log "Error: must run as root"
        exit 1
    fi

    install_dependencies
    clone_repo
    run_ansible
    start_services

    log "Bootstrap complete!"
    log "Server is ready."
}

main "$@"
