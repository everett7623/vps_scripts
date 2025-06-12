#!/bin/bash
#/scripts/service_install/install_python.sh - VPS Scripts Python环境安装工具

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

# 安装Python
install_python() {
    echo -e "${BLUE}正在安装Python...${NC}"
    
    # 检查是否已安装Python
    python3_installed=false
    python2_installed=false
    
    if command -v python3 &>/dev/null; then
        python3_installed=true
        echo -e "${YELLOW}Python 3已安装，当前版本: $(python3 -V)${NC}"
    fi
    
    if command -v python2 &>/dev/null || command -v python &>/dev/null && ! python -c "import sys; sys.exit(1 if sys.version_info.major >= 3 else 0)"; then
        python2_installed=true
        echo -e "${YELLOW}Python 2已安装，当前版本: $(python -V 2>&1)${NC}"
    fi
    
    # 选择要安装的Python版本
    echo "请选择要安装的Python版本:"
    echo "1) Python 3 (推荐)"
    echo "2) Python 2 (不推荐，仅用于兼容)"
    echo "3) Python 3 和 Python 2"
    
    read -p "请输入选项 (1-3): " version_choice
    
    case $version_choice in
        1)
            if [ "$python3_installed" = true ]; then
                read -p "Python 3已安装，是否更新？(y/n): " update_choice
                if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
                    return 0
                fi
            fi
            install_python3
            ;;
        2)
            if [ "$python2_installed" = true ]; then
                read -p "Python 2已安装，是否更新？(y/n): " update_choice
                if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
                    return 0
                fi
            fi
            install_python2
            ;;
        3)
            if [ "$python3_installed" = true ]; then
                read -p "Python 3已安装，是否更新？(y/n): " update_choice
                if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
                    install_python3=false
                else
                    install_python3=true
                fi
            else
                install_python3=true
            fi
            
            if [ "$python2_installed" = true ]; then
                read -p "Python 2已安装，是否更新？(y/n): " update_choice
                if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
                    install_python2=false
                else
                    install_python2=true
                fi
            else
                install_python2=true
            fi
            
            if [ "$install_python3" = true ]; then
                install_python3
            fi
            
            if [ "$install_python2" = true ]; then
                install_python2
            fi
            ;;
        *)
            echo -e "${RED}无效选项，默认安装Python 3${NC}"
            install_python3
            ;;
    esac
    
    return 0
}

# 安装Python 3
install_python3() {
    echo -e "${BLUE}正在安装Python 3...${NC}"
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt install -y python3 python3-dev python3-pip python3-venv
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum install -y python3 python3-devel python3-pip
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm python python-pip
    else
        echo -e "${RED}不支持的操作系统，无法安装Python 3。${NC}"
        return 1
    fi
    
    # 确保pip3是最新的
    python3 -m pip install --upgrade pip
    
    echo -e "${GREEN}Python 3安装完成。${NC}"
    
    # 验证安装
    python3 -V
    pip3 -V
    
    return 0
}

# 安装Python 2 (不推荐，仅用于兼容)
install_python2() {
    echo -e "${BLUE}正在安装Python 2 (不推荐，仅用于兼容)...${NC}"
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt install -y python2 python2-dev
        curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
        python2 get-pip.py
        rm get-pip.py
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum install -y python2 python2-devel
        curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
        python2 get-pip.py
        rm get-pip.py
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm python2 python2-pip
    else
        echo -e "${RED}不支持的操作系统，无法安装Python 2。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Python 2安装完成。${NC}"
    
    # 验证安装
    python2 -V 2>&1
   
