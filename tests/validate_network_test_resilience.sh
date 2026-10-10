#!/bin/bash
# ==============================================================================
# Script: tests/validate_network_test_resilience.sh
# Purpose: Regression checks for network_test Issue #2 hardening.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
NETWORK_DIR="${REPO_ROOT}/scripts/network_test"
COMMON_LIB="${REPO_ROOT}/lib/common_functions.sh"

FILES=(
    "scripts/network_test/backhaul_route_test.sh"
    "scripts/network_test/bandwidth_test.sh"
    "scripts/network_test/ip_quality_test.sh"
    "scripts/network_test/network_quality_test.sh"
    "scripts/network_test/streaming_unlock_test.sh"
)

fail() {
    echo "$1" >&2
    exit 1
}

grep -Fq 'init_script_dirs()' "${COMMON_LIB}" || fail "Missing init_script_dirs() in common_functions.sh"
grep -Fq 'run_soft()' "${COMMON_LIB}" || fail "Missing run_soft() in common_functions.sh"
grep -Eq 'export -f safe_mkdir .*init_script_dirs .*run_soft' "${COMMON_LIB}" || fail "init_script_dirs/run_soft not exported"

for relative_path in "${FILES[@]}"; do
    target="${REPO_ROOT}/${relative_path}"
    [ -f "${target}" ] || fail "Missing file: ${relative_path}"
    bash -n "${target}"

    if grep -Eq '\[ ! -d .* \] && mkdir' "${target}"; then
        fail "${relative_path} still uses set -e unsafe [ ! -d ] && mkdir"
    fi

    if ! grep -Eq 'init_script_dirs' "${target}"; then
        fail "${relative_path} does not call init_script_dirs"
    fi
done

BACKHAUL="${NETWORK_DIR}/backhaul_route_test.sh"
grep -Fq 'while [ $# -gt 0 ]' "${BACKHAUL}" || fail "backhaul_route_test.sh missing safe CLI while-loop"
if grep -Eq 'if \[ -n "\$1" \]' "${BACKHAUL}"; then
    fail "backhaul_route_test.sh still reads unbound \$1"
fi

BANDWIDTH="${NETWORK_DIR}/bandwidth_test.sh"
grep -Fq '单点失败不终止整轮测试' "${BANDWIDTH}" || fail "bandwidth_test.sh missing soft-fail comment for speedtest"
# Soft-fail calls at menu / CLI entry points
grep -Fq 'run_speedtest_single "$id" "$name" || true' "${BANDWIDTH}" || fail "bandwidth_test.sh missing || true around speedtest calls"
# Function body must return 0 after logging node failure
awk '/^run_speedtest_single\(\)/,/^}/ { if ($0 ~ /return 1/) bad=1 } END { exit bad ? 1 : 0 }' "${BANDWIDTH}" \
    || fail "bandwidth_test.sh run_speedtest_single still returns 1"
grep -Fq -- '--skip-install' "${BANDWIDTH}" || fail "bandwidth_test.sh missing --skip-install"
grep -Fq -- '--skip-install' "${BACKHAUL}" || fail "backhaul_route_test.sh missing --skip-install"
grep -Fq -- '--skip-install' "${NETWORK_DIR}/network_quality_test.sh" \
    || fail "network_quality_test.sh missing --skip-install"

IP_QUALITY="${NETWORK_DIR}/ip_quality_test.sh"
grep -Fq 'local arg1="${1:-}"' "${IP_QUALITY}" || fail "ip_quality_test.sh missing arg1=\${1:-} guard"

STREAMING="${NETWORK_DIR}/streaming_unlock_test.sh"
# get_ip_location must not abort the script on missing public IP
if grep -A3 '无法获取公网IP' "${STREAMING}" | grep -Fq 'return 1'; then
    fail "streaming_unlock_test.sh get_ip_location still returns 1"
fi

# Behavioral smoke: init_script_dirs falls back when preferred cannot be created
# shellcheck source=/dev/null
source "${COMMON_LIB}"
TEST_ROOT=$(mktemp -d "/tmp/vps-net-resilience.XXXXXX")
cleanup() { rm -rf -- "${TEST_ROOT}"; }
trap cleanup EXIT

# Preferred path is under a regular file so mkdir must fail → fallback
touch "${TEST_ROOT}/blocker"
export VPS_LOG_DIR="${TEST_ROOT}/blocker/nested_logs"
init_script_dirs "resilience_smoke" "testrun"
case "${LOG_DIR}" in
    "${TEST_ROOT}/blocker"/*) fail "init_script_dirs used blocked preferred dir" ;;
esac
[ -d "${REPORT_DIR}" ] || fail "REPORT_DIR not created"
[ -f "${LOG_FILE}" ] || fail "LOG_FILE not created"

# Preferred writable path is used when available
export VPS_LOG_DIR="${TEST_ROOT}/writable"
mkdir -p "${VPS_LOG_DIR}"
init_script_dirs "resilience_ok" "testrun2"
[ "${LOG_DIR}" = "${TEST_ROOT}/writable" ] || fail "init_script_dirs did not prefer writable VPS_LOG_DIR"

echo "Network test resilience checks are valid."
