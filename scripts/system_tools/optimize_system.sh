#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/optimize_system.sh
# Purpose: Conservative VPS tuning with backups, logging, and safer defaults.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
CONFIG_FILE="${PROJECT_ROOT}/config/vps_scripts.conf"

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="${LOG_DIR}/optimize_system.log"
BACKUP_DIR="/var/backups/system_optimize"

AUTO_CONFIRM=false
RUN_ALL=false
RUN_KERNEL=false
RUN_LIMITS=false
RUN_MEMORY=false
RUN_SERVICES=false
RUN_SECURITY=false

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
    [ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/optimize_system.log"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[INFO] $1"; }
    print_success() { print_msg "${GREEN}" "[OK] $1"; }
    print_warn() { print_msg "${YELLOW}" "[WARN] $1"; }
    print_error() { print_msg "${RED}" "[ERROR] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 28 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    print_title() { echo ""; printf "%b>> %s%b\n" "${BOLD}${YELLOW}" "$1" "${NC}"; print_separator "-" 80; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    safe_mkdir() { [ -d "$1" ] || mkdir -p "$1"; }
    check_root() { [[ ${EUID} -ne 0 ]] && { print_error "This script requires root privileges."; exit 1; }; }
    ask_yes_no() { local prompt="$1"; local answer=""; read -r -p "${prompt} [y/N]: " answer; [[ "${answer}" =~ ^[Yy]$ ]]; }
    get_total_memory() { free -m | awk '/^Mem:/ {print $2}'; }
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
Usage: bash optimize_system.sh [options]

Options:
  --auto, -a       Run all conservative optimization modules
  --yes, -y        Skip confirmation prompts
  --kernel         Apply safe sysctl tuning
  --limits         Raise file/process limits
  --memory         Ensure swap protection when memory is low
  --services       Disable known low-value desktop services
  --security       Apply SSH latency/security baseline
  --help, -h       Show this help message
EOF
}

backup_target() {
    local target="$1"
    local destination=""

    [ -e "${target}" ] || return 0

    ensure_runtime_dirs
    destination="${BACKUP_DIR}/$(basename "${target}")_$(date +%Y%m%d_%H%M%S)"
    cp -a "${target}" "${destination}"
    log "BACKUP" "Saved backup ${destination}"
}

run_logged_command() {
    local description="$1"
    shift

    log "INFO" "Running: ${description}"
    "$@" >> "${LOG_FILE}" 2>&1
}

write_file_atomically() {
    local target="$1"
    local temp_file="$2"

    cat "${temp_file}" > "${target}"
    rm -f "${temp_file}"
}

apply_kernel_tuning() {
    local sysctl_file="/etc/sysctl.d/99-vps-optimize.conf"
    local temp_file=""

    print_title "Kernel Tuning"
    ensure_runtime_dirs
    backup_target "${sysctl_file}"
    [ -f /etc/sysctl.conf ] && backup_target "/etc/sysctl.conf"

    temp_file=$(mktemp "/tmp/vps_sysctl.XXXXXX") || {
        print_error "Unable to create a temporary sysctl file."
        return 1
    }

    cat > "${temp_file}" <<'EOF'
# Managed by vps_scripts optimize_system.sh
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 10
vm.min_free_kbytes = 65536
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF

    write_file_atomically "${sysctl_file}" "${temp_file}"

    if run_logged_command "apply sysctl tuning" sysctl -p "${sysctl_file}"; then
        print_success "Kernel tuning applied."
        return 0
    fi

    print_warn "Kernel tuning file was written, but sysctl reload reported issues."
    return 1
}

apply_limits_tuning() {
    local limits_file="/etc/security/limits.d/99-vps-scripts.conf"
    local systemd_dir="/etc/systemd/system.conf.d"
    local systemd_file="${systemd_dir}/99-vps-scripts.conf"
    local temp_file=""

    print_title "Limits Tuning"
    ensure_runtime_dirs
    backup_target "${limits_file}"
    backup_target "${systemd_file}"

    temp_file=$(mktemp "/tmp/vps_limits.XXXXXX") || {
        print_error "Unable to create a temporary limits file."
        return 1
    }

    cat > "${temp_file}" <<'EOF'
# Managed by vps_scripts optimize_system.sh
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
root soft nproc 65535
root hard nproc 65535
root soft nofile 65535
root hard nofile 65535
EOF

    write_file_atomically "${limits_file}" "${temp_file}"

    if [ -d "${systemd_dir}" ]; then
        temp_file=$(mktemp "/tmp/vps_systemd_limits.XXXXXX") || {
            print_error "Unable to create a temporary systemd limits file."
            return 1
        }

        cat > "${temp_file}" <<'EOF'
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF

        write_file_atomically "${systemd_file}" "${temp_file}"
        run_logged_command "reload systemd manager" systemctl daemon-reexec || true
    fi

    print_success "Limits tuning applied."
}

recommended_swap_size_mb() {
    local total_memory_mb="${1:-0}"

    if [ "${total_memory_mb}" -le 1024 ]; then
        echo 1024
    elif [ "${total_memory_mb}" -le 2048 ]; then
        echo 2048
    else
        echo 0
    fi
}

ensure_swap_protection() {
    local current_swap_mb
    local total_memory_mb
    local new_swap_mb

    print_title "Memory Protection"

    current_swap_mb=$(free -m 2>/dev/null | awk '/^Swap:/ {print $2}')
    current_swap_mb=${current_swap_mb:-0}

    total_memory_mb=$(get_total_memory 2>/dev/null || true)
    total_memory_mb=${total_memory_mb:-0}

    new_swap_mb=$(recommended_swap_size_mb "${total_memory_mb:-0}")

    if [ "${current_swap_mb}" -gt 0 ]; then
        print_success "Swap is already enabled (${current_swap_mb}MB)."
        return 0
    fi

    if [ "${new_swap_mb}" -eq 0 ]; then
        print_info "Swap is not enabled, but RAM size is large enough that no automatic swap file will be created."
        return 0
    fi

    print_warn "Swap is disabled on a low-memory host (${total_memory_mb}MB RAM)."
    if [ "${AUTO_CONFIRM}" = false ] && ! ask_yes_no "Create a ${new_swap_mb}MB swap file at /swapfile?"; then
        print_info "Swap creation skipped."
        return 0
    fi

    if [ -f /swapfile ]; then
        print_warn "/swapfile already exists. Skipping automatic swap creation."
        return 0
    fi

    run_logged_command "allocate swap file" dd if=/dev/zero of=/swapfile bs=1M count="${new_swap_mb}" status=none || {
        print_error "Swap allocation failed."
        return 1
    }
    run_logged_command "lock down swap file permissions" chmod 600 /swapfile || {
        print_error "Setting swap file permissions failed."
        return 1
    }
    run_logged_command "initialize swap file" mkswap /swapfile || {
        print_error "mkswap failed."
        return 1
    }
    run_logged_command "enable swap file" swapon /swapfile || {
        print_error "swapon failed."
        return 1
    }

    if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
        printf '%s\n' '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    print_success "Swap file created and enabled."
    return 0
}

disable_low_value_services() {
    local services=("bluetooth" "cups" "avahi-daemon")
    local service=""

    print_title "Service Cleanup"

    if ! command_exists systemctl; then
        print_warn "systemctl is not available; skipping service cleanup."
        return 0
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            if systemctl is-enabled "${service}" >/dev/null 2>&1 || systemctl is-active "${service}" >/dev/null 2>&1; then
                run_logged_command "stop ${service}" systemctl stop "${service}" || true
                run_logged_command "disable ${service}" systemctl disable "${service}" || true
                print_success "Disabled ${service}."
            else
                print_info "${service} is already inactive."
            fi
        fi
    done
}

apply_ssh_baseline() {
    local sshd_main="/etc/ssh/sshd_config"
    local sshd_dropin_dir="/etc/ssh/sshd_config.d"
    local sshd_dropin_file="${sshd_dropin_dir}/99-vps-scripts.conf"
    local temp_file=""

    print_title "SSH Baseline"

    if [ -d "${sshd_dropin_dir}" ]; then
        backup_target "${sshd_dropin_file}"
        temp_file=$(mktemp "/tmp/vps_sshd_dropin.XXXXXX") || {
            print_error "Unable to create a temporary SSH config file."
            return 1
        }

        cat > "${temp_file}" <<'EOF'
# Managed by vps_scripts optimize_system.sh
UseDNS no
EOF

        write_file_atomically "${sshd_dropin_file}" "${temp_file}"
    elif [ -f "${sshd_main}" ]; then
        backup_target "${sshd_main}"
        if grep -q '^UseDNS' "${sshd_main}" 2>/dev/null; then
            sed -i 's/^UseDNS.*/UseDNS no/' "${sshd_main}"
        else
            printf '\nUseDNS no\n' >> "${sshd_main}"
        fi
    else
        print_warn "SSH configuration file not found; skipping SSH tuning."
        return 0
    fi

    if command_exists systemctl; then
        run_logged_command "reload sshd" systemctl reload sshd || run_logged_command "reload ssh" systemctl reload ssh || true
    fi

    print_success "SSH baseline applied."
}

run_selected_modules() {
    local executed_any=false
    local result=0

    if [ "${RUN_ALL}" = true ]; then
        RUN_KERNEL=true
        RUN_LIMITS=true
        RUN_MEMORY=true
        RUN_SERVICES=true
        RUN_SECURITY=true
    fi

    if [ "${RUN_KERNEL}" = true ]; then
        executed_any=true
        apply_kernel_tuning || result=1
    fi

    if [ "${RUN_LIMITS}" = true ]; then
        executed_any=true
        apply_limits_tuning || result=1
    fi

    if [ "${RUN_MEMORY}" = true ]; then
        executed_any=true
        ensure_swap_protection || result=1
    fi

    if [ "${RUN_SERVICES}" = true ]; then
        executed_any=true
        disable_low_value_services || result=1
    fi

    if [ "${RUN_SECURITY}" = true ]; then
        executed_any=true
        apply_ssh_baseline || result=1
    fi

    if [ "${executed_any}" = false ]; then
        interactive_menu
        return $?
    fi

    echo ""
    print_separator
    if [ "${result}" -eq 0 ]; then
        print_success "Selected optimization modules completed."
    else
        print_warn "Optimization finished with warnings. Review ${LOG_FILE}."
    fi
    return "${result}"
}

interactive_menu() {
    local selection=""

    while true; do
        clear 2>/dev/null || true
        print_header "VPS Safe Optimization"
        echo "1) Run all conservative optimizations"
        echo "2) Kernel tuning only"
        echo "3) Limits tuning only"
        echo "4) Memory protection only"
        echo "5) Service cleanup only"
        echo "6) SSH baseline only"
        echo "0) Exit"
        echo ""
        read -r -p "Select an option [0-6]: " selection

        case "${selection}" in
            1) RUN_ALL=true; break ;;
            2) RUN_KERNEL=true; break ;;
            3) RUN_LIMITS=true; break ;;
            4) RUN_MEMORY=true; break ;;
            5) RUN_SERVICES=true; break ;;
            6) RUN_SECURITY=true; break ;;
            0) exit 0 ;;
            *) print_error "Invalid selection."; sleep 1 ;;
        esac
    done

    run_selected_modules
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto|-a)
                RUN_ALL=true
                ;;
            --yes|-y)
                AUTO_CONFIRM=true
                ;;
            --kernel)
                RUN_KERNEL=true
                ;;
            --limits)
                RUN_LIMITS=true
                ;;
            --memory)
                RUN_MEMORY=true
                ;;
            --services)
                RUN_SERVICES=true
                ;;
            --security)
                RUN_SECURITY=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    check_root
    ensure_runtime_dirs
    run_selected_modules
}

main "$@"
