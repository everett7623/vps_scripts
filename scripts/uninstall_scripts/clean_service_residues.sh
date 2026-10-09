#!/bin/bash
# ==============================================================================
# Script: scripts/uninstall_scripts/clean_service_residues.sh
# Purpose: Back up and remove services installed through VPS Scripts.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"
BACKUP_DIR="${BACKUP_ROOT}/service_clean_$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
AUTO_YES=false
PURGE_DATA=false
TARGET=""
WP_DIR=""

TARGET_IDS=(bt 1panel wordpress docker nginx apache mysql php all)
TARGET_LABELS=("宝塔面板" "1Panel面板" "WordPress" "Docker" "Nginx" "Apache" "MySQL/MariaDB" "PHP-FPM" "全部服务（不含 WordPress）")

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
用法：bash clean_service_residues.sh [选项]

选项：
  --list               列出可清理的服务
  --target <ID|编号>   直接选择服务（bt|1panel|wordpress|docker|nginx|apache|mysql|php|all 或 1-9）
  --wp-dir <路径>      WordPress 目录（需包含 wp-config.php）
  --purge-data         同时删除 /var/lib/docker、/var/lib/mysql 等数据目录（默认保留）
  --dry-run            仅预览将执行的操作，不修改系统
  --yes                跳过确认提示
  --help               显示帮助

备份目录默认位于 /var/backups/vps_scripts，可用 VPS_BACKUP_ROOT 覆盖。
EOF
}

show_list() {
    local i
    print_info "可清理的服务列表:"
    for i in "${!TARGET_IDS[@]}"; do
        printf '%d. %-10s %s\n' "$((i + 1))" "${TARGET_IDS[$i]}" "${TARGET_LABELS[$i]}"
    done
}

resolve_target() {
    local value="$1"
    if [[ ${value} =~ ^[1-9]$ ]]; then
        printf '%s\n' "${TARGET_IDS[$((value - 1))]}"
        return 0
    fi
    local id
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
        run_optional systemctl disable "${svc}"
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

is_protected_path() {
    case "${1%/}" in
        ""|/|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|/var/lib|/var/log|/var/www|/www|/www/server)
            return 0
            ;;
    esac
    return 1
}

remove_path() {
    local target="$1"
    [[ ${target} == /* ]] || error_exit "拒绝删除相对路径: ${target}"
    is_protected_path "${target}" && error_exit "拒绝删除受保护路径: ${target}"
    [ -e "${target}" ] || [ -L "${target}" ] || return 0
    run rm -rf -- "${target}"
}

remove_packages() {
    local -a installed=()
    local pkg
    if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        for pkg in "$@"; do
            if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q 'install ok installed'; then
                installed+=("${pkg}")
            fi
        done
        [ "${#installed[@]}" -gt 0 ] || return 0
        run_optional apt-get purge -y "${installed[@]}"
    elif command -v rpm >/dev/null 2>&1; then
        for pkg in "$@"; do
            rpm -q "${pkg}" >/dev/null 2>&1 && installed+=("${pkg}")
        done
        [ "${#installed[@]}" -gt 0 ] || return 0
        if command -v dnf >/dev/null 2>&1; then
            run_optional dnf remove -y "${installed[@]}"
        else
            run_optional yum remove -y "${installed[@]}"
        fi
    fi
}

purge_data_dir() {
    local dir="$1"
    local name="$2"
    [ -e "${dir}" ] || return 0
    if [ "${PURGE_DATA}" != true ]; then
        print_warn "[保留] 数据目录 ${dir}（如需删除请加 --purge-data）"
        return 0
    fi
    backup_path "${dir}" "${name}"
    remove_path "${dir}"
}

clean_bt() {
    print_info "清理宝塔面板..."
    stop_services bt
    backup_path /www/server/panel bt_panel
    if [ -f /www/server/panel/install.sh ]; then
        run_optional bash /www/server/panel/install.sh uninstall
    fi
    remove_path /www/server/panel
    remove_path /www/wwwroot/default
    remove_path /www/server/nginx
    remove_path /www/server/mysql
    remove_path /www/server/php
    remove_path /www/server/apache
    print_ok "宝塔面板清理完成"
}

clean_1panel() {
    print_info "清理1Panel面板..."
    stop_services 1panel
    backup_path /opt/1panel 1panel
    remove_path /etc/systemd/system/1panel.service
    command -v systemctl >/dev/null 2>&1 && run_optional systemctl daemon-reload
    remove_path /opt/1panel
    print_ok "1Panel面板清理完成"
}

clean_wordpress() {
    local wp_dir="${WP_DIR}"
    print_info "清理WordPress..."
    if [ -z "${wp_dir}" ]; then
        if [ "${AUTO_YES}" = true ] || [ ! -t 0 ]; then
            error_exit "非交互模式下请使用 --wp-dir 指定 WordPress 目录"
        fi
        read -r -p "请输入WordPress安装目录 [/var/www/html/wordpress]: " wp_dir || wp_dir=""
        wp_dir=${wp_dir:-/var/www/html/wordpress}
    fi
    if [[ "${wp_dir}" != /* || "${wp_dir}" == "/" || ! -d "${wp_dir}" || ! -f "${wp_dir}/wp-config.php" ]]; then
        error_exit "WordPress目录必须是包含 wp-config.php 的绝对路径"
    fi
    backup_path "${wp_dir}" wordpress
    remove_path "${wp_dir}"
    print_ok "WordPress清理完成"
    print_warn "注意: 数据库未删除，请手动清理"
}

clean_docker() {
    print_info "清理Docker..."
    stop_services docker containerd
    backup_path /etc/docker docker_config
    remove_packages docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin \
        docker docker-client docker-common docker-engine
    remove_path /etc/docker
    purge_data_dir /var/lib/docker docker_data
    print_ok "Docker清理完成"
}

clean_nginx() {
    print_info "清理Nginx..."
    stop_services nginx
    backup_path /etc/nginx nginx
    remove_packages nginx nginx-common nginx-core
    remove_path /etc/nginx
    remove_path /usr/share/nginx
    print_warn "[保留] 站点目录 /var/www（请手动确认后删除）"
    print_ok "Nginx清理完成"
}

clean_apache() {
    print_info "清理Apache..."
    stop_services httpd apache2
    backup_path /etc/httpd apache
    backup_path /etc/apache2 apache2
    remove_packages httpd apache2
    remove_path /etc/httpd
    remove_path /etc/apache2
    print_warn "[保留] 站点目录 /var/www（请手动确认后删除）"
    print_ok "Apache清理完成"
}

clean_mysql() {
    print_info "清理MySQL/MariaDB..."
    stop_services mysql mysqld mariadb
    backup_path /etc/mysql mysql_config
    backup_path /etc/my.cnf my.cnf
    remove_packages mysql-server mysql-client mysql-common mysql mysql-devel \
        mariadb-server mariadb-client mariadb
    remove_path /etc/mysql
    purge_data_dir /var/lib/mysql mysql_data
    remove_path /var/log/mysql
    print_ok "MySQL/MariaDB清理完成"
}

clean_php() {
    local -a php_services=(php-fpm)
    local unit
    print_info "清理PHP-FPM..."
    if command -v systemctl >/dev/null 2>&1; then
        while IFS= read -r unit; do
            [ -n "${unit}" ] && php_services+=("${unit%.service}")
        done < <(systemctl list-unit-files 'php*-fpm.service' --no-legend 2>/dev/null | awk '{print $1}')
    fi
    stop_services "${php_services[@]}"
    backup_path /etc/php php_config
    remove_packages php php-fpm php-mysql php-mysqlnd php-gd php-mbstring php-xml
    remove_path /etc/php
    remove_path /var/lib/php
    print_ok "PHP-FPM清理完成"
}

run_target() {
    case "$1" in
        bt) clean_bt ;;
        1panel) clean_1panel ;;
        wordpress) clean_wordpress ;;
        docker) clean_docker ;;
        nginx) clean_nginx ;;
        apache) clean_apache ;;
        mysql) clean_mysql ;;
        php) clean_php ;;
        all)
            local item
            for item in bt 1panel docker nginx apache mysql php; do
                run_target "${item}"
            done
            print_warn "WordPress需要指定目录，未包含在批量清理中"
            ;;
        *) error_exit "未知目标: $1" ;;
    esac
}

confirm_or_exit() {
    local confirm=""
    [ "${AUTO_YES}" = true ] && return 0
    [ "${DRY_RUN}" = true ] && return 0
    print_warn "警告: 此操作将卸载通过VPS Scripts安装的服务并清理相关残留文件和配置"
    echo -e "${RED}配置会先备份到 ${BACKUP_DIR}，但卸载本身不可逆${NC}"
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
            --purge-data) PURGE_DATA=true ;;
            --target)
                [ $# -ge 2 ] || error_exit "--target 需要参数"
                TARGET="$2"
                shift
                ;;
            --wp-dir)
                [ $# -ge 2 ] || error_exit "--wp-dir 需要参数"
                WP_DIR="$2"
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

    print_info "VPS Scripts 服务残留清理工具"
    echo "------------------------"

    if [ -n "${TARGET}" ]; then
        target=$(resolve_target "${TARGET}") || error_exit "未知目标: ${TARGET}（使用 --list 查看）"
    else
        show_list
        echo ""
        read -r -p "请选择要清理的服务编号 (1-9): " choice || choice=""
        target=$(resolve_target "${choice}") || error_exit "无效的选择"
    fi

    confirm_or_exit
    [ "${DRY_RUN}" = true ] && print_warn "DRY-RUN: 以下操作仅预览，不会修改系统"
    run_target "${target}"

    echo ""
    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN 完成，未实际修改系统。"
    else
        print_ok "服务残留清理完成"
        [ -d "${BACKUP_DIR}" ] && echo -e "${WHITE}备份目录: ${YELLOW}${BACKUP_DIR}${NC}"
    fi
    return 0
}

main "$@"
