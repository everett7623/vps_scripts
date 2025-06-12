#!/bin/bash
#/scripts/service_install/install_docker_swarm.sh - VPS Scripts Docker Swarm安装工具

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

# 安装Docker
install_docker() {
    echo -e "${BLUE}正在检查Docker安装...${NC}"
    
    if command -v docker &>/dev/null; then
        echo -e "${GREEN}Docker已安装，版本: $(docker --version)${NC}"
    else
        echo -e "${RED}Docker未安装，请先安装Docker。${NC}"
        echo -e "${YELLOW}请运行 install_docker.sh 脚本安装Docker。${NC}"
        exit 1
    fi
    
    # 检查Docker Compose
    if command -v docker-compose &>/dev/null; then
        echo -e "${GREEN}Docker Compose已安装，版本: $(docker-compose --version)${NC}"
    else
        echo -e "${YELLOW}Docker Compose未安装，建议安装。${NC}"
        echo -e "${YELLOW}请运行 install_docker.sh 脚本安装Docker Compose。${NC}"
    fi
    
    return 0
}

# 初始化Docker Swarm
init_docker_swarm() {
    echo -e "${BLUE}正在初始化Docker Swarm...${NC}"
    
    # 检查是否已经加入Swarm
    if docker info | grep -q "Swarm: active"; then
        echo -e "${YELLOW}Docker Swarm已经处于活动状态。${NC}"
        
        # 询问是否重置Swarm
        read -p "是否重置Docker Swarm？(y/n): " reset_swarm
        
        if [ "$reset_swarm" = "y" ] || [ "$reset_swarm" = "Y" ]; then
            # 重置Swarm
            docker swarm leave --force
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}重置Docker Swarm失败。${NC}"
                return 1
            fi
            
            echo -e "${GREEN}Docker Swarm已重置。${NC}"
        else
            echo -e "${YELLOW}跳过Docker Swarm初始化。${NC}"
            return 0
        fi
    fi
    
    # 获取本机IP地址
    local_ip=$(hostname -I | awk '{print $1}')
    
    # 询问是否使用默认IP
    read -p "是否使用默认IP地址 ($local_ip)？(y/n): " use_default_ip
    
    if [ "$use_default_ip" != "y" ] && [ "$use_default_ip" != "Y" ]; then
        read -p "请输入要使用的IP地址: " swarm_ip
    else
        swarm_ip=$local_ip
    fi
    
    # 询问是否配置Swarm加密
    read -p "是否启用Docker Swarm加密传输？(y/n): " enable_encryption
    
    if [ "$enable_encryption" = "y" ] || [ "$enable_encryption" = "Y" ]; then
        # 初始化Swarm并启用加密
        docker swarm init --advertise-addr $swarm_ip --data-path-addr $swarm_ip --data-path-port 4789 --default-addr-pool 10.0.0.0/8 --default-addr-pool-mask-length 24 --autolock
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}初始化Docker Swarm失败。${NC}"
            return 1
        fi
        
        # 获取Swarm解锁密钥
        unlock_key=$(docker swarm unlock-key | grep "SWMKEY" | awk '{print $2}')
        
        echo -e "${GREEN}Docker Swarm已初始化并启用加密。${NC}"
        echo -e "${YELLOW}Swarm解锁密钥: $unlock_key${NC}"
        echo -e "${YELLOW}请妥善保存此密钥，重启Docker时需要使用。${NC}"
    else
        # 初始化Swarm
        docker swarm init --advertise-addr $swarm_ip --data-path-addr $swarm_ip --data-path-port 4789 --default-addr-pool 10.0.0.0/8 --default-addr-pool-mask-length 24
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}初始化Docker Swarm失败。${NC}"
            return 1
        fi
        
        echo -e "${GREEN}Docker Swarm已初始化。${NC}"
    fi
    
    # 获取加入令牌
    manager_token=$(docker swarm join-token manager -q)
    worker_token=$(docker swarm join-token worker -q)
    
    echo -e "${GREEN}Docker Swarm初始化成功。${NC}"
    echo -e "${YELLOW}Manager节点加入命令:${NC}"
    echo -e "${YELLOW}docker swarm join --token $manager_token $swarm_ip:2377${NC}"
    echo -e "${YELLOW}Worker节点加入命令:${NC}"
    echo -e "${YELLOW}docker swarm join --token $worker_token $swarm_ip:2377${NC}"
    
    # 显示Swarm信息
    echo -e "${YELLOW}Swarm节点信息:${NC}"
    docker node ls
    
    return 0
}

# 配置Docker Swarm网络
configure_swarm_network() {
    echo -e "${BLUE}正在配置Docker Swarm网络...${NC}"
    
    # 创建默认覆盖网络
    read -p "是否创建默认覆盖网络？(y/n): " create_network
    
    if [ "$create_network" = "y" ] || [ "$create_network" = "Y" ]; then
        # 询问网络名称
        read -p "请输入网络名称 (默认: overlay-net): " network_name
        
        if [ -z "$network_name" ]; then
            network_name="overlay-net"
        fi
        
        # 检查网络是否
