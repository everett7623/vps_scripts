#!/bin/bash

# VPS管理脚本 - 优化版本，兼容CentOS
# 此脚本仅负责调用其他脚本，不修改被调用脚本内容

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统类型
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | cut -d ' ' -f 1)
        if [[ "$OS" == "CentOS" ]]; then
            VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
            if [ -z "$VER" ]; then
                VER=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
            fi
        fi
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    # 标准化操作系统名称
    case "$OS" in
        "Ubuntu")
            OS="Ubuntu"
            ;;
        "Debian GNU/Linux"|"Debian")
            OS="Debian"
            ;;
        "CentOS Linux"|"CentOS")
            OS="CentOS"
            ;;
        *)
            log_warn "不支持的操作系统: $OS"
            ;;
    esac
    
    echo "$OS $VER"
}

# 安装依赖函数 - 根据系统类型选择包管理器
install_dependencies() {
    local deps=("$@")
    local cmd=""
    
    log_info "正在安装依赖: ${deps[*]}"
    
    if [[ "$OS" == "CentOS" ]]; then
        # 检查是否使用yum或dnf
        if command -v dnf >/dev/null 2>&1; then
            cmd="dnf install -y"
        else
            cmd="yum install -y"
        fi
    else
        # Debian/Ubuntu
        apt update -y
        cmd="apt install -y"
    fi
    
    $cmd "${deps[@]}"
    if [ $? -ne 0 ]; then
        log_error "安装依赖失败"
        return 1
    fi
    
    log_info "依赖安装完成"
    return 0
}

# 检查是否有root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "此脚本需要root权限运行"
        return 1
    fi
    return 0
}

# 主函数
main() {
    # 检查root权限
    check_root || exit 1
    
    # 检测系统
    SYS_INFO=$(detect_system)
    OS=$(echo "$SYS_INFO" | awk '{print $1}')
    VER=$(echo "$SYS_INFO" | awk '{print $2}')
    
    log_info "检测到系统: $SYS_INFO"
    
    # 根据系统类型设置依赖
    if [[ "$OS" == "CentOS" ]]; then
        # CentOS依赖
        DEPS=("wget" "curl" "unzip" "tar")
    else
        # Debian/Ubuntu依赖
        DEPS=("wget" "curl" "unzip" "tar")
    fi
    
    # 安装依赖
    install_dependencies "${DEPS[@]}" || exit 1
    
    log_info "开始执行VPS管理脚本..."
    
    # 以下是调用其他脚本的部分，不做修改
    # 仅展示调用逻辑，实际脚本中会替换为具体的脚本调用
    
    # 调用Docker安装脚本
    if [ -f "scripts/install_docker.sh" ]; then
        log_info "正在安装Docker..."
        bash scripts/install_docker.sh
        if [ $? -ne 0 ]; then
            log_error "Docker安装失败"
        else
            log_info "Docker安装完成"
        fi
    else
        log_warn "Docker安装脚本不存在"
    fi
    
    # 调用其他脚本...
    # ...
    
    log_info "VPS管理脚本执行完成"
}

# 执行主函数
main
