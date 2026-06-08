#!/bin/bash
# ==============================================================================
# Script: tests/validate_loader_performance.sh
# Purpose: Validate lightweight loader optimizations remain in place.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"
COMMON_FILE="${REPO_ROOT}/lib/common_functions.sh"

require_text() {
    local file="$1"
    local text="$2"

    if ! grep -Fq -- "${text}" "${file}"; then
        echo "Missing loader optimization text in ${file}: ${text}" >&2
        exit 1
    fi
}

require_text "${LAUNCHER}" "LOCAL_REPO_ROOT"
require_text "${LAUNCHER}" "DOWNLOAD_CONNECT_TIMEOUT"
require_text "${LAUNCHER}" "copy_local_repo_file()"
require_text "${LAUNCHER}" "download_repo_bundle()"
require_text "${LAUNCHER}" "并发加载模块与公共依赖"
require_text "${COMMON_FILE}" "--connect-timeout"
require_text "${COMMON_FILE}" "VPS_CONNECT_TIMEOUT"

if grep -Fq 'sleep "${attempt}"' "${LAUNCHER}"; then
    echo "Launcher still sleeps after every failed download attempt." >&2
    exit 1
fi

bash -n "${LAUNCHER}"
bash -n "${COMMON_FILE}"

echo "Loader performance optimizations are valid."
