#!/bin/bash
# ==============================================================================
# Script: tests/validate_nginx_installer_safety.sh
# Purpose: Guard Nginx installer download and source-build safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/nginx.sh"

bash -n "${SCRIPT}"
grep -Fq 'download_to_file()' "${SCRIPT}"
grep -Fq 'key_file=$(mktemp "/tmp/nginx-key.XXXXXX")' "${SCRIPT}"
grep -Fq 'work_dir=$(mktemp -d "/tmp/nginx-build.XXXXXX")' "${SCRIPT}"
grep -Fq 'archive_file="${work_dir}/nginx-${NGINX_VERSION}.tar.gz"' "${SCRIPT}"
grep -Fq 'make -j"$(nproc)"' "${SCRIPT}"
grep -Fq 'rm -rf -- "$work_dir"' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh|apt-key)' "${SCRIPT}"; then
    echo "Nginx installer still pipes remote content into a command." >&2
    exit 1
fi

if grep -Fq 'cd /tmp' "${SCRIPT}" || grep -Eq 'rm[[:space:]]+-rf[[:space:]]+/tmp/nginx' "${SCRIPT}"; then
    echo "Nginx source build still uses shared /tmp paths." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--stable" <<< "${help_output}"
grep -Fq -- "--source" <<< "${help_output}"

echo "Nginx installer safety is valid."
