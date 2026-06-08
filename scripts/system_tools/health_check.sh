#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/health_check.sh
# Purpose: Read-only VPS health check for common operational risks.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
WARNINGS=0
CRITICALS=0
CHECK_NETWORK=true

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'; WHITE='\033[1;37m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[INFO] $1"; }
    print_success() { print_msg "${GREEN}" "[OK] $1"; }
    print_warn() { print_msg "${YELLOW}" "[WARN] $1"; }
    print_error() { print_msg "${RED}" "[ERROR] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 28 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    print_title() { echo ""; printf "%b>> %s%b\n" "${BOLD}${YELLOW}" "$1" "${NC}"; print_separator "-" 80; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi

show_help() {
    cat <<'EOF'
Usage: bash health_check.sh [options]

Options:
  --no-network   Skip external network probes
  --help, -h     Show this help
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-network)
                CHECK_NETWORK=false
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

warn() {
    WARNINGS=$((WARNINGS + 1))
    print_warn "$1"
}

critical() {
    CRITICALS=$((CRITICALS + 1))
    print_error "$1"
}

ok() {
    print_success "$1"
}

check_load() {
    local cores=1
    local load_1="0"
    local load_scaled=0
    local cores_scaled=0

    print_title "Load"

    cores=$(nproc 2>/dev/null || echo 1)
    load_1=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo 0)
    load_scaled=$(awk -v v="${load_1}" 'BEGIN {printf "%d", v * 100}')
    cores_scaled=$((cores * 100))

    printf "Load average: %s, CPU cores: %s\n" "${load_1}" "${cores}"
    if [ "${load_scaled}" -gt $((cores_scaled * 2)) ]; then
        critical "1-minute load is more than 2x CPU cores."
    elif [ "${load_scaled}" -gt "${cores_scaled}" ]; then
        warn "1-minute load is higher than CPU core count."
    else
        ok "Load is within the expected range."
    fi
}

check_memory() {
    local total_kb=0
    local available_kb=0
    local swap_total_kb=0
    local usage_pct=0

    print_title "Memory"

    total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    available_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    swap_total_kb=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)

    if [ "${total_kb}" -gt 0 ]; then
        usage_pct=$(((total_kb - available_kb) * 100 / total_kb))
    fi

    printf "RAM usage: %s%%, available: %sMB, swap: %sMB\n" \
        "${usage_pct}" "$((available_kb / 1024))" "$((swap_total_kb / 1024))"

    if [ "${usage_pct}" -ge 95 ]; then
        critical "Memory usage is critically high."
    elif [ "${usage_pct}" -ge 85 ]; then
        warn "Memory usage is high."
    else
        ok "Memory pressure is acceptable."
    fi

    if [ "${swap_total_kb}" -eq 0 ] && [ "${total_kb}" -le $((2 * 1024 * 1024)) ]; then
        warn "Low-memory VPS has no swap configured."
    fi
}

check_disk() {
    local line=""
    local mount=""
    local usage=""
    local inode_usage=""
    local usage_num=0
    local inode_num=0

    print_title "Disk"

    df -hP 2>/dev/null | awk 'NR == 1 || $1 ~ "^/dev/"'

    while IFS= read -r line; do
        mount=$(awk '{print $6}' <<< "${line}")
        usage=$(awk '{print $5}' <<< "${line}")
        usage_num=${usage%\%}
        if [ "${usage_num}" -ge 95 ]; then
            critical "Disk usage is critical on ${mount}: ${usage}"
        elif [ "${usage_num}" -ge 85 ]; then
            warn "Disk usage is high on ${mount}: ${usage}"
        fi
    done < <(df -P 2>/dev/null | awk '$1 ~ "^/dev/"')

    if command_exists df; then
        while IFS= read -r line; do
            mount=$(awk '{print $6}' <<< "${line}")
            inode_usage=$(awk '{print $5}' <<< "${line}")
            inode_num=${inode_usage%\%}
            if [ "${inode_num}" -ge 90 ]; then
                warn "Inode usage is high on ${mount}: ${inode_usage}"
            fi
        done < <(df -Pi 2>/dev/null | awk '$1 ~ "^/dev/"')
    fi
}

check_services() {
    local services=("ssh" "sshd" "cron" "crond" "systemd-journald")
    local service=""
    local found=false

    print_title "Core Services"

    if ! command_exists systemctl; then
        warn "systemctl is unavailable; service health cannot be checked."
        return 0
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            found=true
            if systemctl is-active --quiet "${service}"; then
                ok "${service} is active."
            else
                warn "${service} is installed but not active."
            fi
        fi
    done

    [ "${found}" = false ] && warn "No common core services were detected through systemctl."
}

check_reboot_and_time() {
    print_title "Reboot And Time"

    if [ -f /var/run/reboot-required ]; then
        warn "System reports that a reboot is required."
    else
        ok "No reboot-required marker was found."
    fi

    if command_exists timedatectl; then
        timedatectl status 2>/dev/null | sed -n '1,6p'
    else
        printf "Current time: %s\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    fi
}

check_network() {
    print_title "Network"

    if [ "${CHECK_NETWORK}" = false ]; then
        print_info "Network checks skipped."
        return 0
    fi

    if command_exists ping; then
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            ok "IPv4 connectivity probe succeeded."
        else
            warn "IPv4 connectivity probe failed."
        fi
    else
        warn "ping is unavailable."
    fi

    if command_exists curl; then
        if curl -fsS --max-time 5 https://example.com >/dev/null 2>&1; then
            ok "HTTPS connectivity probe succeeded."
        else
            warn "HTTPS connectivity probe failed."
        fi
    else
        warn "curl is unavailable."
    fi
}

print_summary() {
    echo ""
    print_separator
    printf "Health check summary: %s critical, %s warning(s)\n" "${CRITICALS}" "${WARNINGS}"

    if [ "${CRITICALS}" -gt 0 ]; then
        print_error "Critical issues were found."
    elif [ "${WARNINGS}" -gt 0 ]; then
        print_warn "Warnings were found; review before production use."
    else
        print_success "No obvious health risks were detected."
    fi
}

main() {
    parse_args "$@"
    print_header "VPS Health Check"
    check_load
    check_memory
    check_disk
    check_services
    check_reboot_and_time
    check_network
    print_summary
}

main "$@"
