#!/bin/bash
#/vps_scripts/scripts/update_scripts/trigger_auto_update.sh - VPS Scripts 自动更新触发器

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

echo -e "${WHITE}VPS Scripts 自动更新触发器${NC}"
echo "------------------------"

# 确认更新
echo -e "${YELLOW}警告: 自动更新可能会修改现有脚本和配置${NC}"
read -p "确定要触发自动更新吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始触发自动更新...${NC}";;
  n|N ) echo -e "${YELLOW}已取消更新${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消更新${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 检查更新配置
if [ ! -f "$PARENT_DIR/config/update.conf" ]; then
    echo -e "${YELLOW}警告: 未找到更新配置文件，将使用默认配置${NC}"
    AUTO_UPDATE=1
    UPDATE_SOURCE="https://github.com/your-repo/vps-scripts.git"
else
    source "$PARENT_DIR/config/update.conf"
fi

# 检查是否启用自动更新
if [ "$AUTO_UPDATE" -eq 0 ]; then
    echo -e "${YELLOW}警告: 自动更新已禁用，请先在配置文件中启用${NC}"
    exit 0
fi

# 检查是否安装了git
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: 未安装git，请先安装git${NC}"
    exit 1
fi

# 检查是否为git仓库
if [ ! -d "$PARENT_DIR/.git" ]; then
    echo -e "${RED}错误: 当前目录不是git仓库，无法执行自动更新${NC}"
    exit 1
fi

# 执行更新
echo -e "${WHITE}正在从 $UPDATE_SOURCE 拉取更新...${NC}"
cd "$PARENT_DIR" || exit
git pull origin main

if [ $? -ne 0 ]; then
    echo -e "${RED}更新失败，请检查网络连接或仓库状态${NC}"
    exit 1
else
    echo -e "${GREEN}更新成功完成${NC}"
    
    # 执行核心脚本更新
    if [ -f "$PARENT_DIR/scripts/update_scripts/update_core_scripts.sh" ]; then
        echo -e "${WHITE}执行核心脚本更新...${NC}"
        bash "$PARENT_DIR/scripts/update_scripts/update_core_scripts.sh"
    fi
    
    # 执行依赖环境更新
    if [ -f "$PARENT_DIR/scripts/update_scripts/update_dependencies.sh" ]; then
        echo -e "${WHITE}执行依赖环境更新...${NC}"
        bash "$PARENT_DIR/scripts/update_scripts/update_dependencies.sh"
    fi
    
    # 执行功能工具脚本更新
    if [ -f "$PARENT_DIR/scripts/update_scripts/update_functional_tools.sh" ]; then
        echo -e "${WHITE}执行功能工具脚本更新...${NC}"
        bash "$PARENT_DIR/scripts/update_scripts/update_functional_tools.sh"
    fi
    
    echo -e "${GREEN}所有更新操作已完成${NC}"
fi

echo ""
echo -e "${WHITE}VPS Scripts 自动更新完成${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
