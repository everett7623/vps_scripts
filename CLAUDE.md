# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This is the mainline repo. All tests, scripts, and docs live here; there is no separate "work copy" — treat this directory as the single source of truth.

## Build, lint, and test

No build step — everything is Bash scripts. All test scripts accept `REPO_ROOT_OVERRIDE` (and `LAUNCHER_OVERRIDE` where relevant) so they can run from any directory. The commands below assume you are `cd`'d to the repo root; `$PWD` must be the repo root when used as the override value.

### Quick syntax checks

```bash
bash -n vps.sh
bash -n vps_scripts.sh
bash -n scripts/system_tools/install_deps.sh
```

### Launcher coverage

```bash
# Menu entries must point to files that exist in the repo
LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh

# Per-category launcher coverage
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools_launcher.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_service_install_launcher.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_active_category_coverage.sh
```

### Core asset & policy validation

```bash
# Required files present, version.json ↔ config version match, legacy launcher points to vps.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh

# All .sh files: #!/bin/bash header, LF line endings, no UTF-8 BOM
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_script_headers.sh

# CRLF not allowed in shell scripts, docs, metadata, or config files
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_line_endings_policy.sh

# update_scripts/ removed; update_log.sh hands off to CHANGELOG.md
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_update_scripts_legacy.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_update_log_handoff.sh
```

### Syntax validation for script categories

```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_common_helpers.sh
```

### Safety & execution checks

```bash
# No eval / sh -c regressions in launcher and update-system paths
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_execution_safety.sh

# Per-installer safety (input validation, download paths, archive handling)
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_docker_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_python_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_kubernetes_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_go_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_java_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_nginx_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_mysql_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_postgresql_installer_safety.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_redis_installer_safety.sh

# Input contract and remote module runtime
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_input_contract.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_remote_module_runtime.sh
```

### UI, loader & misc

```bash
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_ui_framework.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_chinese_ui.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_loader_performance.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_menu_eof.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_command_install.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_legacy_launcher_policy.sh
```

### Static analysis (if shellcheck is installed)

```bash
shellcheck vps.sh vps_scripts.sh
shellcheck lib/common_functions.sh
```

## Architecture

**VPS Scripts** is a modular Bash toolkit for Linux VPS operations — diagnostics, benchmarking, service deployment, and system maintenance. Deployed via `curl | bash` from GitHub raw content. Licensed AGPL-3.0. Target distros (per version.json): Ubuntu 18.04+, Debian 10+, CentOS 7+, AlmaLinux/Rocky 8+, Alpine 3.10+. Architectures: x86_64, aarch64. Fedora and Arch have some community support but are not in the canonical compatibility list. The UI is in Chinese.

### Dual-launcher design

| Launcher | File | Role |
|----------|------|------|
| Primary (modular) | `vps.sh` | Self-contained menu that downloads individual `scripts/` modules to temp files and executes them. First-party modules are fetched securely; third-party scripts require interactive confirmation. |
| Legacy (compatibility) | `vps_scripts.sh` | Thin handoff shell that offers to launch local `vps.sh`, download remote `vps.sh`, or print the bootstrap command. No longer expanded with new features. |

Both launchers are self-contained (no `source` of external libs) and detect `curl`/`wget` at startup. They use `mktemp` for downloads and `trap INT TERM` for clean interrupt handling.

### Persistent install command

`vps.sh --install` creates a persistent command at `/usr/local/bin/vps` that execs `/usr/local/lib/vps-scripts/vps.sh`. The launcher is downloaded fresh on install. `vps.sh --uninstall-command` removes both files. `VPS_INSTALL_PREFIX` overrides the install root; `VPS_INSTALL_SOURCE_OVERRIDE` points to a local launcher file instead of downloading.

### Runtime execution model (`run_repo_script()`)

When the launcher runs a first-party script, it does **not** execute the local file directly. Instead:

1. **Path validation** — the script path must be relative and contain no `..`.
2. **Temp runtime directory** — created via `mktemp -d`.
3. **Parallel download** — the script, `lib/common_functions.sh`, and `config/vps_scripts.conf` are downloaded concurrently to the temp dir.
4. **Local fast path** — if a local repo copy exists and passes `bash -n`, it is copied directly (avoids network round-trip).
5. **Execution** — `bash <temp_script>` runs the script from the temp directory.
6. **Cleanup** — the temp directory is removed after execution.

**Consequence for scripts**: when run through the launcher, scripts execute from a temp directory, not the repo. Scripts that need to locate the library or config must compute paths relative to `$0` (the temp script path) — not relative to a repo root.

### Download fallback chain

The launcher tries these sources in order for each downloaded file:
1. **Local repo copy** (if `LOCAL_REPO_ROOT` is set and file exists + passes `bash -n`)
2. **GitHub Raw** — `https://raw.githubusercontent.com/everett7623/vps_scripts/main/<path>`
3. **GitHub refs/heads** — `https://github.com/everett7623/vps_scripts/raw/refs/heads/main/<path>`
4. **jsDelivr CDN** — `https://cdn.jsdelivr.net/gh/everett7623/vps_scripts@main/<path>`

Each remote base is tried with 2 retries (1s delay between attempts). Timeouts are configurable via `VPS_DOWNLOAD_CONNECT_TIMEOUT` (default 6s) and `VPS_DOWNLOAD_MAX_TIME` (default 60s).

### Shared library (`lib/common_functions.sh`)

Scripts in `scripts/` can `source` this library. It provides:
- **Logging**: `print_info`, `print_success`, `print_warn`, `print_error` (level-gated via `CURRENT_LOG_LEVEL`)
- **Formatting**: `print_header`, `print_title`, `print_separator`, `show_progress`, `wait_with_animation`
- **System detection**: `get_os_release`, `get_os_version`, `get_arch`, `get_cpu_cores`, `get_total_memory`
- **Package management**: `command_exists`, `ensure_command` (auto-installs if missing, across apt/yum/dnf/apk/pacman)
- **Safety utilities**: `check_root`, `is_valid_identifier`, `backup_file`, `safe_mkdir`, `check_port`
- **I/O**: `ask_yes_no`, `select_option`, `read_input`, `download_file` (with retries), `read_config`/`write_config`
- **Service control**: `check_service_status`, `start_service`, `stop_service`, `restart_service`
- **Cleanup**: `cleanup_temp_files`, `graceful_exit` (called on `INT`/`TERM`)

All functions are `export -f`'d so they are available to sub-shells.

### Defensive library sourcing pattern

Scripts must handle two execution contexts: running from a cloned repo (library available) and running from a launcher-created temp directory (library downloaded alongside). The canonical pattern (from `install_deps.sh`):

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
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[完成] $1${NC}"; }
    # ... etc.
fi
```

The `PROJECT_ROOT` is computed as two levels up from the script's own directory, which works both when the script is at `scripts/category/script.sh` in a repo and when it's at `tmp/vps_runtime/scripts/category/script.sh` from the launcher.

### Script categories

```
scripts/
├── system_tools/       # update_system, install_deps, clean_system, optimize_system,
│                       #   system_info, change_hostname, set_timezone, health_check, security_audit
├── network_test/       # backhaul_route, bandwidth, ip_quality, network_quality, streaming_unlock
├── performance_test/   # cpu_benchmark, disk_io, memory_benchmark, network_throughput
├── service_install/    # docker, nginx, mysql, postgresql, redis, nodejs, python, go, java,
│                       #   ruby, rust, wordpress, jenkins, kubernetes, ldnmp,
│                       #   panel installers: 1panel, aapanel, amh, btpanel, cyberpanel
├── other_tools/        # bbr, fail2ban, nezha, swap, modern_cli
└── uninstall_scripts/  # clean_service_residues, rollback_system_environment,
│                       #   clear_configuration_files, full_uninstall
```

### Config (`config/vps_scripts.conf`)

Project-level defaults: package lists for basic/dev/monitor/security groups, service install versions (nginx, mysql, php, redis), benchmark parameters, sysctl optimization values, third-party script URLs, logging paths. Sourced by scripts that also source `lib/common_functions.sh`. Its `SCRIPT_VERSION` must match `version.json`'s `version` field — this is enforced by `tests/validate_core_assets.sh`.

### Version metadata (`version.json`)

Canonical source for project version (`1.1.0`), supported OS/arch, launcher URLs, update-check URL, and documentation index. The launcher reads this at runtime for update notifications. Config key `maintenance_state` is `active-modernization` — the project is under active development.

### Legacy changelog viewer (`update_log.sh`)

Root-level compat script that reads `version.json` and prints `CHANGELOG.md` excerpt. Its only role is displaying version info; `CHANGELOG.md` is the canonical history. Any release-note logic should update `CHANGELOG.md`, not this script.

### Environment variable overrides

| Variable | Used by | Purpose |
|----------|---------|---------|
| `REPO_ROOT_OVERRIDE` | All tests | Point tests at a specific repo root |
| `LAUNCHER_OVERRIDE` | Launcher path tests | Point at a specific launcher file |
| `VPS_DOWNLOAD_CONNECT_TIMEOUT` | Launcher | Connection timeout for downloads (default 6s) |
| `VPS_DOWNLOAD_MAX_TIME` | Launcher | Max download time (default 60s) |
| `VPS_INSTALL_PREFIX` | Launcher `--install` | Install root (default `/usr/local`) |
| `VPS_INSTALL_SOURCE_OVERRIDE` | Launcher `--install` | Use local file as launcher source |
| `VPS_CONNECT_TIMEOUT` | Common functions | Connection timeout for URL/port checks (default 2s) |
| `CURRENT_LOG_LEVEL` | Common functions | Log verbosity (0=DEBUG, 1=INFO, 2=WARN, 3=ERROR) |
| `UI_WIDTH` | Common functions | Terminal width for formatting (default 80) |
| `UI_THEME` | Common functions | Theme identifier (default `neon-shell`) |

### `vps.sh` menu structure

```
Main Menu
├── 1. System Tools         → scripts run via run_repo_script()
├── 2. Network Tests        → scripts run via run_repo_script()
├── 3. Performance Tests    → scripts run via run_repo_script()
├── 4. Service Install      → scripts run via run_repo_script()
├── 5. Community Scripts    → third-party: run_remote_script_url() or run_remote_command()
├── 6. Proxy Tools          → third-party: run_remote_script_url()
├── 7. Other Tools          → mixed first-party + third-party
├── 8. Command Setup        → install/uninstall persistent vps command
├── 9. Update Info
├── 10. Cleanup / Uninstall → scripts run via run_repo_script()
└── 0. Exit
```

Key pattern: `run_repo_script()` validates the path is relative and contains no `..`, downloads to `mktemp` temp file with parallel dependency fetch, executes, then cleans up. `run_remote_script_url()` and `run_remote_command()` require `[y/N]` confirmation.

### Script file policy

All `.sh` files in the repository must:
- Start with `#!/bin/bash` (no other shell)
- Use LF line endings (no CRLF)
- Have no UTF-8 BOM
- Be ASCII unless there is a strong reason otherwise

`.gitattributes` enforces LF for all `.sh`, `.md`, `.json`, `.conf`, and `.txt` files — important for Windows/NAS checkouts. The line-endings policy is validated by `tests/validate_script_headers.sh` and `tests/validate_line_endings_policy.sh`.

Script header format:
```bash
#!/bin/bash
# ==============================================================================
# Script: path/to/script.sh
# Purpose: One-line description.
# ==============================================================================
```

## Working rules (from AGENTS.md)

- Prefer editing the modular path (`vps.sh`, `lib/`, `scripts/`, `tests/`) over expanding `vps_scripts.sh`.
- Do not restore `scripts/update_scripts/`; migrate any needed historical logic into a focused, tested module.
- Avoid `eval` unless no safer alternative exists.
- Prefer arrays over command strings for package-manager commands.
- Prefer `mktemp` over predictable `/tmp` filenames.
- Validate user input before using in commands, paths, or service names.
- When downloading first-party modules, download to temp file and execute that file — not process substitution.
- First-party launcher actions must point only to files that exist in this repository.
- Keep new files ASCII unless strong reason otherwise.
- Quote variables unless unquoted expansion is genuinely required.

## Review priorities

When reviewing changes to this repo, focus on: reliability, safety, idempotency, error handling, input validation, logging clarity, menu-to-script consistency, and testability.

## Documentation expectations (from AGENTS.md)

Update the relevant docs when behavior changes:
- `README.md` for user-visible workflow changes
- `CHANGELOG.md` for notable changes
- `PROGRESS.md` and `TASKS.md` for roadmap changes
- `RELEASE_CHECKLIST.md` when release process changes
