#!/usr/bin/env bash
#
# 0.new_server.sh - Initial setup & hardening for a fresh Ubuntu server.
#
# Steps (each is optional and confirmed interactively):
#   1. Create a new sudo-enabled user with a home directory.
#   2. Disable remote root login over SSH.
#   3. Change the SSH server listening port.
#
# Target OS : Ubuntu (uses apt/systemd/sshd conventions)
# Privileges: must be run as root (or via sudo).
#
set -euo pipefail

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------
SSHD_CONFIG="/etc/ssh/sshd_config"

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

# Ask a yes/no question. Returns 0 for yes, 1 for no. Default is no.
confirm() {
    local prompt="$1" reply
    read -r -p "$prompt [y/N]: " reply || reply=""
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Restart the SSH service, handling both 'ssh' and 'sshd' unit names.
restart_ssh() {
    if systemctl list-unit-files 2>/dev/null | grep -q '^ssh\.service'; then
        systemctl restart ssh
    elif systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then
        systemctl restart sshd
    else
        warn "Could not detect ssh service unit; please restart SSH manually."
        return 1
    fi
    ok "SSH service restarted."
}

# Set (or add) a key/value directive in sshd_config idempotently.
set_sshd_directive() {
    local key="$1" value="$2"
    if grep -Eq "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
        sed -ri "s|^[[:space:]]*#?[[:space:]]*(${key})[[:space:]]+.*|\1 ${value}|" "$SSHD_CONFIG"
    else
        printf '%s %s\n' "$key" "$value" >>"$SSHD_CONFIG"
    fi
}

#-----------------------------------------------------------------------------
# Pre-flight checks
#-----------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    err "This script must be run as root (try: sudo $0)."
    exit 1
fi

#-----------------------------------------------------------------------------
# Step 1: Create a new sudo user
#-----------------------------------------------------------------------------
step_create_user() {
    local username
    read -r -p "Enter the username to create: " username

    if [[ -z "$username" ]]; then
        err "No username provided; skipping user creation."
        return 1
    fi

    # Validate against Linux username conventions.
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        err "Invalid username '$username'. Use lowercase letters, digits, '-' or '_'."
        return 1
    fi

    if id "$username" &>/dev/null; then
        warn "User '$username' already exists; ensuring sudo membership only."
    else
        log "Creating user '$username' with home directory..."
        adduser --gecos "" "$username"   # prompts for password interactively
        ok "User '$username' created."
    fi

    log "Adding '$username' to the sudo group..."
    usermod -aG sudo "$username"
    ok "User '$username' is now a sudoer."
}

#-----------------------------------------------------------------------------
# Step 2: Disable remote root login over SSH
#-----------------------------------------------------------------------------
step_disable_root_login() {
    log "Disabling remote root login in $SSHD_CONFIG..."
    cp -a "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    set_sshd_directive "PermitRootLogin" "no"
    ok "PermitRootLogin set to 'no'."
    restart_ssh || true
}

#-----------------------------------------------------------------------------
# Step 3: Change the SSH server port
#-----------------------------------------------------------------------------
step_change_ssh_port() {
    local port
    read -r -p "Enter the new SSH port number: " port

    if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        err "Invalid port '$port'. Must be a number between 1 and 65535."
        return 1
    fi

    log "Setting SSH port to $port in $SSHD_CONFIG..."
    cp -a "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    set_sshd_directive "Port" "$port"
    ok "SSH Port set to $port."

    # Open the new port in UFW if the firewall is active.
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        log "UFW is active; allowing new SSH port $port/tcp..."
        ufw allow "${port}/tcp"
        ok "UFW rule added for port $port/tcp."
    fi

    warn "Reconnect on the new port after restart: ssh -p $port <user>@<host>"
    restart_ssh || true
}

#-----------------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------------
main() {
    log "Ubuntu new-server setup & hardening"
    echo

    if confirm "Step 1) Create a new sudo user?"; then
        step_create_user || warn "Step 1 did not complete."
    else
        log "Skipping step 1."
    fi
    echo

    if confirm "Step 2) Disable remote root SSH login?"; then
        step_disable_root_login || warn "Step 2 did not complete."
    else
        log "Skipping step 2."
    fi
    echo

    if confirm "Step 3) Change the SSH server port?"; then
        step_change_ssh_port || warn "Step 3 did not complete."
    else
        log "Skipping step 3."
    fi
    echo

    ok "Done."
}

main "$@"
