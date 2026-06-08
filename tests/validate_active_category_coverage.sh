#!/bin/bash
# ==============================================================================
# Script: tests/validate_active_category_coverage.sh
# Purpose: Validate launcher coverage for active non-system categories.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"

ACTIVE_CATEGORIES=(
    "scripts/network_test"
    "scripts/performance_test"
    "scripts/other_tools"
    "scripts/uninstall_scripts"
)

if [ ! -f "${LAUNCHER}" ]; then
    echo "Launcher not found: ${LAUNCHER}" >&2
    exit 1
fi

validate_category() {
    local category="$1"
    local category_dir="${REPO_ROOT}/${category}"
    local script=""
    local relative_path=""
    local found_count=0
    local missing=0

    if [ ! -d "${category_dir}" ]; then
        echo "Active category directory not found: ${category}" >&2
        return 1
    fi

    while IFS= read -r script; do
        relative_path="${category}/$(basename "${script}")"
        found_count=$((found_count + 1))
        if ! grep -Fq "run_repo_script \"${relative_path}\"" "${LAUNCHER}"; then
            echo "Unreferenced active script: ${relative_path}" >&2
            missing=1
        fi
    done < <(find "${category_dir}" -maxdepth 1 -type f -name '*.sh' | sort)

    if [ "${found_count}" -eq 0 ]; then
        echo "Active category contains no scripts: ${category}" >&2
        missing=1
    fi

    return "${missing}"
}

overall_missing=0
for category in "${ACTIVE_CATEGORIES[@]}"; do
    validate_category "${category}" || overall_missing=1
done

if [ "${overall_missing}" -ne 0 ]; then
    exit 1
fi

echo "Active category launcher coverage is valid."
