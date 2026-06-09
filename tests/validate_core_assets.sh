#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

if [ ! -d "${REPO_ROOT}" ]; then
    echo "Repository root not found: ${REPO_ROOT}" >&2
    exit 1
fi

require_file() {
    local path="$1"
    if [ ! -f "${REPO_ROOT}/${path}" ]; then
        echo "Missing required file: ${path}" >&2
        return 1
    fi
}

extract_json_value() {
    local file="$1"
    local key="$2"
    local line=""

    while IFS= read -r line; do
        case "${line}" in
            *"\"${key}\""*":"*)
                line="${line#*:}"
                line="${line# }"
                line="${line#\"}"
                line="${line%%\"*}"
                printf '%s\n' "${line}"
                return 0
                ;;
        esac
    done < "${file}"

    return 1
}

extract_shell_value() {
    local file="$1"
    local key="$2"
    local line=""

    while IFS= read -r line; do
        case "${line}" in
            "${key}="*)
                line="${line#*=}"
                line="${line#\"}"
                line="${line%\"}"
                printf '%s\n' "${line}"
                return 0
                ;;
        esac
    done < "${file}"

    return 1
}

main() {
    local json_version=""
    local conf_version=""
    local line=""
    local required_docs=(
        "README.md"
        "AGENTS.md"
        "CHANGELOG.md"
        "DEVELOPMENT_GUIDE.md"
        "PROGRESS.md"
        "RELEASE_CHECKLIST.md"
        "TASKS.md"
        "VERSIONING.md"
    )
    local doc=""

    require_file "version.json"
    require_file "update_log.sh"
    require_file "config/vps_scripts.conf"
    require_file "vps.sh"
    require_file "vps_scripts.sh"
    require_file "tests/validate_launcher_paths.sh"
    require_file "tests/validate_command_install.sh"
    require_file "tests/validate_remote_module_runtime.sh"
    require_file "tests/validate_input_contract.sh"
    require_file "tests/validate_system_tools_launcher.sh"
    require_file "tests/validate_execution_safety.sh"
    require_file "tests/validate_ui_framework.sh"
    require_file "tests/validate_loader_performance.sh"
    require_file "tests/validate_active_category_coverage.sh"
    require_file "tests/validate_menu_eof.sh"

    for doc in "${required_docs[@]}"; do
        require_file "${doc}"
    done

    json_version=$(extract_json_value "${REPO_ROOT}/version.json" "version" || true)
    conf_version=$(extract_shell_value "${REPO_ROOT}/config/vps_scripts.conf" "SCRIPT_VERSION" || true)

    if [ -z "${json_version}" ] || [ -z "${conf_version}" ]; then
        echo "Failed to extract version from version.json or vps_scripts.conf." >&2
        exit 1
    fi

    if [ "${json_version}" != "${conf_version}" ]; then
        echo "Version mismatch: version.json=${json_version}, config=${conf_version}" >&2
        exit 1
    fi

    while IFS= read -r line; do
        case "${line}" in
            SCRIPT_URL=*vps.sh*)
                echo "Core assets are valid."
                return 0
                ;;
        esac
    done < "${REPO_ROOT}/vps_scripts.sh"

    echo "Legacy compatibility launcher does not point to vps.sh." >&2
    exit 1
}

main "$@"
