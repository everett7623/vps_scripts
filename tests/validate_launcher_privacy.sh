#!/bin/bash
# ==============================================================================
# Script: tests/validate_launcher_privacy.sh
# Purpose: Ensure the launcher does not emit implicit usage-counter requests.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"

if grep -Fq 'visitor-badge.laobi.icu' "${LAUNCHER}"; then
    echo "Launcher must not contact a usage-counter service implicitly." >&2
    exit 1
fi

if grep -Fq '累计运行:' "${LAUNCHER}"; then
    echo "Launcher must not display a removed remote usage counter." >&2
    exit 1
fi

echo "Launcher privacy boundary is valid."
