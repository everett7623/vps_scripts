#!/bin/bash
# ==============================================================================
# Script: tests/validate_execution_safety.sh
# Purpose: Guard against avoidable eval and string-shell execution regressions.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

require_no_pattern() {
    local file="$1"
    local pattern="$2"
    local message="$3"

    if grep -Eq "${pattern}" "${REPO_ROOT}/${file}"; then
        echo "${message}: ${file}" >&2
        exit 1
    fi
}

require_no_pattern "vps.sh" '(^|[[:space:]])eval[[:space:]]' "Launcher should not use eval for command execution"
require_no_pattern "scripts/system_tools/update_system.sh" '(^|[[:space:]])eval[[:space:]]' "System update workflow should not use eval"
require_no_pattern "scripts/system_tools/update_system.sh" 'sh[[:space:]]+-c' "System update workflow should avoid sh -c command strings"

echo "Execution safety checks are valid."
