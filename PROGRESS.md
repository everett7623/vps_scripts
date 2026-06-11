# Progress

## Current Phase

Repository stabilization and documentation alignment for the modular launcher path.

## Completed

- Audited the repository structure and script inventory
- Identified launcher menu targets that did not exist in the repo
- Rebuilt `vps.sh` around actual repository modules
- Added safer first-party download-and-execute behavior
- Added confirmation before running third-party launcher commands
- Reworked `scripts/system_tools/install_deps.sh` for better idempotency and reporting
- Added `tests/validate_launcher_paths.sh`
- Added `scripts/system_tools/health_check.sh` for read-only VPS health checks
- Added `scripts/system_tools/security_audit.sh` for read-only security baseline audits
- Added `tests/validate_system_tools_launcher.sh` for system-tools launcher coverage
- Added `tests/validate_service_install_launcher.sh` for service-install launcher coverage
- Hardened `scripts/service_install/nodejs.sh` version handling and remote installer execution
- Removed the remaining avoidable launcher/update-system string execution path (`eval` / `sh -c`)
- Added `tests/validate_execution_safety.sh` to prevent regressions in launcher and update execution safety
- Added shared UI helpers for key-value rows, step display, status output, and runtime context
- Updated the launcher module runtime panel to show path validation, isolated runtime, dependency download, and execution stages
- Aligned `install_deps.sh` and `update_system.sh` with the shared runtime context display while preserving existing behavior
- Added launcher local-file fast path for cloned-repo runs and parallel loading for module dependencies
- Tuned download and public-IP probe timeouts so network failures return faster
- Added `tests/validate_loader_performance.sh` to prevent loader-speed regressions
- Added active-category launcher coverage for network, performance, other-tools, and uninstall menus
- Tightened launcher header links, menu detail columns, and system-info tables for cleaner terminal alignment
- Fixed launcher menu EOF handling so non-interactive runs do not loop on invalid choices
- Added `tests/validate_menu_eof.sh` to prevent stdin EOF regressions
- Hardened shared config helpers against regex-like keys and cross-filesystem replacement
- Added symbolic-link protection to shared temporary-directory cleanup
- Added `tests/validate_common_helpers.sh` for config and cleanup helper regression coverage
- Defined `vps_scripts.sh` as a supported legacy-only compatibility handoff
- Added `tests/validate_legacy_launcher_policy.sh` and legacy menu EOF handling
- Hardened `scripts/service_install/python.sh` input, pyenv, and source-build execution paths
- Added `tests/validate_python_installer_safety.sh`
- Hardened `scripts/service_install/kubernetes.sh` input and worker join execution
- Added `tests/validate_kubernetes_installer_safety.sh`
- Hardened `scripts/service_install/docker.sh` download and removal paths
- Added `tests/validate_docker_installer_safety.sh`
- Hardened `scripts/service_install/go.sh` input validation, archive handling, and remote tool installation
- Added `tests/validate_go_installer_safety.sh`
- Hardened `scripts/service_install/java.sh` parameter validation and archive download handling
- Added `tests/validate_java_installer_safety.sh`
- Hardened `scripts/service_install/nginx.sh` repository key handling and source-build cleanup
- Added `tests/validate_nginx_installer_safety.sh`
- Completed `update_log.sh` handoff to canonical `CHANGELOG.md`
- Added `tests/validate_update_log_handoff.sh`
- Classified `scripts/update_scripts/` as inactive legacy/reference only
- Added `tests/validate_update_scripts_legacy.sh`
- Added repository line-ending policy for shell scripts, docs, metadata, and config files
- Added `tests/validate_line_endings_policy.sh`
- Added shell header, CRLF, and BOM validation for repository shell scripts
- Completed the current script header and encoding guardrail pass
- Created baseline project documentation set

## In Progress

- Standardizing docs and release workflow around the modular path
- Deepening system-tools diagnostics and launcher validation
- Defining follow-up targets for update and install hardening
- Reviewing remaining service-install scripts in priority order from `TASKS.md`
- Expanding shared UI conventions across remaining script categories
- Improving module startup speed and slow-network behavior
- Auditing framework guardrails before deeper category rewrites
- Refining terminal layout consistency across launcher and system reports

## Not Started

- Define the next high-risk install/update script review batch

## Success Criteria For Next Round

- High-risk update/install scripts have a shared execution pattern
- More scripts can pass `shellcheck` cleanly
- Release docs and runtime metadata are consistent
- Service-install launcher coverage remains protected by repo-local validation
