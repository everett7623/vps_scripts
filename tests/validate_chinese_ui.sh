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
require_text "scripts/system_tools/system_info.sh" "VPS 系统信息"
require_text "scripts/system_tools/install_deps.sh" "常用依赖安装向导"
require_text "scripts/system_tools/update_system.sh" "系统更新工具"
require_text "scripts/system_tools/clean_system.sh" "系统清理工具"
require_text "scripts/system_tools/optimize_system.sh" "VPS 安全优化"
require_text "scripts/system_tools/change_hostname.sh" "VPS 主机名管理"
require_text "scripts/system_tools/set_timezone.sh" "从常用时区中选择"
require_text "scripts/system_tools/system_info.sh" "系统概览"
require_text "scripts/system_tools/install_deps.sh" "正在刷新软件包元数据"
require_text "scripts/system_tools/update_system.sh" "正在备份关键配置文件"
require_text "scripts/system_tools/clean_system.sh" "软件包缓存"
require_text "scripts/system_tools/optimize_system.sh" "内核参数优化"
require_text "scripts/system_tools/change_hostname.sh" "验证结果"
require_text "scripts/system_tools/set_timezone.sh" "时区与时间信息"

echo "Chinese launcher and system tools UI are valid."
