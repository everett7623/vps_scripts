# Tasks

## P0 (done)

- [x] Refactor `scripts/system_tools/update_system.sh` to remove avoidable `eval`
- [x] Review `lib/common_functions.sh` for helper safety, quoting, and temp-file handling
- [x] Decide `vps_scripts.sh` as legacy-only compatibility handoff
- [x] Fix cross-script `VERSION_ID` unbound-variable crash (9 installers)
- [x] Fix `TOTAL_MEM` unbound crash in postgresql.sh `--shared-buffers` path
- [x] Fix dead `PIPESTATUS` check in kubernetes.sh under `set -o pipefail`
- [x] Fix `set -e` preempting pyenv pipeline guard in python.sh
- [x] Fix `nproc`→`make -j0` (unlimited) in ruby.sh and redis.sh

## P0 (completed safety round)

- [x] Make `bbr.sh` use a project-owned `/etc/sysctl.d/` drop-in and reversible backup
- [x] Make `swap.sh` idempotent without `swapoff -a` or duplicate `/etc/fstab` entries
- [x] Preserve existing Fail2ban configuration and support distro-specific SSH logging
- [x] Validate and escape all Nezha systemd unit inputs
- [x] Route third-party project installer scripts through isolated download, syntax validation, confirmation, and execution paths

## P1 (done)

- [x] Review and harden `scripts/service_install/nodejs.sh`
- [x] Review and harden `scripts/service_install/docker.sh`
- [x] Review and harden `scripts/service_install/go.sh`
- [x] Review and harden `scripts/service_install/java.sh`
- [x] Review and harden `scripts/service_install/nginx.sh`
- [x] Review and harden `scripts/service_install/python.sh`
- [x] Review and harden `scripts/service_install/kubernetes.sh`
- [x] Review and harden `scripts/service_install/mysql.sh`
- [x] Review and harden `scripts/service_install/postgresql.sh`
- [x] Review and harden `scripts/service_install/redis.sh`
- [x] Review and harden `scripts/service_install/ruby.sh`
- [x] Add per-installer safety tests for all 11 core installers
- [x] Add `bash -n` validation to `run_remote_script_url()` and `run_remote_command()`
- [x] Fix wget `--connect-timeout` and `pipefail` gaps in launcher download/execution functions
- [x] Add service-install launcher coverage test
- [x] Add execution-safety, UI-framework, loader-performance regression tests
- [x] Migrate update history from `update_log.sh` into `CHANGELOG.md`

## P2 (in progress)

- [x] Refresh launcher/shared UI alignment, hierarchy, and narrow-terminal layout
- [x] Add CJK display-width handling and responsive UI regression coverage
- [x] Normalize logging conventions across system_tools modules
- [x] Optimize module loading speed and slow-network behavior
- [x] Standardize script headers and encoding (LF, no BOM, `#!/bin/bash`)
- [x] Remove inactive legacy `update_scripts/` and retain a regression boundary
- [x] Add Hysteria2 to Proxy Tools menu
- [x] Add WP Panel to Service Install menu
- [x] Add `set -euo pipefail` to remaining 8 service_install scripts (1panel, aapanel, amh, btpanel, cyberpanel, jenkins, ruby, rust)
- [x] Refactor `network_test/` category for consistent structure and output
- [x] Refactor `performance_test/` category for consistent structure and output
- [x] Add validated arguments to the third-party script wrapper for official installer flags
- [ ] Add more non-interactive safety flags where appropriate

## P3 (new)

- [x] Remove direct remote shell pipelines from first-party LDNMP, dependency, Jenkins, and bandwidth-test flows
- [x] Add an upgrade-hardening regression test for launcher, Nezha, LDNMP, and bandwidth-test policies
- [x] Add LDNMP input, credential-disclosure, and demo-site safety regression coverage
- [x] Require explicit `--reboot` for non-interactive system-update restarts
- [x] Fix Issue #2 network-test menu failures (`unbound $1`, single-node `set -e` abort, log-dir fallback)
- [x] Add `init_script_dirs` / `run_soft` helpers and `validate_network_test_resilience.sh`
- [x] Harden `performance_test/` with the same log-dir and soft-fail patterns
- [x] Add `--status`/`--dry-run` flags for swap/fail2ban and CLI modes for bbr
- [x] Batch-scan remaining categories for `set -u` / AND-list mkdir / probe-abort defects
- [x] Add `resolve_log_dir`, system_tools log fallback, uninstall dry-run, LDNMP `--status`, mocked runtime smoke tests

## P3 (existing)

- [x] Extract repeated build-from-source pattern into shared helper in `lib/common_functions.sh`
- [x] Add `die()` helper function to consolidate 30+ scattered `print_error; exit 1` patterns
- [x] Create `scripts/service_install/wppanel.sh` first-party wrapper (currently inline `run_remote_command`)
- [x] Add `tests/validate_service_install_strict_mode.sh` to enforce `set -euo pipefail` coverage
- [x] Add shellcheck CI or pre-commit hook
- [x] Consider moving WAL archive directory outside PostgreSQL DATA_DIR for disaster recovery

## 1.1.0 release

- [x] Add the first-party modern CLI toolkit with non-interactive flags
- [x] Add modern CLI and launcher privacy regression tests
- [x] Enforce synchronized version, release date, changelog, README, and runtime metadata
- [x] Make ShellCheck errors fail CI
- [x] Remove the implicit launcher usage-counter request
- [x] Repair the removed `update_scripts/` validation boundary
- [x] Synchronize version and launcher style metadata at `1.1.0`

## 1.1.1 release

- [x] Automatically create the managed `vps` command on the first interactive root launch
- [x] Preserve explicit `8 → 1` and `--install` command installation paths
- [x] Protect unrelated `/usr/local/bin/vps` commands from automatic overwrite
- [x] Cover forced, disabled, non-interactive, and collision behavior
- [x] Synchronize patch-release metadata and user documentation at `1.1.1`

## 1.1.2 release

- [x] Fix Issue #2 network-test menu failures and extend soft-fail / log-dir hardening
- [x] Standardize public bootstrap commands to one-line `/tmp/vps.sh` form
- [x] Synchronize version, date, changelog, README badge, VERSIONING, CLAUDE, and release validation at `1.1.2`
- [x] Add `tests/validate_bootstrap_command.sh` to keep docs/launcher hints aligned

## 1.1.3 release

- [x] Add `--help`/`--list`/`--dry-run`/`--yes`/`--target` to the three legacy uninstall helpers
- [x] Move uninstall backups to `/var/backups/vps_scripts` and make batch mode run in-process
- [x] Limit swap rollback to `/swapfile`; keep data directories unless `--purge-data`
- [x] Repair the Nezha installer for `nezhahq/agent` v1+ with SHA-256 verification and add `--status`/`--dry-run`/`--uninstall`
- [x] Add `--status`/`--dry-run` to the Docker installer wrapper
- [x] Add executed dry-run behavior coverage (`tests/validate_dry_run_behavior.sh`)
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.3`

## 1.1.4 release

- [x] Add `--dry-run` to optimize, hostname, timezone, and update system tools
- [x] Fix timezone path traversal, SSH baseline validation, yum/dnf reboot detection, and stdin-EOF menu loops
- [x] Extend `tests/validate_dry_run_behavior.sh` to execute the system-tool previews
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.4`

## Ongoing

- [ ] Per-category review: add popular maintained tools/projects, deprioritize outdated entries (see AGENTS.md "Catalog Freshness")
- [ ] Mocked behavioral tests for real (non-preview) package-manager, systemd, and download paths
- Not planned: splitting the LDNMP installer into focused installers (kept as one combined installer)

## Documentation

- [x] Update `CLAUDE.md` with accurate architecture and test commands
- [x] Update `CHANGELOG.md` with 1.1.0 changes
- [x] Refresh `PROGRESS.md` with completed hardening and current phase
- [x] Update `TASKS.md` (this file)
- [x] Retain `SESSION.md` as the historical 2026-06-11 session summary
- [x] Update `DEVELOPMENT_GUIDE.md` with current patterns and full test suite
- [x] Update `code_review.md` with current review findings
- [x] Keep `README.md` aligned with the modular launcher and current inventory
