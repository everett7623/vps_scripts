#!/bin/bash
#/vps_scripts/scripts/other_tools/bbr.sh - VPS Scripts BBR网络加速工具

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

echo -e "${WHITE}BBR网络加速工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 启用BBR可能会影响现有网络配置${NC}"
read -p "确定要启用BBR网络加速吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始配置BBR...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 检查当前内核版本
current_kernel=$(uname -r)
echo -e "${WHITE}当前内核版本: ${YELLOW}$current_kernel${NC}"

# 检查内核是否支持BBR
if [[ "$current_kernel" > "4.9" ]]; then
    echo -e "${GREEN}当前内核版本支持BBR${NC}"
else
    echo -e "${YELLOW}当前内核版本可能不支持BBR，尝试升级内核...${NC}"
    
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
    
    # 根据系统类型升级内核
    if [ "$system_type" == "centos" ]; then
        yum -y update
        yum -y install kernel
    else
        apt-get update
        apt-get -y upgrade
    fi
    
    echo -e "${YELLOW}内核已更新，请重启系统后再次运行此脚本${NC}"
    read -p "是否立即重启系统? (y/n): " reboot_choice
    case "$reboot_choice" in 
      y|Y ) echo -e "${GREEN}系统将在5秒后重启...${NC}"; sleep 5; reboot;;
      n|N ) echo -e "${YELLOW}请在适当的时候手动重启系统${NC}"; exit 0;;
      * ) echo -e "${YELLOW}已取消重启，系统不会立即重启${NC}"; exit 0;;
    esac
fi

# 配置BBR
echo -e "${WHITE}配置BBR...${NC}"
cat > /etc/sysctl.d/bbr.conf << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

# 应用配置
sysctl --system

# 验证BBR是否启用
if lsmod | grep -q tcp_bbr; then
    echo -e "${GREEN}BBR已成功启用${NC}"
else
    echo -e "${RED}BBR启用失败，请手动检查${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}BBR网络加速配置完成${NC}"
echo -e "${WHITE}当前TCP拥塞控制: ${YELLOW}$(sysctl -n net.ipv4.tcp_congestion_control)${NC}"
echo -e "${WHITE}当前默认队列规则: ${YELLOW}$(sysctl -n net.core.default_qdisc)${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
