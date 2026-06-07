#!/bin/bash
# ==============================================================================
# Script: vps_scripts.sh
# Purpose: Legacy compatibility launcher that hands off to the maintained modular
#          launcher experience in vps.sh.
# ==============================================================================

set -u

VERSION="2026-06-07 compat-1.0"
SCRIPT_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh"
PROJECT_URL="https://github.com/everett7623/vps_scripts"

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'

DOWNLOAD_TOOL=""

detect_download_tool() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
    else
        echo -e "${RED}[ERROR] curl or wget is required.${RESET}"
        exit 1
    fi
}

download_file() {
    local url="${1}"
    local output="${2}"

    case "${DOWNLOAD_TOOL}" in
        curl)
            curl -fsSL --connect-timeout 10 --max-time 120 "${url}" -o "${output}"
            ;;
        wget)
            wget -q --timeout=120 -O "${output}" "${url}"
            ;;
        *)
            return 1
            ;;
    esac
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear
}

draw_rule() {
    local width="${1:-74}"
    local color="${2:-$CYAN}"
    printf '%b' "${color}"
    printf '%*s' "${width}" '' | tr ' ' '='
    printf '%b\n' "${RESET}"
}

print_header() {
    clear_screen
    draw_rule 74 "$CYAN"
    echo -e "${BOLD}${WHITE}  VPS Scripts compatibility launcher${RESET}"
    echo -e "${CYAN}  version:${RESET} ${VERSION}"
    echo -e "${CYAN}  repo:${RESET} ${PROJECT_URL}"
    echo -e "${DIM}Legacy entrypoint detected. The maintained experience now lives in vps.sh.${RESET}"
    draw_rule 74 "$CYAN"
    echo ""
}

pause_for_menu() {
    echo ""
    echo -e "${CYAN}[Press any key to continue]${RESET}"
    read -n 1 -s -r
}

launch_local_vps() {
    local script_dir=""
    local local_launcher=""

    script_dir=$(cd "$(dirname "$0")" && pwd)
    local_launcher="${script_dir}/vps.sh"

    if [ ! -f "${local_launcher}" ]; then
        echo -e "${RED}[ERROR] Local vps.sh not found next to this script.${RESET}"
        return 1
    fi

    exec bash "${local_launcher}"
}

launch_remote_vps() {
    local temp_file=""

    temp_file=$(mktemp "/tmp/vps_compat_remote.XXXXXX") || {
        echo -e "${RED}[ERROR] Failed to create a temporary file.${RESET}"
        return 1
    }

    if ! download_file "${SCRIPT_URL}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[ERROR] Failed to download the modular launcher.${RESET}"
        echo -e "${DIM}URL:${RESET} ${SCRIPT_URL}"
        return 1
    fi

    exec bash "${temp_file}"
}

show_help() {
    printf '%s\n' \
        "Usage: bash vps_scripts.sh [option]" \
        "" \
        "Options:" \
        "  --local     Launch sibling ./vps.sh directly" \
        "  --remote    Download the latest remote vps.sh and launch it" \
        "  --help      Show this help message"
}

main_menu() {
    while true; do
        print_header
        echo -e "${BOLD}${PURPLE}Choose a handoff mode${RESET}"
        draw_rule 74 "$PURPLE"
        echo -e "${YELLOW} 1${RESET}. Launch local modular experience    ${DIM}use the checked-out vps.sh${RESET}"
        echo -e "${YELLOW} 2${RESET}. Launch latest remote experience    ${DIM}download current vps.sh${RESET}"
        echo -e "${YELLOW} 3${RESET}. Show quick-start command           ${DIM}copy/paste bootstrap${RESET}"
        echo -e "${YELLOW} 0${RESET}. Exit"
        echo ""
        read -r -p "Select [0-3]: " choice

        case "${choice}" in
            1) launch_local_vps ;;
            2) launch_remote_vps ;;
            3)
                echo ""
                echo -e "${CYAN}bash <(curl -fsSL ${SCRIPT_URL})${RESET}"
                pause_for_menu
                ;;
            0)
                echo ""
                echo -e "${GREEN}Compatibility launcher closed.${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice.${RESET}"
                sleep 1
                ;;
        esac
    done
}

main() {
    detect_download_tool

    case "${1:-}" in
        --local)
            launch_local_vps
            ;;
        --remote)
            launch_remote_vps
            ;;
        --help|-h)
            show_help
            ;;
        "")
            main_menu
            ;;
        *)
            echo -e "${RED}[ERROR] Unknown option: $1${RESET}"
            show_help
            exit 1
            ;;
    esac
}

trap 'echo -e "\n${GREEN}Interrupted by user.${RESET}"; exit 0' INT TERM

main "$@"
