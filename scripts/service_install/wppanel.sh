#!/bin/bash
set -euo pipefail
#==============================================================================
# 脚本名称: wppanel.sh
# 脚本描述: WP Panel (WordPress面板) 安装脚本 - 基于官方安装脚本的安全包装
# 脚本路径: vps_scripts/scripts/service_install/wppanel.sh
# 作者: Jensfrank
# 使用方法: bash wppanel.sh [选项]
# 选项说明:
#   --skip-update    跳过系统更新
#   --help           显示帮助信息
# 更新日期: 2026-06-29
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 全局变量
SKIP_UPDATE=false
SCRIPT_VERSION="1.0.0"
WPPANEL_URL="https://raw.githubusercontent.com/naibabiji/wp-panel/main/install.sh"

# 加载公共库
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    # 内联回退
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[完成] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; return 1; }; }
fi

# 显示帮助
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash wppanel.sh [选项]"
    echo ""
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --skip-update    跳过系统更新步骤"
    echo "  --help           显示此帮助信息"
    echo ""
    echo -e "${GREEN}说明:${NC}"
    echo "  WP Panel 是一个轻量级 WordPress 管理面板。"
    echo "  本脚本会下载官方安装脚本并在验证语法后执行。"
    echo ""
    echo -e "${GREEN}项目地址:${NC}"
    echo "  https://github.com/naibabiji/wp-panel"
}

# 检查系统要求
check_system() {
    print_info "检查系统要求..."

    if ! check_root; then
        exit 1
    fi

    # 检测系统类型
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local os_id="${ID:-unknown}"
        print_info "检测到系统: ${os_id} ${VERSION_ID:-}"
    else
        print_error "无法检测系统类型"
        exit 1
    fi

    # 检查基础命令
    for cmd in wget curl; do
        if ! command -v "$cmd" &>/dev/null; then
            print_warn "未找到 $cmd，尝试安装..."
            if command -v apt-get &>/dev/null; then
                apt-get update -qq && apt-get install -y "$cmd" >/dev/null 2>&1
            elif command -v yum &>/dev/null; then
                yum install -y "$cmd" >/dev/null 2>&1
            fi
        fi
    done

    print_success "系统检查通过"
}

# 安装依赖
install_dependencies() {
    if [[ "$SKIP_UPDATE" == true ]]; then
        print_info "跳过系统更新"
        return 0
    fi

    print_info "更新软件包索引并安装依赖..."

    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y wget ca-certificates >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y wget ca-certificates >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install -y wget ca-certificates >/dev/null 2>&1
    else
        print_error "不支持的包管理器"
        exit 1
    fi

    print_success "依赖安装完成"
}

# 下载并执行安装脚本
install_wppanel() {
    print_info "下载 WP Panel 安装脚本..."

    local install_script
    install_script=$(mktemp "/tmp/wppanel_install.XXXXXX") || {
        print_error "创建临时文件失败"
        exit 1
    }

    # 下载安装脚本
    if ! wget -qO "$install_script" "$WPPANEL_URL"; then
        if ! curl -fsSL "$WPPANEL_URL" -o "$install_script"; then
            print_error "下载安装脚本失败"
            rm -f -- "$install_script"
            exit 1
        fi
    fi

    # 语法校验
    if ! bash -n "$install_script" 2>/dev/null; then
        print_error "安装脚本语法检查未通过，已拒绝执行"
        rm -f -- "$install_script"
        exit 1
    fi

    print_success "安装脚本下载成功，语法校验通过"
    print_info "开始执行 WP Panel 安装..."
    echo ""

    # 执行安装
    bash "$install_script"
    local exit_code=$?

    # 清理
    rm -f -- "$install_script"

    if [[ $exit_code -ne 0 ]]; then
        print_error "WP Panel 安装失败 (退出码: $exit_code)"
        exit $exit_code
    fi

    print_success "WP Panel 安装完成"
}

# 显示安装后信息
show_post_install_info() {
    local server_ip
    server_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null || hostname -I | awk '{print $1}')

    echo ""
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}WP Panel 安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo ""
    echo -e "${CYAN}访问信息:${NC}"
    echo "  请查看上方安装输出获取面板地址和凭据"
    echo ""
    echo -e "${CYAN}项目文档:${NC}"
    echo "  https://github.com/naibabiji/wp-panel"
    echo ""
    echo -e "${YELLOW}安全建议:${NC}"
    echo "  1. 修改默认端口和密码"
    echo "  2. 配置防火墙规则"
    echo "  3. 启用 SSL 证书"
    echo "  4. 定期备份数据"
    echo ""
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-update)
                SKIP_UPDATE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 执行安装流程
    check_system
    install_dependencies
    install_wppanel
    show_post_install_info
}

# 执行主函数
main "$@"
