#!/bin/bash
# ==============================================================================
# Script: tests/validate_go_installer_safety.sh
# Purpose: Guard Go installer input, download, and removal safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/go.sh"

bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'validate_inputs()' "${SCRIPT}"
grep -Fq 'validate_go_version()' "${SCRIPT}"
grep -Fq 'validate_install_path()' "${SCRIPT}"
grep -Fq 'work_dir=$(mktemp -d "/tmp/go-install.XXXXXX")' "${SCRIPT}"
grep -Fq 'archive_file="${work_dir}/go.tar.gz"' "${SCRIPT}"
grep -Fq 'safe_remove_go_tree' "${SCRIPT}"
grep -Fq 'run_remote_installer "https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh" -b "${GOPATH}/bin"' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*(bash|sh)' "${SCRIPT}"; then
    echo "Go installer pipes remote content to a shell." >&2
    exit 1
fi

if grep -Fq 'cd /tmp' "${SCRIPT}" || grep -Fq 'wget -O go.tar.gz' "${SCRIPT}"; then
    echo "Go installer still uses a fixed /tmp archive path." >&2
    exit 1
fi

if grep -Eq 'rm[[:space:]]+-rf[[:space:]]+"\$\{INSTALL_PATH\}/go"' "${SCRIPT}"; then
    echo "Go installer still removes INSTALL_PATH/go directly." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--version" <<< "${help_output}"
grep -Fq -- "--install-path" <<< "${help_output}"

echo "Go installer safety is valid."
