#!/usr/bin/env bash
#
# install_podman.sh - Install and configure Podman on Ubuntu.
#
# - Installs Podman from the Ubuntu repositories.
# - Configures rootless usage and enables the Podman socket (Docker-compatible
#   API) plus auto-restart of containers on boot.
# - Enables lingering so user services survive logout / start after reboot.
#
# Target OS : Ubuntu
# Privileges: must be run as root (or via sudo).
#
set -euo pipefail

log()  { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
    err "This script must be run as root (try: sudo $0)."
    exit 1
fi

#-----------------------------------------------------------------------------
# Install Podman
#-----------------------------------------------------------------------------
log "Updating package index..."
apt-get update -y

log "Installing Podman and rootless dependencies..."
apt-get install -y podman uidmap slirp4netns fuse-overlayfs

ok "Podman installed: $(podman --version)"

#-----------------------------------------------------------------------------
# System-wide configuration
#-----------------------------------------------------------------------------
# Enable the system Podman socket so containers/tools can talk to the API and
# so the service is available after reboot.
log "Enabling system Podman socket (auto-start on boot)..."
systemctl enable --now podman.socket
ok "podman.socket enabled and started."

# Auto-update / restart units (no-op unless containers opt in via the
# 'io.containers.autoupdate' label, but enabling makes it available on boot).
if systemctl list-unit-files 2>/dev/null | grep -q '^podman-restart\.service'; then
    log "Enabling podman-restart.service (restarts containers on boot)..."
    systemctl enable podman-restart.service
    ok "podman-restart.service enabled."
fi

#-----------------------------------------------------------------------------
# Rootless setup for the invoking (non-root) user, if any
#-----------------------------------------------------------------------------
# When run via sudo, SUDO_USER is the real user we should configure for rootless.
TARGET_USER="${SUDO_USER:-}"

if [[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]]; then
    log "Configuring rootless Podman for user '$TARGET_USER'..."

    # Ensure subuid/subgid ranges exist for rootless containers.
    if ! grep -q "^${TARGET_USER}:" /etc/subuid; then
        usermod --add-subuids 100000-165535 "$TARGET_USER"
    fi
    if ! grep -q "^${TARGET_USER}:" /etc/subgid; then
        usermod --add-subgids 100000-165535 "$TARGET_USER"
    fi

    # Enable lingering so the user's Podman services start at boot without login.
    loginctl enable-linger "$TARGET_USER"

    # Enable the user-level Podman socket and restart service.
    sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" \
        systemctl --user enable --now podman.socket 2>/dev/null \
        || warn "Could not enable user podman.socket (may need an active user session)."

    ok "Rootless Podman configured for '$TARGET_USER'."
else
    warn "No non-root SUDO_USER detected; skipped rootless per-user setup."
    warn "For rootless use later, run as that user: systemctl --user enable --now podman.socket"
fi

#-----------------------------------------------------------------------------
# Verify
#-----------------------------------------------------------------------------
log "Verifying Podman installation..."
podman info >/dev/null && ok "Podman is working."

ok "Done. Podman is installed, configured, and set to start on boot."
