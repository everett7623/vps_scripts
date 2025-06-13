#!/bin/bash
#/vps_scripts/scripts/update_scripts/update_functional_tools.sh - VPS Scripts 功能工具脚本更新工具

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

echo -e "${WHITE}VPS Scripts 功能工具脚本更新工具${NC}"
echo "------------------------"

# 确认更新
echo -e "${YELLOW}警告: 此操作将更新VPS Scripts的功能工具脚本${NC}"
read -p "确定要更新功能工具脚本吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始更新功能工具脚本...${NC}";;
  n|N ) echo -e "${YELLOW}已取消更新${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消更新${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 定义功能工具目录
SYSTEM_TOOLS_DIR="$PARENT_DIR/scripts/system_tools"
SERVICE_INSTALL_DIR="$PARENT_DIR/scripts/service_install"
OTHER_TOOLS_DIR="$PARENT_DIR/scripts/other_tools"
UPDATE_SCRIPTS_DIR="$PARENT_DIR/scripts/update_scripts"
UNINSTALL_SCRIPTS_DIR="$PARENT_DIR/scripts/uninstall_scripts"

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/tools_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR/system_tools"
mkdir -p "$BACKUP_DIR/service_install"
mkdir -p "$BACKUP_DIR/other_tools"
mkdir -p "$BACKUP_DIR/update_scripts"
mkdir -p "$BACKUP_DIR/uninstall_scripts"

# 备份当前脚本
echo -e "${WHITE}备份当前功能工具脚本...${NC}"
if [ -d "$SYSTEM_TOOLS_DIR" ]; then
    cp -r "$SYSTEM_TOOLS_DIR"/* "$BACKUP_DIR/system_tools/"
fi
if [ -d "$SERVICE_INSTALL_DIR" ]; then
    cp -r "$SERVICE_INSTALL_DIR"/* "$BACKUP_DIR/service_install/"
fi
if [ -d "$OTHER_TOOLS_DIR" ]; then
    cp -r "$OTHER_TOOLS_DIR"/* "$BACKUP_DIR/other_tools/"
fi
if [ -d "$UPDATE_SCRIPTS_DIR" ]; then
    cp -r "$UPDATE_SCRIPTS_DIR"/* "$BACKUP_DIR/update_scripts/"
fi
if [ -d "$UNINSTALL_SCRIPTS_DIR" ]; then
    cp -r "$UNINSTALL_SCRIPTS_DIR"/* "$BACKUP_DIR/uninstall_scripts/"
fi
echo -e "${GREEN}功能工具脚本备份完成${NC}"

# 检查更新配置
if [ ! -f "$PARENT_DIR/config/update.conf" ]; then
    echo -e "${YELLOW}警告: 未找到更新配置文件，将使用默认配置${NC}"
    UPDATE_SOURCE="https://github.com/your-repo/vps-scripts.git"
fi

# 下载最新功能工具脚本
echo -e "${WHITE}下载最新功能工具脚本...${NC}"
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit

# 克隆或下载最新脚本
git clone -q --depth=1 "$UPDATE_SOURCE" vps-scripts

# 更新系统工具脚本
echo -e "${WHITE}更新系统工具脚本...${NC}"
if [ -d "vps-scripts/scripts/system_tools" ]; then
    mkdir -p "$SYSTEM_TOOLS_DIR"
    cp -r "vps-scripts/scripts/system_tools/"* "$SYSTEM_TOOLS_DIR/"
    chmod -R 755 "$SYSTEM_TOOLS_DIR"
    echo -e "${GREEN}系统工具脚本更新完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到系统工具脚本，跳过更新${NC}"
fi

# 更新服务安装脚本
echo -e "${WHITE}更新服务安装脚本...${NC}"
if [ -d "vps-scripts/scripts/service_install" ]; then
    mkdir -p "$SERVICE_INSTALL_DIR"
    cp -r "vps-scripts/scripts/service_install/"* "$SERVICE_INSTALL_DIR/"
    chmod -R 755 "$SERVICE_INSTALL_DIR"
    echo -e "${GREEN}服务安装脚本更新完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到服务安装脚本，跳过更新${NC}"
fi

# 更新其他工具脚本
echo -e "${WHITE}更新其他工具脚本...${NC}"
if [ -d "vps-scripts/scripts/other_tools" ]; then
    mkdir -p "$OTHER_TOOLS_DIR"
    cp -r "vps-scripts/scripts/other_tools/"* "$OTHER_TOOLS_DIR/"
    chmod -R 755 "$OTHER_TOOLS_DIR"
    echo -e "${GREEN}其他工具脚本更新完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到其他工具脚本，跳过更新${NC}"
fi

# 更新更新脚本目录
echo -e "${WHITE}更新更新脚本目录...${NC}"
if [ -d "vps-scripts/scripts/update_scripts" ]; then
    mkdir -p "$UPDATE_SCRIPTS_DIR"
    cp -r "vps-scripts/scripts/update_scripts/"* "$UPDATE_SCRIPTS_DIR/"
    chmod -R 755 "$UPDATE_SCRIPTS_DIR"
    echo -e "${GREEN}更新脚本目录更新完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到更新脚本目录，跳过更新${NC}"
fi

# 更新卸载脚本目录
echo -e "${WHITE}更新卸载脚本目录...${NC}"
if [ -d "vps-scripts/scripts/uninstall_scripts" ]; then
    mkdir -p "$UNINSTALL_SCRIPTS_DIR"
    cp -r "vps-scripts/scripts/uninstall_scripts/"* "$UNINSTALL_SCRIPTS_DIR/"
    chmod -R 755 "$UNINSTALL_SCRIPTS_DIR"
    echo -e "${GREEN}卸载脚本目录更新完成${NC}"
else
    echo -e "${YELLOW}警告: 未找到卸载脚本目录，跳过更新${NC}"
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}功能工具脚本更新完成${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
