# Progress

## Current Phase

Version 1.1.7 hardens the first-party system, network, and performance tools after the 1.1.5–1.1.6 third-party catalog refresh. `install_deps` now matches the mutator contract (`--dry-run`/`--yes`/`resolve_log_dir`); performance benchmarks soft-fail package installs; auto-installing test scripts gain `--skip-install`; disk `--size` and network `--client` are validated. The LDNMP installer stays a single combined installer.

Next work: mocked pkg/systemd suites for real (non-preview) execution paths, and extend checksum verification to more project-owned installers.

## Catalog Review Status

| Menu | Status | Release |
|---|---|---|
| Service install | Reviewed: Coolify, Dokploy, Dockge, Nginx Proxy Manager added; AMH moved last | 1.1.5 |
| Other tools | Reviewed: Beszel, first-party FRP added; Uptime Kuma 2; FileBrowser labelled archived | 1.1.5 |
| Community | Reviewed: NextTrace URL fixed; JCNF, BlueSkyXN, i-abc Speedtest labelled and moved last; re-checked in 1.1.6, no changes | 1.1.5 |
| Proxy tools | Reviewed: S-UI, v2ray-agent, official Hysteria2/Xray added; x-ui-yg and X-Panel URLs updated | 1.1.6 |
| Network test | First-party; `--skip-install` on auto-installing scripts | 1.1.7 |
| Performance test | First-party; soft-fail installs, `--skip-install`, CLI validation | 1.1.7 |
| System tools | First-party; `install_deps` dry-run/yes/log-dir aligned with other mutators | 1.1.7 |

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

- Fixed Issue #2 across all five `scripts/network_test/` modules with `${1:-}` guards, soft-fail probes, and `init_script_dirs` log/report fallback
- Added shared `init_script_dirs()` and `run_soft()` helpers plus `tests/validate_network_test_resilience.sh`
- Hardened all four `performance_test/` modules with the same log-dir and soft-fail patterns
- Added `--status`/`--dry-run` to swap/fail2ban, CLI modes to bbr, and interrupt-aware launcher messaging
- Added `resolve_log_dir()` and wired system_tools log/backup fallbacks; `full_uninstall.sh --dry-run`; `ldnmp.sh --status`
- Added `validate_category_resilience.sh` and `validate_mocked_runtime_smoke.sh`
- Enabled `set -euo pipefail` across all 21 service installers and all network/performance scripts
- Replaced predictable temporary paths with `mktemp` in the affected maintained scripts
- Removed first-party `curl | sh` patterns from the hardened service installers
- Fixed installer quoting, input validation, cleanup, package-manager, strict-mode, and build concurrency defects
- Moved PostgreSQL WAL archives outside the primary data directory
- Added shared `die()` and build-from-source helpers
- Hardened the Nezha agent installer with input validation, isolated archive verification, systemd escaping, and unit verification
- Moved the Nezha agent to the current `nezhahq/agent` v1+ release with upstream `checksums.txt` SHA-256 verification and a `600` config file
- Added `--dry-run`/`--target`/`--yes` to the three legacy uninstall helpers with `/var/backups/vps_scripts` backups, in-process batch mode, `/swapfile`-only swap rollback, and `sshd -t`-guarded SSH restore
- Added `--status`/`--dry-run` to the Docker installer wrapper
- Hardened first-party tools (1.1.7): install_deps `--dry-run`/`--yes`/`resolve_log_dir`; performance soft-fail installs; `--skip-install` for network/performance auto-install paths; disk `--size` and network `--client` validation
- Refreshed the proxy tools menu (1.1.6): added S-UI, mack-a v2ray-agent, official Hysteria2/Xray-core installers; moved x-ui-yg and X-Panel to current upstream URLs
- Refreshed the service install, other tools, and community menus (1.1.5): added Coolify, Dokploy, Dockge, Nginx Proxy Manager, Beszel; replaced the dead FRP entry with a first-party checksum-verified installer; moved archived/stale entries to the end
- Added `--dry-run` to optimize/hostname/timezone/update system tools; fixed timezone path traversal, unvalidated SSH baseline reloads, inverted yum/dnf reboot detection, and stdin-EOF menu loops
- Replaced first-party remote shell pipelines in LDNMP, dependency installation, Jenkins build tooling, and bandwidth testing with validated temporary scripts
- Routed third-party project installer entries through launcher confirmation, isolated download, syntax validation, and execution
- Made the LDNMP compatibility installer validate requested PHP/database choices, protect generated credentials, and require explicit demo-site opt-in
- Separated non-interactive system-update confirmation from reboots, which now require explicit `--reboot` opt-in

### Validation and CI

- Repository validation scripts now cover paths, categories, UI, strict mode, installers, release metadata, privacy, execution safety, upgrade-hardening, network/performance resilience, and mocked helper smoke checks
- Release metadata validation keeps the version, date, changelog, README, version policy, config, and launcher synchronized
- ShellCheck error findings now fail CI instead of being ignored
- Fixed `validate_update_scripts_legacy.sh` to match the removed legacy directory
- Launcher path, core asset, menu coverage, and line-ending policies remain enforced

### Documentation and release metadata

- Updated `version.json`, config, launcher, README badge, and version policy to 1.1.7
- Updated `CHANGELOG.md`, `TASKS.md`, `PROGRESS.md`, `PRIVACY.md`, and development guidance
- Recorded the next safety round around the four first-party `other_tools` scripts

## Next Modernization Round

- Re-run the third-party catalog check (URL liveness, archived/stale upstreams) each release
- Add mocked behavioral tests for real (non-preview) package-manager, systemd, and download paths
- Extend checksum or signature validation to other project-owned installer archives where upstream publishes verifiable metadata

## Success Criteria For Next Release

- No first-party utility overwrites a whole shared system configuration file
- All destructive utility actions offer a clear preview, confirmation, and rollback path
- Third-party installers use architecture-aware, temporary-file wrappers where practical
- Behavioral tests supplement the existing syntax and pattern validation
