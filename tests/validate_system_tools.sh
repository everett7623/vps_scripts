#!/bin/bash
# ==============================================================================
# Script: tests/validate_system_tools.sh
# Purpose: Validate syntax for the modernized core system tools.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

FILES=(
    "scripts/system_tools/system_info.sh"
    "scripts/system_tools/change_hostname.sh"
    "scripts/system_tools/clean_system.sh"
    "scripts/system_tools/optimize_system.sh"
    "scripts/system_tools/set_timezone.sh"
    "scripts/system_tools/install_deps.sh"
    "scripts/system_tools/update_system.sh"
)

for relative_path in "${FILES[@]}"; do
    target="${REPO_ROOT}/${relative_path}"
    if [ ! -f "${target}" ]; then
        echo "Missing file: ${relative_path}" >&2
        exit 1
    fi
    bash -n "${target}"
done

echo "System tools syntax is valid."
