#!/bin/bash
# ==============================================================================
# Script: tests/validate_nodejs_installer_safety.sh
# Purpose: Guard Node.js binary installer temp paths and SHA-256 verification.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/nodejs.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'work_dir=$(mktemp -d "/tmp/nodejs-install.XXXXXX")' "${SCRIPT}"
grep -Fq 'https://nodejs.org/dist/${FULL_VERSION}/SHASUMS256.txt' "${SCRIPT}"
grep -Fq 'sha256sum "${archive_file}"' "${SCRIPT}"
grep -Fq 'Node.js 归档 SHA-256 校验失败' "${SCRIPT}"
grep -Fq 'https://nodejs.org/dist/${FULL_VERSION}/${asset}' "${SCRIPT}"

if grep -Eq 'cd /tmp' "${SCRIPT}"; then
    echo "Node.js installer still uses a fixed /tmp working directory." >&2
    exit 1
fi

if grep -Fq 'wget -q "$DOWNLOAD_URL" -O nodejs.tar.xz' "${SCRIPT}"; then
    echo "Node.js installer still uses a fixed archive filename in /tmp." >&2
    exit 1
fi

echo "Node.js installer safety is valid."
