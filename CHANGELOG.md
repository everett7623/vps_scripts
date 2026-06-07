# Changelog

All notable changes to this repository should be documented here.

## Unreleased

### Changed

- Rebuilt `vps.sh` as a cleaner modular remote launcher aligned with files that actually exist in the repository
- Added safer first-party module execution by downloading to a temporary file before running
- Added confirmation before executing third-party remote one-liners from launcher menus
- Reworked `scripts/system_tools/install_deps.sh` toward a more idempotent package installation flow
- Added `tests/validate_launcher_paths.sh` to catch launcher references to missing scripts
- Refreshed core project documentation and contributor guidance

### Fixed

- Fixed menu items in `vps.sh` that previously referenced missing `scripts/network_test/*` and `scripts/service_install/install_*` files
- Reduced false success cases in dependency installation by checking installed packages and reporting failures more clearly

## 2.6.0 - 2026-01-20

### Changed

- Refactored the project around stateless remote execution
- Added remote launcher metadata in `version.json`
- Continued modularizing system, network, benchmark, install, and cleanup capabilities

## Legacy History

Older history is still preserved in `update_log.sh`, but it should gradually be migrated into this file in a cleaner format.
