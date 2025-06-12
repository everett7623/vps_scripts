#!/bin/bash
#/scripts/service_install/install_redis.sh - VPS Scripts Redis安装工具

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

# 安装Redis
install_redis() {
    echo -e "${BLUE}正在安装Redis...${NC}"
    
    if command -v redis-server &>/dev/null; then
        echo -e "${YELLOW}Redis已安装，当前版本: $(redis-server --version)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt install -y redis-server
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum install -y redis
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm redis
    else
        echo -e "${RED}不支持的操作系统，无法安装Redis。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Redis安装完成。${NC}"
    
    # 配置Redis
    configure_redis
    
    # 验证安装
    redis-server --version
    
    return 0
}

# 配置Redis
configure_redis() {
    echo -e "${BLUE}正在配置Redis...${NC}"
    
    # 备份原始配置
    if [ -f /etc/redis/redis.conf ]; then
        cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    fi
    
    # 配置Redis
    sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf
    sed -i 's/^# requirepass foobared/requirepass /g'
    
    # 询问是否设置密码
    read -p "是否为Redis设置密码？(y/n): " set_password
    
    if [ "$set_password" = "y" ] || [ "$set_password" = "Y" ]; then
        read -s -p "请输入Redis密码: " redis_password
        echo ""
        read -s -p "请再次输入Redis密码: " redis_password_confirm
        echo ""
        
        if [ "$redis_password" != "$redis_password_confirm" ]; then
            echo -e "${RED}密码不匹配，使用默认配置。${NC}"
        else
            sed -i "s/^requirepass /requirepass $redis_password/g" /etc/redis/redis.conf
            echo -e "${GREEN}Redis密码已设置。${NC}"
        fi
    fi
    
    # 配置Redis作为服务启动
    systemctl enable redis-server
    systemctl restart redis-server
    
    # 验证Redis服务状态
    if systemctl is-active --quiet redis-server; then
        echo -e "${GREEN}Redis服务已成功启动。${NC}"
    else
        echo -e "${RED}Redis服务启动失败，请检查日志。${NC}"
        return 1
    fi
    
    # 测试Redis连接
    echo -e "${YELLOW}正在测试Redis连接...${NC}"
    
    if [ "$set_password" = "y" ] || [ "$set_password" = "Y" ]; then
        redis-cli -a "$redis_password" ping
    else
        redis-cli ping
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Redis连接测试成功。${NC}"
    else
        echo -e "${RED}Redis连接测试失败，请检查配置。${NC}"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           Redis安装工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    # 安装Redis
    install_redis
    
    echo -e "${GREEN}Redis安装工具执行完成!${NC}"
}

# 执行主函数
main
