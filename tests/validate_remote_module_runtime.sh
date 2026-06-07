#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
RUNTIME_ROOT=$(mktemp -d "/tmp/vps-runtime-test.XXXXXX")

cleanup() {
    rm -rf "${RUNTIME_ROOT}"
}
trap cleanup EXIT

mkdir -p \
    "${RUNTIME_ROOT}/scripts/system_tools" \
    "${RUNTIME_ROOT}/lib" \
    "${RUNTIME_ROOT}/config"

cp "${REPO_ROOT}/lib/common_functions.sh" "${RUNTIME_ROOT}/lib/"
cp "${REPO_ROOT}/config/vps_scripts.conf" "${RUNTIME_ROOT}/config/"
cp "${REPO_ROOT}/scripts/system_tools/clean_system.sh" "${RUNTIME_ROOT}/scripts/system_tools/"
cp "${REPO_ROOT}/scripts/system_tools/set_timezone.sh" "${RUNTIME_ROOT}/scripts/system_tools/"

clean_help=$(bash "${RUNTIME_ROOT}/scripts/system_tools/clean_system.sh" --help)
timezone_help=$(bash "${RUNTIME_ROOT}/scripts/system_tools/set_timezone.sh" --help)

grep -Fq "用法：bash clean_system.sh" <<< "${clean_help}"
grep -Fq "用法：bash set_timezone.sh" <<< "${timezone_help}"

echo "Remote module runtime layout is valid."
