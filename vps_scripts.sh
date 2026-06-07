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
        echo -e "${RED}[错误] 系统需要 curl 或 wget 才能下载脚本。${RESET}"
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
    echo -e "${BOLD}${WHITE}  VPS 综合管理脚本兼容入口${RESET}"
    echo -e "${CYAN}  版本:${RESET} ${VERSION}"
    echo -e "${CYAN}  项目:${RESET} ${PROJECT_URL}"
    echo -e "${DIM}当前为旧版兼容入口，将转交给持续维护的 vps.sh。${RESET}"
    draw_rule 74 "$CYAN"
    echo ""
}

pause_for_menu() {
    echo ""
    echo -e "${CYAN}[按任意键继续]${RESET}"
    read -n 1 -s -r
}

launch_local_vps() {
    local script_dir=""
    local local_launcher=""

    script_dir=$(cd "$(dirname "$0")" && pwd)
    local_launcher="${script_dir}/vps.sh"

    if [ ! -f "${local_launcher}" ]; then
        echo -e "${RED}[错误] 当前脚本目录中找不到 vps.sh。${RESET}"
        return 1
    fi

    exec bash "${local_launcher}"
}

launch_remote_vps() {
    local temp_file=""

    temp_file=$(mktemp "/tmp/vps_compat_remote.XXXXXX") || {
        echo -e "${RED}[错误] 创建临时文件失败。${RESET}"
        return 1
    }

    if ! download_file "${SCRIPT_URL}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[错误] 下载模块化启动器失败。${RESET}"
        echo -e "${DIM}URL:${RESET} ${SCRIPT_URL}"
        return 1
    fi

    exec bash "${temp_file}"
}

show_help() {
    printf '%s\n' \
        "用法：bash vps_scripts.sh [选项]" \
        "" \
        "选项：" \
        "  --local     直接运行同目录下的 vps.sh" \
        "  --remote    下载并运行最新版远程 vps.sh" \
        "  --help      显示此帮助信息"
}

main_menu() {
    while true; do
        print_header
        echo -e "${BOLD}${PURPLE}请选择启动方式${RESET}"
        draw_rule 74 "$PURPLE"
        echo -e "${YELLOW} 1${RESET}. 启动本地模块化脚本              ${DIM}使用同目录 vps.sh${RESET}"
        echo -e "${YELLOW} 2${RESET}. 启动最新远程脚本                ${DIM}下载最新版 vps.sh${RESET}"
        echo -e "${YELLOW} 3${RESET}. 显示快速启动命令                ${DIM}便于复制使用${RESET}"
        echo -e "${YELLOW} 0${RESET}. 退出"
        echo ""
        read -r -p "请选择 [0-3]: " choice

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
                echo -e "${GREEN}兼容启动器已退出。${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入。${RESET}"
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
            echo -e "${RED}[错误] 未知选项：$1${RESET}"
            show_help
            exit 1
            ;;
    esac
}

trap 'echo -e "\n${GREEN}用户已中断操作。${RESET}"; exit 0' INT TERM

main "$@"
