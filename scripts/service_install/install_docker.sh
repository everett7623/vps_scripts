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

# 判断网络环境（国内/国外）
detect_network_env() {
    echo -e "${BLUE}正在检测网络环境...${NC}"
    
    # 尝试访问阿里云镜像站，判断是否为国内网络环境
    if curl -s -m 5 https://mirrors.aliyun.com > /dev/null; then
        # 能访问阿里云，可能是国内环境，再测试Docker官方源速度
        echo -e "${YELLOW}正在测试Docker官方源下载速度...${NC}"
        OFFICIAL_SPEED=$(curl -s -w "%{speed_download}" -o /dev/null https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/containerd.io_1.4.9-1_amd64.deb -m 10)
        
        # 转换为KB/s
        OFFICIAL_SPEED_KB=$(echo "$OFFICIAL_SPEED / 1024" | bc)
        
        if (( $(echo "$OFFICIAL_SPEED_KB < 50" | bc -l) )); then
            # 下载速度低于50KB/s，判定为国内网络环境
            echo -e "${GREEN}检测到国内网络环境，将使用阿里云镜像安装Docker。${NC}"
            return 0 # 0表示国内环境
        else
            echo -e "${GREEN}检测到国外网络环境，将使用官方源安装Docker。${NC}"
            return 1 # 1表示国外环境
        fi
    else
        # 无法访问阿里云，判定为国外网络环境
        echo -e "${GREEN}检测到国外网络环境，将使用官方源安装Docker。${NC}"
        return 1 # 1表示国外环境
    fi
}

# 安装Docker和Docker Compose
install_docker() {
    echo -e "${BLUE}正在安装Docker和Docker Compose...${NC}"
    
    # 安装Docker
    if command -v docker &>/dev/null; then
        echo -e "${YELLOW}Docker已安装，跳过安装。${NC}"
    else
        # 判断网络环境
        if detect_network_env; then
            # 国内环境，使用阿里云镜像
            echo -e "${BLUE}正在使用阿里云镜像安装Docker...${NC}"
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
        else
            # 国外环境，使用官方源
            echo -e "${BLUE}正在使用官方源安装Docker...${NC}"
            curl -fsSL https://get.docker.com | bash -s docker
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
