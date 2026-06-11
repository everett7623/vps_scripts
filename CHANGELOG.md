# Changelog

All notable changes to this repository should be documented here.

## Unreleased

## 2.7.0 - 2026-06-12

### Added

- Added **Hysteria2** installer to Proxy Tools menu (`vps.sh` menu item 6) via `run_remote_script_url`
- Added **WP Panel** installer to Service Install menu (`vps.sh` menu item 21) via `run_remote_command`
- Added `tests/validate_mysql_installer_safety.sh`, `tests/validate_postgresql_installer_safety.sh`, `tests/validate_redis_installer_safety.sh` to complete per-installer safety coverage
- Added `bash -n` syntax validation to `run_remote_script_url()` — third-party scripts are now rejected if they fail syntax check
- Added `bash -n` syntax validation to `run_remote_command()` — all 13+ call sites now screen content before execution

### Changed

- Rebuilt `vps.sh` as a cleaner modular remote launcher aligned with files that actually exist in the repository
- Reworked `scripts/system_tools/install_deps.sh` toward a more idempotent package installation flow
- Added safer first-party module execution by downloading to a temporary file before running
- Added confirmation before executing third-party remote one-liners from launcher menus
- Added shared UI helpers and a runtime context display for modernized modules
- Added read-only system tools for health checks and security baseline audits
- Updated `CLAUDE.md` with accurate distro/arch compatibility, VERSION_ID safety, `.gitattributes` policy, `version.json` and `update_log.sh` architecture notes
- Updated `DEVELOPMENT_GUIDE.md`, `PROGRESS.md`, `TASKS.md`, `SESSION.md`, `code_review.md` with current project state

### Fixed (safety & correctness — 2026-06-11 session)

- **`vps.sh`**: wget missing `--connect-timeout` (60s→6s on bad connections); `run_remote_script_url` lacked `bash -n` validation; `run_remote_command` injected `set -e` without `pipefail` (silent wget failure in pipelines); `run_remote_command` now gets `bash -n` check before execution
- **`python.sh`**: added `set -euo pipefail`; guarded `pyenv install --list` pipeline against `set -e` preemptive abort with `|| true`; fixed `wget` silent-exit under `set -e`; guarded EXIT trap `rm -rf` with `|| true`
- **`ruby.sh`**: replaced predictable `/tmp` paths with `mktemp -d` in source build; capped `make -j` at 4 (was unlimited `$(nproc)`); guarded `nproc` against non-numeric output (`make -j0` bug); fixed `sed -i '/rbenv/d'` over-deletion of user config; fixed build_dir leak on `cd` failure; quoted `echo $RUBY_VERSION`
- **`kubernetes.sh`**: added `set -euo pipefail`; removed duplicate `tcp_max_syn_backlog` sysctl; fixed dead `PIPESTATUS` check under `set -o pipefail` by wrapping pipeline with `set +e`/`set -e`
- **`mysql.sh`**: quoted `chown "$USER:$USER"`; stripped `'` from generated passwords to prevent SQL breakage
- **`redis.sh`**: quoted `chown "$USER:$USER"` (3 occurrences); added floor to `make -j` fallback (0→1)
- **`postgresql.sh`**: fixed `TOTAL_MEM` unbound crash when `--shared-buffers` provided; pre-computed `NP=$(nproc)` outside heredoc to avoid `set -e` abort; stripped `'` from generated passwords; WAL archive path now uses `$DATA_DIR` variable
- **`go.sh`**: changed `sh`→`bash` for remote installer execution (fixes dash incompatibility)
- **`lib/common_functions.sh`**: quoted `$default` in `answer=${answer:-"${default}"}`; quoted `$1` in service-control print messages
- **`vps_scripts.sh`**: quoted `$1` in error message
- **Cross-script (9 files)**: `VERSION=$VERSION_ID`→`VERSION=${VERSION_ID:-}` to prevent `set -u` crash on minimal containers/WSL that lack `VERSION_ID` in `/etc/os-release`

### Fixed (prior hardening)

- Fixed menu items in `vps.sh` that previously referenced missing `scripts/network_test/*` and `scripts/service_install/install_*` files
- Reduced false success cases in dependency installation by checking installed packages and reporting failures more clearly
- Removed avoidable `eval` usage from third-party launcher command execution and avoided `sh -c` in Alpine update cleanup
- Improved module startup speed with local cloned-repo loading, parallel dependency downloads, and shorter failed-network waits
- Fixed launcher menu handling when stdin reaches EOF in non-interactive runs
- Hardened shared config helpers with validated keys, exact matching, same-directory atomic replacement, and permission preservation
- Refused symbolic-link and out-of-scope paths in shared temporary-directory cleanup
- Defined `vps_scripts.sh` as a supported legacy-only handoff and fixed EOF handling in its interactive menu
- Hardened `scripts/service_install/python.sh` with strict method/version validation, temporary remote installer execution, eval-free pyenv setup, and isolated source-build cleanup
- Hardened `scripts/service_install/kubernetes.sh` with validated deployment inputs and array-based `kubeadm join` execution
- Hardened `scripts/service_install/docker.sh` with temporary downloads for Docker assets and guarded Docker removal paths
- Hardened `scripts/service_install/go.sh` with strict input validation, isolated archive downloads, guarded Go tree replacement, and temp-file execution for the golangci-lint installer
- Hardened `scripts/service_install/java.sh` with strict input validation, isolated archive downloads, quoted Java paths, and safer Maven/Gradle archive handling
- Hardened `scripts/service_install/nginx.sh` with temp-file repository key import, isolated source-build directories, and safe cleanup
- Completed the `update_log.sh` history handoff by making `CHANGELOG.md` the single source of release notes
- Classified `scripts/update_scripts/` as inactive legacy/reference material instead of active architecture

### Test suite additions

- `tests/validate_launcher_paths.sh`, `tests/validate_system_tools_launcher.sh`, `tests/validate_service_install_launcher.sh`
- `tests/validate_active_category_coverage.sh`, `tests/validate_execution_safety.sh`
- `tests/validate_ui_framework.sh`, `tests/validate_loader_performance.sh`, `tests/validate_menu_eof.sh`
- `tests/validate_common_helpers.sh`, `tests/validate_legacy_launcher_policy.sh`
- `tests/validate_core_assets.sh`, `tests/validate_script_headers.sh`, `tests/validate_line_endings_policy.sh`
- `tests/validate_update_log_handoff.sh`, `tests/validate_update_scripts_legacy.sh`
- `tests/validate_docker_installer_safety.sh`, `tests/validate_python_installer_safety.sh`, `tests/validate_kubernetes_installer_safety.sh`
- `tests/validate_go_installer_safety.sh`, `tests/validate_java_installer_safety.sh`, `tests/validate_nginx_installer_safety.sh`
- `tests/validate_mysql_installer_safety.sh`, `tests/validate_postgresql_installer_safety.sh`, `tests/validate_redis_installer_safety.sh`
- `tests/validate_input_contract.sh`, `tests/validate_remote_module_runtime.sh`
- `tests/validate_chinese_ui.sh`, `tests/validate_command_install.sh`
- `.gitattributes` (LF enforcement for `.sh`, `.md`, `.json`, `.conf`, `.txt`)

## 2.6.0 - 2026-01-20

### Changed

- Refactored the project around stateless remote execution
- Added remote launcher metadata in `version.json`
- Continued modularizing system, network, benchmark, install, and cleanup capabilities

## Legacy History

`CHANGELOG.md` is now the canonical human-readable history. The legacy `update_log.sh` script is retained only as a compatibility viewer that prints version metadata and an excerpt from this file.
