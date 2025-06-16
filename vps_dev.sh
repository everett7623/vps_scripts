#!/bin/bash

# 脚本名称: vps_dev.sh
# 用途: VPS综合管理测试脚本 - 开发测试版本
# 脚本路径: vps_scripts/vps_dev.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 版本信息
VERSION="1.0.0-dev"
AUTHOR="Everett"
PROJECT_URL="https://github.com/everett7623/vps_scripts/"
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main"

# 定义安装目录
INSTALL_DIR="/root/vps_scripts"

# 检查并创建安装目录
ensure_install_dir() {
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}首次运行，正在初始化环境...${NC}"
        mkdir -p "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        
        # 克隆整个项目
        echo -e "${GREEN}正在下载脚本文件...${NC}"
        git clone https://github.com/everett7623/vps_scripts.git . 2>/dev/null || {
            # 如果git失败，尝试使用curl下载必要文件
            echo -e "${YELLOW}Git克隆失败，尝试使用curl下载...${NC}"
            
            # 创建必要的目录结构
            mkdir -p lib config scripts/{system_tools,network_test,performance_test,service_install,good_scripts,proxy_tools,other_tools,update_scripts,uninstall_scripts}
            
            # 下载核心文件
            curl -sL "${GITHUB_RAW_URL}/vps_dev.sh" -o vps_dev.sh
            curl -sL "${GITHUB_RAW_URL}/lib/common_functions.sh" -o lib/common_functions.sh
            curl -sL "${GITHUB_RAW_URL}/config/vps_scripts.conf" -o config/vps_scripts.conf
            
            # 下载system_info.sh作为示例
            curl -sL "${GITHUB_RAW_URL}/scripts/system_tools/system_info.sh" -o scripts/system_tools/system_info.sh
            
            chmod +x vps_dev.sh
        }
        
        echo -e "${GREEN}初始化完成！${NC}"
        echo ""
    fi
    
    # 切换到安装目录
    cd "$INSTALL_DIR"
}

# 加载公共函数库
load_common_functions() {
    if [ -f "${INSTALL_DIR}/lib/common_functions.sh" ]; then
        source "${INSTALL_DIR}/lib/common_functions.sh"
    else
        # 如果本地没有，尝试下载
        echo -e "${YELLOW}下载公共函数库...${NC}"
        mkdir -p "${INSTALL_DIR}/lib"
        curl -sL "${GITHUB_RAW_URL}/lib/common_functions.sh" -o "${INSTALL_DIR}/lib/common_functions.sh"
        if [ -f "${INSTALL_DIR}/lib/common_functions.sh" ]; then
            source "${INSTALL_DIR}/lib/common_functions.sh"
        else
            echo -e "${RED}错误: 无法加载公共函数库${NC}"
            return 1
        fi
    fi
    return 0
}

# 加载配置文件
load_config() {
    if [ -f "${INSTALL_DIR}/config/vps_scripts.conf" ]; then
        source "${INSTALL_DIR}/config/vps_scripts.conf"
    else
        # 如果本地没有，尝试下载
        echo -e "${YELLOW}下载配置文件...${NC}"
        mkdir -p "${INSTALL_DIR}/config"
        curl -sL "${GITHUB_RAW_URL}/config/vps_scripts.conf" -o "${INSTALL_DIR}/config/vps_scripts.conf"
        if [ -f "${INSTALL_DIR}/config/vps_scripts.conf" ]; then
            source "${INSTALL_DIR}/config/vps_scripts.conf"
        else
            echo -e "${YELLOW}警告: 无法加载配置文件，使用默认配置${NC}"
        fi
    fi
}

# 显示脚本头部信息
show_header() {
    clear
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}         VPS 综合管理测试脚本            ${NC}"
    echo -e "${CYAN}            ${YELLOW}[开发测试版]${NC}"
    echo -e "${GREEN}    Author: ${AUTHOR}${NC}"
    echo -e "${GREEN}   Project: ${PROJECT_URL}${NC}"
    echo -e "${GREEN}   Version: ${VERSION}${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# 显示主菜单
show_main_menu() {
    show_header
    echo -e "${YELLOW}请选择要执行的操作类别：${NC}"
    echo ""
    echo -e "${CYAN}  1.${NC} ${GREEN}系统工具${NC}     - 系统信息、更新、清理、优化等"
    echo -e "${CYAN}  2.${NC} ${BLUE}网络测试${NC}     - 路由、带宽、延迟、IP质量、流媒体等"
    echo -e "${CYAN}  3.${NC} ${PURPLE}性能测试${NC}     - CPU、磁盘IO、内存、网络吞吐量基准测试"
    echo -e "${CYAN}  4.${NC} ${YELLOW}服务安装${NC}     - Docker、LNMP、面板、WordPress等"
    echo -e "${CYAN}  5.${NC} ${RED}优秀脚本${NC}     - 集成社区优秀评测与工具脚本"
    echo -e "${CYAN}  6.${NC} ${GREEN}梯子工具${NC}     - 常用代理工具一键安装"
    echo -e "${CYAN}  7.${NC} ${BLUE}其他工具${NC}     - BBR、Fail2ban、SWAP、哪吒监控等"
    echo -e "${CYAN}  8.${NC} ${PURPLE}更新脚本${NC}     - 脚本更新相关的操作"
    echo -e "${CYAN}  9.${NC} ${YELLOW}卸载脚本${NC}     - 清理卸载相关的操作与配置"
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${RED}  0.${NC} ${WHITE}退出脚本${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    echo -e "${GREEN}提示:${NC} 输入对应数字选择功能 [0-9]"
}

# 执行子脚本
run_script() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    local full_path="${INSTALL_DIR}/${script_path}"
    
    # 检查脚本是否存在，如果不存在则尝试下载
    if [ ! -f "$full_path" ]; then
        echo -e "${YELLOW}脚本不存在，尝试下载...${NC}"
        local dir_path=$(dirname "$full_path")
        mkdir -p "$dir_path"
        
        # 尝试从GitHub下载
        curl -sL "${GITHUB_RAW_URL}/${script_path}" -o "$full_path"
        
        if [ -f "$full_path" ]; then
            chmod +x "$full_path"
            echo -e "${GREEN}下载成功！${NC}"
        else
            echo -e "${RED}错误: 无法下载脚本 - ${script_path}${NC}"
            echo -e "${YELLOW}请检查网络连接或手动下载完整项目${NC}"
            echo ""
            read -p "按回车键返回菜单..."
            return
        fi
    fi
    
    # 执行脚本
    echo -e "${GREEN}正在执行: ${script_name}${NC}"
    bash "$full_path"
    echo -e "${GREEN}执行完成！${NC}"
    echo ""
    read -p "按回车键返回菜单..."
}

# 系统工具子菜单
system_tools_menu() {
    while true; do
        show_header
        echo -e "${GREEN}系统工具${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} 查看系统信息"
        echo -e "${CYAN}  2.${NC} 安装常用依赖"
        echo -e "${CYAN}  3.${NC} 更新系统"
        echo -e "${CYAN}  4.${NC} 清理系统"
        echo -e "${CYAN}  5.${NC} 系统优化"
        echo -e "${CYAN}  6.${NC} 修改主机名"
        echo -e "${CYAN}  7.${NC} 设置时区"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-7]: " choice
        
        case $choice in
            1) run_script "scripts/system_tools/system_info.sh" ;;
            2) run_script "scripts/system_tools/install_deps.sh" ;;
            3) run_script "scripts/system_tools/update_system.sh" ;;
            4) run_script "scripts/system_tools/clean_system.sh" ;;
            5) run_script "scripts/system_tools/optimize_system.sh" ;;
            6) run_script "scripts/system_tools/change_hostname.sh" ;;
            7) run_script "scripts/system_tools/set_timezone.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 网络测试子菜单
network_test_menu() {
    while true; do
        show_header
        echo -e "${BLUE}网络测试${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} 回程路由测试"
        echo -e "${CYAN}  2.${NC} 带宽测试"
        echo -e "${CYAN}  3.${NC} CDN延迟测试"
        echo -e "${CYAN}  4.${NC} IP质量测试"
        echo -e "${CYAN}  5.${NC} 网络连通性测试"
        echo -e "${CYAN}  6.${NC} 网络质量测试"
        echo -e "${CYAN}  7.${NC} 网络安全扫描"
        echo -e "${CYAN}  8.${NC} 网络测速"
        echo -e "${CYAN}  9.${NC} 路由追踪"
        echo -e "${CYAN} 10.${NC} 端口扫描器"
        echo -e "${CYAN} 11.${NC} 响应时间测试"
        echo -e "${CYAN} 12.${NC} 流媒体解锁测试"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-12]: " choice
        
        case $choice in
            1) run_script "scripts/network_test/backhaul_route_test.sh" ;;
            2) run_script "scripts/network_test/bandwidth_test.sh" ;;
            3) run_script "scripts/network_test/cdn_latency_test.sh" ;;
            4) run_script "scripts/network_test/ip_quality_test.sh" ;;
            5) run_script "scripts/network_test/network_connectivity_test.sh" ;;
            6) run_script "scripts/network_test/network_quality_test.sh" ;;
            7) run_script "scripts/network_test/network_security_scan.sh" ;;
            8) run_script "scripts/network_test/network_speedtest.sh" ;;
            9) run_script "scripts/network_test/network_traceroute.sh" ;;
            10) run_script "scripts/network_test/port_scanner.sh" ;;
            11) run_script "scripts/network_test/response_time_test.sh" ;;
            12) run_script "scripts/network_test/streaming_unlock_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 性能测试子菜单
performance_test_menu() {
    while true; do
        show_header
        echo -e "${PURPLE}性能测试${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} CPU基准测试"
        echo -e "${CYAN}  2.${NC} 磁盘IO基准测试"
        echo -e "${CYAN}  3.${NC} 内存基准测试"
        echo -e "${CYAN}  4.${NC} 网络吞吐量测试"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1) run_script "scripts/performance_test/cpu_benchmark.sh" ;;
            2) run_script "scripts/performance_test/disk_io_benchmark.sh" ;;
            3) run_script "scripts/performance_test/memory_benchmark.sh" ;;
            4) run_script "scripts/performance_test/network_throughput_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 服务安装子菜单
service_install_menu() {
    while true; do
        show_header
        echo -e "${YELLOW}服务安装${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} Docker安装"
        echo -e "${CYAN}  2.${NC} LNMP环境安装"
        echo -e "${CYAN}  3.${NC} Node.js安装"
        echo -e "${CYAN}  4.${NC} Python安装"
        echo -e "${CYAN}  5.${NC} Redis安装"
        echo -e "${CYAN}  6.${NC} 宝塔面板安装"
        echo -e "${CYAN}  7.${NC} 1Panel面板安装"
        echo -e "${CYAN}  8.${NC} WordPress安装"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-8]: " choice
        
        case $choice in
            1) run_script "scripts/service_install/install_docker.sh" ;;
            2) run_script "scripts/service_install/install_lnmp.sh" ;;
            3) run_script "scripts/service_install/install_nodejs.sh" ;;
            4) run_script "scripts/service_install/install_python.sh" ;;
            5) run_script "scripts/service_install/install_redis.sh" ;;
            6) run_script "scripts/service_install/install_bt_panel.sh" ;;
            7) run_script "scripts/service_install/install_1panel.sh" ;;
            8) run_script "scripts/service_install/install_wordpress.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 优秀脚本菜单
good_scripts_menu() {
    while true; do
        show_header
        echo -e "${RED}优秀脚本集合${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${GREEN}注意: 以下脚本均为第三方优秀脚本${NC}"
        echo ""
        run_script "scripts/good_scripts/good_scripts.sh"
        return
    done
}

# 梯子工具菜单
proxy_tools_menu() {
    while true; do
        show_header
        echo -e "${GREEN}梯子工具${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${YELLOW}注意: 请遵守当地法律法规${NC}"
        echo ""
        run_script "scripts/proxy_tools/proxy_tools.sh"
        return
    done
}

# 其他工具子菜单
other_tools_menu() {
    while true; do
        show_header
        echo -e "${BLUE}其他工具${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} BBR加速"
        echo -e "${CYAN}  2.${NC} Fail2ban安装"
        echo -e "${CYAN}  3.${NC} 安装哪吒监控"
        echo -e "${CYAN}  4.${NC} 设置SWAP"
        echo -e "${CYAN}  5.${NC} 哪吒Agent清理"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-5]: " choice
        
        case $choice in
            1) run_script "scripts/other_tools/bbr.sh" ;;
            2) run_script "scripts/other_tools/fail2ban.sh" ;;
            3) run_script "scripts/other_tools/nezha.sh" ;;
            4) run_script "scripts/other_tools/swap.sh" ;;
            5) 
                echo -e "${GREEN}正在执行哪吒Agent清理脚本...${NC}"
                bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)
                echo -e "${GREEN}执行完成！${NC}"
                read -p "按回车键返回菜单..."
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 更新脚本子菜单
update_scripts_menu() {
    while true; do
        show_header
        echo -e "${PURPLE}更新脚本${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} 触发自动更新"
        echo -e "${CYAN}  2.${NC} 更新核心脚本"
        echo -e "${CYAN}  3.${NC} 更新依赖环境"
        echo -e "${CYAN}  4.${NC} 更新功能工具脚本"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1) run_script "scripts/update_scripts/trigger_auto_update.sh" ;;
            2) run_script "scripts/update_scripts/update_core_scripts.sh" ;;
            3) run_script "scripts/update_scripts/update_dependencies.sh" ;;
            4) run_script "scripts/update_scripts/update_functional_tools.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 卸载脚本子菜单
uninstall_scripts_menu() {
    while true; do
        show_header
        echo -e "${YELLOW}卸载脚本${NC}"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        echo -e "${RED}警告: 以下操作可能会删除重要数据，请谨慎操作！${NC}"
        echo ""
        echo -e "${CYAN}  1.${NC} 清理服务残留"
        echo -e "${CYAN}  2.${NC} 回滚系统环境"
        echo -e "${CYAN}  3.${NC} 清除配置文件"
        echo -e "${CYAN}  4.${NC} 完全卸载模式"
        echo ""
        echo -e "${RED}  0.${NC} 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        echo ""
        
        read -p "请输入选项 [0-4]: " choice
        
        case $choice in
            1) run_script "scripts/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_script "scripts/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_script "scripts/uninstall_scripts/clear_configuration_files.sh" ;;
            4) 
                echo -e "${RED}警告: 完全卸载将删除所有相关文件和配置！${NC}"
                read -p "确定要继续吗？(y/N): " confirm
                if [[ $confirm == [yY] ]]; then
                    run_script "scripts/uninstall_scripts/full_uninstall.sh"
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}无效选项，请重新输入${NC}" && sleep 2 ;;
        esac
    done
}

# 主程序循环
main() {
    # 检查是否以root权限运行
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo bash $0 重新运行${NC}"
        exit 1
    fi
    
    # 初始化环境
    ensure_install_dir
    
    # 加载必要的文件
    load_common_functions || echo -e "${YELLOW}警告: 公共函数库加载失败，部分功能可能不可用${NC}"
    load_config
    
    # 显示开发版本提示
    show_header
    echo -e "${YELLOW}========== 开发测试版本提示 ==========${NC}"
    echo -e "${RED}注意: 这是开发测试版本！${NC}"
    echo -e "${YELLOW}某些功能可能还不稳定${NC}"
    echo -e "${YELLOW}如遇问题请反馈至: ${PROJECT_URL}${NC}"
    echo -e "${YELLOW}====================================${NC}"
    echo ""
    read -p "按回车键继续..."
    
    while true; do
        show_main_menu
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1) system_tools_menu ;;
            2) network_test_menu ;;
            3) performance_test_menu ;;
            4) service_install_menu ;;
            5) good_scripts_menu ;;
            6) proxy_tools_menu ;;
            7) other_tools_menu ;;
            8) update_scripts_menu ;;
            9) uninstall_scripts_menu ;;
            0) 
                echo ""
                echo -e "${GREEN}感谢使用VPS综合管理测试脚本！${NC}"
                echo -e "${YELLOW}项目地址: ${PROJECT_URL}${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入${NC}"
                sleep 2
                ;;
        esac
    done
}

# 运行主程序
main
