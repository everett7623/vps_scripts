#!/bin/bash
# ==============================================================================
# Script: scripts/uninstall_scripts/rollback_system_environment.sh
# Purpose: Roll back system changes made by VPS Scripts tools.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

BACKUP_ROOT="${VPS_BACKUP_ROOT:-/var/backups/vps_scripts}"
BACKUP_DIR="${BACKUP_ROOT}/environment_rollback_$(date +%Y%m%d_%H%M%S)"
BBR_DROPIN="/etc/sysctl.d/99-vps-bbr.conf"
SWAP_FILE="/swapfile"
SWAPPINESS_DROPIN="/etc/sysctl.d/99-swappiness.conf"
DRY_RUN=false
AUTO_YES=false
TARGET=""
ORIGINAL_HOSTNAME=""

TARGET_IDS=(bbr fail2ban swap timezone hostname kernel all)
TARGET_LABELS=("BBR网络加速" "Fail2ban安全防护" "Swap空间（仅 /swapfile）" "系统时区（重置为 UTC）" "系统主机名" "系统内核（仅交互模式）" "全部环境（不含主机名和内核）")

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
用法：bash rollback_system_environment.sh [选项]

选项：
  --list                 列出可回滚的项目
  --target <ID|编号>     直接选择项目（bbr|fail2ban|swap|timezone|hostname|kernel|all 或 1-7）
  --hostname <名称>      回滚主机名时使用的原始主机名
  --dry-run              仅预览将执行的操作，不修改系统
  --yes                  跳过确认提示（内核回滚始终需要交互确认）
  --help                 显示帮助

备份目录默认位于 /var/backups/vps_scripts，可用 VPS_BACKUP_ROOT 覆盖。
EOF
}

show_list() {
    local i
    print_info "可回滚的环境项目:"
    for i in "${!TARGET_IDS[@]}"; do
        printf '%d. %-9s %s\n' "$((i + 1))" "${TARGET_IDS[$i]}" "${TARGET_LABELS[$i]}"
    done
}

resolve_target() {
    local value="$1"
    local id
    if [[ ${value} =~ ^[1-7]$ ]]; then
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

is_interactive() {
    [ -t 0 ] && [ "${AUTO_YES}" != true ]
}

reload_sysctl() {
    command -v sysctl >/dev/null 2>&1 || return 0
    run_optional sysctl --system
}

rollback_bbr() {
    print_info "回滚BBR网络加速..."
    backup_path /etc/sysctl.conf sysctl.conf.bak
    backup_path "${BBR_DROPIN}" "$(basename "${BBR_DROPIN}")"
    if [ -f "${BBR_DROPIN}" ]; then
        run rm -f -- "${BBR_DROPIN}"
    fi
    if [ -f /etc/sysctl.conf ] && grep -Eq '^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=' /etc/sysctl.conf; then
        run sed -i -E '/^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control)[[:space:]]*=/d' /etc/sysctl.conf
    fi
    reload_sysctl
    print_ok "BBR网络加速已回滚（重启后完全生效）"
}

rollback_fail2ban() {
    print_info "回滚Fail2ban安全防护..."
    backup_path /etc/fail2ban fail2ban
    if command -v systemctl >/dev/null 2>&1; then
        run_optional systemctl stop fail2ban
        run_optional systemctl disable fail2ban
    fi
    if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' fail2ban 2>/dev/null | grep -q 'install ok installed'; then
        run_optional apt-get purge -y fail2ban
    elif command -v rpm >/dev/null 2>&1 && rpm -q fail2ban >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
            run_optional dnf remove -y fail2ban
        else
            run_optional yum remove -y fail2ban
        fi
    fi
    if [ -d /etc/fail2ban ]; then
        run rm -rf -- /etc/fail2ban
    fi
    print_ok "Fail2ban安全防护已回滚"
}

rollback_swap() {
    print_info "回滚Swap空间（仅 ${SWAP_FILE}）..."
    backup_path /etc/fstab fstab.bak
    if [ -r /proc/swaps ] && awk 'NR > 1 {print $1}' /proc/swaps | grep -Fxq "${SWAP_FILE}"; then
        run swapoff -- "${SWAP_FILE}"
    fi
    if [ -f /etc/fstab ] && grep -Eq '^/swapfile[[:space:]]' /etc/fstab; then
        run sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab
    fi
    if [ -f "${SWAP_FILE}" ]; then
        run rm -f -- "${SWAP_FILE}"
    fi
    if [ -f "${SWAPPINESS_DROPIN}" ]; then
        backup_path "${SWAPPINESS_DROPIN}" "$(basename "${SWAPPINESS_DROPIN}")"
        run rm -f -- "${SWAPPINESS_DROPIN}"
        reload_sysctl
    fi
    print_ok "Swap空间已回滚（其他交换分区未改动）"
}

rollback_timezone() {
    print_info "回滚系统时区..."
    backup_path /etc/timezone timezone.bak
    backup_path /etc/localtime localtime.bak
    if [ "${DRY_RUN}" = true ]; then
        printf '[DRY-RUN] 设置时区为 UTC（timedatectl 或 /etc/localtime）\n'
    elif command -v timedatectl >/dev/null 2>&1; then
        run timedatectl set-timezone UTC
    elif [ -f /usr/share/zoneinfo/UTC ]; then
        run ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    else
        error_exit "未找到 timedatectl 或 UTC 时区文件"
    fi
    print_ok "系统时区已回滚为UTC"
}

is_valid_hostname() {
    local name="$1"
    [ "${#name}" -le 253 ] || return 1
    [[ ${name} =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$ ]]
}

rollback_hostname() {
    local original_hostname="${ORIGINAL_HOSTNAME}"
    local current_hostname escaped_current

    print_info "回滚系统主机名..."
    if [ -z "${original_hostname}" ]; then
        is_interactive || error_exit "非交互模式下请使用 --hostname 指定原始主机名"
        read -r -p "请输入原始主机名: " original_hostname || original_hostname=""
    fi
    is_valid_hostname "${original_hostname}" || error_exit "主机名格式无效: ${original_hostname}"

    backup_path /etc/hostname hostname.bak
    backup_path /etc/hosts hosts.bak

    current_hostname=$(hostname)
    if [ "${current_hostname}" = "${original_hostname}" ]; then
        print_warn "当前主机名已是 ${original_hostname}，无需回滚"
        return 0
    fi

    if command -v hostnamectl >/dev/null 2>&1; then
        run hostnamectl set-hostname "${original_hostname}"
    else
        run hostname "${original_hostname}"
        if [ "${DRY_RUN}" = true ]; then
            printf '[DRY-RUN] 写入 /etc/hostname: %s\n' "${original_hostname}"
        else
            printf '%s\n' "${original_hostname}" > /etc/hostname
        fi
    fi

    if is_valid_hostname "${current_hostname}" && [ -f /etc/hosts ]; then
        escaped_current=${current_hostname//./\\.}
        run sed -i -E "s/(^|[[:space:]])${escaped_current}([[:space:]]|$)/\\1${original_hostname}\\2/g" /etc/hosts
    fi
    print_ok "系统主机名已回滚为: ${original_hostname}"
}

rollback_kernel() {
    local confirm_kernel="" kernel_version=""

    print_info "回滚系统内核..."
    if ! [ -t 0 ] || [ "${DRY_RUN}" = true ]; then
        print_warn "[跳过] 内核回滚仅支持交互模式，且不支持 --dry-run"
        return 0
    fi
    print_warn "警告: 回滚系统内核可能导致系统不稳定"
    read -r -p "确定要继续吗? (y/n): " confirm_kernel || confirm_kernel="n"
    case "${confirm_kernel}" in
        y|Y) ;;
        *) print_warn "已取消内核回滚"; return 0 ;;
    esac

    if command -v rpm >/dev/null 2>&1 && command -v grubby >/dev/null 2>&1; then
        print_info "可用内核列表:"
        rpm -qa kernel | sort -V || true
        read -r -p "请输入要回滚到的内核版本 (例如: kernel-5.14.0-362.el9.x86_64): " kernel_version || kernel_version=""
        [[ ${kernel_version} =~ ^kernel-[A-Za-z0-9._+-]+$ ]] || error_exit "内核版本格式无效"
        yum install -y "${kernel_version}"
        grubby --set-default "/boot/vmlinuz-${kernel_version#kernel-}"
    elif command -v dpkg >/dev/null 2>&1; then
        print_info "可用内核列表:"
        dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2}' || true
        read -r -p "请输入要回滚到的内核版本 (例如: linux-image-5.15.0-71-generic): " kernel_version || kernel_version=""
        [[ ${kernel_version} =~ ^linux-image-[A-Za-z0-9._+-]+$ ]] || error_exit "内核版本格式无效"
        apt-get install -y "${kernel_version}"
        command -v update-grub >/dev/null 2>&1 && update-grub
    else
        error_exit "未识别的包管理器，无法回滚内核"
    fi
    print_ok "系统内核已设置为: ${kernel_version}"
    print_warn "注意: 请重启系统以应用新内核"
}

run_target() {
    case "$1" in
        bbr) rollback_bbr ;;
        fail2ban) rollback_fail2ban ;;
        swap) rollback_swap ;;
        timezone) rollback_timezone ;;
        hostname) rollback_hostname ;;
        kernel) rollback_kernel ;;
        all)
            local item
            for item in bbr fail2ban swap timezone; do
                run_target "${item}"
            done
            print_warn "主机名需要手动输入，未包含在批量回滚中"
            ;;
        *) error_exit "未知目标: $1" ;;
    esac
}

confirm_or_exit() {
    local confirm=""
    [ "${AUTO_YES}" = true ] && return 0
    [ "${DRY_RUN}" = true ] && return 0
    print_warn "警告: 此操作将移除VPS Scripts对系统环境所做的更改"
    echo -e "${RED}相关文件会先备份到 ${BACKUP_DIR}${NC}"
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
            --hostname)
                [ $# -ge 2 ] || error_exit "--hostname 需要参数"
                ORIGINAL_HOSTNAME="$2"
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

    print_info "VPS Scripts 系统环境回滚工具"
    echo "------------------------"

    if [ -n "${TARGET}" ]; then
        target=$(resolve_target "${TARGET}") || error_exit "未知目标: ${TARGET}（使用 --list 查看）"
    else
        show_list
        echo ""
        read -r -p "请选择要回滚的项目编号 (1-7): " choice || choice=""
        target=$(resolve_target "${choice}") || error_exit "无效的选择"
    fi

    confirm_or_exit
    [ "${DRY_RUN}" = true ] && print_warn "DRY-RUN: 以下操作仅预览，不会修改系统"
    run_target "${target}"

    echo ""
    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY-RUN 完成，未实际修改系统。"
    else
        print_ok "系统环境回滚完成"
        [ -d "${BACKUP_DIR}" ] && echo -e "${WHITE}备份目录: ${YELLOW}${BACKUP_DIR}${NC}"
    fi
    return 0
}

main "$@"
