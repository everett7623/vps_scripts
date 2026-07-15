#!/bin/bash
# ==============================================================================
# Script: tests/validate_update_scripts_legacy.sh
# Purpose: Keep removed legacy update scripts out of the active architecture.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

if [ -d "${REPO_ROOT}/scripts/update_scripts" ]; then
    echo "Removed legacy update_scripts directory must not be restored." >&2
    exit 1
fi

if grep -Eq 'run_repo_script "scripts/update_scripts/' "${REPO_ROOT}/vps.sh"; then
    echo "Legacy update scripts must not be exposed from the active launcher." >&2
    exit 1
fi

echo "Update scripts legacy boundary is valid."
