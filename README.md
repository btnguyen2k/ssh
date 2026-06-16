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

## License

MIT — see [LICENSE.md](LICENSE.md).
