#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/clean_system.sh
# Purpose: Safer system cleanup workflow with analysis, dry-run, and guardrails.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
CONFIG_FILE="${PROJECT_ROOT}/config/vps_scripts.conf"

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="${LOG_DIR}/clean_system.log"
REPORT_DIR="${LOG_DIR}"

DRY_RUN=false
AUTO_CONFIRM=false
DEEP_CLEAN=false
ANALYZE_ONLY=false

OS_TYPE=""
PKG_MANAGER="unknown"
TOTAL_BYTES_FREED=0
INITIAL_DISK_USAGE=""
FINAL_DISK_USAGE=""

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
    [ -f "${CONFIG_FILE}" ] && source "${CONFIG_FILE}"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/clean_system.log"
    [ -n "${LOG_DIR:-}" ] && REPORT_DIR="${LOG_DIR}"
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
    get_os_release() { [ -f /etc/os-release ] && . /etc/os-release && echo "${ID}" || echo "unknown"; }
fi

ensure_runtime_dirs() {
    safe_mkdir "${LOG_DIR}"
    safe_mkdir "${REPORT_DIR}"
}

check_root_or_exit() {
    check_root || exit 1
}

log() {
    local level="$1"
    shift
    ensure_runtime_dirs
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "$*" >> "${LOG_FILE}"
}

show_help() {
    cat <<'EOF'
Usage: bash clean_system.sh [options]

Options:
  --auto, -a       Run the standard cleanup profile
  --deep, -d       Run the standard profile plus deep-clean modules
  --analyze        Print disk usage analysis only
  --dry-run        Show what would be cleaned without deleting anything
  --yes, -y        Skip confirmation prompts
  --help, -h       Show this help message
EOF
}

human_readable() {
    local size="${1:-0}"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while [ "${size}" -ge 1024 ] && [ "${unit}" -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done

    printf '%s%s' "${size}" "${units[${unit}]}"
}

get_dir_size() {
    local target="$1"

    if [ -e "${target}" ]; then
        du -sb "${target}" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
}

add_freed_bytes() {
    local before="${1:-0}"
    local after="${2:-0}"
    local freed=0

    if [ "${before}" -gt "${after}" ]; then
        freed=$((before - after))
        TOTAL_BYTES_FREED=$((TOTAL_BYTES_FREED + freed))
    fi

    echo "${freed}"
}

detect_system() {
    OS_TYPE=$(get_os_release)

    case "${OS_TYPE}" in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command_exists dnf; then
                PKG_MANAGER="dnf"
            else
                PKG_MANAGER="yum"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            ;;
        *)
            PKG_MANAGER="unknown"
            ;;
    esac

    if [ "${ANALYZE_ONLY}" = false ]; then
        log "INFO" "Detected OS ${OS_TYPE} with package manager ${PKG_MANAGER}"
    fi
}

confirm_if_needed() {
    local prompt="$1"

    if [ "${AUTO_CONFIRM}" = true ]; then
        return 0
    fi

    ask_yes_no "${prompt}"
}

safe_remove_glob_contents() {
    local dir="$1"
    local before=0
    local after=0

    case "${dir}" in
        /root/.cache|/home/*/.cache|/var/cache/man)
            ;;
        *)
            print_warn "Refusing to remove unexpected path: ${dir}"
            return 1
            ;;
    esac

    [ -d "${dir}" ] || return 0
    before=$(get_dir_size "${dir}")

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would clean ${dir}"
        after="${before}"
    else
        find "${dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>>"${LOG_FILE}" || true
        after=$(get_dir_size "${dir}")
    fi

    add_freed_bytes "${before}" "${after}" >/dev/null
}

safe_delete_old_files() {
    local dir="$1"
    local days="$2"
    local file_pattern="${3:-*}"
    local before=0
    local after=0

    case "${dir}" in
        /tmp|/var/tmp|/var/log)
            ;;
        *)
            print_warn "Refusing to delete old files from unexpected path: ${dir}"
            return 1
            ;;
    esac

    [ -d "${dir}" ] || return 0
    before=$(get_dir_size "${dir}")

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would delete files matching ${file_pattern} older than ${days} day(s) in ${dir}"
        after="${before}"
    else
        find "${dir}" -type f -name "${file_pattern}" -mtime +"${days}" -delete 2>>"${LOG_FILE}" || true
    fi

    after=$(get_dir_size "${dir}")
    add_freed_bytes "${before}" "${after}" >/dev/null
}

clean_package_cache() {
    local cache_path="/var/cache/${PKG_MANAGER}"
    local before=0
    local after=0
    local freed=0

    print_title "Package Cache"

    case "${PKG_MANAGER}" in
        apt)
            cache_path="/var/cache/apt"
            ;;
        yum|dnf|apk|pacman)
            ;;
        *)
            print_warn "Unsupported package manager for cache cleanup: ${PKG_MANAGER}"
            return 0
            ;;
    esac

    before=$(get_dir_size "${cache_path}")

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would clean package caches for ${PKG_MANAGER}"
        after="${before}"
    else
        case "${PKG_MANAGER}" in
            apt)
                run_logged_command "apt-get clean" apt-get clean || true
                run_logged_command "apt-get autoclean" apt-get autoclean || true
                ;;
            yum|dnf)
                run_logged_command "${PKG_MANAGER} clean all" "${PKG_MANAGER}" clean all || true
                ;;
            pacman)
                run_logged_command "pacman -Sc --noconfirm" pacman -Sc --noconfirm || true
                ;;
            apk)
                run_logged_command "apk cache clean" apk cache clean || true
                ;;
        esac
        after=$(get_dir_size "${cache_path}")
    fi

    freed=$(add_freed_bytes "${before}" "${after}")
    print_success "Freed $(human_readable "${freed}") from package cache."
}

clean_temp_files() {
    print_title "Temporary Files"
    safe_delete_old_files "/tmp" 7 "*" || true
    safe_delete_old_files "/var/tmp" 7 "*" || true
    [ "${DRY_RUN}" = false ] && find /tmp /var/tmp -type d -empty -delete 2>>"${LOG_FILE}" || true
    print_success "Temporary file cleanup finished."
}

clean_log_files() {
    local before=0
    local after=0
    local freed=0
    local large_log=""

    print_title "Logs"
    before=$(get_dir_size "/var/log")

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would purge old compressed logs and vacuum journal data."
        after="${before}"
    else
        safe_delete_old_files "/var/log" 30 "*.gz" || true
        safe_delete_old_files "/var/log" 30 "*.old" || true
        safe_delete_old_files "/var/log" 30 "*.1" || true

        while IFS= read -r large_log; do
            case "${large_log}" in
                *journal*|*lastlog|*wtmp|*btmp)
                    continue
                    ;;
            esac
            : > "${large_log}"
        done < <(find /var/log -type f -size +100M 2>/dev/null)

        if command_exists journalctl; then
            run_logged_command "journalctl --vacuum-time=7d" journalctl --vacuum-time=7d || true
            run_logged_command "journalctl --vacuum-size=100M" journalctl --vacuum-size=100M || true
        fi
        after=$(get_dir_size "/var/log")
    fi

    freed=$(add_freed_bytes "${before}" "${after}")
    print_success "Freed $(human_readable "${freed}") from log cleanup."
}

clean_orphans() {
    local -a pacman_orphans=()

    print_title "Orphaned Packages"

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would remove orphaned packages via ${PKG_MANAGER}"
        return 0
    fi

    case "${PKG_MANAGER}" in
        apt)
            run_logged_command "apt-get autoremove -y" apt-get autoremove -y || true
            ;;
        yum|dnf)
            run_logged_command "${PKG_MANAGER} autoremove -y" "${PKG_MANAGER}" autoremove -y || true
            ;;
        pacman)
            mapfile -t pacman_orphans < <(pacman -Qtdq 2>/dev/null || true)
            if [ "${#pacman_orphans[@]}" -gt 0 ]; then
                run_logged_command "pacman remove orphaned packages" pacman -Rns --noconfirm "${pacman_orphans[@]}" || true
            else
                print_info "No orphaned pacman packages were detected."
            fi
            ;;
        *)
            print_warn "Orphan cleanup is not supported on ${PKG_MANAGER}."
            ;;
    esac

    print_success "Orphan package cleanup finished."
}

clean_old_kernels() {
    local current_kernel=""
    local -a apt_images=()
    local -a apt_headers=()

    print_title "Old Kernels"

    if [ "${DEEP_CLEAN}" = false ]; then
        print_info "Deep clean is disabled; skipping old kernel cleanup."
        return 0
    fi

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would remove old kernel packages when supported."
        return 0
    fi

    current_kernel=$(uname -r)

    case "${PKG_MANAGER}" in
        apt)
            mapfile -t apt_images < <(dpkg -l | awk '/^ii  linux-image-[0-9]/{print $2}' | grep -v "${current_kernel}" || true)
            mapfile -t apt_headers < <(dpkg -l | awk '/^ii  linux-headers-[0-9]/{print $2}' | grep -v "${current_kernel}" || true)

            if [ "${#apt_images[@]}" -gt 0 ]; then
                run_logged_command "purge old kernel images" apt-get purge -y "${apt_images[@]}" || true
            fi
            if [ "${#apt_headers[@]}" -gt 0 ]; then
                run_logged_command "purge old kernel headers" apt-get purge -y "${apt_headers[@]}" || true
            fi
            ;;
        yum|dnf)
            if command_exists package-cleanup; then
                run_logged_command "remove old kernels" package-cleanup --oldkernels --count=2 -y || true
            else
                print_warn "package-cleanup is not available; skipping old kernel cleanup."
            fi
            ;;
        *)
            print_warn "Old kernel cleanup is not supported on ${PKG_MANAGER}."
            ;;
    esac

    print_success "Old kernel cleanup finished."
}

clean_docker() {
    print_title "Docker"

    if ! command_exists docker; then
        print_info "Docker is not installed."
        return 0
    fi

    if [ "${DRY_RUN}" = true ]; then
        print_info "DRY RUN: would prune stopped containers, dangling images, and unused volumes."
        if [ "${DEEP_CLEAN}" = true ]; then
            print_info "DRY RUN: would also run docker system prune -a."
        fi
        return 0
    fi

    run_logged_command "docker container prune -f" docker container prune -f || true
    run_logged_command "docker image prune -f" docker image prune -f || true
    run_logged_command "docker volume prune -f" docker volume prune -f || true

    if [ "${DEEP_CLEAN}" = true ]; then
        run_logged_command "docker system prune -a -f" docker system prune -a -f || true
    fi

    print_success "Docker cleanup finished."
}

clean_user_cache() {
    local home_dir=""

    print_title "User Cache"

    if [ "${DEEP_CLEAN}" = false ]; then
        print_info "Deep clean is disabled; skipping user cache cleanup."
        return 0
    fi

    for home_dir in /home/* /root; do
        [ -d "${home_dir}" ] || continue
        safe_remove_glob_contents "${home_dir}/.cache" || true
    done

    print_success "User cache cleanup finished."
}

analyze_disk() {
    print_header "Disk Analysis"
    printf "%bCurrent usage:%b %s\n" "${CYAN}" "${NC}" "$(get_disk_usage)"
    echo ""
    printf "%bTop 10 directories on /:%b\n" "${CYAN}" "${NC}"
    du -xh --max-depth=1 / 2>/dev/null | sort -rh | head -10
    echo ""
    printf "%bTop 10 files/directories overall:%b\n" "${CYAN}" "${NC}"
    du -ahx / 2>/dev/null | sort -rh | head -10
}

generate_report() {
    local report_file="${REPORT_DIR}/clean_report_$(date +%Y%m%d_%H%M%S).txt"

    FINAL_DISK_USAGE=$(get_disk_usage)
    ensure_runtime_dirs

    cat > "${report_file}" <<EOF
System Cleanup Report
=====================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')
Mode: $([ "${DEEP_CLEAN}" = true ] && echo "deep" || echo "standard")
Dry run: ${DRY_RUN}
Disk usage before: ${INITIAL_DISK_USAGE}
Disk usage after: ${FINAL_DISK_USAGE}
Estimated bytes freed: ${TOTAL_BYTES_FREED}
Estimated freed: $(human_readable "${TOTAL_BYTES_FREED}")
Log file: ${LOG_FILE}
EOF

    print_success "Report written to ${report_file}"
}

run_standard_profile() {
    clean_package_cache
    clean_temp_files
    clean_log_files
    clean_orphans
    clean_docker
}

run_deep_profile() {
    DEEP_CLEAN=true
    run_standard_profile
    clean_old_kernels
    clean_user_cache
}

custom_menu() {
    local selection=""

    clear 2>/dev/null || true
    print_header "Custom Cleanup"
    echo "1) Package cache"
    echo "2) Temporary files"
    echo "3) Logs"
    echo "4) Orphaned packages"
    echo "5) Docker"
    echo "6) Old kernels (deep clean)"
    echo "7) User cache (deep clean)"
    echo "0) Back"
    echo ""
    read -r -p "Enter one or more selections (for example: 1 3 5): " selection

    [ "${selection}" = "0" ] && return 0

    [[ " ${selection} " == *" 1 "* ]] && clean_package_cache
    [[ " ${selection} " == *" 2 "* ]] && clean_temp_files
    [[ " ${selection} " == *" 3 "* ]] && clean_log_files
    [[ " ${selection} " == *" 4 "* ]] && clean_orphans
    [[ " ${selection} " == *" 5 "* ]] && clean_docker
    [[ " ${selection} " == *" 6 "* ]] && { DEEP_CLEAN=true; clean_old_kernels; }
    [[ " ${selection} " == *" 7 "* ]] && { DEEP_CLEAN=true; clean_user_cache; }
}

interactive_menu() {
    local choice=""

    while true; do
        clear 2>/dev/null || true
        print_header "System Cleanup"
        printf "%bDisk usage:%b %s\n" "${CYAN}" "${NC}" "$(get_disk_usage)"
        echo ""
        echo "1) Quick cleanup (cache, temp files, logs)"
        echo "2) Standard cleanup (quick + orphans + Docker)"
        echo "3) Deep cleanup (standard + old kernels + user cache)"
        echo "4) Analyze disk usage only"
        echo "5) Custom cleanup"
        echo "0) Exit"
        echo ""
        read -r -p "Select an option [0-5]: " choice

        case "${choice}" in
            1)
                clean_package_cache
                clean_temp_files
                clean_log_files
                ;;
            2)
                run_standard_profile
                ;;
            3)
                if confirm_if_needed "Deep cleanup may remove old kernels and user cache. Continue?"; then
                    run_deep_profile
                else
                    print_info "Deep cleanup cancelled."
                    sleep 1
                    continue
                fi
                ;;
            4)
                analyze_disk
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                continue
                ;;
            5)
                custom_menu
                echo ""
                read -r -n 1 -s -p "Press any key to continue..."
                continue
                ;;
            0)
                exit 0
                ;;
            *)
                print_error "Invalid selection."
                sleep 1
                continue
                ;;
        esac

        if [ "${DRY_RUN}" = false ]; then
            generate_report
        fi

        echo ""
        read -r -n 1 -s -p "Press any key to continue..."
    done
}

run_logged_command() {
    local description="$1"
    shift
    log "INFO" "Running: ${description}"
    "$@" >> "${LOG_FILE}" 2>&1
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto|-a)
                AUTO_CONFIRM=true
                ;;
            --deep|-d)
                AUTO_CONFIRM=true
                DEEP_CLEAN=true
                ;;
            --analyze)
                ANALYZE_ONLY=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --yes|-y)
                AUTO_CONFIRM=true
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
    detect_system

    if [ "${ANALYZE_ONLY}" = true ]; then
        analyze_disk
        exit 0
    fi

    check_root_or_exit
    ensure_runtime_dirs
    INITIAL_DISK_USAGE=$(get_disk_usage)

    if [ "${DRY_RUN}" = true ]; then
        print_warn "DRY RUN mode is enabled. No files will be removed."
    fi

    if [ "${DEEP_CLEAN}" = true ] && [ "${AUTO_CONFIRM}" = true ]; then
        run_deep_profile
        [ "${DRY_RUN}" = false ] && generate_report
        exit 0
    fi

    if [ "${AUTO_CONFIRM}" = true ]; then
        run_standard_profile
        [ "${DRY_RUN}" = false ] && generate_report
        exit 0
    fi

    interactive_menu
}

main "$@"
