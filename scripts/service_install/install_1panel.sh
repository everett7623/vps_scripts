#!/bin/bash
#/vps_scripts/scripts/service_install/install_1panel.sh - VPS Scripts 1Panel面板安装工具

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

echo -e "${WHITE}1Panel面板安装工具${NC}"
echo "------------------------"

# 确认安装
echo -e "${YELLOW}警告: 安装1Panel面板将修改您的系统配置，可能影响现有服务${NC}"
read -p "确定要安装1Panel面板吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始安装1Panel面板...${NC}";;
  n|N ) echo -e "${YELLOW}已取消安装${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消安装${NC}"; exit 1;;
esac

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

# 安装必要依赖
echo -e "${WHITE}安装必要依赖...${NC}"
if [ "$system_type" == "centos" ]; then
    yum install -y wget curl
else
    apt-get update
    apt-get install -y wget curl
fi

# 下载并执行1Panel安装脚本
echo -e "${WHITE}下载并执行1Panel安装脚本...${NC}"
curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh
bash quick_start.sh

# 清理安装文件
rm -f quick_start.sh

echo ""
echo -e "${GREEN}1Panel面板安装完成${NC}"
echo -e "${WHITE}访问面板: ${YELLOW}http://服务器IP:8080${NC}"
echo -e "${WHITE}默认账号: ${YELLOW}admin${NC}"
echo -e "${WHITE}默认密码: ${YELLOW}1panel${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
