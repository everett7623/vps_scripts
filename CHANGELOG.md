# Changelog

All notable changes to this repository are documented here.

## Unreleased

## 1.1.6 - 2026-10-09

### Added
- Proxy tools menu: S-UI (sing-box panel, `alireza0/s-ui`), mack-a v2ray-agent multi-protocol script, the official Hysteria2 server installer (`get.hy2.sh`), and the official Xray-core installer (`XTLS/Xray-install`, run with `install`). The two official installers only install the core and a systemd unit; configuration is left to the user.

### Changed
- Proxy tools menu is grouped as panels (3x-ui, S-UI, X-Panel) first, then one-click scripts, then official core installers. **Proxy menu numbers changed.**
- yonggekkk x-ui now downloads from the GitHub repository the author documents (`yonggekkk/x-ui-yg`) instead of the older GitLab copy.
- xeefei's panel entry is renamed X-Panel and uses its current repository URL (`xeefei/X-Panel`; the old `xeefei/3x-ui` path only redirected).

## 1.1.5 - 2026-10-09

### Added
- Service install menu: Coolify and Dokploy (self-hosted PaaS, official installers), Dockge (compose stack manager), and Nginx Proxy Manager (visual reverse proxy with certificates).
- Other tools menu: Beszel hub (lightweight monitoring, official installer).
- `scripts/other_tools/frp.sh`: first-party frpc/frps installer from official `fatedier/frp` releases with `frp_sha256_checksums.txt` verification, token auth enabled by default for frps, existing configs never overwritten, `frp verify` before start, and `--status`/`--dry-run`/`--uninstall`/non-interactive flags.

### Changed
- Reordered the service install, other tools, and community menus so commonly used entries come first and related items are grouped (web servers, databases, runtimes, panels, self-hosted platforms). **Menu numbers in these three submenus changed.**
- Moved entries whose upstream is archived or unmaintained since 2023 to the end and labelled them: FileBrowser, multi-line speedtest (`i-abc/Speedtest`), JCNF toolbox, BlueSkyXN toolbox. AMH moved to the end of the service menu.
- Uptime Kuma now installs the current `louislam/uptime-kuma:2` image (was `:1`).
- Docker-based entries (Portainer, Dockge, Nginx Proxy Manager, Uptime Kuma) check that Docker is installed first and point to the Docker installer if not.
- NextTrace entry points to its canonical `nxtrace/NTrace-core` repository.

### Fixed
- FRP menu entry downloaded a script that no longer exists (`funnyzak/frpc/.../frpc_linux_install.sh` returns 404); it now runs the first-party installer.

## 1.1.4 - 2026-10-09

### Added
- `--dry-run` for `optimize_system.sh`, `change_hostname.sh` (change and `--rollback`), `set_timezone.sh` (timezone, `--ntp`, `--sync`), and `update_system.sh`; previews run without root and write no logs, backups, or config.
- `tests/validate_dry_run_behavior.sh` now executes these system-tool previews with stubbed `systemctl`, `hostnamectl`, `timedatectl`, and package managers.

### Fixed
- `set_timezone.sh` rejected nothing but missing files, so input such as `../../../etc/passwd` could point `/etc/localtime` at an arbitrary file; timezone names are now restricted to zoneinfo path characters.
- `optimize_system.sh` SSH baseline now runs `sshd -t` after writing and restores the previous file instead of reloading SSH with an invalid config.
- `update_system.sh` treated `needs-restarting -r` exit codes backwards on yum/dnf, and answering "n" to the reboot prompt aborted the run under `set -e` before the report was written.
- Interactive menus in `optimize_system.sh`, `change_hostname.sh`, and `set_timezone.sh` no longer loop forever when stdin closes.
- The inline `read_input` fallback in `change_hostname.sh` and `set_timezone.sh` ignored the target variable name, so menu input was silently dropped when the shared library was unavailable.

## 1.1.3 - 2026-10-09

### Added
- `--help`, `--list`, `--dry-run`, `--yes`, and `--target` for `clean_service_residues.sh`, `clear_configuration_files.sh`, and `rollback_system_environment.sh`; plus `--wp-dir`/`--purge-data` and `--hostname` where relevant.
- `--status`, `--dry-run`, `--uninstall`, `--yes`, and `--server`/`--port`/`--secret`/`--tls` (or `NZ_CLIENT_SECRET`) for `nezha.sh`.
- `--help`, `--status`, and `--dry-run` for `scripts/service_install/docker.sh`.
- `tests/validate_dry_run_behavior.sh`: runs preview paths as non-root with stubbed `systemctl`, package managers, `rm`, `swapoff`, and downloads, and fails if any is invoked or a backup directory is created.

### Changed
- Uninstall helpers back up to `/var/backups/vps_scripts/` (override with `VPS_BACKUP_ROOT`) instead of the launcher's temporary runtime directory, which was deleted after each run.
- Batch ("全部") cleanup runs targets in-process instead of re-executing the script through piped answers.
- Service cleanup keeps `/var/lib/docker` and `/var/lib/mysql` unless `--purge-data` is given, no longer deletes `/var/www/html`, and refuses to remove protected system paths.
- Nezha agent now installs the current `nezhahq/agent` v1+ release with a `600` config file instead of passing the client secret on the command line, and the secret is no longer echoed after install.

### Fixed
- Uninstall helpers no longer abort midway under `set -e` when a service, package, or optional file is missing; packages are only removed if installed.
- Swap rollback now only disables and removes `/swapfile` and its fstab line, instead of `swapoff -a` and deleting every fstab line containing "swap".
- BBR rollback removes the project's `/etc/sysctl.d/99-vps-bbr.conf` drop-in; swap rollback removes the swappiness drop-in.
- Hostname rollback validates the hostname and replaces only whole-word matches in `/etc/hosts`.
- Restoring `sshd_config.bak` is validated with `sshd -t` and reverted if invalid before restarting SSH.
- Nezha installer downloaded a retired release asset (`naiba/nezha` `.tar.gz`); it now uses `nezhahq/agent` zip assets verified against upstream `checksums.txt`.

## 1.1.2 - 2026-10-09

### Added
- `init_script_dirs()`, `resolve_log_dir()`, and `run_soft()` helpers in `lib/common_functions.sh` for writable log/report paths and soft-fail diagnostic probes.
- `tests/validate_network_test_resilience.sh` regression coverage for Issue #2 network-test failures.
- `tests/validate_performance_test_resilience.sh` for performance_test log-dir soft-fail and other_tools status/dry-run flags.
- `tests/validate_category_resilience.sh` and `tests/validate_mocked_runtime_smoke.sh` for full-repo footgun scans and mocked helper behavior.
- `tests/validate_bootstrap_command.sh` to keep public one-line bootstrap commands synchronized.
- `--status` / `--dry-run` / `--help` non-interactive modes for `swap.sh` and `fail2ban.sh`; `--status` / `--install` / `--uninstall` for `bbr.sh`.
- `full_uninstall.sh --dry-run` and `ldnmp.sh --status` facade handoff to focused installers.

### Changed
- Standardized public bootstrap commands to the common one-line form: `curl -fsSL .../vps.sh -o /tmp/vps.sh && bash /tmp/vps.sh` (README, `vps.sh`, `vps_scripts.sh`).
- Network and performance test modules now fall back to a user-writable temp log directory when `/var/log/vps_scripts` is unavailable.
- System tools resolve log directories through `resolve_log_dir` instead of assuming `/var/log/vps_scripts` is always writable.
- Launcher `run_repo_script` reports Ctrl+C (exit 130) as cancellation instead of a generic module failure.
- Replaced the custom Docker repository and Compose installation flow with a safely downloaded and syntax-checked `get.docker.com` official installer.
- Kept third-party menu entries on their official project scripts while routing them through launcher confirmation, isolated temporary download, Bash syntax validation, and cleanup.

### Fixed
- Fixed Issue #2: network-test menu modules (backhaul, bandwidth, IP quality, network quality, streaming unlock) no longer exit with code 1 on unbound `$1`, single-node timeouts, or non-writable `/var/log` under `set -euo pipefail`.
- Fixed recursive backup failure in the isolated full-uninstall runtime and limited removal to verified first-party commands, launcher files, and logs.
- Propagated third-party command and script failures through the launcher, and added ARM architecture detection for Caddy and cloudflared downloads.
- Replaced predictable BT Panel helper scripts and CyberPanel option records under `/tmp` with heredoc execution or `mktemp`, and cleaned up the CyberPanel installer after execution failures.
- Prevented the BBR tool from overwriting `/etc/sysctl.conf`, made Swap configuration idempotent in `/etc/fstab`, and validated Fail2ban configuration before restarting the service.
- Repaired legacy cleanup batch actions so confirmation and menu input reach child invocations, excluded interactive WordPress and hostname actions from batch execution, and validated the WordPress deletion target.
- Hardened the Nezha agent installer with validated inputs, verified archive contents, systemd escaping, and unit-file verification.
- Replaced remaining first-party remote shell pipelines in LDNMP, dependency setup, Jenkins build tooling, and bandwidth testing; added upgrade-hardening regression coverage.
- Made shared confirmation and input helpers cancel cleanly on stdin EOF, and stopped hostname rollback from sourcing backup metadata as shell code.
- Made the LDNMP compatibility installer validate PHP versions and conflicting database selections, protect generated credentials, and require an explicit flag before creating a phpinfo demo site.
- Separated system-update confirmation from reboot behavior: automatic updates now require explicit `--reboot` before restarting the host.

## 1.1.1 - 2026-07-15

### Fixed
- Fixed the persistent-command startup gap from Issue #1 by creating the managed `vps` shortcut automatically on the first interactive root launch.

### Changed
- Added `VPS_AUTO_INSTALL_COMMAND=true` for non-interactive installation attempts and `VPS_AUTO_INSTALL_COMMAND=false` to disable automatic installation.
- Kept automatic installation idempotent and prevented it from overwriting an unrelated `/usr/local/bin/vps` command.

## 1.1.0 - 2026-07-15

### Added
- `die()` helper function in `lib/common_functions.sh` to consolidate `print_error; exit 1` patterns.
- `scripts/service_install/wppanel.sh` first-party wrapper for WP Panel (replaces inline `run_remote_command`).
- `tests/validate_service_install_strict_mode.sh` to enforce strict-mode coverage across all service installers.
- `.github/workflows/shellcheck.yml` GitHub Actions CI: bash -n syntax check, shellcheck lint, strict-mode test.
- `scripts/other_tools/modern_cli.sh` for btop, ripgrep, fd, bat, fzf, jq, ncdu, and restic using distribution repositories.
- `tests/validate_modern_cli_tools.sh`, `tests/validate_launcher_privacy.sh`, and `tests/validate_release_metadata.sh` safety boundaries.
- Caddy, Portainer, Komari, acme.sh, tmux, oh-my-zsh, Uptime Kuma, Tailscale, FRP, cloudflared, FileBrowser, and additional community diagnostics to launcher menus.

### Changed
- Added `set -euo pipefail` to all 8 remaining service_install scripts (1panel, aapanel, amh, btpanel, cyberpanel, jenkins, ruby, rust).
- Added `set -euo pipefail` to all 5 network_test scripts (backhaul_route_test, bandwidth_test, ip_quality_test, network_quality_test, streaming_unlock_test).
- Added `set -euo pipefail` to all 4 performance_test scripts (cpu_benchmark, disk_io_benchmark, memory_benchmark, network_throughput_test).
- Replaced predictable `/tmp` paths with `mktemp -d` across all network_test and performance_test scripts.
- Replaced `curl | sh` / `curl | bash` process-substitution patterns with download-to-tempfile-then-execute in cyberpanel.sh, rust.sh, ruby.sh.
- Made ShellCheck error findings fail CI instead of being swallowed by `|| true`.
- Removed the launcher's implicit usage-counter request and its startup latency/privacy cost.
- Updated project and launcher UI metadata to `1.1.0`.
- Made the full validation suite gate CI for release-related scripts and documents.

### Fixed
- cyberpanel.sh: Fixed `TOTAL_MEM` unbound variable in `prepare_system()`, fixed `PKG_MANAGER` unbound when `prepare_system()` called directly, quoted `$service` and `$port` in loops.
- jenkins.sh: Quoted all `$JENKINS_USER` in `chown` calls (5 occurrences), quoted `$VER` in `detect_system()`, added error handling to wget/install operations, fixed predictable log file path.
- amh.sh: Removed duplicate `set -e`, replaced predictable temp dir with `mktemp -d`, guarded cleanup against unset `TEMP_DIR`.
- 1panel.sh: Replaced predictable temp dir with `mktemp -d`, guarded cleanup against unset `TEMP_DIR`.
- aapanel.sh: Replaced unsafe `curl -O`/`ls install*.sh` download pattern with explicit temp file.
- btpanel.sh: Replaced unsafe `wget -O install.sh` download pattern with explicit temp file.
- rust.sh: Fixed `.zshrc` append when file doesn't exist, guarded all `cargo install` calls against `set -e`, replaced `curl | sh` for wasm-pack and rustup.
- ruby.sh: Guarded `gem sources` and `bundle config` against `set -e`, replaced `curl | bash` for RVM, guarded GPG keyserver import.
- postgresql.sh: Moved WAL archive directory from `${DATA_DIR}/archive` to `/var/lib/postgresql/archive` to prevent single-disk-failure data loss.
- Repaired `validate_update_scripts_legacy.sh` after the obsolete directory was removed.

## 1.0.0 - 2026-06-12

### Added
- Modular `vps.sh` launcher with system, network, performance, service, community, proxy, utility, and uninstall menus.
- First-party module loading with local-repository support, isolated temporary runtime directories, syntax validation, and download fallbacks.
- Responsive terminal UI with centered headings, CJK-aware alignment, compact narrow-screen rows, and UTF-8 locale fallback.
- Shared UI, logging, configuration, input, download, service, and cleanup helpers.
- System health and security audit tools.
- Persistent `vps` command installation and removal.
- Legacy-only `vps_scripts.sh` compatibility handoff.
- 30 repository validation scripts covering launchers, assets, UI, syntax, runtime layout, input contracts, and installer safety.

### Changed
- Standardized project, launcher UI, and project-owned module versions at `1.0.0`.
- Standardized system-tool output and hardened core service installers.
- Updated README, development guidance, release checklist, task tracking, progress, and review documentation for the initial stable baseline.

### Fixed
- Corrected launcher paths that referenced missing modules.
- Added confirmation and syntax checks before third-party script execution.
- Fixed non-interactive menu EOF handling and terminal clearing behavior.
- Fixed mixed Chinese/ASCII alignment, narrow-terminal overflow, malformed terminal width handling, and `LC_ALL=C` display-width behavior.
- Hardened temporary-file cleanup, quoting, input validation, package-manager handling, and strict-mode edge cases across maintained scripts.

## Optimization notes - 2026-07-28

### Fixed
- Hardened generated temporary files and execution hints across launchers, panel installers, Kubernetes setup, and WordPress cleanup paths.
- Added safer deletion boundaries to uninstall scripts by using `rm --`, quoted variables, and directory-scoped cleanup helpers instead of direct glob deletion.
- Tightened recursive ownership and permission operations in selected service installers with explicit option terminators and quoted path arguments.
