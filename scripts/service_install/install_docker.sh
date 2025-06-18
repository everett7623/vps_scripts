#!/bin/bash
################################################################################
# 脚本名称: install_docker.sh
# 脚本用途: 自动安装和配置Docker容器引擎
# 脚本路径: vps_scripts/scripts/service_install/install_docker.sh
# 作者: Jensfrank
# 更新日期: $(date +%Y-%m-%d)
################################################################################

# 定义脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
GRAND_PARENT_DIR="$(dirname "$PARENT_DIR")"

# 加载通用函数库
source "$PARENT_DIR/system_tools/install_deps.sh" 2>/dev/null || {
    echo "错误: 无法加载依赖函数库"
    exit 1
}

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 全局变量
DOCKER_VERSION=""
DOCKER_COMPOSE_VERSION=""
INSTALL_MODE=""
CHINA_MIRROR=false

# 函数: 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -v, --version VERSION   指定Docker版本(默认:最新稳定版)"
    echo "  -c, --compose VERSION   安装Docker Compose并指定版本"
    echo "  -m, --mirror            使用中国镜像加速安装"
    echo "  -u, --uninstall         卸载Docker"
    echo ""
    echo "示例:"
    echo "  $0                      # 安装最新版Docker"
    echo "  $0 -v 20.10.21         # 安装指定版本Docker"
    echo "  $0 -c 2.20.3 -m        # 安装Docker和Compose，使用中国镜像"
}

# 函数: 检查系统要求
check_requirements() {
    echo -e "${BLUE}>>> 检查系统要求...${NC}"
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}错误: 无法确定操作系统类型${NC}"
        exit 1
    fi
    
    # 检查系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            DOCKER_ARCH="amd64"
            ;;
        aarch64|arm64)
            DOCKER_ARCH="arm64"
            ;;
        armv7l|armhf)
            DOCKER_ARCH="armhf"
            ;;
        *)
            echo -e "${RED}错误: 不支持的系统架构: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # 检查内核版本
    KERNEL_VERSION=$(uname -r | cut -d'.' -f1,2)
    KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d'.' -f1)
    KERNEL_MINOR=$(echo $KERNEL_VERSION | cut -d'.' -f2)
    
    if [[ $KERNEL_MAJOR -lt 3 ]] || ([[ $KERNEL_MAJOR -eq 3 ]] && [[ $KERNEL_MINOR -lt 10 ]]); then
        echo -e "${RED}错误: Docker需要Linux内核版本3.10或更高${NC}"
        echo -e "${RED}当前内核版本: $(uname -r)${NC}"
        exit 1
    fi
    
    # 检查是否已安装Docker
    if command -v docker &> /dev/null; then
        CURRENT_VERSION=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo -e "${YELLOW}警告: Docker已安装 (版本: $CURRENT_VERSION)${NC}"
        read -p "是否继续重新安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo -e "${GREEN}✓ 系统要求检查通过${NC}"
    echo -e "  操作系统: $OS $VERSION"
    echo -e "  系统架构: $ARCH ($DOCKER_ARCH)"
    echo -e "  内核版本: $(uname -r)"
}

# 函数: 配置中国镜像源
setup_china_mirror() {
    echo -e "${BLUE}>>> 配置中国镜像源...${NC}"
    
    # 创建docker目录
    mkdir -p /etc/docker
    
    # 配置daemon.json
    cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF
    
    echo -e "${GREEN}✓ 中国镜像源配置完成${NC}"
}

# 函数: 安装Docker (Ubuntu/Debian)
install_docker_debian() {
    echo -e "${BLUE}>>> 安装Docker (Debian/Ubuntu)...${NC}"
    
    # 更新包索引
    apt-get update
    
    # 安装必要的包
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # 添加Docker官方GPG密钥
    if [[ "$CHINA_MIRROR" == true ]]; then
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/$OS/gpg | apt-key add -
    else
        curl -fsSL https://download.docker.com/linux/$OS/gpg | apt-key add -
    fi
    
    # 添加Docker仓库
    if [[ "$CHINA_MIRROR" == true ]]; then
        add-apt-repository \
            "deb [arch=$DOCKER_ARCH] https://mirrors.aliyun.com/docker-ce/linux/$OS \
            $(lsb_release -cs) \
            stable"
    else
        add-apt-repository \
            "deb [arch=$DOCKER_ARCH] https://download.docker.com/linux/$OS \
            $(lsb_release -cs) \
            stable"
    fi
    
    # 更新包索引
    apt-get update
    
    # 安装Docker
    if [[ -z "$DOCKER_VERSION" ]]; then
        apt-get install -y docker-ce docker-ce-cli containerd.io
    else
        apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io
    fi
}

# 函数: 安装Docker (CentOS/RHEL/Fedora)
install_docker_rhel() {
    echo -e "${BLUE}>>> 安装Docker (CentOS/RHEL/Fedora)...${NC}"
    
    # 安装必要的包
    yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # 添加Docker仓库
    if [[ "$CHINA_MIRROR" == true ]]; then
        yum-config-manager \
            --add-repo \
            https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    else
        yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
    fi
    
    # 安装Docker
    if [[ -z "$DOCKER_VERSION" ]]; then
        yum install -y docker-ce docker-ce-cli containerd.io
    else
        yum install -y docker-ce-$DOCKER_VERSION docker-ce-cli-$DOCKER_VERSION containerd.io
    fi
}

# 函数: 安装Docker Compose
install_docker_compose() {
    echo -e "${BLUE}>>> 安装Docker Compose...${NC}"
    
    # 确定Compose版本
    if [[ -z "$DOCKER_COMPOSE_VERSION" ]]; then
        if [[ "$CHINA_MIRROR" == true ]]; then
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
        else
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
        fi
    else
        COMPOSE_VERSION="v$DOCKER_COMPOSE_VERSION"
    fi
    
    # 下载Docker Compose
    if [[ "$CHINA_MIRROR" == true ]]; then
        COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    else
        COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
    fi
    
    echo -e "${CYAN}下载Docker Compose ${COMPOSE_VERSION}...${NC}"
    curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # 创建命令链接
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # 验证安装
    if docker-compose --version &> /dev/null; then
        echo -e "${GREEN}✓ Docker Compose安装成功${NC}"
        docker-compose --version
    else
        echo -e "${RED}✗ Docker Compose安装失败${NC}"
        return 1
    fi
}

# 函数: 启动并配置Docker
configure_docker() {
    echo -e "${BLUE}>>> 配置Docker服务...${NC}"
    
    # 启动Docker服务
    systemctl enable docker
    systemctl start docker
    
    # 等待Docker启动
    for i in {1..30}; do
        if docker info &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo
    
    # 验证Docker是否正常运行
    if ! docker info &> /dev/null; then
        echo -e "${RED}错误: Docker服务启动失败${NC}"
        systemctl status docker
        exit 1
    fi
    
    # 配置用户组
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker $SUDO_USER
        echo -e "${GREEN}✓ 用户 $SUDO_USER 已添加到docker组${NC}"
        echo -e "${YELLOW}注意: 请重新登录以使组权限生效${NC}"
    fi
    
    echo -e "${GREEN}✓ Docker服务配置完成${NC}"
}

# 函数: 验证安装
verify_installation() {
    echo -e "${BLUE}>>> 验证Docker安装...${NC}"
    
    # 检查Docker版本
    echo -e "${CYAN}Docker版本信息:${NC}"
    docker --version
    
    # 检查Docker服务状态
    echo -e "\n${CYAN}Docker服务状态:${NC}"
    systemctl is-active docker
    
    # 运行测试容器
    echo -e "\n${CYAN}运行测试容器:${NC}"
    docker run --rm hello-world
    
    # 显示Docker信息
    echo -e "\n${CYAN}Docker系统信息:${NC}"
    docker info | grep -E "Server Version|Storage Driver|Docker Root Dir"
    
    # 检查Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo -e "\n${CYAN}Docker Compose版本:${NC}"
        docker-compose --version
    fi
}

# 函数: 卸载Docker
uninstall_docker() {
    echo -e "${BLUE}>>> 卸载Docker...${NC}"
    
    read -p "确定要卸载Docker吗？这将删除所有容器和镜像。(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # 停止所有容器
    echo -e "${YELLOW}停止所有运行中的容器...${NC}"
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # 删除所有容器
    echo -e "${YELLOW}删除所有容器...${NC}"
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # 删除所有镜像
    echo -e "${YELLOW}删除所有镜像...${NC}"
    docker rmi $(docker images -q) 2>/dev/null || true
    
    # 停止Docker服务
    systemctl stop docker
    systemctl disable docker
    
    # 卸载Docker包
    case $OS in
        ubuntu|debian)
            apt-get purge -y docker-ce docker-ce-cli containerd.io
            apt-get autoremove -y
            ;;
        centos|rhel|fedora)
            yum remove -y docker-ce docker-ce-cli containerd.io
            ;;
    esac
    
    # 删除Docker数据目录
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -rf /etc/docker
    
    # 删除Docker Compose
    rm -f /usr/local/bin/docker-compose
    rm -f /usr/bin/docker-compose
    
    echo -e "${GREEN}✓ Docker卸载完成${NC}"
}

# 函数: 显示安装总结
show_summary() {
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}Docker安装完成！${NC}"
    echo -e "${GREEN}===================================================${NC}"
    echo -e "\n${CYAN}安装信息:${NC}"
    echo -e "  Docker版本: $(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if command -v docker-compose &> /dev/null; then
        echo -e "  Docker Compose版本: $(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    fi
    echo -e "  配置文件: /etc/docker/daemon.json"
    echo -e "  数据目录: /var/lib/docker"
    
    echo -e "\n${CYAN}常用命令:${NC}"
    echo -e "  docker ps              # 查看运行中的容器"
    echo -e "  docker images          # 查看镜像列表"
    echo -e "  docker run [image]     # 运行容器"
    echo -e "  docker-compose up -d   # 启动compose服务"
    
    echo -e "\n${CYAN}下一步建议:${NC}"
    echo -e "  1. 重新登录以使用户组权限生效"
    echo -e "  2. 运行 'docker run hello-world' 测试安装"
    echo -e "  3. 配置镜像加速器以提高下载速度"
    echo -e "${GREEN}===================================================${NC}"
}

# 主函数
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                DOCKER_VERSION="$2"
                shift 2
                ;;
            -c|--compose)
                DOCKER_COMPOSE_VERSION="$2"
                shift 2
                ;;
            -m|--mirror)
                CHINA_MIRROR=true
                shift
                ;;
            -u|--uninstall)
                INSTALL_MODE="uninstall"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示脚本信息
    echo -e "${PURPLE}===================================================${NC}"
    echo -e "${PURPLE}VPS Docker安装脚本${NC}"
    echo -e "${PURPLE}作者: Jensfrank${NC}"
    echo -e "${PURPLE}===================================================${NC}\n"
    
    # 执行相应操作
    if [[ "$INSTALL_MODE" == "uninstall" ]]; then
        uninstall_docker
    else
        # 检查系统要求
        check_requirements
        
        # 配置中国镜像（如果需要）
        if [[ "$CHINA_MIRROR" == true ]]; then
            setup_china_mirror
        fi
        
        # 根据系统类型安装Docker
        case $OS in
            ubuntu|debian)
                install_docker_debian
                ;;
            centos|rhel|fedora)
                install_docker_rhel
                ;;
            *)
                echo -e "${RED}错误: 不支持的操作系统: $OS${NC}"
                exit 1
                ;;
        esac
        
        # 配置Docker
        configure_docker
        
        # 安装Docker Compose（如果需要）
        if [[ -n "$DOCKER_COMPOSE_VERSION" ]] || [[ "$DOCKER_COMPOSE_VERSION" == "latest" ]]; then
            install_docker_compose
        fi
        
        # 验证安装
        verify_installation
        
        # 显示安装总结
        show_summary
    fi
}

# 执行主函数
main "$@"
