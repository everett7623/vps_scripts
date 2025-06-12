#!/bin/bash
#/scripts/service_install/install_nodejs.sh - VPS Scripts Node.js环境安装工具

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

# 安装Node.js
install_nodejs() {
    echo -e "${BLUE}正在安装Node.js...${NC}"
    
    if command -v node &>/dev/null; then
        echo -e "${YELLOW}Node.js已安装，当前版本: $(node -v)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    # 选择Node.js版本
    echo "请选择要安装的Node.js版本:"
    echo "1) 最新LTS版本 (推荐)"
    echo "2) 最新稳定版本"
    echo "3) 指定版本"
    
    read -p "请输入选项 (1-3): " version_choice
    
    case $version_choice in
        1)
            NODE_VERSION="lts"
            ;;
        2)
            NODE_VERSION="current"
            ;;
        3)
            read -p "请输入要安装的Node.js版本 (例如: 18.16.0): " custom_version
            NODE_VERSION=$custom_version
            ;;
        *)
            echo -e "${RED}无效选项，默认安装LTS版本${NC}"
            NODE_VERSION="lts"
            ;;
    esac
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        # 添加NodeSource仓库
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
        apt install -y nodejs
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        # 添加NodeSource仓库
        curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash -
        yum install -y nodejs
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm nodejs npm
    else
        echo -e "${RED}不支持的操作系统，无法安装Node.js。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Node.js安装完成。${NC}"
    
    # 验证安装
    node -v
    npm -v
    
    return 0
}

# 安装Yarn
install_yarn() {
    echo -e "${BLUE}正在安装Yarn...${NC}"
    
    if command -v yarn &>/dev/null; then
        echo -e "${YELLOW}Yarn已安装，当前版本: $(yarn -v)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
        apt update -y
        apt install -y yarn
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
        yum install -y yarn
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm yarn
    else
        # 使用npm安装Yarn
        npm install -g yarn
    fi
    
    echo -e "${GREEN}Yarn安装完成。${NC}"
    
    # 验证安装
    yarn -v
    
    return 0
}

# 安装PM2 (进程管理器)
install_pm2() {
    echo -e "${BLUE}正在安装PM2...${NC}"
    
    if command -v pm2 &>/dev/null; then
        echo -e "${YELLOW}PM2已安装，当前版本: $(pm2 -v)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    # 使用npm安装PM2
    npm install -g pm2
    
    # 设置PM2开机自启
    pm2 startup systemd
    
    echo -e "${GREEN}PM2安装完成。${NC}"
    
    # 验证安装
    pm2 -v
    
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           Node.js环境安装工具               ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    # 安装Node.js
    install_nodejs
    
    # 询问是否安装Yarn
    read -p "是否安装Yarn包管理器？(y/n): " install_yarn_choice
    
    if [ "$install_yarn_choice" = "y" ] || [ "$install_yarn_choice" = "Y" ]; then
        install_yarn
    fi
    
    # 询问是否安装PM2
    read -p "是否安装PM2进程管理器？(y/n): " install_pm2_choice
    
    if [ "$install_pm2_choice" = "y" ] || [ "$install_pm2_choice" = "Y" ]; then
        install_pm2
    fi
    
    echo -e "${GREEN}Node.js环境安装工具执行完成!${NC}"
}

# 执行主函数
main
