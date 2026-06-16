# ssh

Server Setup and Hardening scripts.

## Ubuntu

### `ubuntu/0.new_server.sh`

Interactive initial setup & hardening for a fresh Ubuntu server. Each step is confirmed with a prompt and can be skipped.

Steps:

1. Create a new sudo user.
2. Disable remote root SSH login.
3. Change the SSH port.

### `ubuntu/install_podman.sh`

Installs and configures Podman, with rootless support and auto-start on boot.

### `ubuntu/firewall_ufw_ports.sh`

Prompts for a list of ports and opens them for incoming traffic via UFW. Rules persist across reboots.

### `ubuntu/firewall_iptables_ports.sh`

Same as above but uses iptables, persisting rules via iptables-persistent.

## License

MIT — see [LICENSE.md](LICENSE.md).
