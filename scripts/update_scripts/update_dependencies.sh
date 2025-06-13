#!/bin/bash
#/vps_scripts/scripts/update_scripts/update_dependencies.sh - VPS Scripts 依赖环境更新工具

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

echo -e "${WHITE}VPS Scripts 依赖环境更新工具${NC}"
echo "------------------------"

# 确认更新
echo -e "${YELLOW}警告: 此操作将更新VPS Scripts的依赖环境${NC}"
echo -e "${YELLOW}可能会影响已安装的服务和应用${NC}"
read -p "确定要更新依赖环境吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始更新依赖环境...${NC}";;
  n|N ) echo -e "${YELLOW}已取消更新${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消更新${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 检测系统类型
if [ -f /etc/redhat-release ]; then
    system_type="centos"
elif [ -f /etc/debian_version ]; then
    if grep -q "ubuntu" /etc/os-release; then
        system_type="ubuntu"
    else
        system_type="debian"
    fi
else
    echo -e "${RED}不支持的操作系统类型${NC}"
    exit 1
fi

echo -e "${WHITE}检测到系统类型: ${YELLOW}$system_type${NC}"

# 检查依赖配置
if [ ! -f "$PARENT_DIR/config/dependencies.conf" ]; then
    echo -e "${YELLOW}警告: 未找到依赖配置文件，将使用默认配置${NC}"
    REQUIRED_PACKAGES="wget curl git vim zip unzip tar"
    PYTHON_PACKAGES="pip setuptools wheel"
else
    source "$PARENT_DIR/config/dependencies.conf"
fi

# 更新系统包管理器
echo -e "${WHITE}更新系统包管理器...${NC}"
if [ "$system_type" == "centos" ]; then
    yum update -y
else
    apt-get update -y
fi

# 更新系统基础依赖
echo -e "${WHITE}更新系统基础依赖...${NC}"
if [ "$system_type" == "centos" ]; then
    yum install -y $REQUIRED_PACKAGES
    yum update -y $REQUIRED_PACKAGES
else
    apt-get install -y $REQUIRED_PACKAGES
    apt-get upgrade -y $REQUIRED_PACKAGES
fi

# 更新Python依赖
echo -e "${WHITE}更新Python依赖...${NC}"
if command -v pip3 &> /dev/null; then
    pip3 install --upgrade $PYTHON_PACKAGES
else
    echo -e "${YELLOW}警告: 未安装pip3，跳过Python依赖更新${NC}"
fi

# 清理不再需要的包
echo -e "${WHITE}清理不再需要的包...${NC}"
if [ "$system_type" == "centos" ]; then
    yum autoremove -y
    yum clean all
else
    apt-get autoremove -y
    apt-get clean
fi

echo ""
echo -e "${GREEN}依赖环境更新完成${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
