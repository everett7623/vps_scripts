#!/bin/bash
# ==============================================================================
# Script: tests/validate_modern_cli_tools.sh
# Purpose: Validate modern CLI toolkit safety and launcher integration.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/scripts/other_tools/modern_cli.sh"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"

test -f "${SCRIPT}"
bash -n "${SCRIPT}"
grep -Fq 'set -euo pipefail' "${SCRIPT}"
grep -Fq 'UPDATE_CMD=(' "${SCRIPT}"
grep -Fq 'INSTALL_CMD=(' "${SCRIPT}"
grep -Fq -- '--status' "${SCRIPT}"
grep -Fq -- '--install' "${SCRIPT}"
grep -Fq -- '--help' "${SCRIPT}"
grep -Fq 'run_repo_script "scripts/other_tools/modern_cli.sh"' "${LAUNCHER}"
help_output=$(bash "${SCRIPT}" --help)
grep -Fq -- '--status' <<< "${help_output}"
grep -Fq -- '--install' <<< "${help_output}"

if grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(ba)?sh' "${SCRIPT}"; then
    echo "Modern CLI toolkit must not pipe downloads into a shell." >&2
    exit 1
fi

echo "Modern CLI toolkit safety is valid."
