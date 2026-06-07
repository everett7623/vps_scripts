#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/change_hostname.sh
# Purpose: Safer hostname management with backups, verification, and rollback.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
CONFIG_FILE="${PROJECT_ROOT}/config/vps_scripts.conf"

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="${LOG_DIR}/hostname_change.log"
BACKUP_DIR="/var/backups/hostname_change"
SCRIPT_VERSION="2.0.0"

AUTO_CONFIRM=false
SHOW_HISTORY_ONLY=false
SHOW_CURRENT_ONLY=false
ROLLBACK_ONLY=false

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
    [ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/hostname_change.log"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[信息] $1"; }
    print_success() { print_msg "${GREEN}" "[完成] $1"; }
    print_warn() { print_msg "${YELLOW}" "[警告] $1"; }
    print_error() { print_msg "${RED}" "[错误] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 28 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    safe_mkdir() { [ -d "$1" ] || mkdir -p "$1"; }
    check_root() { [[ ${EUID} -ne 0 ]] && { print_error "此脚本需要 root 权限。"; exit 1; }; }
    ask_yes_no() { local prompt="$1"; local answer=""; read -r -p "${prompt} [y/N]: " answer; [[ "${answer}" =~ ^[Yy]$ ]]; }
    read_input() { local prompt="$1"; local default="${2:-}"; if [ -n "${default}" ]; then read -r -p "${prompt} [${default}]: " REPLY; REPLY=${REPLY:-$default}; else read -r -p "${prompt}: " REPLY; fi; }
fi

ensure_runtime_dirs() {
    safe_mkdir "${LOG_DIR}"
    safe_mkdir "${BACKUP_DIR}"
}

log() {
    local level="$1"
    shift
    ensure_runtime_dirs
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "$*" >> "${LOG_FILE}"
}

show_help() {
    cat <<'EOF'
用法：bash change_hostname.sh [选项] [新主机名]

选项：
  --yes, -y        跳过确认提示
  --rollback       使用最近一次备份回滚
  --history        显示主机名备份历史
  --show           显示当前主机名并退出
  --help, -h       显示此帮助信息
EOF
}

current_hostname() {
    if command_exists hostnamectl; then
        hostnamectl --static 2>/dev/null || hostname
    else
        hostname
    fi
}

validate_hostname() {
    local name="$1"

    if [ -z "${name}" ]; then
        print_error "主机名不能为空。"
        return 1
    fi

    if [ "${#name}" -gt 63 ]; then
        print_error "主机名长度不能超过 63 个字符。"
        return 1
    fi

    if [[ ! "${name}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
        print_error "主机名只能包含字母、数字和连字符。"
        return 1
    fi

    if [[ "${name}" =~ ^[0-9]+$ ]]; then
        print_error "主机名不能全部为数字。"
        return 1
    fi

    return 0
}

create_backup() {
    local old_name="$1"
    local backup_path="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
    local file=""
    local files=(
        "/etc/hostname"
        "/etc/hosts"
        "/etc/sysconfig/network"
        "/etc/mailname"
        "/etc/postfix/main.cf"
        "/etc/cloud/cloud.cfg"
    )

    ensure_runtime_dirs
    mkdir -p "${backup_path}"

    for file in "${files[@]}"; do
        if [ -f "${file}" ]; then
            cp -a "${file}" "${backup_path}/$(basename "${file}")"
        fi
    done

    cat > "${backup_path}/metadata.env" <<EOF
OLD_HOSTNAME='${old_name}'
CREATED_AT='$(date '+%Y-%m-%d %H:%M:%S %Z')'
SCRIPT_VERSION='${SCRIPT_VERSION}'
EOF

    printf '%s\n' "${old_name}" > "${backup_path}/old_hostname.txt"
    log "BACKUP" "Created hostname backup at ${backup_path}"
    echo "${backup_path}"
}

update_hosts_file() {
    local new_name="$1"
    local temp_file=""

    [ -f /etc/hosts ] || return 0

    temp_file=$(mktemp "/tmp/vps_hosts.XXXXXX") || {
        print_error "无法创建临时 hosts 文件。"
        return 1
    }

    awk -v new_name="${new_name}" '
        BEGIN { inserted = 0 }
        /^127\.0\.1\.1[[:space:]]+/ {
            print "127.0.1.1\t" new_name
            inserted = 1
            next
        }
        {
            print
            if (!inserted && $0 ~ /^127\.0\.0\.1[[:space:]]+/) {
                print "127.0.1.1\t" new_name
                inserted = 1
            }
        }
        END {
            if (!inserted) {
                print "127.0.1.1\t" new_name
            }
        }
    ' /etc/hosts > "${temp_file}"

    cat "${temp_file}" > /etc/hosts
    rm -f "${temp_file}"
}

update_key_value_file() {
    local file="$1"
    local key="$2"
    local value="$3"
    local temp_file=""

    temp_file=$(mktemp "/tmp/vps_hostname_cfg.XXXXXX") || return 1

    if [ -f "${file}" ]; then
        awk -F= -v target_key="${key}" -v target_value="${value}" '
            BEGIN { updated = 0 }
            $1 == target_key {
                print target_key "=" target_value
                updated = 1
                next
            }
            { print }
            END {
                if (!updated) {
                    print target_key "=" target_value
                }
            }
        ' "${file}" > "${temp_file}"
    else
        printf '%s=%s\n' "${key}" "${value}" > "${temp_file}"
    fi

    cat "${temp_file}" > "${file}"
    rm -f "${temp_file}"
}

update_cloud_init() {
    local file="/etc/cloud/cloud.cfg"
    local temp_file=""

    [ -f "${file}" ] || return 0

    temp_file=$(mktemp "/tmp/vps_cloudcfg.XXXXXX") || return 1

    awk '
        BEGIN { updated = 0 }
        /^preserve_hostname:/ {
            print "preserve_hostname: true"
            updated = 1
            next
        }
        { print }
        END {
            if (!updated) {
                print "preserve_hostname: true"
            }
        }
    ' "${file}" > "${temp_file}"

    cat "${temp_file}" > "${file}"
    rm -f "${temp_file}"
}

restart_related_services() {
    if ! command_exists systemctl; then
        return 0
    fi

    systemctl restart systemd-hostnamed >/dev/null 2>&1 || true
    systemctl restart rsyslog >/dev/null 2>&1 || true

    if systemctl is-active --quiet postfix; then
        systemctl restart postfix >/dev/null 2>&1 || true
    fi
}

perform_change() {
    local new_name="$1"

    printf '%s\n' "${new_name}" > /etc/hostname
    update_hosts_file "${new_name}" || return 1

    if [ -f /etc/sysconfig/network ] || [ -d /etc/sysconfig ]; then
        update_key_value_file "/etc/sysconfig/network" "HOSTNAME" "${new_name}" || return 1
    fi

    if [ -f /etc/mailname ]; then
        printf '%s\n' "${new_name}" > /etc/mailname
    fi

    update_cloud_init || return 1

    if command_exists hostnamectl; then
        hostnamectl set-hostname "${new_name}" >/dev/null 2>&1 || true
    fi

    hostname "${new_name}" >/dev/null 2>&1 || true

    if command_exists postconf && [ -f /etc/postfix/main.cf ]; then
        postconf -e "myhostname = ${new_name}" >/dev/null 2>&1 || true
    fi

    restart_related_services
    log "INFO" "Applied hostname change to ${new_name}"
}

verify_change() {
    local target_name="$1"
    local verified=true
    local live_name=""

    print_separator
    print_info "验证结果"

    live_name=$(current_hostname)
    if [ "${live_name}" = "${target_name}" ]; then
        print_success "当前主机名与目标一致。"
    else
        print_error "当前主机名为 '${live_name}'，预期为 '${target_name}'。"
        verified=false
    fi

    if [ -f /etc/hostname ] && [ "$(tr -d '[:space:]' </etc/hostname)" = "${target_name}" ]; then
        print_success "/etc/hostname 已更新。"
    else
        print_error "/etc/hostname 中未找到目标主机名。"
        verified=false
    fi

    if [ -f /etc/hosts ] && grep -Eq "^127\.0\.1\.1[[:space:]]+${target_name}([[:space:]]|$)" /etc/hosts; then
        print_success "/etc/hosts 已更新。"
    else
        print_warn "/etc/hosts 未包含 ${target_name} 对应的独立 127.0.1.1 映射。"
        verified=false
    fi

    [ "${verified}" = true ]
}

generate_report() {
    local old_name="$1"
    local new_name="$2"
    local backup_path="$3"
    local report_file="${LOG_DIR}/hostname_change_report_$(date +%Y%m%d_%H%M%S).txt"

    ensure_runtime_dirs
    cat > "${report_file}" <<EOF
Hostname Change Report
======================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
Old hostname: ${old_name}
New hostname: ${new_name}
Backup path: ${backup_path}
Log file: ${LOG_FILE}
Script version: ${SCRIPT_VERSION}
EOF

    print_success "主机名变更报告已写入：${report_file}"
    log "INFO" "Generated report ${report_file}"
}

restore_backup() {
    local backup_path="$1"
    local old_name=""

    [ -d "${backup_path}" ] || {
        print_error "找不到备份路径：${backup_path}"
        return 1
    }

    if [ -f "${backup_path}/metadata.env" ]; then
        # shellcheck disable=SC1090
        . "${backup_path}/metadata.env"
        old_name="${OLD_HOSTNAME:-}"
    fi

    [ -z "${old_name}" ] && [ -f "${backup_path}/old_hostname.txt" ] && old_name=$(cat "${backup_path}/old_hostname.txt")
    [ -n "${old_name}" ] || {
        print_error "备份元数据中缺少原主机名。"
        return 1
    }

    [ -f "${backup_path}/hostname" ] && cp -a "${backup_path}/hostname" /etc/hostname
    [ -f "${backup_path}/hosts" ] && cp -a "${backup_path}/hosts" /etc/hosts
    [ -f "${backup_path}/network" ] && cp -a "${backup_path}/network" /etc/sysconfig/network
    [ -f "${backup_path}/mailname" ] && cp -a "${backup_path}/mailname" /etc/mailname
    [ -f "${backup_path}/main.cf" ] && cp -a "${backup_path}/main.cf" /etc/postfix/main.cf
    [ -f "${backup_path}/cloud.cfg" ] && cp -a "${backup_path}/cloud.cfg" /etc/cloud/cloud.cfg

    if command_exists hostnamectl; then
        hostnamectl set-hostname "${old_name}" >/dev/null 2>&1 || true
    fi
    hostname "${old_name}" >/dev/null 2>&1 || true

    restart_related_services
    log "ROLLBACK" "Rolled back hostname using backup ${backup_path}"

    if verify_change "${old_name}"; then
        print_success "主机名回滚完成。"
        return 0
    fi

    print_warn "回滚已完成，但验证发现问题。"
    return 1
}

show_history() {
    local backup_path=""
    local metadata_file=""
    local old_name=""

    print_header "主机名备份历史"

    if ! ls -1 "${BACKUP_DIR}"/backup_* >/dev/null 2>&1; then
        print_info "未找到主机名备份。"
        return 0
    fi

    for backup_path in $(ls -1dt "${BACKUP_DIR}"/backup_* 2>/dev/null); do
        metadata_file="${backup_path}/metadata.env"
        old_name="unknown"
        if [ -f "${metadata_file}" ]; then
            # shellcheck disable=SC1090
            . "${metadata_file}"
            old_name="${OLD_HOSTNAME:-unknown}"
        elif [ -f "${backup_path}/old_hostname.txt" ]; then
            old_name=$(cat "${backup_path}/old_hostname.txt")
        fi

        printf "  %-28s %s\n" "$(basename "${backup_path}")" "${old_name}"
    done
}

rollback_latest() {
    local latest_backup=""

    latest_backup=$(ls -1dt "${BACKUP_DIR}"/backup_* 2>/dev/null | head -n1 || true)
    [ -n "${latest_backup}" ] || {
        print_error "没有可用于回滚的备份。"
        return 1
    }

    print_warn "最近备份：$(basename "${latest_backup}")"
    if [ "${AUTO_CONFIRM}" = false ] && ! ask_yes_no "Roll back hostname using the latest backup?"; then
        print_info "已取消回滚。"
        return 0
    fi

    restore_backup "${latest_backup}"
}

show_current_hostname() {
    print_header "当前主机名"
    printf "%b%-18s%b %s\n" "${CYAN}" "主机名:" "${NC}" "$(current_hostname)"
    printf "%b%-18s%b %s\n" "${CYAN}" "主要 IP:" "${NC}" "$(hostname -I 2>/dev/null | awk '{print $1}')"
}

change_hostname_flow() {
    local new_name="$1"
    local old_name=""
    local backup_path=""

    old_name=$(current_hostname)

    validate_hostname "${new_name}" || return 1

    if [ "${new_name}" = "${old_name}" ]; then
        print_warn "主机名已经是 ${new_name}。"
        return 0
    fi

    if [ "${AUTO_CONFIRM}" = false ] && ! ask_yes_no "Change hostname from ${old_name} to ${new_name}?"; then
        print_info "已取消主机名修改。"
        return 0
    fi

    backup_path=$(create_backup "${old_name}") || return 1
    print_info "备份已创建：${backup_path}"

    if ! perform_change "${new_name}"; then
        print_error "应用更新时修改主机名失败。"
        return 1
    fi

    if verify_change "${new_name}"; then
        generate_report "${old_name}" "${new_name}" "${backup_path}"
        print_success "主机名修改成功。"
        print_info "如果终端提示符未刷新，请重新连接 SSH。"
        return 0
    fi

    print_warn "主机名修改完成，但验证存在警告，请查看 ${LOG_FILE}。"
    return 1
}

interactive_menu() {
    local selection=""
    local new_name=""

    while true; do
        clear 2>/dev/null || true
        print_header "VPS 主机名管理"
        printf "%b当前主机名:%b %s\n" "${CYAN}" "${NC}" "$(current_hostname)"
        printf "%b主要 IP:%b    %s\n" "${CYAN}" "${NC}" "$(hostname -I 2>/dev/null | awk '{print $1}')"
        print_separator
        echo "1) 修改主机名"
        echo "2) 回滚最近一次修改"
        echo "3) 查看备份历史"
        echo "4) 查看当前主机名"
        echo "0) 退出"
        echo ""
        read -r -p "请选择 [0-4]: " selection

        case "${selection}" in
            1)
                read_input "请输入新的主机名" "" new_name
                [ -n "${new_name}" ] && change_hostname_flow "${new_name}"
                echo ""
                read -r -n 1 -s -p "按任意键继续..."
                ;;
            2)
                rollback_latest
                echo ""
                read -r -n 1 -s -p "按任意键继续..."
                ;;
            3)
                show_history
                echo ""
                read -r -n 1 -s -p "按任意键继续..."
                ;;
            4)
                show_current_hostname
                echo ""
                read -r -n 1 -s -p "按任意键继续..."
                ;;
            0)
                exit 0
                ;;
            *)
                print_error "无效选项。"
                sleep 1
                ;;
        esac
    done
}

parse_args() {
    NEW_HOSTNAME=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y)
                AUTO_CONFIRM=true
                ;;
            --rollback)
                ROLLBACK_ONLY=true
                ;;
            --history)
                SHOW_HISTORY_ONLY=true
                ;;
            --show)
                SHOW_CURRENT_ONLY=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --*)
                print_error "未知选项：$1"
                show_help
                exit 1
                ;;
            *)
                if [ -n "${NEW_HOSTNAME}" ]; then
                    print_error "只能指定一个主机名参数。"
                    exit 1
                fi
                NEW_HOSTNAME="$1"
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    if [ "${SHOW_CURRENT_ONLY}" = true ]; then
        show_current_hostname
        exit 0
    fi

    if [ "${SHOW_HISTORY_ONLY}" = true ]; then
        show_history
        exit 0
    fi

    if [ "${ROLLBACK_ONLY}" = true ]; then
        check_root
        ensure_runtime_dirs
        rollback_latest
        exit $?
    fi

    if [ -n "${NEW_HOSTNAME:-}" ]; then
        check_root
        ensure_runtime_dirs
        change_hostname_flow "${NEW_HOSTNAME}"
        exit $?
    fi

    check_root
    ensure_runtime_dirs
    interactive_menu
}

main "$@"
