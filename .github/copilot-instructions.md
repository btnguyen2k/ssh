# Copilot instructions for `ssh`

## Purpose

This repository hosts **server setup and hardening scripts** (see `README.md`).
It is MIT licensed (`LICENSE`, © Thanh Ba Nguyen).

> **Current state:** The repository is a fresh scaffold — only `README.md` and
> `LICENSE` exist so far. There is no build system, test suite, or source code
> yet. The conventions below are guidance for adding the first scripts; update
> this file as real structure, tooling, and commands are introduced.

## Audience & documentation style

The reader/user is a **senior system administrator**. Keep `README.md` short and
concise — focus on the high-level business logic (what each script does and
why). Do **not** include detailed run instructions, usage examples, or
step-by-step command walkthroughs; assume the reader knows how to run scripts.
Prefer one-liner step summaries over verbose explanations.

## Conventions for new scripts

Since this repo is about server setup/hardening, prefer:

- **POSIX shell / Bash** for portability across target servers. Start scripts
  with `#!/usr/bin/env bash` and `set -euo pipefail` so failures stop execution
  rather than leaving a server half-configured.
- **Idempotency** — hardening scripts may be re-run; check current state before
  applying a change (e.g. test before appending to config files).
- **No secrets in the repo** — never commit passwords, keys, or host-specific
  credentials. Use parameters, environment variables, or external secret stores.
- **Document required privileges** — note when a script needs `root`/`sudo`.
- **Make scripts executable** (`chmod +x`) and keep a short header comment
  describing what the script does, target OS, and any prerequisites.

## Validation

No project-specific commands are defined yet. Once shell scripts exist, the
expected baseline checks are:

- Lint: `shellcheck path/to/script.sh`
- Format: `shfmt -d path/to/script.sh`

Add and document any actual build/test/lint commands here when they are
established.
