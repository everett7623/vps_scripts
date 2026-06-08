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
- Refreshed core project documentation and contributor guidance

### Fixed

- Fixed menu items in `vps.sh` that previously referenced missing `scripts/network_test/*` and `scripts/service_install/install_*` files
- Reduced false success cases in dependency installation by checking installed packages and reporting failures more clearly
- Hardened `scripts/service_install/nodejs.sh` by validating the Node.js major version and downloading remote installer scripts to temporary files before execution
- Removed avoidable `eval` usage from third-party launcher command execution and avoided `sh -c` in Alpine update cleanup
- Improved official module launch output with staged status lines while preserving the classic header and recommended links

## 2.6.0 - 2026-01-20

### Changed

- Refactored the project around stateless remote execution
- Added remote launcher metadata in `version.json`
- Continued modularizing system, network, benchmark, install, and cleanup capabilities

## Legacy History

Older history is still preserved in `update_log.sh`, but it should gradually be migrated into this file in a cleaner format.
