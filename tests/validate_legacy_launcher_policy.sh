#!/bin/bash
# ==============================================================================
# Script: tests/validate_legacy_launcher_policy.sh
# Purpose: Keep the legacy launcher limited to compatibility handoff behavior.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LEGACY="${REPO_ROOT}/vps_scripts.sh"

grep -Fq 'SUPPORT_STATUS="legacy-only"' "${LEGACY}"
grep -Fq 'SCRIPT_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh"' "${LEGACY}"
grep -Fq 'exec bash "${local_launcher}"' "${LEGACY}"
grep -Fq 'exec bash "${temp_file}"' "${LEGACY}"
grep -Fq 'if ! read -r -p "请选择 [0-3]: " choice; then' "${LEGACY}"
grep -Fq '"legacy_support_status": "legacy-only"' "${REPO_ROOT}/version.json"

if grep -Fq 'run_repo_script ' "${LEGACY}"; then
    echo "Legacy launcher should not own modular menu actions." >&2
    exit 1
fi

version_output=$(bash "${LEGACY}" --version)
grep -Fq "legacy-only" <<< "${version_output}"

echo "Legacy launcher policy is valid."
