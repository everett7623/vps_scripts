#!/bin/bash
# ==============================================================================
# Script: lib/common_functions.sh
# Purpose: Shared helpers for VPS Scripts modules.
# ==============================================================================

export RED='\033[1;91m'
export GREEN='\033[1;92m'
export YELLOW='\033[1;93m'
export BLUE='\033[1;94m'
export PURPLE='\033[1;95m'
export CYAN='\033[1;96m'
export WHITE='\033[1;97m'
export NC='\033[0m'
export BOLD='\033[1m'

export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

print_msg() {
    local color="${1}"
    local message="${2}"
    echo -e "${color}${message}${NC}"
}

print_info() {
    [ "${CURRENT_LOG_LEVEL}" -le "${LOG_LEVEL_INFO}" ] && print_msg "${CYAN}" "[INFO] $1"
}

print_success() {
    [ "${CURRENT_LOG_LEVEL}" -le "${LOG_LEVEL_INFO}" ] && print_msg "${GREEN}" "[OK] $1"
}

print_warn() {
    [ "${CURRENT_LOG_LEVEL}" -le "${LOG_LEVEL_WARN}" ] && print_msg "${YELLOW}" "[WARN] $1"
}

print_error() {
    print_msg "${RED}" "[ERROR] $1"
}

print_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    local color="${3:-$BLUE}"
    echo -e "${color}$(printf '%*s' "$width" '' | tr ' ' "$char")${NC}"
}

print_header() {
    local title=" $1 "
    local width=80
    echo ""
    print_separator "=" "$width" "$CYAN"
    printf "%b%*s%s%b\n" "${BOLD}${WHITE}" $(( (width - ${#title}) / 2 )) "" "${title}" "${NC}"
    print_separator "=" "$width" "$CYAN"
    echo ""
}

print_title() {
    echo ""
    echo -e "${BOLD}${YELLOW}>> $1${NC}"
    print_separator "-" 80 "$BLUE"
}

show_progress() {
    local current="${1}"
    local total="${2}"
    local width="${3:-50}"
    local percent=0
    local filled=0
    local empty=0

    if [ "${total}" -le 0 ]; then
        total=1
    fi

    percent=$((current * 100 / total))
    filled=$((width * current / total))
    empty=$((width - filled))

    printf "\r${CYAN}[%s%s] %3d%%${NC}" \
        "$(printf '%*s' "$filled" '' | tr ' ' '=')" \
        "$(printf '%*s' "$empty" '')" \
        "${percent}"

    [ "${current}" -ge "${total}" ] && echo ""
}

wait_with_animation() {
    local message="${1}"
    local duration="${2:-3}"
    local spin='|/-\'
    local i=0
    local loops=0

    if [[ "${duration}" =~ ^[0-9]+$ ]] && [ "${duration}" -gt 1000 ] && kill -0 "${duration}" 2>/dev/null; then
        while kill -0 "${duration}" 2>/dev/null; do
            printf "\r${CYAN}%s %s${NC}" "${spin:i++%4:1}" "${message}"
            sleep 0.1
        done
    else
        loops=$((duration * 10))
        while [ "${loops}" -gt 0 ]; do
            printf "\r${CYAN}%s %s${NC}" "${spin:i++%4:1}" "${message}"
            sleep 0.1
            loops=$((loops - 1))
        done
    fi

    printf "\r${GREEN}OK %s${NC}\n" "${message}"
}

check_root() {
    if [[ ${EUID} -ne 0 ]]; then
        print_error "This script requires root privileges."
        print_info "Switch to root or run with sudo."
        return 1
    fi
    return 0
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

ensure_command() {
    local cmd="${1}"
    local package="${2:-$1}"

    if command_exists "${cmd}"; then
        return 0
    fi

    print_warn "Command '${cmd}' was not found. Attempting to install '${package}'."

    if command_exists apt-get; then
        apt-get update -qq >/dev/null 2>&1 || {
            print_error "apt-get update failed."
            return 1
        }
        apt-get install -y "${package}" >/dev/null 2>&1
    elif command_exists yum; then
        yum install -y "${package}" >/dev/null 2>&1
    elif command_exists dnf; then
        dnf install -y "${package}" >/dev/null 2>&1
    elif command_exists apk; then
        apk add "${package}" >/dev/null 2>&1
    elif command_exists pacman; then
        pacman -S --noconfirm "${package}" >/dev/null 2>&1
    else
        print_error "No supported package manager found. Install '${package}' manually."
        return 1
    fi

    if command_exists "${cmd}"; then
        print_success "Installed '${package}'."
        return 0
    fi

    print_error "Failed to install '${package}'."
    return 1
}

get_os_release() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID}"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

get_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${VERSION_ID}"
    else
        echo "unknown"
    fi
}

get_arch() {
    uname -m
}

get_cpu_cores() {
    nproc --all
}

get_total_memory() {
    free -m | awk '/^Mem:/ {print $2}'
}

get_public_ip() {
    local ip_version="${1:-4}"
    local timeout="${2:-5}"
    local ip=""

    command_exists curl || {
        echo "unavailable"
        return 1
    }

    if [ "${ip_version}" = "4" ]; then
        ip=$(curl -fsS -4 --max-time "${timeout}" ifconfig.me 2>/dev/null || \
             curl -fsS -4 --max-time "${timeout}" ip.sb 2>/dev/null || \
             curl -fsS -4 --max-time "${timeout}" icanhazip.com 2>/dev/null)
    else
        ip=$(curl -fsS -6 --max-time "${timeout}" ifconfig.me 2>/dev/null || \
             curl -fsS -6 --max-time "${timeout}" ip.sb 2>/dev/null || \
             curl -fsS -6 --max-time "${timeout}" icanhazip.com 2>/dev/null)
    fi

    echo "${ip:-unavailable}"
}

check_port() {
    local port="${1}"
    if command_exists ss; then
        ss -tuln | grep -q ":${port} "
    elif command_exists netstat; then
        netstat -tuln | grep -q ":${port} "
    else
        return 2
    fi
}

test_url() {
    local url="${1}"
    local timeout="${2:-5}"
    curl -fsSIL --max-time "${timeout}" "${url}" >/dev/null 2>&1
}

safe_mkdir() {
    local dir="${1}"
    [ -d "${dir}" ] || mkdir -p "${dir}"
}

backup_file() {
    local file="${1}"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"

    if [ -f "${file}" ]; then
        cp "${file}" "${file}.${backup_suffix}" && print_success "Backed up ${file} to ${file}.${backup_suffix}"
    fi
}

download_file() {
    local url="${1}"
    local output="${2}"
    local retries="${3:-3}"
    local timeout="${4:-30}"
    local i=1

    while [ "${i}" -le "${retries}" ]; do
        if curl -fsSL --max-time "${timeout}" "${url}" -o "${output}"; then
            print_success "Downloaded $(basename "${output}")"
            return 0
        fi
        print_warn "Download failed (${i}/${retries}): ${url}"
        sleep 2
        i=$((i + 1))
    done

    print_error "Download failed: ${url}"
    return 1
}

read_config() {
    local config_file="${1}"
    local key="${2}"
    local default="${3}"
    local value=""

    if [ ! -f "${config_file}" ]; then
        echo "${default}"
        return 0
    fi

    value=$(grep -m1 "^${key}=" "${config_file}" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    echo "${value:-$default}"
}

write_config() {
    local config_file="${1}"
    local key="${2}"
    local value="${3}"
    local config_dir=""
    local temp_file=""

    config_dir=$(dirname "${config_file}")
    safe_mkdir "${config_dir}"
    [ -f "${config_file}" ] || touch "${config_file}"

    temp_file=$(mktemp "/tmp/vps_config.XXXXXX") || {
        print_error "Failed to create temporary config file."
        return 1
    }

    if grep -q "^${key}=" "${config_file}"; then
        awk -v k="${key}" -v v="${value}" 'BEGIN { updated=0 } $0 ~ ("^" k "=") { print k "=" v; updated=1; next } { print } END { if (!updated) print k "=" v }' \
            "${config_file}" > "${temp_file}" && mv "${temp_file}" "${config_file}"
    else
        cat "${config_file}" > "${temp_file}"
        printf '%s=%s\n' "${key}" "${value}" >> "${temp_file}"
        mv "${temp_file}" "${config_file}"
    fi
}

ask_yes_no() {
    local question="${1}"
    local default="${2:-n}"
    local prompt="[y/N]"
    local answer=""

    [ "${default}" = "y" ] && prompt="[Y/n]"

    while true; do
        read -r -p "${question} ${prompt}: " answer
        answer=${answer:-$default}
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) print_warn "Please enter y or n." ;;
        esac
    done
}

select_option() {
    local prompt="${1}"
    shift
    local options=("$@")
    PS3="${prompt}: "
    select opt in "${options[@]}"; do
        if [ -n "${opt}" ]; then
            echo "${REPLY}"
            return 0
        fi
        print_warn "Invalid choice. Try again."
    done
}

is_valid_identifier() {
    [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

read_input() {
    local prompt="${1}"
    local default="${2:-}"
    local variable_name="${3:-}"
    local input=""

    if [ -n "${default}" ]; then
        read -r -p "${prompt} [${default}]: " input
        input=${input:-$default}
    else
        read -r -p "${prompt}: " input
    fi

    if [ -n "${variable_name}" ]; then
        if ! is_valid_identifier "${variable_name}"; then
            print_error "Invalid variable name: ${variable_name}"
            return 1
        fi
        printf -v "${variable_name}" '%s' "${input}"
    else
        printf -v REPLY '%s' "${input}"
    fi
}

check_service_status() {
    systemctl is-active --quiet "$1"
}

start_service() {
    systemctl start "$1" && print_success "Service $1 started." || print_error "Failed to start service $1."
}

stop_service() {
    systemctl stop "$1" && print_success "Service $1 stopped." || print_error "Failed to stop service $1."
}

restart_service() {
    systemctl restart "$1" && print_success "Service $1 restarted." || print_error "Failed to restart service $1."
}

cleanup_temp_files() {
    local temp_dir="${1:-/tmp/vps_scripts_temp}"

    case "${temp_dir}" in
        /tmp/*|/var/tmp/*)
            [ -d "${temp_dir}" ] && rm -rf -- "${temp_dir}"
            ;;
        *)
            print_warn "Skipping cleanup for unexpected temp path: ${temp_dir}"
            ;;
    esac
}

graceful_exit() {
    local exit_code="${1:-0}"
    local message="${2:-}"

    if [ -n "${message}" ]; then
        if [ "${exit_code}" -eq 0 ]; then
            print_success "${message}"
        else
            print_error "${message}"
        fi
    fi

    cleanup_temp_files
    exit "${exit_code}"
}

trap 'graceful_exit 1 "Script interrupted."' INT TERM

export -f print_msg print_info print_success print_warn print_error
export -f print_separator print_header print_title
export -f show_progress wait_with_animation
export -f check_root command_exists ensure_command
export -f get_os_release get_os_version get_arch get_cpu_cores get_total_memory
export -f get_public_ip check_port test_url
export -f safe_mkdir backup_file download_file
export -f read_config write_config
export -f ask_yes_no select_option read_input is_valid_identifier
export -f check_service_status start_service stop_service restart_service
export -f cleanup_temp_files graceful_exit
