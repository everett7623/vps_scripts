#!/bin/bash
# ==============================================================================
# Script: tests/validate_ui_layout.sh
# Purpose: Validate responsive widths and CJK-aware launcher alignment helpers.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${REPO_ROOT}/vps.sh"
COMMON_FILE="${REPO_ROOT}/lib/common_functions.sh"

require_text() {
    local file="$1"
    local text="$2"

    if ! grep -Fq "${text}" "${file}"; then
        echo "Missing responsive UI text in ${file}: ${text}" >&2
        exit 1
    fi
}

require_text "${LAUNCHER}" "get_ui_width()"
require_text "${LAUNCHER}" "text_display_width()"
require_text "${LAUNCHER}" 'VPS_UI_WIDTH'
require_text "${LAUNCHER}" 'MENU_LABEL_WIDTH'
require_text "${LAUNCHER}" 'UI_WIDTH}" -lt 64'
require_text "${COMMON_FILE}" "detect_ui_width()"
require_text "${COMMON_FILE}" "print_centered_line()"
require_text "${COMMON_FILE}" "print_aligned_value()"

# shellcheck source=../lib/common_functions.sh
source "${COMMON_FILE}"

VPS_UI_WIDTH=120
[ "$(detect_ui_width)" -eq 88 ] || {
    echo "UI width cap is not enforced." >&2
    exit 1
}

VPS_UI_WIDTH=52
[ "$(detect_ui_width)" -eq 52 ] || {
    echo "Explicit narrow UI width is not preserved." >&2
    exit 1
}

chinese_width=$(LC_ALL=C text_display_width "系统工具")
ascii_width=$(text_display_width "Docker")
[[ "${chinese_width}" =~ ^[0-9]+$ ]] && [ "${chinese_width}" -ge 4 ]
[[ "${ascii_width}" =~ ^[0-9]+$ ]] && [ "${ascii_width}" -eq 6 ]

bash -n "${LAUNCHER}"
bash -n "${COMMON_FILE}"

echo "Responsive UI layout helpers are valid."
