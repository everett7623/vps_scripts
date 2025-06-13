#!/bin/bash
#/vps_scripts/scripts/other_tools/swap.sh - VPS Scripts SWAP设置工具

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

echo -e "${WHITE}SWAP设置工具${NC}"
echo "------------------------"

# 检查当前SWAP状态
current_swap=$(free -m | grep Swap | awk '{print $2}')
if [ "$current_swap" -gt 0 ]; then
    echo -e "${YELLOW}检测到当前系统已有 $current_swap MB SWAP${NC}"
    read -p "是否要重新配置SWAP? (y/n): " reconfig
    case "$reconfig" in 
      y|Y ) echo -e "${GREEN}开始重新配置SWAP...${NC}";;
      n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
      * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
    esac
else
    echo -e "${GREEN}当前系统没有SWAP，将创建新的SWAP${NC}"
fi

# 获取SWAP大小
echo -e "${WHITE}请选择SWAP大小:${NC}"
echo "1. 1GB"
echo "2. 2GB"
echo "3. 4GB"
echo "4. 8GB"
echo "5. 自定义大小"

read -p "请选择 (1-5): " size_choice

case "$size_choice" in
    1) swap_size="1G";;
    2) swap_size="2G";;
    3) swap_size="4G";;
    4) swap_size="8G";;
    5) 
        read -p "请输入SWAP大小 (例如: 2G, 1024M): " swap_size
        ;;
    *) 
        echo -e "${RED}无效选择，已取消操作${NC}"
        exit 1
        ;;
esac

# 计算SWAP大小(MB)用于显示
if [[ $swap_size == *"G" ]]; then
    swap_size_mb=$(echo ${swap_size%G}*1024 | bc)
elif [[ $swap_size == *"M" ]]; then
    swap_size_mb=${swap_size%M}
else
    echo -e "${RED}无效的大小格式，请使用G或M后缀${NC}"
    exit 1
fi

# 确认操作
echo -e "${WHITE}将创建 $swap_size_mb MB SWAP${NC}"
read -p "确定要继续吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始创建SWAP...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 如果已有SWAP，先关闭
if [ "$current_swap" -gt 0 ]; then
    echo -e "${WHITE}关闭现有SWAP...${NC}"
    swapoff -a
fi

# 创建SWAP文件
echo -e "${WHITE}创建SWAP文件...${NC}"
fallocate -l "$swap_size" /swapfile

# 设置权限
chmod 600 /swapfile

# 创建SWAP空间
echo -e "${WHITE}创建SWAP空间...${NC}"
mkswap /swapfile

# 启用SWAP
echo -e "${WHITE}启用SWAP...${NC}"
swapon /swapfile

# 添加到fstab
echo -e "${WHITE}配置开机自动挂载...${NC}"
echo '/swapfile none swap defaults 0 0' | tee -a /etc/fstab

# 配置swappiness
echo -e "${WHITE}配置SWAP参数...${NC}"
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf

# 验证SWAP
new_swap=$(free -m | grep Swap | awk '{print $2}')
if [ "$new_swap" -gt 0 ]; then
    echo -e "${GREEN}SWAP创建成功，大小为 $new_swap MB${NC}"
else
    echo -e "${RED}SWAP创建失败，请手动检查${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}SWAP设置完成${NC}"
echo -e "${WHITE}当前SWAP信息:${NC}"
free -m | grep Swap
echo -e "${WHITE}SWAP参数:${NC}"
echo -e "${YELLOW}swappiness: 10${NC}"
echo ""
echo -e "${WHITE}管理命令:${NC}"
echo -e "${YELLOW}关闭SWAP: swapoff /swapfile${NC}"
echo -e "${YELLOW}启用SWAP: swapon /swapfile${NC}"
echo ""
