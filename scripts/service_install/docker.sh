#!/bin/bash
#==============================================================================
# 脚本名称: docker.sh
# 脚本描述: Docker和Docker Compose安装脚本 - 支持多种系统的自动化安装
# 脚本路径: vps_scripts/scripts/service_install/docker.sh
# 作者: Jensfrank
# 使用方法: bash install_docker.sh [选项]
# 选项: 
#   --remove     卸载Docker
#   --update     更新Docker到最新版本
#   --compose    只安装Docker Compose
#   --cn         使用国内镜像源
# 更新日期: 2025-01-17
#==============================================================================

# 严格模式
set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# 全局变量
readonly SCRIPT_NAME="Docker安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/docker_install_$(date +%Y%m%d_%H%M%S).log"
readonly DOCKER_CONFIG_DIR="/etc/docker"
readonly DOCKER_DATA_DIR="/var/lib/docker"

# 系统信息
OS=""
VERSION=""
ARCH=""
USE_CN_MIRROR=false
ACTION="install"

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --remove     卸载Docker和Docker Compose
    --update     更新Docker到最新版本
    --compose    只安装Docker Compose
    --cn         使用国内镜像源（适用于中国大陆用户）
    -h, --help   显示此帮助信息

示例:
    $(basename "$0")             # 默认安装Docker和Docker Compose
    $(basename "$0") --cn        # 使用国内镜像源安装
    $(basename "$0") --remove    # 卸载Docker
    $(basename "$0") --update    # 更新Docker

EOF
}

# 日志记录
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 错误处理
error_exit() {
    log ERROR "$1"
    log ERROR "安装日志已保存到: $LOG_FILE"
    exit 1
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本需要root权限运行，请使用 sudo bash $0"
    fi
}

# 检测系统信息
detect_system() {
    log INFO "检测系统信息..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error_exit "无法检测操作系统信息"
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armhf" ;;
        *) error_exit "不支持的系统架构: $ARCH" ;;
    esac
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查系统兼容性
check_compatibility() {
    log INFO "检查系统兼容性..."
    
    local supported=false
    case $OS in
        ubuntu)
            case $VERSION in
                18.04|20.04|22.04|24.04) supported=true ;;
            esac
            ;;
        debian)
            case $VERSION in
                9|10|11|12) supported=true ;;
            esac
            ;;
        centos|rhel|almalinux|rocky)
            case $VERSION in
                7|8|9) supported=true ;;
            esac
            ;;
        fedora)
            if [[ $VERSION -ge 35 ]]; then
                supported=true
            fi
            ;;
    esac
    
    if [[ $supported == false ]]; then
        error_exit "不支持的系统: $OS $VERSION"
    fi
    
    log SUCCESS "系统兼容性检查通过"
}

# 设置国内镜像源
setup_cn_mirrors() {
    if [[ $USE_CN_MIRROR == true ]]; then
        log INFO "配置国内镜像源..."
        
        case $OS in
            ubuntu|debian)
                # 备份原始源
                cp /etc/apt/sources.list /etc/apt/sources.list.bak
                
                # 使用阿里云镜像
                if [[ $OS == "ubuntu" ]]; then
                    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
                    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
                else
                    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
                fi
                ;;
            centos|rhel|almalinux|rocky)
                # 使用阿里云镜像
                sed -i 's|mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-*.repo
                sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://mirrors.aliyun.com|g' /etc/yum.repos.d/CentOS-*.repo
                ;;
        esac
        
        log SUCCESS "国内镜像源配置完成"
    fi
}

# 安装依赖
install_dependencies() {
    log INFO "安装必要的依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                software-properties-common
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y -q \
                yum-utils \
                device-mapper-persistent-data \
                lvm2
            ;;
        fedora)
            dnf install -y -q \
                dnf-plugins-core \
                device-mapper-persistent-data \
                lvm2
            ;;
    esac
    
    log SUCCESS "依赖安装完成"
}

# 设置Docker仓库
setup_docker_repo() {
    log INFO "配置Docker仓库..."
    
    local docker_repo_url
    if [[ $USE_CN_MIRROR == true ]]; then
        docker_repo_url="https://mirrors.aliyun.com/docker-ce"
    else
        docker_repo_url="https://download.docker.com"
    fi
    
    case $OS in
        ubuntu|debian)
            # 添加Docker GPG密钥
            mkdir -p /etc/apt/keyrings
            curl -fsSL "$docker_repo_url/linux/$OS/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # 添加Docker仓库
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $docker_repo_url/linux/$OS \
                $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt-get update -qq
            ;;
            
        centos|rhel|almalinux|rocky)
            yum-config-manager --add-repo "$docker_repo_url/linux/centos/docker-ce.repo"
            if [[ $USE_CN_MIRROR == true ]]; then
                sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
            fi
            ;;
            
        fedora)
            dnf config-manager --add-repo "$docker_repo_url/linux/fedora/docker-ce.repo"
            if [[ $USE_CN_MIRROR == true ]]; then
                sed -i 's+download.docker.com+mirrors.aliyun.com/docker-ce+' /etc/yum.repos.d/docker-ce.repo
            fi
            ;;
    esac
    
    log SUCCESS "Docker仓库配置完成"
}

# 安装Docker
install_docker() {
    log INFO "安装Docker Engine..."
    
    case $OS in
        ubuntu|debian)
            apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ $OS == "fedora" ]]; then
                dnf install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            else
                yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;
    esac
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    log SUCCESS "Docker Engine安装完成"
}

# 安装Docker Compose (独立版本)
install_docker_compose() {
    log INFO "安装Docker Compose..."
    
    local compose_version
    compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z $compose_version ]]; then
        compose_version="v2.24.0"  # 默认版本
        log WARNING "无法获取最新版本，使用默认版本 $compose_version"
    fi
    
    local download_url
    if [[ $USE_CN_MIRROR == true ]]; then
        download_url="https://github.com.cnpmjs.org/docker/compose/releases/download/${compose_version}/docker-compose-linux-${ARCH}"
    else
        download_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-linux-${ARCH}"
    fi
    
    # 下载并安装
    curl -L "$download_url" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # 创建软链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    log SUCCESS "Docker Compose安装完成"
}

# 配置Docker
configure_docker() {
    log INFO "配置Docker..."
    
    # 创建配置目录
    mkdir -p "$DOCKER_CONFIG_DIR"
    
    # 配置Docker daemon
    cat > "$DOCKER_CONFIG_DIR/daemon.json" << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
EOF
    
    # 添加国内镜像加速器
    if [[ $USE_CN_MIRROR == true ]]; then
        cat >> "$DOCKER_CONFIG_DIR/daemon.json" << EOF
,
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://registry.docker-cn.com",
        "https://mirror.ccs.tencentyun.com"
    ]
EOF
    fi
    
    echo "}" >> "$DOCKER_CONFIG_DIR/daemon.json"
    
    # 重启Docker服务
    systemctl daemon-reload
    systemctl restart docker
    
    log SUCCESS "Docker配置完成"
}

# 验证安装
verify_installation() {
    log INFO "验证安装..."
    
    # 检查Docker版本
    if command_exists docker; then
        local docker_version=$(docker --version)
        log SUCCESS "Docker已安装: $docker_version"
    else
        error_exit "Docker安装失败"
    fi
    
    # 检查Docker Compose版本
    if command_exists docker-compose; then
        local compose_version=$(docker-compose --version)
        log SUCCESS "Docker Compose已安装: $compose_version"
    fi
    
    # 测试Docker运行
    log INFO "测试Docker运行..."
    if docker run --rm hello-world &>/dev/null; then
        log SUCCESS "Docker运行正常"
    else
        log WARNING "Docker测试运行失败，请检查配置"
    fi
}

# 卸载Docker
remove_docker() {
    log INFO "开始卸载Docker..."
    
    # 停止Docker服务
    if systemctl is-active docker &>/dev/null; then
        systemctl stop docker
        systemctl disable docker
    fi
    
    case $OS in
        ubuntu|debian)
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            apt-get autoremove -y
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ $OS == "fedora" ]]; then
                dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            else
                yum remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;
    esac
    
    # 删除Docker数据和配置
    rm -rf "$DOCKER_DATA_DIR"
    rm -rf "$DOCKER_CONFIG_DIR"
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose
    
    log SUCCESS "Docker卸载完成"
}

# 更新Docker
update_docker() {
    log INFO "开始更新Docker..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get upgrade -y docker-ce docker-ce-cli containerd.io
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ $OS == "fedora" ]]; then
                dnf update -y docker-ce docker-ce-cli containerd.io
            else
                yum update -y docker-ce docker-ce-cli containerd.io
            fi
            ;;
    esac
    
    # 更新Docker Compose
    install_docker_compose
    
    # 重启Docker服务
    systemctl restart docker
    
    log SUCCESS "Docker更新完成"
}

# 显示安装信息
show_installation_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Docker安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}版本信息:${NC}"
    docker --version
    docker-compose --version 2>/dev/null || echo "Docker Compose: 使用 'docker compose' 命令"
    echo
    echo -e "${BLUE}常用命令:${NC}"
    echo "  docker ps              # 查看运行中的容器"
    echo "  docker images          # 查看镜像列表"
    echo "  docker compose up -d   # 启动compose服务"
    echo "  docker system prune    # 清理未使用的资源"
    echo
    echo -e "${BLUE}配置文件:${NC}"
    echo "  $DOCKER_CONFIG_DIR/daemon.json"
    echo
    echo -e "${BLUE}日志文件:${NC}"
    echo "  $LOG_FILE"
    echo
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove)
                ACTION="remove"
                shift
                ;;
            --update)
                ACTION="update"
                shift
                ;;
            --compose)
                ACTION="compose"
                shift
                ;;
            --cn)
                USE_CN_MIRROR=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log ERROR "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_system
    check_compatibility
    
    # 开始执行
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            log INFO "开始安装Docker..."
            setup_cn_mirrors
            install_dependencies
            setup_docker_repo
            install_docker
            install_docker_compose
            configure_docker
            verify_installation
            show_installation_info
            ;;
        remove)
            remove_docker
            ;;
        update)
            update_docker
            verify_installation
            ;;
        compose)
            install_docker_compose
            docker-compose --version
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"
