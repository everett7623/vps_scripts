#!/bin/bash
#/scripts/service_install/install_docker.sh - VPS Scripts Docker安装工具

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
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
        OS="Red Hat/CentOS"
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo -e "${YELLOW}检测到操作系统: ${GREEN}$OS $VER${NC}"
}

# 更新系统
update_system() {
    echo -e "${BLUE}正在更新系统...${NC}"
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt update -y
        apt upgrade -y
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum update -y
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -Syu --noconfirm
    else
        echo -e "${YELLOW}跳过系统更新，未知操作系统${NC}"
    fi
    
    echo -e "${GREEN}系统更新完成。${NC}"
}

# 安装Docker和Docker Compose
install_docker() {
    echo -e "${BLUE}正在安装Docker和Docker Compose...${NC}"
    
    # 安装Docker
    if command -v docker &>/dev/null; then
        echo -e "${YELLOW}Docker已安装，跳过安装。${NC}"
    else
        if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
            apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update -y
            apt install -y docker-ce docker-ce-cli containerd.io
        elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
        elif [ "$OS" = "Arch Linux" ]; then
            pacman -S --noconfirm docker
        else
            echo -e "${RED}不支持的操作系统，无法安装Docker。${NC}"
            return 1
        fi
        
        # 启动Docker服务
        systemctl enable docker
        systemctl start docker
        
        echo -e "${GREEN}Docker安装完成。${NC}"
    fi
    
    # 安装Docker Compose
    if command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}Docker Compose已安装，跳过安装。${NC}"
    else
        # 获取最新版本的Docker Compose
        LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d'"' -f4)
        
        # 下载并安装Docker Compose
        curl -L "https://github.com/docker/compose/releases/download/$LATEST_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        echo -e "${GREEN}Docker Compose安装完成。${NC}"
    fi
    
    # 验证安装
    docker --version
    docker-compose --version
    
    echo -e "${GREEN}Docker和Docker Compose安装成功。${NC}"
}

# 添加当前用户到docker组
add_user_to_docker_group() {
    read -p "是否将当前用户添加到docker组？(y/n): " choice
    
    if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
        current_user=$(whoami)
        usermod -aG docker $current_user
        echo -e "${GREEN}用户 $current_user 已添加到docker组。${NC}"
        echo -e "${YELLOW}注意: 需要重新登录才能生效。${NC}"
    fi
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           Docker安装工具                    ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    install_docker
    add_user_to_docker_group
    
    echo -e "${GREEN}Docker安装工具执行完成!${NC}"
}

# 执行主函数
main
