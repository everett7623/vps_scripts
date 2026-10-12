#!/bin/bash
# ==============================================================================
# Script: run_all_tests.sh
# Purpose: Run every repository validation script and report a summary.
# Usage:   bash run_all_tests.sh [repo_root]
# ==============================================================================

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${1:-${SCRIPT_DIR}}"

cd "${REPO_ROOT}" || exit 1
export REPO_ROOT_OVERRIDE="${PWD}"
export LAUNCHER_OVERRIDE="${PWD}/vps.sh"

failures=0
total=0
failed_tests=()

for test_file in tests/*.sh; do
    total=$((total + 1))
    echo "RUN ${test_file}"
    if ! bash "${test_file}"; then
        echo "FAIL ${test_file}" >&2
        failures=$((failures + 1))
        failed_tests+=("${test_file}")
    fi
done

echo "TEST_TOTAL=${total} TEST_FAILURES=${failures}"
if [ "${failures}" -ne 0 ]; then
    printf '  failed: %s\n' "${failed_tests[@]}" >&2
    exit 1
fi
