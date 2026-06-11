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
    local launcher_version=""
    local json_style_version=""
    local conf_style_version=""
    local launcher_style_version=""
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
    require_file "tests/validate_java_installer_safety.sh"
    require_file "tests/validate_common_helpers.sh"
    require_file "tests/validate_docker_installer_safety.sh"
    require_file "tests/validate_legacy_launcher_policy.sh"
    require_file "tests/validate_kubernetes_installer_safety.sh"
    require_file "tests/validate_line_endings_policy.sh"
    require_file "tests/validate_python_installer_safety.sh"
    require_file "tests/validate_script_headers.sh"
    require_file "tests/validate_system_tools_launcher.sh"
    require_file "tests/validate_update_log_handoff.sh"
    require_file "tests/validate_update_scripts_legacy.sh"
    require_file "tests/validate_execution_safety.sh"
    require_file "tests/validate_go_installer_safety.sh"
    require_file "tests/validate_ui_framework.sh"
    require_file "tests/validate_ui_layout.sh"
    require_file "tests/validate_loader_performance.sh"
    require_file "tests/validate_active_category_coverage.sh"
    require_file "tests/validate_menu_eof.sh"
    require_file "tests/validate_nginx_installer_safety.sh"

    for doc in "${required_docs[@]}"; do
        require_file "${doc}"
    done

    json_version=$(extract_json_value "${REPO_ROOT}/version.json" "version" || true)
    conf_version=$(extract_shell_value "${REPO_ROOT}/config/vps_scripts.conf" "SCRIPT_VERSION" || true)
    launcher_version=$(extract_shell_value "${REPO_ROOT}/vps.sh" "PROJECT_VERSION" || true)
    json_style_version=$(extract_json_value "${REPO_ROOT}/version.json" "style_version" || true)
    conf_style_version=$(extract_shell_value "${REPO_ROOT}/config/vps_scripts.conf" "LAUNCHER_STYLE_VERSION" || true)
    launcher_style_version=$(extract_shell_value "${REPO_ROOT}/vps.sh" "LAUNCHER_STYLE_VERSION" || true)

    if [ -z "${json_version}" ] || [ -z "${conf_version}" ] || [ -z "${launcher_version}" ]; then
        echo "Failed to extract project version metadata." >&2
        exit 1
    fi

    if [ "${json_version}" != "${conf_version}" ] || [ "${json_version}" != "${launcher_version}" ]; then
        echo "Version mismatch: version.json=${json_version}, config=${conf_version}, launcher=${launcher_version}" >&2
        exit 1
    fi

    if [ -z "${json_style_version}" ] || [ -z "${conf_style_version}" ] || [ -z "${launcher_style_version}" ]; then
        echo "Failed to extract launcher style version metadata." >&2
        exit 1
    fi

    if [ "${json_style_version}" != "${conf_style_version}" ] || [ "${json_style_version}" != "${launcher_style_version}" ]; then
        echo "Launcher style version mismatch: version.json=${json_style_version}, config=${conf_style_version}, launcher=${launcher_style_version}" >&2
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
