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
- [x] Optimize module loading speed and slow-network behavio
- [x] Standardize script headers and encoding (LF, no BOM, `#!/bin/bash`)
- [x] Remove inactive legacy `update_scripts/` and retain a regression boundary
- [x] Add Hysteria2 to Proxy Tools menu
- [x] Add WP Panel to Service Install menu
- [x] Add `set -euo pipefail` to remaining 8 service_install scripts (1panel, aapanel, amh, btpanel, cyberpanel, jenkins, ruby, rust)
- [x] Refactor `network_test/` category for consistent structure and output
- [x] Refactor `performance_test/` category for consistent structure and output
- [x] Add validated arguments to the third-party script wrapper for official installer flags
- [x] Add more non-interactive safety flags where appropriate (1.1.9: `DEBIAN_FRONTEND` everywhere, swap `--size/--yes/--remove`)

## P3 (new)

- [x] Remove direct remote shell pipelines from first-party LDNMP, dependency, Jenkins, and bandwidth-test flows
- [x] Add an upgrade-hardening regression test for launcher, Nezha, LDNMP, and bandwidth-test policies
- [x] Add LDNMP input, credential-disclosure, and demo-site safety regression coverage
- [x] Require explicit `--reboot` for non-interactive system-update restarts
- [x] Fix Issue #2 network-test menu failures (`unbound $1`, single-node `set -e` abort, log-dir fallback)
- [x] Add `init_script_dirs` / `run_soft` helpers and `validate_network_test_resilience.sh`
- [x] Harden `performance_test/` with the same log-dir and soft-fail patterns
- [x] Add `--status`/`--dry-run` flags for swap/fail2ban and CLI modes for bb
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
- [x] Cover forced, disabled, non-interactive, and collision behavio
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
- [x] Add `--status`/`--dry-run` to the Docker installer wrappe
- [x] Add executed dry-run behavior coverage (`tests/validate_dry_run_behavior.sh`)
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.3`

## 1.1.4 release

- [x] Add `--dry-run` to optimize, hostname, timezone, and update system tools
- [x] Fix timezone path traversal, SSH baseline validation, yum/dnf reboot detection, and stdin-EOF menu loops
- [x] Extend `tests/validate_dry_run_behavior.sh` to execute the system-tool previews
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.4`

## 1.1.5 release

- [x] Catalog review of service install, other tools, and community menus (URL liveness + upstream activity)
- [x] Add Coolify, Dokploy, Dockge, Nginx Proxy Manager, Beszel
- [x] Replace the broken FRP entry with a first-party checksum-verified `frp.sh`
- [x] Move archived/stale entries to the end with labels; Uptime Kuma to 2.x; Docker presence check for Docker-based entries
- [x] Synchronize version, date, changelog, README, PRIVACY, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.5`

## 1.1.6 release

- [x] Catalog review of the proxy tools menu (URL liveness + upstream activity); community test tools re-checked, no changes needed
- [x] Add S-UI, mack-a v2ray-agent, official Hysteria2 and Xray-core installers
- [x] Move x-ui-yg and X-Panel to current upstream URLs; group panels before scripts
- [x] Synchronize version, date, changelog, README, PRIVACY, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.6`

## 1.1.7 release

- [x] Feature-gap review of first-party network test, performance test, and system tools
- [x] `install_deps.sh`: `--dry-run` / `--yes` / `resolve_log_dir` / expanded help
- [x] Soft-fail package installs + `--skip-install` for performance and auto-installing network tests
- [x] Validate disk `--size` and network `--client` CLI arguments
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.7`

## 1.1.8 release

- [x] Mocked pkg/systemd suite for real BBR install/uninstall and Fail2ban `--yes` paths
- [x] Go official `.sha256` verification; Node.js `SHASUMS256.txt` verification + mktemp binary install
- [x] Fail2ban `--yes` and testable path/OS overrides; BBR drop-in override
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, and TASKS at `1.1.8`

## 1.1.9 release

- [x] Non-interactive apt across all first-party scripts; keep-config upgrades in `update_system.sh` (ported from the local working copy)
- [x] Maven / Gradle / Oracle JDK 17/21 / GraalVM checksum verification before extract
- [x] Remove TLS-verification bypasses; HTTPS for aaPanel, BT Panel (`download.bt.cn`), and Redis downloads
- [x] `swap.sh --size/--yes/--remove`, disk-space precheck, abort on `swapoff` failure
- [x] `install_deps.sh` adds Docker/NodeSource repos only when the selected packages need them
- [x] Mocked real-path tests for swap and install_deps; host-independent dry-run test
- [x] `run_all_tests.sh`
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.9`

## 1.1.10 release

- [x] Redis source SHA-256 via official `redis-hashes`; default version `7.2.16`
- [x] AMH (`dl.amh.sh`) and BT Panel beta (`io.bt.sy`) installers on HTTPS
- [x] Mocked real-path tests for `optimize_system` and `clean_system`; `VPS_OPTIMIZE_*` / `VPS_APT_*` overrides
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.10`

## 1.1.11 release

- [x] Remove aaPanel `curl -k`; Jenkins WAR via `get.jenkins.io` HTTPS
- [x] PostgreSQL apt `signed-by` + HTTPS; Kubernetes CRI-O / Azure Helm HTTPS
- [x] Upgrade-hardening catches combined `-k` and `.war` plain HTTP
- [x] Catalog URL liveness spot-check (Coolify, Dokploy, 3x-ui, S-UI, Hysteria2, Xray, Beszel, etc. OK)
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.11`

## 1.1.12 release

- [x] Ruby source SHA-256 via official `releases.yml`; default version `3.3.12`
- [x] Mocked real-path tests for `change_hostname` and `set_timezone`; `VPS_HOSTNAME_*` / `VPS_TIMEZONE_*` overrides
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.12`

## 1.1.13 release

- [x] Mocked real-path tests for `update_system` (`VPS_UPDATE_*`, reboot-required override, skip-network hook)
- [x] Fix Oracle JDK 17 archive URL and GraalVM `jdk-17.0.9` / `jdk-21.0.2` tags
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.13`

## 1.1.14 release

- [x] Rust `rustup-init` binary + SHA-256 (drop `sh.rustup.rs`)
- [x] Replace offline `seedloc.com` blog with project docs; UI label `项目文档`
- [x] Third-party catalog URL liveness re-check
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.14`

## 1.1.15 release

- [x] Mocked real-path tests for Nezha / FRP (`VPS_NEZHA_*` / `VPS_FRP_*`)
- [x] Jenkins WAR SHA-256 via official `get.jenkins.io` sidecar; `validate_jenkins_installer_safety.sh`
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.15`

## 1.1.16 release

- [x] Mocked real-path tests for uninstall rollback / clear / clean / full_uninstall
- [x] Wire shared `VPS_*` path overrides into rollback; add `VPS_ETC_ROOT` family for clear/clean
- [x] Fix swap fstab rollback to filter by `VPS_SWAP_FILE` (awk)
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.16`

## 1.1.17 release

- [x] Catalog URL liveness re-check; pin `bench.sh` / `kejilion.sh` to raw GitHub
- [x] Refuse Oracle JDK 8/11 OTN soft-404; keep checksummed 17/21
- [x] Guard CRI-O against OpenSUSE kubic 1.29+ 404; ELF-check Caddy/cloudflared
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.17`

## 1.1.18 release

- [x] Jenkins apt: `signed-by` keyring (`jenkins.io-2023.key`); no `apt-key add`
- [x] Kubernetes apt: migrate to `pkgs.k8s.io` / Aliyun `kubernetes-new`; Docker CE + CRI-O use `signed-by`
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.18`

## 1.1.19 release

- [x] Nginx / MariaDB / PostgreSQL apt: `signed-by` keyrings; remove remaining `apt-key add`
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.19`

## 1.1.20 release

- [x] BT cleanup: `VPS_BT_*` path overrides; local-only vendor uninstall; mocked bt + 1panel coverage
- [x] Catalog URL liveness re-check (all probed third-party script URLs live)
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.20`

## 1.1.21 release

- [x] Python source digest via python.org downloads API; `bash -n` on Python/Node/Go remote installers
- [x] Mocked cleanup coverage for nginx/apache/mysql/php
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.21`

## 1.1.22 release

- [x] Add Beszel Agent; demote CyberPanel next to AMH with a niche label
- [x] `bash -n` before 1Panel / aaPanel / AMH / BT / CyberPanel vendor scripts
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.22`

## 1.1.23 release

- [x] RVM / Helm / wasm-pack: `bash -n` before remote installer execution; RVM fixed argv
- [x] LDNMP Docker Compose ELF magic guard; Beszel hub URL pin in upgrade-hardening
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.23`

## 1.1.24 release

- [x] Nginx source: verify `.tar.gz.asc` with `nginx_signing.key` before extract
- [x] WP-CLI: SHA-256 sidecar check; stop using `curl -O` into the working directory
- [x] Synchronize version, date, changelog, README, VERSIONING, CLAUDE, PROGRESS, SESSION, and TASKS at `1.1.24`

## Ongoing

- [ ] Per-category review: add popular maintained tools/projects, deprioritize outdated entries (see AGENTS.md "Catalog Freshness"); next: URL re-check each release
- [ ] Kernel rollback stays interactive-only (no mocked non-interactive path planned)
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
