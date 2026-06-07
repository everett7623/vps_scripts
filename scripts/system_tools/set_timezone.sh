#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/set_timezone.sh
# Purpose: Structured timezone management with backup, validation, and NTP setup.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
CONFIG_FILE="${PROJECT_ROOT}/config/vps_scripts.conf"

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="${LOG_DIR}/set_timezone.log"
BACKUP_DIR="/var/backups/timezone_change"

OS_TYPE="unknown"
OS_VERSION="unknown"
CURRENT_TIMEZONE=""
NEW_TIMEZONE=""
USE_TIMEDATECTL=false
NTP_ENABLED=false
SYNC_TIME=true
AUTO_CONFIRM=false
SEARCH_KEYWORD=""
SHOW_LIST=false
SHOW_COMMON=false
SHOW_INFO=false
CONFIGURE_NTP_ONLY=false
SYNC_ONLY=false

NTP_SERVERS=(
    "ntp.aliyun.com"
    "cn.pool.ntp.org"
    "time.cloudflare.com"
    "time.google.com"
    "pool.ntp.org"
)

COMMON_TIMEZONE_ROWS=(
    "1|Asia/Shanghai|Shanghai"
    "2|Asia/Hong_Kong|Hong Kong"
    "3|Asia/Taipei|Taipei"
    "4|Asia/Tokyo|Tokyo"
    "5|Asia/Seoul|Seoul"
    "6|Asia/Singapore|Singapore"
    "7|Asia/Bangkok|Bangkok"
    "8|Asia/Kolkata|Kolkata"
    "9|Asia/Dubai|Dubai"
    "10|Asia/Ho_Chi_Minh|Ho Chi Minh City"
    "11|Asia/Jakarta|Jakarta"
    "12|Asia/Manila|Manila"
    "13|Asia/Riyadh|Riyadh"
    "14|Asia/Tehran|Tehran"
    "15|Asia/Jerusalem|Jerusalem"
    "16|Asia/Kuala_Lumpur|Kuala Lumpur"
    "17|Asia/Yangon|Yangon"
    "18|Asia/Tashkent|Tashkent"
    "20|Europe/London|London"
    "21|Europe/Paris|Paris"
    "22|Europe/Berlin|Berlin"
    "23|Europe/Moscow|Moscow"
    "24|Europe/Amsterdam|Amsterdam"
    "25|Europe/Rome|Rome"
    "26|Europe/Madrid|Madrid"
    "27|Europe/Zurich|Zurich"
    "28|Europe/Kyiv|Kyiv"
    "29|Europe/Istanbul|Istanbul"
    "30|Europe/Stockholm|Stockholm"
    "31|Europe/Warsaw|Warsaw"
    "32|Europe/Vienna|Vienna"
    "33|Europe/Athens|Athens"
    "34|Europe/Brussels|Brussels"
    "40|America/New_York|New York"
    "41|America/Chicago|Chicago"
    "42|America/Los_Angeles|Los Angeles"
    "43|America/Toronto|Toronto"
    "44|America/Vancouver|Vancouver"
    "45|America/Sao_Paulo|Sao Paulo"
    "46|America/Mexico_City|Mexico City"
    "47|America/Argentina/Buenos_Aires|Buenos Aires"
    "48|America/Santiago|Santiago"
    "50|Australia/Sydney|Sydney"
    "60|Africa/Johannesburg|Johannesburg"
    "0|UTC|UTC"
)

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
    [ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/set_timezone.log"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[INFO] $1"; }
    print_success() { print_msg "${GREEN}" "[OK] $1"; }
    print_warn() { print_msg "${YELLOW}" "[WARN] $1"; }
    print_error() { print_msg "${RED}" "[ERROR] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 27 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    print_title() { echo ""; printf "%b>> %s%b\n" "${BOLD}${YELLOW}" "$1" "${NC}"; print_separator "-" 80; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    safe_mkdir() { [ -d "$1" ] || mkdir -p "$1"; }
    check_root() { [[ ${EUID} -ne 0 ]] && { print_error "This script requires root privileges."; exit 1; }; }
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

check_root_or_exit() {
    check_root || exit 1
}

show_help() {
    cat <<'EOF'
Usage: bash set_timezone.sh [options] [timezone-or-alias]

Options:
  --list              List available timezones
  --common            Show the curated common timezone table
  --search <keyword>  Search available timezones
  --ntp               Configure NTP and exit
  --sync              Force a time sync and exit
  --info              Show current timezone and clock info
  --yes, -y           Skip confirmation prompts
  --help, -h          Show this help message

Common aliases:
  cn, china, shanghai
  hk, hongkong
  tw, taiwan, taipei
  jp, japan, tokyo
  sg, singapore
  kr, korea, seoul
  us, usa, ny, newyork
  la, losangeles
  uk, london
  de, berlin
  fr, paris
  utc, gmt
EOF
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-unknown}"
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null || echo "unknown")
    fi

    if command_exists timedatectl; then
        USE_TIMEDATECTL=true
    fi
}

get_current_timezone() {
    if [ "${USE_TIMEDATECTL}" = true ]; then
        CURRENT_TIMEZONE=$(timedatectl show -p Timezone --value 2>/dev/null || true)
    fi

    if [ -z "${CURRENT_TIMEZONE}" ] && [ -f /etc/timezone ]; then
        CURRENT_TIMEZONE=$(cat /etc/timezone)
    fi

    if [ -z "${CURRENT_TIMEZONE}" ] && [ -L /etc/localtime ]; then
        CURRENT_TIMEZONE=$(readlink /etc/localtime | sed 's|.*zoneinfo/||')
    fi

    CURRENT_TIMEZONE=${CURRENT_TIMEZONE:-unknown}
}

show_time_info() {
    print_header "Timezone Information"
    printf "%bCurrent timezone:%b %s\n" "${CYAN}" "${NC}" "${CURRENT_TIMEZONE}"
    printf "%bLocal time:%b       %s\n" "${CYAN}" "${NC}" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf "%bUTC time:%b         %s\n" "${CYAN}" "${NC}" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf "%bUTC offset:%b       %s\n" "${CYAN}" "${NC}" "$(date '+%z')"

    if [ "${USE_TIMEDATECTL}" = true ]; then
        printf "%bNTP sync:%b         %s\n" "${CYAN}" "${NC}" "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo "unknown")"
    fi

    if command_exists hwclock; then
        printf "%bHardware clock:%b   %s\n" "${CYAN}" "${NC}" "$(hwclock -r 2>/dev/null || echo "unavailable")"
    fi
}

get_all_timezones() {
    if [ -d /usr/share/zoneinfo ]; then
        find /usr/share/zoneinfo -type f \
            ! -path '*/posix/*' \
            ! -path '*/right/*' \
            ! -path '*/Etc/GMT*' \
            -printf '%P\n' 2>/dev/null | sort
    fi
}

show_common_timezones() {
    print_header "Common Timezones"
    printf "%-6s %-32s %s\n" "Code" "Timezone" "City"
    print_separator "-" 80

    local row=""
    local code=""
    local timezone=""
    local city=""
    for row in "${COMMON_TIMEZONE_ROWS[@]}"; do
        IFS='|' read -r code timezone city <<<"${row}"
        printf "%-6s %-32s %s\n" "${code}" "${timezone}" "${city}"
    done
}

search_timezones() {
    local keyword="$1"
    [ -n "${keyword}" ] || return 0
    get_all_timezones | grep -i -- "${keyword}" | head -20
}

get_timezone_by_number() {
    local number="$1"
    local row=""
    local code=""
    local timezone=""
    local city=""

    for row in "${COMMON_TIMEZONE_ROWS[@]}"; do
        IFS='|' read -r code timezone city <<<"${row}"
        if [ "${code}" = "${number}" ]; then
            echo "${timezone}"
            return 0
        fi
    done
    return 1
}

validate_timezone() {
    local timezone="$1"
    if [ -f "/usr/share/zoneinfo/${timezone}" ]; then
        return 0
    fi
    print_error "Invalid timezone: ${timezone}"
    return 1
}

quick_set_timezone() {
    case "${1,,}" in
        cn|china|shanghai) NEW_TIMEZONE="Asia/Shanghai" ;;
        hk|hongkong) NEW_TIMEZONE="Asia/Hong_Kong" ;;
        tw|taiwan|taipei) NEW_TIMEZONE="Asia/Taipei" ;;
        jp|japan|tokyo) NEW_TIMEZONE="Asia/Tokyo" ;;
        sg|singapore) NEW_TIMEZONE="Asia/Singapore" ;;
        kr|korea|seoul) NEW_TIMEZONE="Asia/Seoul" ;;
        us|usa|newyork|ny) NEW_TIMEZONE="America/New_York" ;;
        la|losangeles) NEW_TIMEZONE="America/Los_Angeles" ;;
        uk|london) NEW_TIMEZONE="Europe/London" ;;
        de|berlin) NEW_TIMEZONE="Europe/Berlin" ;;
        fr|paris) NEW_TIMEZONE="Europe/Paris" ;;
        utc|gmt) NEW_TIMEZONE="UTC" ;;
        *) return 1 ;;
    esac
    return 0
}

backup_configs() {
    local backup_path="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
    local file=""
    local files_to_backup=(
        "/etc/timezone"
        "/etc/localtime"
        "/etc/sysconfig/clock"
        "/etc/ntp.conf"
        "/etc/chrony.conf"
        "/etc/systemd/timesyncd.conf"
    )

    ensure_runtime_dirs
    mkdir -p "${backup_path}"

    for file in "${files_to_backup[@]}"; do
        if [ -e "${file}" ]; then
            cp -a "${file}" "${backup_path}/$(basename "${file}")" 2>/dev/null || true
        fi
    done

    printf '%s\n' "${CURRENT_TIMEZONE}" > "${backup_path}/old_timezone.txt"
    log "BACKUP" "Saved timezone backup to ${backup_path}"
    echo "${backup_path}"
}

write_file_atomically() {
    local target="$1"
    local temp_file="$2"
    cat "${temp_file}" > "${target}"
    rm -f "${temp_file}"
}

set_timezone_value() {
    local timezone="$1"
    local temp_file=""

    print_title "Apply Timezone"

    if [ "${USE_TIMEDATECTL}" = true ]; then
        log "INFO" "Using timedatectl to set timezone ${timezone}"
        timedatectl set-timezone "${timezone}" >> "${LOG_FILE}" 2>&1
    else
        log "INFO" "Using traditional timezone configuration for ${timezone}"
        ln -sfn "/usr/share/zoneinfo/${timezone}" /etc/localtime

        if [ -f /etc/timezone ] || [ "${OS_TYPE}" = "ubuntu" ] || [ "${OS_TYPE}" = "debian" ]; then
            printf '%s\n' "${timezone}" > /etc/timezone
        fi

        if [ -f /etc/sysconfig/clock ] || [[ "${OS_TYPE}" =~ ^(centos|rhel|fedora|rocky|almalinux)$ ]]; then
            temp_file=$(mktemp "/tmp/vps_clock.XXXXXX") || return 1
            cat > "${temp_file}" <<EOF
ZONE="${timezone}"
UTC=true
ARC=false
EOF
            write_file_atomically "/etc/sysconfig/clock" "${temp_file}"
        fi
    fi

    if command_exists hwclock; then
        hwclock --systohc >> "${LOG_FILE}" 2>&1 || true
    fi
}

configure_ntp() {
    local temp_file=""
    local server=""

    print_title "Configure NTP"

    if [ "${USE_TIMEDATECTL}" = true ] && [ -f /etc/systemd/timesyncd.conf ]; then
        temp_file=$(mktemp "/tmp/vps_timesyncd.XXXXXX") || return 1
        cat > "${temp_file}" <<EOF
[Time]
NTP=${NTP_SERVERS[*]}
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=2048
EOF
        write_file_atomically "/etc/systemd/timesyncd.conf" "${temp_file}"
        systemctl restart systemd-timesyncd >> "${LOG_FILE}" 2>&1 || true
        systemctl enable systemd-timesyncd >> "${LOG_FILE}" 2>&1 || true
        timedatectl set-ntp true >> "${LOG_FILE}" 2>&1 || true
        print_success "Configured systemd-timesyncd."
        return 0
    fi

    if command_exists chronyd && [ -f /etc/chrony.conf ]; then
        backup_file "/etc/chrony.conf" "bak_$(date +%Y%m%d_%H%M%S)"
        sed -i '/^server /d;/^pool /d' /etc/chrony.conf
        for server in "${NTP_SERVERS[@]}"; do
            printf 'server %s iburst\n' "${server}" >> /etc/chrony.conf
        done
        systemctl restart chronyd >> "${LOG_FILE}" 2>&1 || true
        systemctl enable chronyd >> "${LOG_FILE}" 2>&1 || true
        print_success "Configured chrony."
        return 0
    fi

    if command_exists ntpd && [ -f /etc/ntp.conf ]; then
        backup_file "/etc/ntp.conf" "bak_$(date +%Y%m%d_%H%M%S)"
        sed -i '/^server /d;/^pool /d' /etc/ntp.conf
        for server in "${NTP_SERVERS[@]}"; do
            printf 'server %s iburst\n' "${server}" >> /etc/ntp.conf
        done
        systemctl restart ntpd >> "${LOG_FILE}" 2>&1 || true
        systemctl enable ntpd >> "${LOG_FILE}" 2>&1 || true
        print_success "Configured ntpd."
        return 0
    fi

    if [ "${USE_TIMEDATECTL}" = true ]; then
        timedatectl set-ntp true >> "${LOG_FILE}" 2>&1 || true
        print_success "Enabled timedatectl NTP support."
        return 0
    fi

    print_warn "No supported NTP service was detected."
    return 0
}

sync_time_manual() {
    local server=""

    if [ "${SYNC_TIME}" = false ]; then
        return 0
    fi

    print_title "Time Sync"

    if command_exists ntpdate; then
        for server in "${NTP_SERVERS[@]}"; do
            if ntpdate -u "${server}" >> "${LOG_FILE}" 2>&1; then
                print_success "Synchronized time from ${server}."
                return 0
            fi
        done
    elif command_exists chronyc; then
        chronyc makestep >> "${LOG_FILE}" 2>&1 || true
        print_success "Requested chrony time step."
        return 0
    elif [ "${USE_TIMEDATECTL}" = true ]; then
        timedatectl set-ntp false >> "${LOG_FILE}" 2>&1 || true
        timedatectl set-ntp true >> "${LOG_FILE}" 2>&1 || true
        print_success "Requested timedatectl NTP resync."
        return 0
    fi

    print_warn "Automatic time sync is unavailable on this host."
    return 0
}

verify_timezone() {
    local expected_timezone="$1"
    local actual_timezone=""

    get_current_timezone
    actual_timezone="${CURRENT_TIMEZONE}"

    if [ "${actual_timezone}" = "${expected_timezone}" ]; then
        print_success "Timezone verification passed."
        return 0
    fi

    print_error "Timezone verification failed. Expected ${expected_timezone}, got ${actual_timezone}."
    return 1
}

generate_report() {
    local backup_path="$1"
    local report_file="${LOG_DIR}/timezone_report_$(date +%Y%m%d_%H%M%S).txt"

    ensure_runtime_dirs
    cat > "${report_file}" <<EOF
Timezone Change Report
======================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
System: ${OS_TYPE} ${OS_VERSION}
Old timezone: ${CURRENT_TIMEZONE}
New timezone: ${NEW_TIMEZONE}
NTP enabled: ${NTP_ENABLED}
Backup path: ${backup_path}
Log file: ${LOG_FILE}
Current local time: $(date '+%Y-%m-%d %H:%M:%S %Z')
Current UTC time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
EOF

    print_success "Report written to ${report_file}"
}

confirm_change() {
    if [ "${AUTO_CONFIRM}" = true ]; then
        return 0
    fi

    echo ""
    printf "%bCurrent timezone:%b %s\n" "${CYAN}" "${NC}" "${CURRENT_TIMEZONE}"
    printf "%bNew timezone:%b     %s\n" "${CYAN}" "${NC}" "${NEW_TIMEZONE}"
    ask_yes_no "Apply this timezone change?"
}

update_ntp_choice_from_reply() {
    case "${REPLY,,}" in
        n|no)
            NTP_ENABLED=false
            ;;
        *)
            NTP_ENABLED=true
            ;;
    esac
}

apply_timezone_flow() {
    local backup_path=""

    validate_timezone "${NEW_TIMEZONE}" || return 1

    if [ "${NEW_TIMEZONE}" = "${CURRENT_TIMEZONE}" ]; then
        print_warn "Timezone is already set to ${NEW_TIMEZONE}."
        return 0
    fi

    confirm_change || {
        print_info "Timezone change cancelled."
        return 0
    }

    backup_path=$(backup_configs)
    set_timezone_value "${NEW_TIMEZONE}" || return 1

    if [ "${NTP_ENABLED}" = true ]; then
        configure_ntp || return 1
    fi

    sync_time_manual || true

    if verify_timezone "${NEW_TIMEZONE}"; then
        generate_report "${backup_path}"
        show_time_info
        print_success "Timezone updated successfully."
        return 0
    fi

    print_warn "Timezone change finished with verification warnings. Review ${LOG_FILE}."
    return 1
}

interactive_menu() {
    local choice=""
    local selection=""

    while true; do
        clear 2>/dev/null || true
        show_time_info
        echo ""
        echo "1) Choose from common timezones"
        echo "2) Enter timezone manually"
        echo "3) Search timezones"
        echo "4) Configure NTP only"
        echo "5) Sync time now"
        echo "0) Exit"
        echo ""
        read -r -p "Select an option [0-5]: " choice

        case "${choice}" in
            1)
                show_common_timezones
                echo ""
                read_input "Enter a timezone code or full timezone name"
                selection="${REPLY}"
                if [[ "${selection}" =~ ^[0-9]+$ ]] && get_timezone_by_number "${selection}" >/dev/null 2>&1; then
                    NEW_TIMEZONE=$(get_timezone_by_number "${selection}")
                else
                    NEW_TIMEZONE="${selection}"
                fi
                read_input "Configure NTP as well?" "y"
                update_ntp_choice_from_reply
                apply_timezone_flow
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            2)
                read_input "Enter timezone name (for example: Asia/Shanghai)"
                NEW_TIMEZONE="${REPLY}"
                read_input "Configure NTP as well?" "y"
                update_ntp_choice_from_reply
                apply_timezone_flow
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            3)
                read_input "Enter a search keyword"
                selection="${REPLY}"
                echo ""
                search_timezones "${selection}"
                echo ""
                read_input "Enter the full timezone name"
                NEW_TIMEZONE="${REPLY}"
                read_input "Configure NTP as well?" "y"
                update_ntp_choice_from_reply
                apply_timezone_flow
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            4)
                check_root_or_exit
                ensure_runtime_dirs
                configure_ntp
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            5)
                check_root_or_exit
                ensure_runtime_dirs
                sync_time_manual
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                ;;
            0)
                exit 0
                ;;
            *)
                print_error "Invalid selection."
                sleep 1
                ;;
        esac
    done
}

parse_args() {
    TIMEZONE_ARG=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --list)
                SHOW_LIST=true
                ;;
            --common)
                SHOW_COMMON=true
                ;;
            --search)
                shift
                [ $# -gt 0 ] || { print_error "Missing value for --search."; exit 1; }
                SEARCH_KEYWORD="$1"
                ;;
            --ntp)
                CONFIGURE_NTP_ONLY=true
                NTP_ENABLED=true
                ;;
            --sync)
                SYNC_ONLY=true
                ;;
            --info)
                SHOW_INFO=true
                ;;
            --yes|-y)
                AUTO_CONFIRM=true
                NTP_ENABLED=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -n "${TIMEZONE_ARG}" ]; then
                    print_error "Only one timezone argument is supported."
                    exit 1
                fi
                TIMEZONE_ARG="$1"
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    detect_os
    get_current_timezone

    if [ "${SHOW_INFO}" = true ]; then
        show_time_info
        exit 0
    fi

    if [ "${SHOW_LIST}" = true ]; then
        get_all_timezones
        exit 0
    fi

    if [ "${SHOW_COMMON}" = true ]; then
        show_common_timezones
        exit 0
    fi

    if [ -n "${SEARCH_KEYWORD}" ]; then
        search_timezones "${SEARCH_KEYWORD}"
        exit 0
    fi

    if [ "${CONFIGURE_NTP_ONLY}" = true ]; then
        check_root_or_exit
        ensure_runtime_dirs
        configure_ntp
        exit 0
    fi

    if [ "${SYNC_ONLY}" = true ]; then
        check_root_or_exit
        ensure_runtime_dirs
        sync_time_manual
        exit 0
    fi

    if [ -n "${TIMEZONE_ARG}" ]; then
        if ! quick_set_timezone "${TIMEZONE_ARG}"; then
            NEW_TIMEZONE="${TIMEZONE_ARG}"
        fi
        NTP_ENABLED=true
        check_root_or_exit
        ensure_runtime_dirs
        apply_timezone_flow
        exit $?
    fi

    check_root_or_exit
    ensure_runtime_dirs
    interactive_menu
}

main "$@"
