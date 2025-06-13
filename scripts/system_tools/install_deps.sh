#!/bin/bash
#/scripts/system_tools/install_deps.sh - VPS Scripts 系统工具库

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
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
   exit 1
fi

echo -e "${WHITE}正在安装常用依赖...${NC}"
echo "------------------------"

# 获取操作系统类型
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

# 根据操作系统类型安装依赖
if [[ "$OS" == "Ubuntu" || "$OS" == "Debian" || "$OS" == "Linux Mint" ]]; then
    apt-get update -y
    apt-get install -y wget curl git vim zip unzip tar bzip2 build-essential python3 python3-pip
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}依赖安装成功!${NC}"
    else
        echo -e "${RED}依赖安装失败，请检查网络连接或系统状态${NC}"
        exit 1
    fi
    
    # 安装一些常用的网络工具
    apt-get install -y net-tools traceroute nmap dnsutils htop iftop iotop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}网络工具安装成功!${NC}"
    else
        echo -e "${RED}网络工具安装失败${NC}"
    fi
    
elif [[ "$OS" == "CentOS" || "$OS" == "Red Hat/CentOS" || "$OS" == "Fedora" ]]; then
    yum update -y
    yum install -y wget curl git vim zip unzip tar bzip2 gcc gcc-c++ make python3 python3-pip
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}依赖安装成功!${NC}"
    else
        echo -e "${RED}依赖安装失败，请检查网络连接或系统状态${NC}"
        exit 1
    fi
    
    # 安装一些常用的网络工具
    yum install -y net-tools traceroute nmap bind-utils htop iftop iotop
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}网络工具安装成功!${NC}"
    else
        echo -e "${RED}网络工具安装失败${NC}"
    fi
    
else
    echo -e "${YELLOW}警告: 不支持的操作系统类型: $OS${NC}"
    echo -e "${YELLOW}请手动安装所需依赖${NC}"
    exit 1
fi

# 检查Python3和pip3是否安装成功
if command -v python3 &>/dev/null && command -v pip3 &>/dev/null; then
    echo -e "${GREEN}Python3和pip3已成功安装${NC}"
else
    echo -e "${YELLOW}警告: Python3或pip3安装可能有问题，请手动检查${NC}"
fi

echo ""
echo -e "${WHITE}常用依赖安装完成${NC}"
echo "------------------------"
echo -e "${WHITE}已安装的主要依赖:${NC}"
echo -e "${GREEN}wget, curl, git, vim, zip, unzip, tar, bzip2, build-essential, python3, pip3${NC}"
echo -e "${GREEN}net-tools, traceroute, nmap, dnsutils, htop, iftop, iotop${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
