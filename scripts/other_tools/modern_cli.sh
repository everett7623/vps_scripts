#!/bin/bash
# ==============================================================================
# Script: scripts/other_tools/modern_cli.sh
# Purpose: Install a curated modern CLI toolkit from distribution repositories.
# ==============================================================================

set -euo pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "${SCRIPT_PATH}")
PROJECT_ROOT=$(dirname "$(dirname "${SCRIPT_DIR}")")
LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[完成] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() {
        if [ "$(id -u)" -ne 0 ]; then
            print_error "安装操作需要 root 权限。"
            exit 1
        fi
    }
    get_os_release() {
        if [ -f /etc/os-release ]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            printf '%s\n' "${ID:-unknown}"
        else
            printf 'unknown\n'
        fi
    }
fi

TOOL_NAMES=(
    "btop"
    "ripgrep"
    "fd"
    "bat"
    "fzf"
    "jq"
    "ncdu"
    "restic"
)

TOOL_COMMANDS=(
    "btop"
    "rg"
    "fd:fdfind"
    "bat:batcat"
    "fzf"
    "jq"
    "ncdu"
    "restic"
)

TOOL_DESCRIPTIONS=(
    "资源与进程监控"
    "快速文本搜索"
    "友好的文件查找"
    "带语法高亮的文件查看"
    "交互式模糊筛选"
    "JSON 处理"
    "磁盘空间分析"
    "加密增量备份"
)

APT_PACKAGES=(btop ripgrep fd-find bat fzf jq ncdu restic)
RPM_PACKAGES=(btop ripgrep fd-find bat fzf jq ncdu restic)
APK_PACKAGES=(btop ripgrep fd bat fzf jq ncdu restic)

PKG_MANAGER=""
OS_TYPE=""
declare -a UPDATE_CMD=()
declare -a INSTALL_CMD=()
declare -a PACKAGES=()

detect_package_manager() {
    OS_TYPE=$(get_os_release)
    case "${OS_TYPE}" in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            UPDATE_CMD=(apt-get update -qq)
            INSTALL_CMD=(apt-get install -y -qq)
            PACKAGES=("${APT_PACKAGES[@]}")
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                UPDATE_CMD=(dnf makecache -q)
                INSTALL_CMD=(dnf install -y -q)
            else
                PKG_MANAGER="yum"
                UPDATE_CMD=(yum makecache -q)
                INSTALL_CMD=(yum install -y -q)
            fi
            PACKAGES=("${RPM_PACKAGES[@]}")
            ;;
        alpine)
            PKG_MANAGER="apk"
            UPDATE_CMD=(apk update)
            INSTALL_CMD=(apk add)
            PACKAGES=("${APK_PACKAGES[@]}")
            ;;
        *)
            print_error "不支持的操作系统：${OS_TYPE}"
            return 1
            ;;
    esac
}

find_tool_command() {
    local index="$1"
    local command_name=""
    local command_names=()

    IFS=':' read -r -a command_names <<< "${TOOL_COMMANDS[$index]}"
    for command_name in "${command_names[@]}"; do
        if command -v "${command_name}" >/dev/null 2>&1; then
            command -v "${command_name}"
            return 0
        fi
    done
    return 1
}

print_tool_status() {
    local index=0
    local command_path=""

    print_header "现代 CLI 工具包"
    printf '%-12s %-10s %s\n' "工具" "状态" "用途"
    printf '%-12s %-10s %s\n' "------------" "----------" "------------------------"
    for index in "${!TOOL_NAMES[@]}"; do
        command_path=$(find_tool_command "${index}" || true)
        if [ -n "${command_path}" ]; then
            printf '%-12s %-10s %s (%s)\n' \
                "${TOOL_NAMES[$index]}" "已安装" "${TOOL_DESCRIPTIONS[$index]}" "${command_path}"
        else
            printf '%-12s %-10s %s\n' \
                "${TOOL_NAMES[$index]}" "未安装" "${TOOL_DESCRIPTIONS[$index]}"
        fi
    done

    if [ "${PKG_MANAGER}" = "apt" ]; then
        echo ""
        print_info "Debian/Ubuntu 中 fd、bat 的命令名可能是 fdfind、batcat。"
    fi
}

refresh_package_metadata() {
    print_info "正在刷新 ${PKG_MANAGER} 软件包元数据..."
    if "${UPDATE_CMD[@]}"; then
        print_success "软件包元数据刷新完成。"
    else
        print_warn "软件包元数据刷新失败，将尝试使用现有缓存。"
    fi
}

install_toolkit() {
    local index=0
    local package=""
    local installed=0
    local skipped=0
    local failed=0

    check_root
    refresh_package_metadata

    for index in "${!TOOL_NAMES[@]}"; do
        package="${PACKAGES[$index]}"
        if find_tool_command "${index}" >/dev/null 2>&1; then
            print_info "跳过已安装工具：${TOOL_NAMES[$index]}"
            skipped=$((skipped + 1))
            continue
        fi

        print_info "正在安装 ${TOOL_NAMES[$index]}（软件包：${package}）..."
        if env DEBIAN_FRONTEND=noninteractive "${INSTALL_CMD[@]}" "${package}" \
            && find_tool_command "${index}" >/dev/null 2>&1; then
            print_success "${TOOL_NAMES[$index]} 安装完成。"
            installed=$((installed + 1))
        else
            print_warn "${TOOL_NAMES[$index]} 安装失败或当前软件源不提供 ${package}。"
            failed=$((failed + 1))
        fi
    done

    echo ""
    print_info "结果：新安装 ${installed}，已存在 ${skipped}，失败 ${failed}。"
    if [ "${failed}" -gt 0 ]; then
        print_warn "旧版发行版可能缺少部分软件包；脚本未自动添加第三方软件源。"
        return 1
    fi
    print_success "现代 CLI 工具包已就绪。"
}

confirm_install() {
    local answer=""

    echo ""
    print_warn "安装会刷新系统软件包元数据，并从当前发行版软件源安装缺失工具。"
    read -r -p "确认继续？[y/N]: " answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

interactive_menu() {
    local choice=""

    while true; do
        print_tool_status
        echo ""
        echo "1. 刷新状态"
        echo "2. 安装缺失工具"
        echo "0. 退出"
        echo ""
        read -r -p "请选择 [0-2]: " choice

        case "${choice}" in
            1)
                ;;
            2)
                if confirm_install; then
                    install_toolkit || true
                else
                    print_warn "已取消安装。"
                fi
                ;;
            0)
                return 0
                ;;
            *)
                print_warn "无效选项。"
                ;;
        esac
        echo ""
        read -r -p "按回车键继续..." _
    done
}

show_help() {
    cat <<'EOF'
用法：bash modern_cli.sh [选项]

选项：
  --status    仅显示工具安装状态，不修改系统
  --install   非交互安装缺失工具
  --help      显示帮助

工具来源仅限当前 Linux 发行版已配置的软件包仓库。
EOF
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            return 0
            ;;
    esac

    detect_package_manager

    case "${1:-}" in
        --status)
            print_tool_status
            ;;
        --install)
            install_toolkit
            ;;
        "")
            interactive_menu
            ;;
        *)
            print_error "未知参数：$1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
