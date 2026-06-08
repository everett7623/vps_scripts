#!/bin/bash
# ==============================================================================
# Script: tests/validate_ui_framework.sh
# Purpose: Validate shared UI helpers used by modernized modules.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
COMMON_FILE="${REPO_ROOT}/lib/common_functions.sh"

require_text() {
    local text="$1"

    if ! grep -Fq "${text}" "${COMMON_FILE}"; then
        echo "Missing UI helper text: ${text}" >&2
        exit 1
    fi
}

require_text "print_key_value()"
require_text "print_step()"
require_text "print_status()"
require_text "print_runtime_context()"
require_text "UI_THEME"

bash -n "${COMMON_FILE}"

echo "Shared UI framework helpers are valid."
