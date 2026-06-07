#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT_DEFAULT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT="${REPO_ROOT_OVERRIDE:-${REPO_ROOT_DEFAULT}}"

require_text() {
    local file="$1"
    local text="$2"

    if ! grep -Fq "${text}" "${REPO_ROOT}/${file}"; then
        echo "Missing Chinese UI text in ${file}: ${text}" >&2
        exit 1
    fi
}

require_text "vps.sh" "VPS 综合管理脚本"
require_text "vps.sh" "主菜单"
require_text "vps.sh" "系统工具"
require_text "vps.sh" "快捷命令管理"
require_text "vps.sh" "清理与卸载"
require_text "vps_scripts.sh" "VPS 综合管理脚本兼容入口"
require_text "vps_scripts.sh" "请选择启动方式"

echo "Chinese launcher UI is valid."
