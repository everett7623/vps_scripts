#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/update_system.sh
# Purpose: Safer system update workflow with backup, logging, and reboot checks.
# ==============================================================================

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="${LOG_DIR}/system_update.log"
BACKUP_DIR="/var/backups/system_update"
UPDATE_CACHE_AGE=3600

AUTO_CONFIRM=false
UPDATE_KERNEL=false
SECURITY_ONLY=false
REBOOT_REQUIRED=false

PKG_MANAGER=""
OS_TYPE=""
declare -a UPDATE_CMD=()
declare -a FULL_UPDATE_CMD=()
declare -a DIST_UPDATE_CMD=()
declare -a SECURITY_UPDATE_CMD=()
declare -a CLEANUP_CMD=()

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
CONFIG_FILE="${PROJECT_ROOT}/config/vps_scripts.conf"

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
    [ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/system_update.log"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[INFO] $1${NC}"; }
    print_success() { echo -e "${GREEN}[OK] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
    print_error() { echo -e "${RED}[ERROR] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}Root is required.${NC}"; exit 1; }; }
    get_os_release() { [ -f /etc/os-release ] && . /etc/os-release && echo "$ID" || echo "unknown"; }
fi

mkdir -p "${LOG_DIR}" "${BACKUP_DIR}"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "${LOG_FILE}"
}

run_logged_command() {
    local description="${1}"
    shift

    log "Running: ${description}"
    "$@" >> "${LOG_FILE}" 2>&1
}

detect_system() {
    OS_TYPE=$(get_os_release)

    case "${OS_TYPE}" in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            UPDATE_CMD=(apt-get update -qq)
            FULL_UPDATE_CMD=(apt-get upgrade -y)
            DIST_UPDATE_CMD=(apt-get dist-upgrade -y)
            CLEANUP_CMD=(apt-get autoremove -y)
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                UPDATE_CMD=(dnf makecache -q)
                FULL_UPDATE_CMD=(dnf update -y)
                SECURITY_UPDATE_CMD=(dnf update-minimal --security -y)
                CLEANUP_CMD=(dnf autoremove -y)
            else
                PKG_MANAGER="yum"
                UPDATE_CMD=(yum makecache -q)
                FULL_UPDATE_CMD=(yum update -y)
                SECURITY_UPDATE_CMD=(yum update-minimal --security -y)
                CLEANUP_CMD=(yum autoremove -y)
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            UPDATE_CMD=(apk update)
            FULL_UPDATE_CMD=(apk upgrade)
            CLEANUP_CMD=(sh -c 'rm -rf /var/cache/apk/*')
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            UPDATE_CMD=(pacman -Sy)
            FULL_UPDATE_CMD=(pacman -Su --noconfirm)
            CLEANUP_CMD=(pacman -Sc --noconfirm)
            ;;
        *)
            print_error "Unsupported OS: ${OS_TYPE}"
            exit 1
            ;;
    esac

    print_info "Detected OS: ${OS_TYPE} (${PKG_MANAGER})"
}

show_help() {
    cat <<'EOF'
用法：bash update_system.sh [选项]

选项：
  --auto, -y      无需交互确认
  --kernel, -k    在支持时包含内核或发行版升级
  --security, -s  在 yum/dnf 系统中仅安装安全更新
  --help, -h      显示此帮助信息
EOF
}

check_network() {
    print_info "正在检查网络连接..."

    if command -v ping >/dev/null 2>&1; then
        ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && return 0
        ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsS --max-time 5 https://1.1.1.1 >/dev/null 2>&1 && return 0
        curl -fsS --max-time 5 https://8.8.8.8 >/dev/null 2>&1 && return 0
    fi

    print_error "网络连接检查失败。"
    exit 1
}

backup_configs() {
    local backup_path="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
    local file=""
    local files=(
        "/etc/apt/sources.list"
        "/etc/apt/sources.list.d"
        "/etc/yum.repos.d"
        "/etc/ssh/sshd_config"
        "/etc/fstab"
        "/etc/network/interfaces"
        "/etc/netplan"
    )

    print_info "Backing up key configuration files..."
    mkdir -p "${backup_path}"

    for file in "${files[@]}"; do
        [ -e "${file}" ] && cp -r "${file}" "${backup_path}/" 2>/dev/null || true
    done

    case "${PKG_MANAGER}" in
        apt)
            dpkg --get-selections > "${backup_path}/packages.list" 2>/dev/null || true
            ;;
        yum|dnf)
            rpm -qa > "${backup_path}/packages.list" 2>/dev/null || true
            ;;
        pacman)
            pacman -Qqe > "${backup_path}/packages.list" 2>/dev/null || true
            ;;
        apk)
            apk info > "${backup_path}/packages.list" 2>/dev/null || true
            ;;
    esac

    log "Backup created at ${backup_path}"
    print_success "Backup created: ${backup_path}"
}

refresh_cache() {
    local last_update=0
    local now=0

    print_info "Refreshing package metadata..."

    if [ "${PKG_MANAGER}" = "apt" ] && [ -f /var/cache/apt/pkgcache.bin ]; then
        last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin 2>/dev/null || echo 0)
        now=$(date +%s)
        if [ $((now - last_update)) -lt "${UPDATE_CACHE_AGE}" ]; then
            print_info "Skipping cache refresh because apt metadata is still fresh."
            return 0
        fi
    fi

    if run_logged_command "refresh package metadata" "${UPDATE_CMD[@]}"; then
        print_success "Package metadata refreshed."
    else
        print_warn "Package metadata refresh encountered issues."
    fi
}

count_available_updates() {
    case "${PKG_MANAGER}" in
        apt)
            apt list --upgradable 2>/dev/null | grep -c "upgradable" || true
            ;;
        yum|dnf)
            "${PKG_MANAGER}" check-update -q 2>/dev/null | grep -c -v '^$' || true
            ;;
        apk)
            apk list -u 2>/dev/null | wc -l
            ;;
        pacman)
            pacman -Qu 2>/dev/null | wc -l
            ;;
        *)
            echo 0
            ;;
    esac
}

check_available_updates() {
    local count=0

    print_info "正在检查可用更新..."
    count=$(count_available_updates)

    if [ "${count}" -eq 0 ]; then
        print_success "当前没有可用更新。"
        exit 0
    fi

    print_info "发现 ${count} 个可用更新。"
    if [ "${PKG_MANAGER}" = "apt" ]; then
        apt list --upgradable 2>/dev/null | head -n 11
    fi
}

perform_update() {
    local description="full system update"
    local -a selected_cmd=()

    if [ "${SECURITY_ONLY}" = "true" ]; then
        if [ ${#SECURITY_UPDATE_CMD[@]} -eq 0 ]; then
            print_warn "Security-only mode is not supported on ${PKG_MANAGER}. Falling back to full update."
            selected_cmd=("${FULL_UPDATE_CMD[@]}")
        else
            description="security-only update"
            selected_cmd=("${SECURITY_UPDATE_CMD[@]}")
        fi
    elif [ "${UPDATE_KERNEL}" = "true" ] && [ ${#DIST_UPDATE_CMD[@]} -gt 0 ]; then
        description="kernel/dist upgrade"
        selected_cmd=("${DIST_UPDATE_CMD[@]}")
    else
        selected_cmd=("${FULL_UPDATE_CMD[@]}")
    fi

    print_info "Mode: ${description}"
    log "Selected update mode: ${description}"

    if [ "${AUTO_CONFIRM}" = "false" ]; then
        read -r -p "是否继续执行 ${description}？[y/N]: " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            print_warn "已取消系统更新。"
            exit 0
        fi
    fi

    if run_logged_command "${description}" "${selected_cmd[@]}"; then
        print_success "系统更新成功完成。"
    else
        print_error "系统更新失败，请查看日志：${LOG_FILE}"
        exit 1
    fi
}

cleanup_system() {
    print_info "Cleaning package residue..."

    if run_logged_command "cleanup packages" "${CLEANUP_CMD[@]}"; then
        print_success "Cleanup completed."
    else
        print_warn "Cleanup encountered issues. Check log: ${LOG_FILE}"
    fi

    if [ "${PKG_MANAGER}" = "apt" ]; then
        run_logged_command "apt autoclean" apt-get autoclean || true
    elif [ "${PKG_MANAGER}" = "yum" ] || [ "${PKG_MANAGER}" = "dnf" ]; then
        run_logged_command "${PKG_MANAGER} clean all" "${PKG_MANAGER}" clean all || true
    fi
}

check_reboot_needed() {
    if [ -f /var/run/reboot-required ]; then
        REBOOT_REQUIRED=true
    elif [[ "${PKG_MANAGER}" =~ ^(yum|dnf)$ ]] && command -v needs-restarting >/dev/null 2>&1; then
        needs-restarting -r >/dev/null 2>&1 && REBOOT_REQUIRED=true
    fi

    if [ "${REBOOT_REQUIRED}" != "true" ]; then
        print_success "No reboot required."
        return 0
    fi

    print_warn "A reboot is required to complete this update."

    if [ "${AUTO_CONFIRM}" = "true" ]; then
        print_warn "Auto mode enabled. Rebooting in 5 seconds..."
        sleep 5
        reboot
    else
        read -r -p "是否立即重启？[y/N]: " answer
        [[ "${answer}" =~ ^[Yy]$ ]] && reboot
    fi
}

generate_report() {
    local report_file="${LOG_DIR}/update_report_$(date +%Y%m%d_%H%M%S).txt"

    cat > "${report_file}" <<EOF
==================================================
System Update Report
==================================================
Time: $(date)
OS: ${OS_TYPE}
Package Manager: ${PKG_MANAGER}
Security Only: ${SECURITY_ONLY}
Kernel/Dist Upgrade: ${UPDATE_KERNEL}
Reboot Required: ${REBOOT_REQUIRED}
Log File: ${LOG_FILE}
==================================================
EOF

    print_info "Report written to ${report_file}"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto|-y) AUTO_CONFIRM=true ;;
            --kernel|-k) UPDATE_KERNEL=true ;;
            --security|-s) SECURITY_ONLY=true ;;
            --help|-h) show_help; exit 0 ;;
            *) print_error "未知参数：$1"; show_help; exit 1 ;;
        esac
        shift
    done

    check_root
    print_header "系统更新工具"
    detect_system
    check_network
    backup_configs
    refresh_cache
    check_available_updates
    perform_update
    cleanup_system
    check_reboot_needed
    generate_report
}

main "$@"
