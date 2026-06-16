#!/usr/bin/env bash
#
# firewall_ufw_ports.sh - Open incoming ports using UFW on Ubuntu.
#
# - Prompts for a list of ports to allow.
# - Adds UFW rules permitting incoming traffic on those ports.
# - UFW rules persist across reboots by design (enabled as a service).
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
# Ensure UFW is installed
#-----------------------------------------------------------------------------
if ! command -v ufw &>/dev/null; then
    log "UFW not found; installing..."
    apt-get update -y
    apt-get install -y ufw
    ok "UFW installed."
fi

#-----------------------------------------------------------------------------
# Collect ports to open
#-----------------------------------------------------------------------------
# Accepts space/comma separated entries. Each entry is either:
#   - a port number            -> opens tcp (e.g. 80)
#   - port/proto               -> opens that protocol (e.g. 53/udp)
echo "Enter the port(s) to open, separated by spaces or commas."
echo "Use 'port/proto' for a specific protocol (e.g. 80 443 53/udp). Default proto is tcp."
read -r -p "Ports: " ports_input

# Normalise separators (commas -> spaces) and split into an array.
read -r -a ports <<<"${ports_input//,/ }"

if [[ "${#ports[@]}" -eq 0 ]]; then
    err "No ports provided; nothing to do."
    exit 1
fi

#-----------------------------------------------------------------------------
# Validate and apply rules
#-----------------------------------------------------------------------------
valid_rules=()
for entry in "${ports[@]}"; do
    [[ -z "$entry" ]] && continue

    port="${entry%%/*}"
    proto="tcp"
    [[ "$entry" == */* ]] && proto="${entry##*/}"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || ((port < 1 || port > 65535)); then
        warn "Skipping invalid port '$entry' (must be 1-65535)."
        continue
    fi
    if [[ "$proto" != "tcp" && "$proto" != "udp" ]]; then
        warn "Skipping '$entry' (protocol must be tcp or udp)."
        continue
    fi

    valid_rules+=("${port}/${proto}")
done

if [[ "${#valid_rules[@]}" -eq 0 ]]; then
    err "No valid ports to open; aborting."
    exit 1
fi

for rule in "${valid_rules[@]}"; do
    log "Allowing incoming ${rule}..."
    ufw allow "${rule}"
done

#-----------------------------------------------------------------------------
# Enable UFW so rules persist across reboots
#-----------------------------------------------------------------------------
if ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw reload
else
    warn "UFW is inactive; enabling it now (rules persist across reboots)."
    # --force avoids the interactive 'this may disrupt SSH' confirmation.
    ufw --force enable
fi

# Ensure the service starts on boot.
systemctl enable ufw &>/dev/null || true

ok "Firewall rules applied and will persist after reboot."
ufw status verbose
