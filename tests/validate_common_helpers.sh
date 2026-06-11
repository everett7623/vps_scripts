#!/bin/bash
# ==============================================================================
# Script: tests/validate_common_helpers.sh
# Purpose: Validate shared config and temporary-file helper safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
TEST_ROOT=$(mktemp -d "/tmp/vps-common-test.XXXXXX")

cleanup() {
    rm -rf -- "${TEST_ROOT}"
}
trap cleanup EXIT

# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/common_functions.sh"

config_file="${TEST_ROOT}/config/settings.conf"
mkdir -p "$(dirname "${config_file}")"
printf '%s\n' 'FOO=old' 'FOO_EXTRA=keep' 'QUOTED="hello world"' > "${config_file}"
chmod 640 "${config_file}"

[ "$(read_config "${config_file}" "FOO" "default")" = "old" ]
[ "$(read_config "${config_file}" "QUOTED" "default")" = "hello world" ]
[ "$(read_config "${config_file}" "MISSING" "default")" = "default" ]

write_config "${config_file}" "FOO" "new value"
write_config "${config_file}" "ADDED" "yes"

grep -Fxq 'FOO=new value' "${config_file}"
grep -Fxq 'FOO_EXTRA=keep' "${config_file}"
grep -Fxq 'ADDED=yes' "${config_file}"
if [ "$(uname -s)" = "Linux" ]; then
    [ "$(stat -c '%a' "${config_file}")" = "640" ]
fi

if read_config "${config_file}" 'FOO.*' "default" >/dev/null 2>&1; then
    echo "read_config accepted an invalid key." >&2
    exit 1
fi

if write_config "${config_file}" 'BAD-KEY' "value" >/dev/null 2>&1; then
    echo "write_config accepted an invalid key." >&2
    exit 1
fi

if [ "$(uname -s)" = "Linux" ]; then
    real_temp="${TEST_ROOT}/real-temp"
    temp_link="/tmp/vps-common-link.$$"
    mkdir -p "${real_temp}"
    printf '%s\n' "keep" > "${real_temp}/sentinel"
    ln -s "${real_temp}" "${temp_link}"

    if cleanup_temp_files "${temp_link}" >/dev/null 2>&1; then
        echo "cleanup_temp_files accepted a symbolic-link path." >&2
        exit 1
    fi

    [ -f "${real_temp}/sentinel" ]
    rm -f -- "${temp_link}"
fi

safe_temp="/tmp/vps-common-clean.$$"
mkdir -p "${safe_temp}"
printf '%s\n' "remove" > "${safe_temp}/file"
cleanup_temp_files "${safe_temp}"
[ ! -e "${safe_temp}" ]

echo "Common helper safety is valid."
