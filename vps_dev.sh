#!/bin/bash

# 导入核心功能库
source "$(dirname "$0")/lib/common_functions.sh"

# 导入配置文件
source "$(dirname "$0")/config/vps_scripts.conf"

# 脚本信息
SCRIPT_NAME="vps_dev.sh"
SCRIPT_VERSION="0.1.0"
SCRIPT_DESCRIPTION="VPS开发测试脚本"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 主菜单
function show_main_menu() {
    clear
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${CYAN}                 VPS开发测试脚本 - ${SCRIPT_VERSION}                 ${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}[1]${NC} 系统工具"
    echo -e "${GREEN}[2]${NC} 网络测试"
    echo -e "${GREEN}[3]${NC} 性能测试"
    echo -e "${GREEN}[4]${NC} 服务安装"
    echo -e "${GREEN}[5]${NC} 第三方优秀脚本"
    echo -e "${GREEN}[6]${NC} 代理工具"
    echo -e "${GREEN}[7]${NC} 其他工具"
    echo -e "${GREEN}[8]${NC} 更新脚本"
    echo -e "${GREEN}[9]${NC} 卸载脚本"
    echo -e "${RED}[0]${NC} 退出"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -n "请输入你的选择 [0-9]: "
}

# 系统工具子菜单
function show_system_tools_menu() {
    clear
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${CYAN}                    系统工具菜单                    ${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${GREEN}[1]${NC} 查看系统信息"
    echo -e "${GREEN}[2]${NC} 安装常用依赖"
    echo -e "${GREEN}[3]${NC} 更新系统"
    echo -e "${GREEN}[4]${NC} 清理系统"
    echo -e "${GREEN}[5]${NC} 系统优化"
    echo -e "${GREEN}[6]${NC} 修改主机名"
    echo -e "${GREEN}[7]${NC} 设置时区"
    echo -e "${RED}[0]${NC} 返回主菜单"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -n "请输入你的选择 [0-7]: "
}

# 主循环
while true; do
    show_main_menu
    read choice
    
    case $choice in
        1)  # 系统工具
            while true; do
                show_system_tools_menu
                read sub_choice
                
                case $sub_choice in
                    1) source "/scripts/system_tools/install_deps.sh" ;;
                    2) source "/scripts/system_tools/install_deps.sh" ;;
                    3) source "/scripts/system_tools/update_system.sh" ;;
                    4) source "/scripts/system_tools/clean_system.sh" ;;
                    5) source "/scripts/system_tools/optimize_system.sh" ;;
                    6) source "/scripts/system_tools/change_hostname.sh" ;;
                    7) source "/scripts/system_tools/set_timezone.sh" ;;
                    0) break ;;
                    *) echo -e "${RED}错误: 无效选择，请重试!${NC}" && sleep 1 ;;
                esac
            done
            ;;
        2)  # 网络测试
            source "$(dirname "$0")/scripts/network_test/network_menu.sh"
            ;;
        3)  # 性能测试
            source "$(dirname "$0")/scripts/performance_test/performance_menu.sh"
            ;;
        4)  # 服务安装
            source "$(dirname "$0")/scripts/service_install/service_menu.sh"
            ;;
        5)  # 第三方优秀脚本
            source "$(dirname "$0")/scripts/good_scripts/good_scripts.sh"
            ;;
        6)  # 代理工具
            source "$(dirname "$0")/scripts/proxy_tools/proxy_tools.sh"
            ;;
        7)  # 其他工具
            source "$(dirname "$0")/scripts/other_tools/other_tools_menu.sh"
            ;;
        8)  # 更新脚本
            source "$(dirname "$0")/scripts/update_scripts/update_menu.sh"
            ;;
        9)  # 卸载脚本
            source "$(dirname "$0")/scripts/uninstall_scripts/uninstall_menu.sh"
            ;;
        0)  # 退出
            echo -e "${GREEN}感谢使用VPS开发测试脚本，再见!${NC}"
            exit 0
            ;;
        *)  # 无效选择
            echo -e "${RED}错误: 无效选择，请重试!${NC}" && sleep 1
            ;;
    esac
done    
