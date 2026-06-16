#!/usr/bin/env bash
#
# firewall_iptables_ports.sh - Open incoming ports using iptables on Ubuntu.
#
# - Prompts for a list of ports to allow.
# - Adds iptables rules permitting incoming traffic on those ports.
# - Persists rules across reboots via iptables-persistent (netfilter-persistent).
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
# Ensure iptables and the persistence package are installed
#-----------------------------------------------------------------------------
if ! command -v iptables &>/dev/null; then
    log "iptables not found; installing..."
    apt-get update -y
    apt-get install -y iptables
    ok "iptables installed."
fi

if ! command -v netfilter-persistent &>/dev/null; then
    log "Installing iptables-persistent for rule persistence..."
    # Preseed answers so the installer does not prompt to save current rules.
    echo "iptables-persistent iptables-persistent/autosave_v4 boolean false" | debconf-set-selections
    echo "iptables-persistent iptables-persistent/autosave_v6 boolean false" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    ok "iptables-persistent installed."
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
    port="${rule%%/*}"
    proto="${rule##*/}"

    # Insert only if an identical ACCEPT rule does not already exist (idempotent).
    if iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT &>/dev/null; then
        warn "Rule for ${rule} already exists; skipping."
    else
        log "Allowing incoming ${rule}..."
        iptables -A INPUT -p "$proto" --dport "$port" -j ACCEPT
    fi
done

#-----------------------------------------------------------------------------
# Persist rules across reboots
#-----------------------------------------------------------------------------
log "Saving iptables rules for persistence..."
netfilter-persistent save
systemctl enable netfilter-persistent &>/dev/null || true

ok "Firewall rules applied and will persist after reboot."
iptables -L INPUT -n --line-numbers
