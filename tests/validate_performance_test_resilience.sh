#!/bin/bash
# ==============================================================================
# Script: tests/validate_performance_test_resilience.sh
# Purpose: Regression checks for performance_test log-dir and soft-fail hardening.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

FILES=(
    "scripts/performance_test/cpu_benchmark.sh"
    "scripts/performance_test/disk_io_benchmark.sh"
    "scripts/performance_test/memory_benchmark.sh"
    "scripts/performance_test/network_throughput_test.sh"
)

fail() {
    echo "$1" >&2
    exit 1
}

for relative_path in "${FILES[@]}"; do
    target="${REPO_ROOT}/${relative_path}"
    [ -f "${target}" ] || fail "Missing file: ${relative_path}"
    bash -n "${target}"

    if grep -Eq '\[ ! -d .* \] && mkdir' "${target}"; then
        fail "${relative_path} still uses set -e unsafe [ ! -d ] && mkdir"
    fi
    grep -Eq 'init_script_dirs' "${target}" || fail "${relative_path} missing init_script_dirs"
    grep -Fq -- '--skip-install' "${target}" || fail "${relative_path} missing --skip-install"
    grep -Fq 'SKIP_INSTALL' "${target}" || fail "${relative_path} missing SKIP_INSTALL"
    # Package installs must soft-fail under set -e
    if grep -E 'apt-get install|yum install|apk add' "${target}" | grep -v '\|\| true' | grep -q .; then
        fail "${relative_path} has hard-fail package install lines"
    fi
done

DISK_IO="${REPO_ROOT}/scripts/performance_test/disk_io_benchmark.sh"
grep -Fq '1-64' "${DISK_IO}" || fail "disk_io_benchmark.sh missing --size bounds check"

NET_TP="${REPO_ROOT}/scripts/performance_test/network_throughput_test.sh"
grep -Fq -- '--client 需要目标' "${NET_TP}" || fail "network_throughput_test.sh missing --client presence check"

# other_tools non-interactive flags
grep -Fq -- '--status' "${REPO_ROOT}/scripts/other_tools/swap.sh" || fail "swap.sh missing --status"
grep -Fq -- '--dry-run' "${REPO_ROOT}/scripts/other_tools/swap.sh" || fail "swap.sh missing --dry-run"
if grep -Fq -- 'swapoff -a' "${REPO_ROOT}/scripts/other_tools/swap.sh"; then
    fail "swap.sh still uses swapoff -a"
fi

grep -Fq -- '--status' "${REPO_ROOT}/scripts/other_tools/bbr.sh" || fail "bbr.sh missing --status"
grep -Fq 'main "$@"' "${REPO_ROOT}/scripts/other_tools/bbr.sh" || fail "bbr.sh must pass CLI args to main"

grep -Fq -- '--status' "${REPO_ROOT}/scripts/other_tools/fail2ban.sh" || fail "fail2ban.sh missing --status"
grep -Fq -- '--dry-run' "${REPO_ROOT}/scripts/other_tools/fail2ban.sh" || fail "fail2ban.sh missing --dry-run"

# launcher distinguishes interrupt cancel
grep -Fq '模块被中断' "${REPO_ROOT}/vps.sh" || fail "vps.sh missing interrupt cancel messaging"

echo "Performance test resilience checks are valid."
