# Progress

## Current Phase

Service-installer hardening completed. All 11 core installers now have safety tests, `set -euo pipefail`, and guarded execution paths. Menu expanded to 22 items (WP Panel added). Proxy tools now include Hysteria2. Documentation refresh and cross-script bug-fix sweep completed.

## Completed

### Launcher & framework
- Audited the repository structure and script inventory
- Rebuilt `vps.sh` around actual repository modules
- Added safer first-party download-and-execute behavior
- Added confirmation before running third-party launcher commands
- Added shared UI helpers for key-value rows, step display, status output, and runtime context
- Added launcher local-file fast path and parallel module-bundle loading
- Tuned download and public-IP probe timeouts
- Fixed launcher menu EOF handling for non-interactive runs
- Added `bash -n` validation to `run_remote_script_url()` and `run_remote_command()`
- Fixed wget missing `--connect-timeout`; added `pipefail` to `run_remote_command`

### Menu additions
- Added **Hysteria2** to Proxy Tools menu (item 6)
- Added **WP Panel** to Service Install menu (item 21)

### System tools (9 scripts)
- Reworked `install_deps.sh` for better idempotency and reporting
- Refactored `update_system.sh` to remove avoidable `eval`
- Added `health_check.sh` and `security_audit.sh` (read-only diagnostics)
- Normalized logging, validation, and backup patterns across all system tools

### Service install hardening (11 scripts)
- `docker.sh`: temp-file downloads, guarded removal paths
- `nginx.sh`: temp-file key import, isolated source build, safe cleanup
- `mysql.sh`: quoted chown, SQL-safe password generation
- `postgresql.sh`: fixed `TOTAL_MEM` unbound crash, `$(nproc)` heredoc safety, WAL archive path
- `redis.sh`: quoted chown (3×), make-jobs floor
- `nodejs.sh`: version validation, temp-file remote installer
- `python.sh`: `set -euo pipefail`, pyenv pipeline guard, wget error handling, trap safety
- `go.sh`: `sh`→`bash` remote installer, strict input validation
- `java.sh`: strict input validation, isolated archive downloads, quoted paths
- `ruby.sh`: `mktemp -d` source build, `make -j` cap, nproc validation, sed precision fix, cd-leak fix
- `kubernetes.sh`: `set -euo pipefail`, dead `PIPESTATUS` fix, duplicate sysctl removed

### Cross-script fixes (9 files)
- `VERSION_ID` unbound-variable crash fixed across all installers with `detect_system()`

### Library (`lib/common_functions.sh`)
- Reviewed for quoting, temp-file handling, and config safety
- Fixed `$default` quoting in `ask_yes_no()`
- Fixed `$1` quoting in service-control print messages
- Hardened config helpers against regex-like keys and cross-filesystem replacement
- Added symlink protection to temp-directory cleanup

### Legacy launcher (`vps_scripts.sh`)
- Defined as supported legacy-only compatibility handoff
- Fixed EOF handling and quoting in error messages

### Tests (29 validation scripts)
- Launcher coverage: `validate_launcher_paths`, `validate_system_tools_launcher`, `validate_service_install_launcher`, `validate_active_category_coverage`
- Core assets: `validate_core_assets`, `validate_script_headers`, `validate_line_endings_policy`
- Policy: `validate_execution_safety`, `validate_legacy_launcher_policy`, `validate_update_scripts_legacy`, `validate_update_log_handoff`
- Per-installer safety: `docker`, `python`, `kubernetes`, `go`, `java`, `nginx`, `mysql`, `postgresql`, `redis`
- UI/misc: `validate_ui_framework`, `validate_chinese_ui`, `validate_loader_performance`, `validate_menu_eof`, `validate_command_install`, `validate_input_contract`, `validate_remote_module_runtime`, `validate_common_helpers`

### Documentation
- `CLAUDE.md`: accurate distro/arch/version metadata, architecture sections for `version.json`/`update_log.sh`/`.gitattributes`
- `CHANGELOG.md`: comprehensive Unreleased section with all 2026-06-11 changes
- `DEVELOPMENT_GUIDE.md`: updated with full test suite and current patterns
- `TASKS.md`: updated P0/P1/P2 status
- `PROGRESS.md`: this file
- `SESSION.md`: 2026-06-11 session summary
- `code_review.md`: updated findings and review targets

### In Progress

- Standardizing `set -euo pipefail` across remaining 8 service_install scripts (panel installers, jenkins, ruby, rust)
- Expanding shared UI conventions across network_test and performance_test categories
- Auditing framework guardrails before deeper category rewrites

### Not Started

- Refactor `network_test/` and `performance_test/` categories for consistent structure and output
- Add shellcheck CI or pre-commit hook
- Consider extracting repeated build-from-source pattern into shared helper
- Add `die()` helper function to `lib/common_functions.sh`

### Success Criteria For Next Round

- All 20 service_install scripts have `set -euo pipefail`
- Network/performance test scripts share a consistent output format
- Release docs and runtime metadata reflect current menu structure (22 service items, 6 proxy items)
