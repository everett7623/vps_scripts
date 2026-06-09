#!/bin/bash
# ==============================================================================
# Script: tests/validate_menu_eof.sh
# Purpose: Ensure launcher menus exit cleanly when stdin reaches EOF.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"
output=""
status=0

if ! command -v timeout >/dev/null 2>&1; then
    echo "timeout command is required for EOF validation." >&2
    exit 1
fi

output=$(TERM=xterm timeout 8 bash "${LAUNCHER}" < /dev/null 2>&1) || status=$?

if [ "${status}" -eq 124 ]; then
    echo "Launcher did not exit after stdin EOF." >&2
    exit 1
fi

if [ "${status}" -ne 0 ]; then
    echo "Launcher exited unexpectedly on stdin EOF: ${status}" >&2
    printf '%s\n' "${output}" >&2
    exit 1
fi

if grep -Fq "无效选项" <<< "${output}"; then
    echo "Launcher treated stdin EOF as an invalid menu choice." >&2
    exit 1
fi

grep -Fq "输入已结束" <<< "${output}"

echo "Launcher menu EOF handling is valid."
