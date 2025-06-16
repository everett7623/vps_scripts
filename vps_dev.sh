#!/bin/bash

# 脚本名称: vps_dev.sh
# 描述: VPS管理工具测试版本
# 作者: VPS Scripts Development Team
# 版本: DEV-1.0.0
# 更新时间: 2025-06-16

# GitHub 仓库信息
GITHUB_RAW="https://raw.githubusercontent.com/everett7623/vps_scripts/main"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 导出颜色变量供子脚本使用
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE NC

# 设置脚本路径
if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    # 脚本以文件形式存在
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # 脚本通过 bash <(curl ...) 运行，创建临时目录
    SCRIPT_DIR="/tmp/vps_scripts_$"
    mkdir -p "${SCRIPT_DIR}"
fi

SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
LIB_DIR="${SCRIPT_DIR}/lib"
CONFIG_DIR="${SCRIPT_DIR}/config"

# 创建必要的目录
mkdir -p "${LIB_DIR}" "${CONFIG_DIR}"

# 下载依赖文件的函数
download_dependency() {
    local url="$1"
    local dest="$2"
    local desc="$3"
    
    echo -e "${CYAN}正在下载 ${desc}...${NC}"
    if curl -sL "${url}" -o "${dest}" 2>/dev/null; then
        echo -e "${GREEN}✓ ${desc} 下载成功${NC}"
        return 0
    else
        echo -e "${RED}✗ ${desc} 下载失败${NC}"
        return 1
    fi
}

# 检查并下载公共函数库
if [ ! -f "${LIB_DIR}/common_functions.sh" ]; then
    download_dependency "${GITHUB_RAW}/lib/common_functions.sh" "${LIB_DIR}/common_functions.sh" "公共函数库" || {
        echo -e "${RED}错误: 无法下载公共函数库${NC}"
        exit 1
    }
fi

# 检查并下载配置文件
if [ ! -f "${CONFIG_DIR}/vps_scripts.conf" ]; then
    download_dependency "${GITHUB_RAW}/config/vps_scripts.conf" "${CONFIG_DIR}/vps_scripts.conf" "配置文件" || {
        echo -e "${YELLOW}警告: 无法下载配置文件，使用默认配置${NC}"
    }
fi

# 加载配置文件
if [ -f "${CONFIG_DIR}/vps_scripts.conf" ]; then
    source "${CONFIG_DIR}/vps_scripts.conf"
fi

# 加载公共函数库
if [ -f "${LIB_DIR}/common_functions.sh" ]; then
    source "${LIB_DIR}/common_functions.sh"
else
    echo -e "${RED}错误: 无法加载公共函数库${NC}"
    exit 1
fi

# 显示横幅
show_banner() {
    clear
    echo -e "${CYAN}===================================================${NC}"
    echo -e "${CYAN}#                                                 #${NC}"
    echo -e "${CYAN}#           VPS 管理工具箱 (测试版)               #${NC}"
    echo -e "${CYAN}#                DEV Version                      #${NC}"
    echo -e "${CYAN}#                                                 #${NC}"
    echo -e "${CYAN}===================================================${NC}"
    echo
}

# 显示主菜单
show_main_menu() {
    echo -e "${YELLOW}==================== 主菜单 ====================${NC}"
    echo -e "  ${GREEN}1${NC}. 系统工具"
    echo -e "  ${GREEN}2${NC}. 网络测试"
    echo -e "  ${GREEN}3${NC}. 性能测试"
    echo -e "  ${GREEN}4${NC}. 服务安装"
    echo -e "  ${GREEN}5${NC}. 优秀脚本"
    echo -e "  ${GREEN}6${NC}. 梯子工具"
    echo -e "  ${GREEN}7${NC}. 其他工具"
    echo -e "  ${GREEN}8${NC}. 更新脚本"
    echo -e "  ${GREEN}9${NC}. 卸载脚本"
    echo -e "  ${RED}0${NC}. 退出"
    echo -e "${YELLOW}===============================================${NC}"
}

# 系统工具子菜单
system_tools_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 系统工具 ==================${NC}"
        echo -e "  ${GREEN}1${NC}. 查看系统信息"
        echo -e "  ${GREEN}2${NC}. 安装常用依赖"
        echo -e "  ${GREEN}3${NC}. 更新系统"
        echo -e "  ${GREEN}4${NC}. 清理系统"
        echo -e "  ${GREEN}5${NC}. 系统优化"
        echo -e "  ${GREEN}6${NC}. 修改主机名"
        echo -e "  ${GREEN}7${NC}. 设置时区"
        echo -e "  ${RED}0${NC}. 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-7]: " choice
        
        case $choice in
            1)
                run_script "scripts/system_tools/system_info.sh"
                read -p "按任意键继续..." -n 1
                ;;
            2)
                run_script "scripts/system_tools/install_deps.sh"
                read -p "按任意键继续..." -n 1
                ;;
            3)
                run_script "scripts/system_tools/update_system.sh"
                read -p "按任意键继续..." -n 1
                ;;
            4)
                run_script "scripts/system_tools/clean_system.sh"
                read -p "按任意键继续..." -n 1
                ;;
            5)
                run_script "scripts/system_tools/optimize_system.sh"
                read -p "按任意键继续..." -n 1
                ;;
            6)
                run_script "scripts/system_tools/change_hostname.sh"
                read -p "按任意键继续..." -n 1
                ;;
            7)
                run_script "scripts/system_tools/set_timezone.sh"
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 网络测试子菜单
network_test_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 网络测试 ==================${NC}"
        echo -e "${GREEN}1.${NC} 回程路由测试"
        echo -e "${GREEN}2.${NC} 带宽测试"
        echo -e "${GREEN}3.${NC} CDN延迟测试"
        echo -e "${GREEN}4.${NC} IP质量测试"
        echo -e "${GREEN}5.${NC} 网络连通性测试"
        echo -e "${GREEN}6.${NC} 网络质量测试"
        echo -e "${GREEN}7.${NC} 网络安全扫描"
        echo -e "${GREEN}8.${NC} 网络测速"
        echo -e "${GREEN}9.${NC} 路由追踪"
        echo -e "${GREEN}10.${NC} 端口扫描器"
        echo -e "${GREEN}11.${NC} 响应时间测试"
        echo -e "${GREEN}12.${NC} 流媒体解锁测试"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-12]: " choice
        
        case $choice in
            1)
                run_script "scripts/network_test/backhaul_route_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            2)
                run_script "scripts/network_test/bandwidth_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            3)
                run_script "scripts/network_test/cdn_latency_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            4)
                run_script "scripts/network_test/ip_quality_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            5)
                run_script "scripts/network_test/network_connectivity_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            6)
                run_script "scripts/network_test/network_quality_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            7)
                run_script "scripts/network_test/network_security_scan.sh"
                read -p "按任意键继续..." -n 1
                ;;
            8)
                run_script "scripts/network_test/network_speedtest.sh"
                read -p "按任意键继续..." -n 1
                ;;
            9)
                run_script "scripts/network_test/network_traceroute.sh"
                read -p "按任意键继续..." -n 1
                ;;
            10)
                run_script "scripts/network_test/port_scanner.sh"
                read -p "按任意键继续..." -n 1
                ;;
            11)
                run_script "scripts/network_test/response_time_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            12)
                run_script "scripts/network_test/streaming_unlock_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 性能测试子菜单
performance_test_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 性能测试 ==================${NC}"
        echo -e "${GREEN}1.${NC} CPU基准测试"
        echo -e "${GREEN}2.${NC} 磁盘IO基准测试"
        echo -e "${GREEN}3.${NC} 内存基准测试"
        echo -e "${GREEN}4.${NC} 网络吞吐量测试"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1)
                run_script "scripts/performance_test/cpu_benchmark.sh"
                read -p "按任意键继续..." -n 1
                ;;
            2)
                run_script "scripts/performance_test/disk_io_benchmark.sh"
                read -p "按任意键继续..." -n 1
                ;;
            3)
                run_script "scripts/performance_test/memory_benchmark.sh"
                read -p "按任意键继续..." -n 1
                ;;
            4)
                run_script "scripts/performance_test/network_throughput_test.sh"
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 服务安装子菜单
service_install_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 服务安装 ==================${NC}"
        echo -e "${GREEN}1.${NC} Docker安装"
        echo -e "${GREEN}2.${NC} LNMP环境安装"
        echo -e "${GREEN}3.${NC} Node.js安装"
        echo -e "${GREEN}4.${NC} Python安装"
        echo -e "${GREEN}5.${NC} Redis安装"
        echo -e "${GREEN}6.${NC} 宝塔面板安装"
        echo -e "${GREEN}7.${NC} 1Panel面板安装"
        echo -e "${GREEN}8.${NC} Wordpress安装"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-8]: " choice
        
        case $choice in
            1)
                if [ -f "${SCRIPTS_DIR}/service_install/install_docker.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_docker.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            2)
                if [ -f "${SCRIPTS_DIR}/service_install/install_lnmp.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_lnmp.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            3)
                if [ -f "${SCRIPTS_DIR}/service_install/install_nodejs.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_nodejs.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                if [ -f "${SCRIPTS_DIR}/service_install/install_python.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_python.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            5)
                if [ -f "${SCRIPTS_DIR}/service_install/install_redis.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_redis.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            6)
                if [ -f "${SCRIPTS_DIR}/service_install/install_bt_panel.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_bt_panel.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            7)
                if [ -f "${SCRIPTS_DIR}/service_install/install_1panel.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_1panel.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            8)
                if [ -f "${SCRIPTS_DIR}/service_install/install_wordpress.sh" ]; then
                    bash "${SCRIPTS_DIR}/service_install/install_wordpress.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 优秀脚本子菜单
good_scripts_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 优秀脚本 ==================${NC}"
        echo -e "${GREEN}1.${NC} 打开优秀脚本整合菜单"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-1]: " choice
        
        case $choice in
            1)
                run_script "scripts/good_scripts/good_scripts.sh"
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 梯子工具子菜单
proxy_tools_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 梯子工具 ==================${NC}"
        echo -e "${GREEN}1.${NC} 打开梯子工具整合菜单"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-1]: " choice
        
        case $choice in
            1)
                run_script "scripts/proxy_tools/proxy_tools.sh"
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 其他工具子菜单
other_tools_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 其他工具 ==================${NC}"
        echo -e "${GREEN}1.${NC} BBR加速"
        echo -e "${GREEN}2.${NC} Fail2ban安装"
        echo -e "${GREEN}3.${NC} 哪吒监控安装"
        echo -e "${GREEN}4.${NC} SWAP设置"
        echo -e "${GREEN}5.${NC} 哪吒Agent清理"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-5]: " choice
        
        case $choice in
            1)
                if [ -f "${SCRIPTS_DIR}/other_tools/bbr.sh" ]; then
                    bash "${SCRIPTS_DIR}/other_tools/bbr.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            2)
                if [ -f "${SCRIPTS_DIR}/other_tools/fail2ban.sh" ]; then
                    bash "${SCRIPTS_DIR}/other_tools/fail2ban.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            3)
                if [ -f "${SCRIPTS_DIR}/other_tools/nezha.sh" ]; then
                    bash "${SCRIPTS_DIR}/other_tools/nezha.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                if [ -f "${SCRIPTS_DIR}/other_tools/swap.sh" ]; then
                    bash "${SCRIPTS_DIR}/other_tools/swap.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            5)
                echo -e "${CYAN}执行哪吒Agent清理脚本...${NC}"
                bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 更新脚本子菜单
update_scripts_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 更新脚本 ==================${NC}"
        echo -e "${GREEN}1.${NC} 触发自动更新"
        echo -e "${GREEN}2.${NC} 更新核心脚本"
        echo -e "${GREEN}3.${NC} 更新依赖环境"
        echo -e "${GREEN}4.${NC} 更新功能工具"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1)
                if [ -f "${SCRIPTS_DIR}/update_scripts/trigger_auto_update.sh" ]; then
                    bash "${SCRIPTS_DIR}/update_scripts/trigger_auto_update.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            2)
                if [ -f "${SCRIPTS_DIR}/update_scripts/update_core_scripts.sh" ]; then
                    bash "${SCRIPTS_DIR}/update_scripts/update_core_scripts.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            3)
                if [ -f "${SCRIPTS_DIR}/update_scripts/update_dependencies.sh" ]; then
                    bash "${SCRIPTS_DIR}/update_scripts/update_dependencies.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                if [ -f "${SCRIPTS_DIR}/update_scripts/update_functional_tools.sh" ]; then
                    bash "${SCRIPTS_DIR}/update_scripts/update_functional_tools.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 卸载脚本子菜单
uninstall_scripts_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}================== 卸载脚本 ==================${NC}"
        echo -e "${GREEN}1.${NC} 清理服务残留"
        echo -e "${GREEN}2.${NC} 回滚系统环境"
        echo -e "${GREEN}3.${NC} 清除配置文件"
        echo -e "${GREEN}4.${NC} 完全卸载"
        echo -e "${RED}0.${NC} 返回主菜单"
        echo -e "${YELLOW}===============================================${NC}"
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1)
                if [ -f "${SCRIPTS_DIR}/uninstall_scripts/clean_service_residues.sh" ]; then
                    bash "${SCRIPTS_DIR}/uninstall_scripts/clean_service_residues.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            2)
                if [ -f "${SCRIPTS_DIR}/uninstall_scripts/rollback_system_environment.sh" ]; then
                    bash "${SCRIPTS_DIR}/uninstall_scripts/rollback_system_environment.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            3)
                if [ -f "${SCRIPTS_DIR}/uninstall_scripts/clear_configuration_files.sh" ]; then
                    bash "${SCRIPTS_DIR}/uninstall_scripts/clear_configuration_files.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            4)
                if [ -f "${SCRIPTS_DIR}/uninstall_scripts/full_uninstall.sh" ]; then
                    bash "${SCRIPTS_DIR}/uninstall_scripts/full_uninstall.sh"
                else
                    echo -e "${RED}错误: 脚本不存在${NC}"
                fi
                read -p "按任意键继续..." -n 1
                ;;
            0)
                return
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 清理函数
cleanup() {
    if [[ "${SCRIPT_DIR}" == /tmp/vps_scripts_* ]]; then
        echo -e "${CYAN}正在清理临时文件...${NC}"
        rm -rf "${SCRIPT_DIR}"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 主函数
main() {
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}请使用root权限运行此脚本${NC}"
        exit 1
    fi
    
    while true; do
        show_banner
        show_main_menu
        
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                system_tools_menu
                ;;
            2)
                network_test_menu
                ;;
            3)
                performance_test_menu
                ;;
            4)
                service_install_menu
                ;;
            5)
                good_scripts_menu
                ;;
            6)
                proxy_tools_menu
                ;;
            7)
                other_tools_menu
                ;;
            8)
                update_scripts_menu
                ;;
            9)
                uninstall_scripts_menu
                ;;
            0)
                echo -e "${GREEN}感谢使用VPS管理工具箱！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选项，请重新选择${NC}"
                sleep 2
                ;;
        esac
    done
}

# 运行主函数
main
