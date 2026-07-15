# Progress

## Current Phase

Version 1.1.1 closes the persistent-command startup gap from Issue #1. The launcher now creates the managed `vps` command on the first interactive root run while retaining explicit install, opt-out, non-interactive, and collision-safe behavior.

## Completed

### Launcher and framework

- Rebuilt `vps.sh` around real repository modules with local-file and remote download paths
- Added temporary-file isolation, syntax checks, download fallbacks, and confirmation for third-party commands
- Added responsive terminal widths, CJK-aware alignment, compact narrow-screen rows, and shared UI helpers
- Added persistent `vps` command installation and a legacy-only `vps_scripts.sh` compatibility handoff
- Added idempotent automatic `vps` command installation for first interactive root launches without overwriting unrelated commands
- Removed the synchronous third-party usage-counter request from launcher startup

### Menus and tools

- Added Hysteria2, WP Panel, Caddy, Portainer, Komari, acme.sh, tmux, oh-my-zsh, Uptime Kuma, Tailscale, FRP, cloudflared, FileBrowser, and additional community diagnostics
- Added `scripts/other_tools/modern_cli.sh` for btop, ripgrep, fd, bat, fzf, jq, ncdu, and restic
- Added `--status`, `--install`, and `--help` to the modern CLI toolkit
- Kept the toolkit on configured distribution repositories without adding remote installer pipelines

### Maintained script hardening

- Enabled `set -euo pipefail` across all 21 service installers and all network/performance scripts
- Replaced predictable temporary paths with `mktemp` in the affected maintained scripts
- Removed first-party `curl | sh` patterns from the hardened service installers
- Fixed installer quoting, input validation, cleanup, package-manager, strict-mode, and build concurrency defects
- Moved PostgreSQL WAL archives outside the primary data directory
- Added shared `die()` and build-from-source helpers

### Validation and CI

- 34 repository validation scripts now cover paths, categories, UI, strict mode, installers, release metadata, privacy, and execution safety
- Release metadata validation keeps the version, date, changelog, README, version policy, config, and launcher synchronized
- ShellCheck error findings now fail CI instead of being ignored
- Fixed `validate_update_scripts_legacy.sh` to match the removed legacy directory
- Launcher path, core asset, menu coverage, and line-ending policies remain enforced

### Documentation and release metadata

- Updated `version.json`, config, launcher, README badge, and version policy to 1.1.1
- Updated `CHANGELOG.md`, `TASKS.md`, `PROGRESS.md`, `PRIVACY.md`, and development guidance
- Recorded the next safety round around the four first-party `other_tools` scripts

## Next Safety Round

- Change BBR to a dedicated `/etc/sysctl.d/` drop-in instead of replacing `/etc/sysctl.conf`
- Make Swap changes idempotent and preserve unrelated swap devices and `/etc/fstab` entries
- Rework Fail2ban defaults for distro-specific logging and existing local configuration
- Validate and escape Nezha agent inputs before writing systemd configuration
- Replace remaining third-party `curl | sh` and architecture-specific commands with reviewed wrappers

## Success Criteria For Next Release

- No first-party utility overwrites a whole shared system configuration file
- All destructive utility actions offer a clear preview, confirmation, and rollback path
- Third-party installers use architecture-aware, temporary-file wrappers where practical
- Behavioral tests supplement the existing syntax and pattern validation
