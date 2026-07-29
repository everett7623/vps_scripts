#!/bin/bash
# ==============================================================================
# Script: scripts/uninstall_scripts/full_uninstall.sh
# Purpose: Back up and remove first-party VPS Scripts artifacts.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

INSTALL_PREFIX="${VPS_INSTALL_PREFIX:-/usr/local}"
INSTALL_COMMAND="${INSTALL_PREFIX}/bin/vps"
INSTALL_LIB_DIR="${INSTALL_PREFIX}/lib/vps-scripts"
LOG_DIR="${VPS_LOG_DIR:-/var/log/vps_scripts}"
BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"
BACKUP_DIR="${BACKUP_ROOT}/full_uninstall_$(date +%Y%m%d_%H%M%S)"

error_exit() {
    echo -e "${RED}[错误] $1${NC}" >&2
    exit 1
}

is_managed_command() {
    [[ -f $INSTALL_COMMAND ]] &&
        grep -Fq "exec bash \"${INSTALL_LIB_DIR}/vps.sh\" \"\$@\"" "$INSTALL_COMMAND"
}

is_managed_install_dir() {
    [[ -f ${INSTALL_LIB_DIR}/vps.sh ]] &&
        grep -Fq "https://github.com/everett7623/vps_scripts" "${INSTALL_LIB_DIR}/vps.sh"
}

safe_remove_file() {
    local target="$1"

    case "$target" in
        "$INSTALL_COMMAND") rm -f -- "$target" ;;
        *) error_exit "拒绝删除非预期文件: $target" ;;
    esac
}

safe_remove_dir() {
    local target="$1"

    case "$target" in
        "$INSTALL_LIB_DIR"|"$LOG_DIR")
            [[ -d "$target" ]] && rm -rf -- "$target"
            ;;
        *)
            error_exit "拒绝删除非预期目录: $target"
            ;;
    esac
}

if [[ $(id -u) -ne 0 ]]; then
    error_exit "此脚本需要 root 权限运行"
fi

case "$BACKUP_ROOT" in
    /*) ;;
    *) error_exit "备份根目录必须是绝对路径: $BACKUP_ROOT" ;;
esac

case "${BACKUP_ROOT}/" in
    "${INSTALL_LIB_DIR}/"*|"${LOG_DIR}/"*)
        error_exit "备份目录不能位于待备份目录内部: $BACKUP_ROOT"
        ;;
esac

echo -e "${WHITE}VPS Scripts 完全卸载工具${NC}"
echo "------------------------"
echo -e "${YELLOW}将备份并删除以下第一方产物:${NC}"
echo "  $INSTALL_COMMAND"
echo "  $INSTALL_LIB_DIR"
echo "  $LOG_DIR"
echo
echo -e "${YELLOW}不会停止或卸载 Docker、Web 服务、数据库等业务服务。${NC}"

read -r -p "确定要继续吗? (y/n): " confirm || confirm="n"
case "$confirm" in
    y|Y) ;;
    n|N)
        echo -e "${YELLOW}已取消操作${NC}"
        exit 0
        ;;
    *)
        error_exit "无效选择，已取消操作"
        ;;
esac

mkdir -p "$BACKUP_DIR"
printf 'created_at=%s\ninstall_prefix=%s\nlog_dir=%s\n' \
    "$(date --iso-8601=seconds)" \
    "$INSTALL_PREFIX" \
    "$LOG_DIR" > "${BACKUP_DIR}/manifest.txt"

if is_managed_command; then
    cp -a "$INSTALL_COMMAND" "${BACKUP_DIR}/vps-command"
    safe_remove_file "$INSTALL_COMMAND"
elif [[ -e $INSTALL_COMMAND ]]; then
    echo -e "${YELLOW}[跳过] $INSTALL_COMMAND 不属于本项目。${NC}"
fi

if is_managed_install_dir; then
    cp -a "$INSTALL_LIB_DIR" "${BACKUP_DIR}/vps-scripts"
    safe_remove_dir "$INSTALL_LIB_DIR"
elif [[ -e $INSTALL_LIB_DIR ]]; then
    echo -e "${YELLOW}[跳过] $INSTALL_LIB_DIR 不属于本项目。${NC}"
fi

if [[ -d $LOG_DIR ]]; then
    cp -a "$LOG_DIR" "${BACKUP_DIR}/logs"
    safe_remove_dir "$LOG_DIR"
fi

echo
echo -e "${GREEN}VPS Scripts 第一方产物已卸载。${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
