# Changelog

All notable changes to this repository should be documented here.

## Unreleased

### Changed

- Rebuilt `vps.sh` as a cleaner modular remote launcher aligned with files that actually exist in the repository
- Added safer first-party module execution by downloading to a temporary file before running
- Added confirmation before executing third-party remote one-liners from launcher menus
- Reworked `scripts/system_tools/install_deps.sh` toward a more idempotent package installation flow
- Added `tests/validate_launcher_paths.sh` to catch launcher references to missing scripts
- Added read-only system tools for health checks and security baseline audits
- Added `tests/validate_system_tools_launcher.sh` to keep system-tools menu entries aligned with script inventory
- Added `tests/validate_service_install_launcher.sh` to keep service-install menu entries aligned with script inventory
- Added `tests/validate_execution_safety.sh` to guard launcher and system-update execution patterns
- Added shared UI helpers and a runtime context display for modernized modules
- Added `tests/validate_ui_framework.sh` to keep the shared UI helper layer present
- Added `tests/validate_loader_performance.sh` to protect loader speed optimizations
- Added `tests/validate_active_category_coverage.sh` to protect active launcher category coverage
- Added `tests/validate_common_helpers.sh` to cover shared config and temporary cleanup safety
- Added `tests/validate_legacy_launcher_policy.sh` to keep the compatibility launcher legacy-only
- Added `tests/validate_python_installer_safety.sh` to protect Python installer execution boundaries
- Added `tests/validate_kubernetes_installer_safety.sh` to protect join-command and input handling
- Added `tests/validate_update_log_handoff.sh` to keep `update_log.sh` aligned with `CHANGELOG.md`
- Added `tests/validate_update_scripts_legacy.sh` to keep legacy update scripts out of active launcher menus
- Added `.gitattributes` and `tests/validate_line_endings_policy.sh` to keep script and documentation line endings stable across Windows/NAS checkouts
- Added `tests/validate_script_headers.sh` to enforce shell shebangs and reject CRLF or UTF-8 BOM in shell scripts
- Refreshed core project documentation and contributor guidance

### Fixed

- Fixed menu items in `vps.sh` that previously referenced missing `scripts/network_test/*` and `scripts/service_install/install_*` files
- Reduced false success cases in dependency installation by checking installed packages and reporting failures more clearly
- Hardened `scripts/service_install/nodejs.sh` by validating the Node.js major version and downloading remote installer scripts to temporary files before execution
- Removed avoidable `eval` usage from third-party launcher command execution and avoided `sh -c` in Alpine update cleanup
- Improved official module launch output with staged status lines while preserving the classic header and recommended links
- Improved module startup speed with local cloned-repo loading, parallel dependency downloads, and shorter failed-network waits
- Improved launcher link/menu alignment and system-info report table spacing
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

## 2.6.0 - 2026-01-20

### Changed

- Refactored the project around stateless remote execution
- Added remote launcher metadata in `version.json`
- Continued modularizing system, network, benchmark, install, and cleanup capabilities

## Legacy History

`CHANGELOG.md` is now the canonical human-readable history. The legacy `update_log.sh` script is retained only as a compatibility viewer that prints version metadata and an excerpt from this file.
