#!/bin/bash
#/vps_scripts/scripts/uninstall_scripts/full_uninstall.sh - VPS Scripts 完全卸载工具

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

echo -e "${WHITE}VPS Scripts 完全卸载工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${RED}警告: 此操作将执行全面的卸载${NC}"
echo -e "${RED}删除所有与VPS Scripts相关的文件、目录、配置以及日志和缓存等残留信息${NC}"
echo -e "${RED}此操作不可逆转，可能导致系统不稳定${NC}"
read -p "确定要继续吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始完全卸载...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/full_uninstall_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 备份当前脚本目录
echo -e "${WHITE}备份VPS Scripts脚本目录...${NC}"
cp -r "$PARENT_DIR" "$BACKUP_DIR/vps_scripts_backup"

# 停止所有VPS Scripts相关服务
echo -e "${WHITE}停止所有VPS Scripts相关服务...${NC}"
systemctl stop bt &> /dev/null
systemctl stop 1panel &> /dev/null
systemctl stop nezha-agent &> /dev/null
systemctl stop fail2ban &> /dev/null
systemctl stop docker &> /dev/null
systemctl stop nginx &> /dev/null
systemctl stop httpd &> /dev/null
systemctl stop mysql &> /dev/null
systemctl stop mysqld &