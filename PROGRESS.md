# Progress

## Current Phase

Version 1.1.2 ships the Issue #2 network-test fix, shared log-dir/soft-fail helpers, standardized one-line bootstrap commands, and synchronized release metadata. Remaining longer-term work includes deeper LDNMP delegation into focused installers and richer mocked pkg/systemd suites.

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

- Updated `version.json`, config, launcher, README badge, and version policy to 1.1.2
- Updated `CHANGELOG.md`, `TASKS.md`, `PROGRESS.md`, `PRIVACY.md`, and development guidance
- Recorded the next safety round around the four first-party `other_tools` scripts

## Next Modernization Round

- Split the LDNMP compatibility facade into calls to focused maintained installers
- Add mocked behavioral tests for package managers, systemd, downloads, and destructive cleanup paths
- Add non-interactive dry-run/status modes to additional state-changing utilities
- Review project-owned installer archives for checksum or signature validation where upstream publishes verifiable metadata

## Success Criteria For Next Release

- No first-party utility overwrites a whole shared system configuration file
- All destructive utility actions offer a clear preview, confirmation, and rollback path
- Third-party installers use architecture-aware, temporary-file wrappers where practical
- Behavioral tests supplement the existing syntax and pattern validation
