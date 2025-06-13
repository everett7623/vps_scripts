#!/bin/bash
#/vps_scripts/scripts/update_scripts/update_core_scripts.sh - VPS Scripts 核心脚本更新工具

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

echo -e "${WHITE}VPS Scripts 核心脚本更新工具${NC}"
echo "------------------------"

# 确认更新
echo -e "${YELLOW}警告: 此操作将更新VPS Scripts的核心脚本${NC}"
read -p "确定要更新核心脚本吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始更新核心脚本...${NC}";;
  n|N ) echo -e "${YELLOW}已取消更新${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消更新${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")
CORE_DIR="$PARENT_DIR/core"

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/core_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 备份当前核心脚本
echo -e "${WHITE}备份当前核心脚本...${NC}"
if [ -d "$CORE_DIR" ]; then
    cp -r "$CORE_DIR"/* "$BACKUP_DIR/"
    echo -e "${GREEN}核心脚本备份完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到核心脚本目录，跳过备份${NC}"
fi

# 检查更新配置
if [ ! -f "$PARENT_DIR/config/update.conf" ]; then
    echo -e "${YELLOW}警告: 未找到更新配置文件，将使用默认配置${NC}"
    UPDATE_SOURCE="https://github.com/your-repo/vps-scripts.git"
fi

# 下载最新核心脚本
echo -e "${WHITE}下载最新核心脚本...${NC}"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit

# 克隆或下载最新脚本
git clone -q --depth=1 "$UPDATE_SOURCE" vps-scripts

if [ ! -d "vps-scripts/core" ]; then
    echo -e "${RED}错误: 无法获取最新核心脚本，请检查更新源${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 复制新脚本到核心目录
echo -e "${WHITE}复制新脚本到核心目录...${NC}"
mkdir -p "$CORE_DIR"
cp -r "vps-scripts/core/"* "$CORE_DIR/"

# 设置权限
chmod -R 755 "$CORE_DIR"

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}核心脚本更新完成${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
