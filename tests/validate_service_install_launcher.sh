#!/bin/bash
# ==============================================================================
# Script: tests/validate_service_install_launcher.sh
# Purpose: Validate service-install launcher coverage.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"
SERVICE_DIR="${REPO_ROOT}/scripts/service_install"

if [ ! -f "${LAUNCHER}" ]; then
    echo "Launcher not found: ${LAUNCHER}" >&2
    exit 1
fi

if [ ! -d "${SERVICE_DIR}" ]; then
    echo "Service install directory not found: ${SERVICE_DIR}" >&2
    exit 1
fi

declare -A referenced=()
declare -A found=()
missing_target=0
unreferenced_script=0

while IFS= read -r line; do
    if [[ "${line}" =~ run_repo_script\ \"(scripts/service_install/[^\"]+\.sh)\" ]]; then
        path="${BASH_REMATCH[1]}"
        referenced["${path}"]=1
        if [ ! -f "${REPO_ROOT}/${path}" ]; then
            echo "Missing service-install launcher target: ${path}" >&2
            missing_target=1
        fi
    fi
done < "${LAUNCHER}"

while IFS= read -r script; do
    relative_path="scripts/service_install/$(basename "${script}")"
    found["${relative_path}"]=1
    if [[ -z "${referenced[${relative_path}]:-}" ]]; then
        echo "Unreferenced service-install script: ${relative_path}" >&2
        unreferenced_script=1
    fi
done < <(find "${SERVICE_DIR}" -maxdepth 1 -type f -name '*.sh' | sort)

if [ "${#referenced[@]}" -eq 0 ]; then
    echo "No service-install launcher references found." >&2
    exit 1
fi

for path in "${!referenced[@]}"; do
    if [[ -z "${found[${path}]:-}" ]]; then
        echo "Service-install reference is outside script inventory: ${path}" >&2
        missing_target=1
    fi
done

if [ "${missing_target}" -ne 0 ] || [ "${unreferenced_script}" -ne 0 ]; then
    exit 1
fi

echo "Service-install launcher coverage is valid."
