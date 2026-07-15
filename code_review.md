# Code Review

This file captures the current high-priority review findings and follow-up direction.

## Current State (2026-06-12)

All 11 core service installers have been hardened with safety tests, `set -euo pipefail`, and guarded execution paths. The launcher and shared UI now use responsive widths, display-width-aware CJK alignment, and compact narrow-terminal layouts. The 30-test validation suite is green.

## Findings

### High (open)

- 8 of 20 service_install scripts still lack `set -euo pipefail`: `1panel.sh`, `aapanel.sh`, `amh.sh`, `btpanel.sh`, `cyberpanel.sh`, `jenkins.sh`, `ruby.sh`, `rust.sh`. These are panel installers and auxiliary tools that would benefit from strict mode.
- WAL archive directory in `postgresql.sh` is co-located with the PostgreSQL data directory (`${DATA_DIR}/archive`). A single disk failure destroys both data and archive, defeating the purpose of WAL archiving.
- No `die()` helper in `lib/common_functions.sh` despite ~30-40 scattered `print_error; exit 1` pairs across installer scripts.

### Medium (open)

- `network_test/` and `performance_test/` categories not yet modernized — inconsistent output formatting, some scripts lack `set -euo pipefail`.
- `vps_scripts.sh` still contains direct third-party `curl | bash` flows without safety wrappers (legacy-only, but still reachable).
- `ruby.sh` sed cleanup block uses 4 separate `sed -i` calls when 1 combined call would suffice.

### Low (open)

- Some scripts use predictable `/tmp` log file paths (`LOG_FILE="/tmp/xxx_$(date ...).log"`) rather than `mktemp`.
- Test coverage is syntax/path/pattern-based — no behavioral or integration tests.
- Several legacy category scripts still use independent fixed-width banners; migrate them to shared UI helpers when those categories are modernized.

## Completed In This Optimization Round (2026-06-11)

### Launcher hardening
- Fixed wget missing `--connect-timeout` (was 60s, now 6s on bad connections)
- Added `bash -n` syntax validation to both `run_remote_script_url()` and `run_remote_command()`
- Added `pipefail` to `run_remote_command` temp-file wrapper
- Added Hysteria2 (Proxy Tools item 6) and WP Panel (Service Install item 21)

### Installer hardening (11 scripts)
- `docker.sh`, `nginx.sh`, `mysql.sh`, `postgresql.sh`, `redis.sh`, `nodejs.sh`, `python.sh`, `go.sh`, `java.sh`, `ruby.sh`, `kubernetes.sh`
- All now have `set -euo pipefail` (except ruby.sh which uses explicit error handling)
- Cross-script `VERSION_ID` unbound-variable crash fixed (9 scripts)
- Critical bugs fixed: `TOTAL_MEM` unbound, dead `PIPESTATUS`, `set -e` preempting guards, `nproc`→`make -j0`, `make -j` floor, wget silent-exit, trap safety, build-dir leak

### Library fixes
- Quoted `$default` in `ask_yes_no()`
- Quoted `$1` in service-control print messages
- Hardened config helpers: exact keys, same-directory atomic writes, symlink guards

### Test suite
- 30 tests, all pass
- Per-installer safety tests for all 11 core installers
- Cross-category coverage for launcher paths, execution safety, UI, loader, EOF handling
- Responsive layout coverage for wide/narrow terminals and `LC_ALL=C` CJK width handling

### Documentation
- `CLAUDE.md`: accurate architecture, distro/arch, test commands
- `CHANGELOG.md`: comprehensive Unreleased section
- `DEVELOPMENT_GUIDE.md`: full test suite, architecture patterns, error-handling rules
- `PROGRESS.md`, `TASKS.md`, `SESSION.md`: current state

## Next Recommended Review Targets

1. Add `set -euo pipefail` to remaining 8 service_install scripts
2. Refactor `network_test/` category (5 scripts) for consistent structure
3. Refactor `performance_test/` category (4 scripts) for consistent structure
4. Extract repeated build-from-source pattern into shared helper
5. Add `die()` helper to `lib/common_functions.sh`
6. Create `scripts/service_install/wppanel.sh` wrapper

## Review Heuristics

Use this checklist when touching a script:

- [ ] Can it be run twice safely (idempotent)?
- [ ] Does it validate external input before use?
- [ ] Does it log failures clearly with actionable messages?
- [ ] Does it use `mktemp` for temp files, not predictable paths?
- [ ] Does it avoid `eval` unless genuinely unavoidable?
- [ ] Does it separate first-party and third-party execution clearly?
- [ ] Does it have `set -euo pipefail` (or explicit error handling)?
- [ ] Are all variables quoted unless unquoted expansion is required?
- [ ] Do heredocs use quoted `<< 'EOF'` when expansion is unwanted, unquoted `<< EOF` when expansion is needed?
- [ ] Are command substitutions in heredocs pre-computed to avoid `set -e` surprises?
