#!/bin/bash
# ==============================================================================
# Script: tests/validate_python_installer_safety.sh
# Purpose: Guard Python installer input and remote-execution safety.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/service_install/python.sh"

bash -n "${SCRIPT}"
grep -Fq 'validate_inputs' "${SCRIPT}"
grep -Fq 'run_remote_installer "https://pyenv.run"' "${SCRIPT}"
grep -Fq 'WORK_DIR=$(mktemp -d "/tmp/python-build.XXXXXX")' "${SCRIPT}"
grep -Fq 'trap cleanup_work_dir EXIT' "${SCRIPT}"

if grep -Eq 'curl[^\n]*\|[[:space:]]*bash' "${SCRIPT}"; then
    echo "Python installer still pipes remote content to bash." >&2
    exit 1
fi

if grep -Eq '(^|[[:space:]])eval[[:space:]]' "${SCRIPT}"; then
    echo "Python installer still uses eval." >&2
    exit 1
fi

if grep -Fq 'rm -rf /tmp/Python-${PYTHON_VERSION}*' "${SCRIPT}"; then
    echo "Python installer still uses version-derived wildcard cleanup." >&2
    exit 1
fi

help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- "--method" <<< "${help_output}"
grep -Fq -- "--version" <<< "${help_output}"

echo "Python installer safety is valid."
