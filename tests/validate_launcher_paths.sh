#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"
LAUNCHER="${LAUNCHER_OVERRIDE:-${REPO_ROOT}/vps.sh}"

if [ ! -f "${LAUNCHER}" ]; then
    echo "Launcher not found: ${LAUNCHER}" >&2
    exit 1
fi

if [ ! -d "${REPO_ROOT}" ]; then
    echo "Repository root not found: ${REPO_ROOT}" >&2
    exit 1
fi

declare -A seen=()
found_any=0
missing=0

while IFS= read -r line; do
    if [[ "${line}" =~ run_repo_script\ \"([^\"]+)\" ]]; then
        found_any=1
        path="${BASH_REMATCH[1]}"
        if [[ -n "${seen[$path]:-}" ]]; then
            continue
        fi
        seen["$path"]=1
        if [ ! -f "${REPO_ROOT}/${path}" ]; then
            echo "Missing launcher target: ${path}" >&2
            missing=1
        fi
    fi
done < "${LAUNCHER}"

if [ "${found_any}" -eq 0 ]; then
    echo "No run_repo_script references found." >&2
    exit 1
fi

if [ "${missing}" -ne 0 ]; then
    exit 1
fi

grep -Fq "raw.githubusercontent.com/everett7623/vps_scripts/main" "${LAUNCHER}"
grep -Fq "github.com/everett7623/vps_scripts/raw/refs/heads/main" "${LAUNCHER}"
grep -Fq "cdn.jsdelivr.net/gh/everett7623/vps_scripts@main" "${LAUNCHER}"

echo "Launcher references are valid."
