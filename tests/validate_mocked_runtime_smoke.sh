#!/bin/bash
# ==============================================================================
# Script: tests/validate_mocked_runtime_smoke.sh
# Purpose: Lightweight mocked behavioral smoke for helpers (no root, no network).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
TEST_ROOT=$(mktemp -d "/tmp/vps-mocked-runtime.XXXXXX")

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/common_functions.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# Mock package-manager style soft failure
fake_pkg_install() {
    return 42
}
run_soft "mocked package install" fake_pkg_install

# Mock download failure should not abort callers that use run_soft
fake_download() {
    return 7
}
run_soft "mocked download" fake_download

# resolve_log_dir prefers writable override
export VPS_LOG_DIR="${TEST_ROOT}/logs"
resolve_log_dir
[ "${LOG_DIR}" = "${TEST_ROOT}/logs" ] || fail "resolve_log_dir ignored VPS_LOG_DIR"

# init_script_dirs creates files under preferred dir
init_script_dirs "mock_module" "stamp"
[ -f "${LOG_FILE}" ] || fail "LOG_FILE missing"
[ -f "${REPORT_FILE}" ] || fail "REPORT_FILE missing"

# Blocked preferred path falls back
touch "${TEST_ROOT}/blocker"
export VPS_LOG_DIR="${TEST_ROOT}/blocker/nested"
resolve_log_dir
case "${LOG_DIR}" in
    "${TEST_ROOT}/blocker"/*) fail "resolve_log_dir used blocked path" ;;
esac

# safe_mkdir is idempotent under set -e
set -e
safe_mkdir "${TEST_ROOT}/logs"
safe_mkdir "${TEST_ROOT}/logs"

echo "Mocked runtime smoke checks are valid."
