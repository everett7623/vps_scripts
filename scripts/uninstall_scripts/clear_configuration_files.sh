#!/bin/bash
# ==============================================================================
# Script: scripts/uninstall_scripts/clear_configuration_files.sh
# Purpose: Back up and reset configuration generated through VPS Scripts.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"
BACKUP_DIR="${BACKUP_ROOT}/config_clean_$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
AUTO_YES=false
TARGET=""

TARGET_IDS=(nginx apache mysql php docker network security all)
TARGET_LABELS=("Nginx配置" "Apache配置" "MySQL/MariaDB配置" "PHP配置" "Docker配置" "系统网络配置" "系统安全配置" "全部配置")

print_info() { echo -e "${WHITE}$*${NC}"; }
print_ok() {
    if [ "${DRY_RUN}" = true ]; then
        echo -e "${GREEN}[预览] $*${NC}"
    else
        echo -e "${GREEN}$*${NC}"
    fi
}
print_warn() { echo -e "${YELLOW}$*${NC}"; }
error_exit() {
    echo -e "${RED}[错误] $*${NC}" >&2
    exit 1
}

show_help() {
    cat <<'EOF'
用法：bash clear_configuration_files.sh [选项]

选项：
  --list               列出可清理的配置
  --target <ID|编号>   直接选择配置（nginx|apache|mysql|php|docker|network|security|all 或 1-8）
  --dry-run            仅预览将执行的操作，不修改系统
  --yes                跳过确认提示
  --help               显示帮助

备份目录默认位于 /var/backups/vps_scripts，可用 VPS_BACKUP_ROOT 覆盖。
EOF
}

show_list() {
    local i
    print_info "可清理的配置文件:"
    for i in "${!TARGET_IDS[@]}"; do
        printf '%d. %-9s %s\n' "$((i + 1))" "${TARGET_IDS[$i]}" "${TARGET_LABELS[$i]}"
    done
}

resolve_target() {
    local value="$1"
    local id
    if [[ ${value} =~ ^[1-8]$ ]]; then
        printf '%s\n' "${TARGET_IDS[$((value - 1))]}"
        return 0
    fi
    for id in "${TARGET_IDS[@]}"; do
        if [ "${id}" = "${value}" ]; then
            printf '%s\n' "${id}"
            return 0
        fi
    done
    return 1
}

run() {
    if [ "${DRY_RUN}" = true ]; then
        printf '[DRY-RUN] %s\n' "$*"
        return 0
    fi
    "$@"
}

run_optional() {
    if [ "${DRY_RUN}" = true ]; then
        printf '[DRY-RUN] %s\n' "$*"
        return 0
    fi
    "$@" >/dev/null 2>&1 || print_warn "[跳过] $*"
    return 0
}

stop_services() {
    local svc
    command -v systemctl >/dev/null 2>&1 || return 0
    for svc in "$@"; do
        run_optional systemctl stop "${svc}"
    done
}

backup_path() {
    local src="$1"
    local name="$2"
    [ -e "${src}" ] || return 0
    if [ "${DRY_RUN}" = true ]; then
        printf '[DRY-RUN] 备份 %s -> %s/%s\n' "${src}" "${BACKUP_DIR}" "${name}"
        return 0
    fi
    mkdir -p -- "${BACKUP_DIR}"
    cp -a -- "${src}" "${BACKUP_DIR}/${name}" || print_warn "[警告] 备份失败: ${src}"
}

restore_from_bak() {
    local bak="$1"
    local dest="$2"
    [ -f "${bak}" ] || return 0
    run cp -- "${bak}" "${dest}"
}

clear_directory_contents() {
    local target_dir="$1"

    [ -d "${target_dir}" ] || return 0
    case "${target_dir%/}" in
        /etc/*/*) ;;
        *) error_exit "拒绝清空非预期目录: ${target_dir}" ;;
    esac
    if [ "${DRY_RUN}" = true ]; then
        printf '[DRY-RUN] 清空目录内容 %s\n' "${target_dir}"
        return 0
    fi
    find "${target_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

clear_nginx() {
    print_info "清理Nginx配置..."
    stop_services nginx
    backup_path /etc/nginx nginx
    clear_directory_contents /etc/nginx/conf.d
    clear_directory_contents /etc/nginx/sites-available
    clear_directory_contents /etc/nginx/sites-enabled
    restore_from_bak /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
    print_ok "Nginx配置清理完成"
}

clear_apache() {
    print_info "清理Apache配置..."
    stop_services httpd apache2
    backup_path /etc/httpd apache
    backup_path /etc/apache2 apache2
    clear_directory_contents /etc/httpd/conf.d
    clear_directory_contents /etc/apache2/sites-available
    clear_directory_contents /etc/apache2/sites-enabled
    restore_from_bak /etc/httpd/conf/httpd.conf.bak /etc/httpd/conf/httpd.conf
    print_ok "Apache配置清理完成"
}

clear_mysql() {
    print_info "清理MySQL/MariaDB配置..."
    stop_services mysql mysqld mariadb
    backup_path /etc/mysql mysql
    backup_path /etc/my.cnf.d my.cnf.d
    backup_path /etc/my.cnf my.cnf
    clear_directory_contents /etc/mysql/conf.d
    clear_directory_contents /etc/mysql/mariadb.conf.d
    clear_directory_contents /etc/my.cnf.d
    restore_from_bak /etc/mysql/my.cnf.bak /etc/mysql/my.cnf
    restore_from_bak /etc/my.cnf.bak /etc/my.cnf
    print_ok "MySQL/MariaDB配置清理完成"
}

clear_php() {
    local php_config_dir
    print_info "清理PHP配置..."
    stop_services php-fpm
    backup_path /etc/php php
    for php_config_dir in /etc/php/*/fpm/pool.d /etc/php/*/conf.d; do
        [ -d "${php_config_dir}" ] || continue
        clear_directory_contents "${php_config_dir}"
    done
    restore_from_bak /etc/php.ini.bak /etc/php.ini
    print_ok "PHP配置清理完成"
}

clear_docker() {
    print_info "清理Docker配置..."
    stop_services docker
    backup_path /etc/docker docker
    if [ -f /etc/docker/daemon.json.bak ]; then
        restore_from_bak /etc/docker/daemon.json.bak /etc/docker/daemon.json
    elif [ -f /etc/docker/daemon.json ]; then
        run rm -f -- /etc/docker/daemon.json
    fi
    print_ok "Docker配置清理完成"
}

clear_network() {
    local netplan_file
    print_info "清理系统网络配置..."
    backup_path /etc/network/interfaces interfaces.bak
    for netplan_file in /etc/netplan/*.yaml; do
        [ -f "${netplan_file}" ] || continue
        backup_path "${netplan_file}" "$(basename "${netplan_file}")"
    done
    backup_path /etc/sysctl.conf sysctl.conf.bak
    restore_from_bak /etc/network/interfaces.bak /etc/network/interfaces
    restore_from_bak /etc/sysctl.conf.bak /etc/sysctl.conf
    command -v sysctl >/dev/null 2>&1 && run_optional sysctl -p
    print_ok "系统网络配置清理完成"
}

restart_ssh_service() {
    command -v systemctl >/dev/null 2>&1 || return 0
    if systemctl list-unit-files ssh.service >/dev/null 2>&1 && systemctl cat ssh.service >/dev/null 2>&1; then
        run_optional systemctl restart ssh
    else
        run_optional systemctl restart sshd
    fi
}

clear_security() {
    local current_copy=""
    print_info "清理系统安全配置..."
    backup_path /etc/ssh/sshd_config sshd_config.bak
    backup_path /etc/fail2ban/jail.local jail.local.bak
    backup_path /etc/firewalld/zones/public.xml public.xml.bak
    backup_path /etc/ufw/applications.d ufw_applications.d

    if [ -f /etc/ssh/sshd_config.bak ]; then
        if [ "${DRY_RUN}" = true ]; then
            printf '[DRY-RUN] 恢复 /etc/ssh/sshd_config.bak 并以 sshd -t 校验\n'
        else
            current_copy=$(mktemp "/tmp/sshd_config.XXXXXX")
            cp -a -- /etc/ssh/sshd_config "${current_copy}"
            cp -- /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
            if command -v sshd >/dev/null 2>&1 && ! sshd -t >/dev/null 2>&1; then
                cp -a -- "${current_copy}" /etc/ssh/sshd_config
                rm -f -- "${current_copy}"
                error_exit "恢复后的 sshd_config 校验失败，已还原当前配置"
            fi
            rm -f -- "${current_copy}"
            restart_ssh_service
        fi
    else
        print_warn "[跳过] 未找到 /etc/ssh/sshd_config.bak"
    fi
    print_ok "系统安全配置清理完成"
}

run_target() {
    case "$1" in
        nginx) clear_nginx ;;
        apache) clear_apache ;;
        mysql) clear_mysql ;;
        php) clear_php ;;
        docker) clear_docker ;;
        network) clear_network ;;
        security) clear_security ;;
        all)
            local item
            for item in nginx apache mysql php docker network security; do
                run_target "${item}"
            done
            ;;
        *) error_exit "未知目标: $1" ;;
    esac
}

confirm_or_exit() {
    local confirm=""
    [ "${AUTO_YES}" = true ] && return 0
    [ "${DRY_RUN}" = true ] && return 0
    print_warn "警告: 此操作将删除VPS Scripts生成的配置文件"
    echo -e "${RED}配置会先备份到 ${BACKUP_DIR}，相关服务可能需要重新配置${NC}"
    read -r -p "确定要继续吗? (y/n): " confirm || confirm="n"
    case "${confirm}" in
        y|Y) ;;
        *) print_warn "已取消操作"; exit 0 ;;
    esac
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h) show_help; exit 0 ;;
            --list) show_list; exit 0 ;;
            --dry-run) DRY_RUN=true ;;
            --yes|-y) AUTO_YES=true ;;
            --target)
                [ $# -ge 2 ] || error_exit "--target 需要参数"
                TARGET="$2"
                shift
                ;;
            *) error_exit "未知参数: $1（使用 --help 查看用法）" ;;
        esac
        shift
    done
}

main() {
    local choice="" target=""
    parse_args "$@"

    [[ ${BACKUP_ROOT} == /* ]] || error_exit "备份根目录必须是绝对路径: ${BACKUP_ROOT}"
    if [ "${DRY_RUN}" != true ] && [ "$(id -u)" != "0" ]; then
        error_exit "此脚本需要root权限运行（预览可使用 --dry-run）"
    fi

    print_info "VPS Scripts 配置文件清理工具"
    echo "------------------------"

    if [ -n "${TARGET}" ]; then
        target=$(resolve_target "${TARGET}") || error_exit "未知目标: ${TARGET}（使用 --list 查看）"
    else
        show_list
        echo ""
        read -r -p "请选择要清理的配置文件编号 (1-8): " choice || choice=""
        target=$(resolve_target "${choice}") || error_exit "无效的选择"
    fi

    confirm_or_exit
    [ "${DRY_RUN}" = true ] && print_warn "DRY-RUN: 以下操作仅预览，不会修改系统"
    run_target "${target}"

    echo ""
    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN 完成，未实际修改系统。"
    else
        print_ok "配置文件清理完成"
        [ -d "${BACKUP_DIR}" ] && echo -e "${WHITE}备份目录: ${YELLOW}${BACKUP_DIR}${NC}"
    fi
    return 0
}

main "$@"
