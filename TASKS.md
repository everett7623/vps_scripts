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

- [x] Normalize logging conventions across system_tools modules
- [x] Optimize module loading speed and slow-network behavior
- [x] Standardize script headers and encoding (LF, no BOM, `#!/bin/bash`)
- [x] Classify `update_scripts/` as inactive legacy/reference
- [x] Add Hysteria2 to Proxy Tools menu
- [x] Add WP Panel to Service Install menu
- [ ] Add `set -euo pipefail` to remaining 8 service_install scripts (1panel, aapanel, amh, btpanel, cyberpanel, jenkins, ruby, rust)
- [ ] Refactor `network_test/` category for consistent structure and output
- [ ] Refactor `performance_test/` category for consistent structure and output
- [ ] Add more non-interactive safety flags where appropriate

## P3 (new)

- [ ] Extract repeated build-from-source pattern into shared helper in `lib/common_functions.sh`
- [ ] Add `die()` helper function to consolidate 30+ scattered `print_error; exit 1` patterns
- [ ] Create `scripts/service_install/wppanel.sh` first-party wrapper (currently inline `run_remote_command`)
- [ ] Add `tests/validate_service_install_strict_mode.sh` to enforce `set -euo pipefail` coverage
- [ ] Add shellcheck CI or pre-commit hook
- [ ] Consider moving WAL archive directory outside PostgreSQL DATA_DIR for disaster recovery

## Documentation

- [x] Update `CLAUDE.md` with accurate architecture and test commands
- [x] Update `CHANGELOG.md` with all 2026-06-11 changes
- [x] Refresh `PROGRESS.md` with completed hardening and current phase
- [x] Update `TASKS.md` (this file)
- [x] Update `SESSION.md` with 2026-06-11 session summary
- [x] Update `DEVELOPMENT_GUIDE.md` with current patterns and full test suite
- [x] Update `code_review.md` with current review findings
- [ ] Keep `README.md` aligned with modular launcher path (review needed)
