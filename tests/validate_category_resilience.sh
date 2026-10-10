#!/bin/bash
# ==============================================================================
# Script: tests/validate_category_resilience.sh
# Purpose: Full-repo scan for set -euo footguns across maintained categories.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

fail() {
    echo "$1" >&2
    exit 1
}

scan_scripts() {
    local pattern="$1"
    local matches=""
    matches=$(find "${REPO_ROOT}/scripts" -name '*.sh' -print0 2>/dev/null \
        | xargs -0 grep -nE "${pattern}" 2>/dev/null || true)
    if [ -n "${matches}" ]; then
        printf '%s\n' "${matches}" >&2
        return 0
    fi
    return 1
}

# No AND-list mkdir footgun in first-party scripts
if scan_scripts '\[ ! -d .* \] && mkdir'; then
    fail "Found set -e unsafe [ ! -d ] && mkdir patterns"
fi

# No unbound $1 probes under set -u in script entry points
if scan_scripts 'if \[ -n "\$1" \]'; then
    fail "Found unbound \$1 checks; use \${1:-}"
fi

# Shared helpers present
grep -Fq 'resolve_log_dir()' "${REPO_ROOT}/lib/common_functions.sh" || fail "Missing resolve_log_dir()"
grep -Fq 'init_script_dirs()' "${REPO_ROOT}/lib/common_functions.sh" || fail "Missing init_script_dirs()"
grep -Fq 'run_soft()' "${REPO_ROOT}/lib/common_functions.sh" || fail "Missing run_soft()"

# system_tools use resolve_log_dir in ensure/runtime paths
for script in optimize_system.sh clean_system.sh change_hostname.sh set_timezone.sh update_system.sh install_deps.sh; do
    grep -Fq 'resolve_log_dir' "${REPO_ROOT}/scripts/system_tools/${script}" \
        || fail "system_tools/${script} missing resolve_log_dir"
done
grep -Fq -- '--dry-run' "${REPO_ROOT}/scripts/system_tools/install_deps.sh" \
    || fail "install_deps.sh missing --dry-run"

# uninstall dry-run
grep -Fq -- '--dry-run' "${REPO_ROOT}/scripts/uninstall_scripts/full_uninstall.sh" \
    || fail "full_uninstall.sh missing --dry-run"

# LDNMP facade status handoff
grep -Fq -- '--status' "${REPO_ROOT}/scripts/service_install/ldnmp.sh" \
    || fail "ldnmp.sh missing --status"
grep -Fq '聚焦安装脚本' "${REPO_ROOT}/scripts/service_install/ldnmp.sh" \
    || fail "ldnmp.sh missing focused-installer guidance"

# launcher cancel messaging
grep -Fq '模块被中断' "${REPO_ROOT}/vps.sh" || fail "vps.sh missing interrupt messaging"

echo "Category resilience scan is valid."
