#!/bin/bash
# ==============================================================================
# Script: tests/validate_update_log_handoff.sh
# Purpose: Ensure update_log.sh remains a compatibility viewer for CHANGELOG.md.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
SCRIPT="${REPO_ROOT}/update_log.sh"

bash -n "${SCRIPT}"
grep -Fq 'CHANGELOG_FILE="${SCRIPT_DIR}/CHANGELOG.md"' "${SCRIPT}"
grep -Fq 'VERSION_FILE="${SCRIPT_DIR}/version.json"' "${SCRIPT}"
grep -Fq 'print_changelog_excerpt' "${SCRIPT}"

output=$(bash "${SCRIPT}" --plain --lines 8)
grep -Fq 'VPS Scripts update log' <<< "${output}"
grep -Fq '## Unreleased' <<< "${output}"

echo "Update log handoff is valid."
