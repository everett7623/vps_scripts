# Changelog

All notable changes to this repository are documented here.

## Unreleased

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
