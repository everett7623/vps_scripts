# Development Guide

## Quick Start

```bash
git clone https://github.com/everett7623/vps_scripts.git
cd vps_scripts
```

No build step — everything is Bash. All tests accept `REPO_ROOT_OVERRIDE` (and `LAUNCHER_OVERRIDE` where relevant).

## Recommended Workflow

1. Inspect the target script and any shared helpers it sources.
2. Check whether the change belongs in the modular path (`vps.sh`, `lib/`, `scripts/`, `tests/`) or only in the legacy launcher (`vps_scripts.sh` — legacy-only, no new features).
3. Make the smallest change that improves reliability or safety without hiding errors.
4. Run syntax validation and relevant repo tests.
5. Update docs if behavior or workflow changed.

## Full Validation Suite

Run all commands from the repo root.

### Syntax checks
```bash
bash -n vps.sh
bash -n vps_scripts.sh
bash -n lib/common_functions.sh
bash -n scripts/system_tools/install_deps.sh
```

### Launcher coverage
```bash
LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools_launcher.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_service_install_launcher.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_active_category_coverage.sh
```

### Core assets & policy
```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_script_headers.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_line_endings_policy.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_update_scripts_legacy.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_update_log_handoff.sh
```

### Category syntax
```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_common_helpers.sh
```

### Installer safety (all 11 core installers)
```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_docker_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_python_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_kubernetes_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_go_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_java_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_nginx_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_mysql_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_postgresql_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_redis_installer_safety.sh
```

### Input contract & runtime
```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_input_contract.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_remote_module_runtime.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_execution_safety.sh
```

### UI, loader & misc
```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_ui_framework.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_ui_layout.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_chinese_ui.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_loader_performance.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_menu_eof.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_command_install.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_legacy_launcher_policy.sh
```

### Static analysis (if shellcheck installed)
```bash
shellcheck vps.sh vps_scripts.sh
shellcheck lib/common_functions.sh
```

### All tests in one command
```bash
export REPO_ROOT_OVERRIDE="$PWD"
for f in tests/*.sh; do bash "$f" || echo "FAIL: $f"; done
```

## Architecture Patterns

### Adding a new first-party script
1. Create `scripts/<category>/<name>.sh` with `#!/bin/bash` header, `set -euo pipefail`, and the defensive library-sourcing pattern
2. Add menu entry in `vps.sh` using `run_repo_script "scripts/<category>/<name>.sh"`
3. Add safety test in `tests/validate_<name>_installer_safety.sh` (for service_install)
4. Update `tests/validate_service_install_launcher.sh` or category-specific launcher test
5. Run full test suite

### Adding a new third-party menu entry
1. Add `print_menu_item` and `case` entry in the relevant menu function
2. Use `run_remote_script_url` for single-URL scripts, `run_remote_command` for multi-step commands
3. Update the prompt range (e.g., `[0-5]` → `[0-6]`)
4. Run `tests/validate_launcher_paths.sh` and category-specific tests

### Defensive library sourcing pattern
```bash
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    # Inline fallback: define minimal print_* and check_root functions
fi
```

### Temp-file handling
Always use `mktemp` or `mktemp -d` with the `XXXXXX` suffix pattern. Never use predictable `/tmp` paths.

```bash
local work_dir
work_dir=$(mktemp -d "/tmp/mybuild.XXXXXX") || { print_error "..."; exit 1; }
# ... do work ...
rm -rf -- "${work_dir}"
# Or use trap for automatic cleanup:
trap 'rm -rf -- "${work_dir}"' EXIT
```

### Error handling
With `set -euo pipefail`:
- Use `|| true` on commands expected to fail (e.g., `systemctl stop ufw || true`)
- Use `if ! cmd; then ... fi` when you need the error message before exit
- Use `|| { print_error "..."; exit 1; }` for fatal errors
- Guard `command substitution` pipelines with `|| true` when `set -e` could preempt your empty-check:
  ```bash
  result=$(some_pipeline | grep ... | tail -1) || true
  if [[ -z "$result" ]]; then ... fi
  ```

## Change Priorities

- First-party launcher safety
- Idempotent installers (safe to run twice)
- Reduced hidden side effects
- Clear rollback and cleanup behavior
- Consistent logging and status messages
- Cross-platform line endings (LF, enforced by `.gitattributes`)

## Script Design Rules

- One responsibility per script
- Shared helpers in `lib/common_functions.sh`
- `export -f` all library functions for sub-shell availability
- New menu entries must point to existing files or valid URLs
- `scripts/update_scripts/` was removed — do not restore it; migrate needed logic into a focused module
- Avoid `eval` unless no safer alternative exists
- Prefer arrays over command strings for package-manager commands
- Validate user input before using in commands, paths, or service names
- Quote variables unless unquoted expansion is genuinely required

## Terminal UI Rules

- Terminal scripts cannot control the user's font size. Use bold/bright hierarchy, whitespace, and concise labels to improve readability instead.
- Respect `VPS_UI_WIDTH` for deterministic previews and tests; otherwise detect the terminal width and cap wide layouts at 88 columns.
- Use `text_display_width()` plus explicit padding for mixed Chinese/ASCII columns. Do not use `printf %-Ns` directly for CJK menu alignment.
- Switch long menu details to a second indented line below 64 columns.
- Avoid clearing the screen when stdout is not a TTY or `TERM` is unset/`dumb`.

## Release Process

See `RELEASE_CHECKLIST.md` and `VERSIONING.md`. Key steps:
- Update `CHANGELOG.md` Unreleased section
- Update `version.json` version and release_date
- Review `TASKS.md` and `PROGRESS.md` for milestone completion
- Run full test suite (34 tests)
- Test remote launcher command from a clean environment
