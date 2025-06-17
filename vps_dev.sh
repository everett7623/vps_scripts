#!/bin/bash
# 加载配置和公共函数
source "$(dirname "$0")/config/vps_scripts.conf"
source "$(dirname "$0")/lib/common_functions.sh"

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${CYAN}                VPS开发测试脚本 v${VERSION}               ${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${WHITE}作者: Jensfrank${NC}"
    echo -e "${WHITE}项目地址: https://github.com/everett7623/vps_scripts/${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
}

# 显示主菜单
show_main_menu() {
    show_welcome
    echo -e "${GREEN}请选择功能类别:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}系统工具${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}网络测试${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}性能测试${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}服务安装${NC}"
    echo -e "${YELLOW}5.${NC} ${WHITE}第三方优秀脚本整合${NC}"
    echo -e "${YELLOW}6.${NC} ${WHITE}梯子工具整合${NC}"
    echo -e "${YELLOW}7.${NC} ${WHITE}其他工具${NC}"
    echo -e "${YELLOW}8.${NC} ${WHITE}脚本更新${NC}"
    echo -e "${YELLOW}9.${NC} ${WHITE}卸载脚本${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}退出${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 系统工具子菜单
show_system_tools_menu() {
    show_welcome
    echo -e "${GREEN}系统工具:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}查看系统信息${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}安装常用依赖${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}更新系统${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}清理系统${NC}"
    echo -e "${YELLOW}5.${NC} ${WHITE}系统优化${NC}"
    echo -e "${YELLOW}6.${NC} ${WHITE}修改主机名${NC}"
    echo -e "${YELLOW}7.${NC} ${WHITE}设置时区${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 网络测试子菜单
show_network_test_menu() {
    show_welcome
    echo -e "${GREEN}网络测试:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}回程路由测试${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}带宽测试${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}CDN延迟测试${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}IP质量测试${NC}"
    echo -e "${YELLOW}5.${NC} ${WHITE}连通性测试${NC}"
    echo -e "${YELLOW}6.${NC} ${WHITE}综合质量测试${NC}"
    echo -e "${YELLOW}7.${NC} ${WHITE}安全扫描${NC}"
    echo -e "${YELLOW}8.${NC} ${WHITE}网络测速${NC}"
    echo -e "${YELLOW}9.${NC} ${WHITE}路由追踪${NC}"
    echo -e "${YELLOW}10.${NC} ${WHITE}端口扫描${NC}"
    echo -e "${YELLOW}11.${NC} ${WHITE}响应时间测试${NC}"
    echo -e "${YELLOW}12.${NC} ${WHITE}流媒体解锁测试${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 性能测试子菜单
show_performance_test_menu() {
    show_welcome
    echo -e "${GREEN}性能测试:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}CPU基准测试${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}磁盘IO测试${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}内存测试${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}网络吞吐量测试${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 服务安装子菜单
show_service_install_menu() {
    show_welcome
    echo -e "${GREEN}服务安装:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}Docker安装${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}LNMP环境安装${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}Node.js安装${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}Python安装${NC}"
    echo -e "${YELLOW}5.${NC} ${WHITE}Redis安装${NC}"
    echo -e "${YELLOW}6.${NC} ${WHITE}宝塔面板安装${NC}"
    echo -e "${YELLOW}7.${NC} ${WHITE}1Panel面板安装${NC}"
    echo -e "${YELLOW}8.${NC} ${WHITE}Wordpress安装${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 第三方优秀脚本整合子菜单
show_good_scripts_menu() {
    show_welcome
    echo -e "${GREEN}第三方优秀脚本整合:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}整合脚本${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 梯子工具整合子菜单
show_proxy_tools_menu() {
    show_welcome
    echo -e "${GREEN}梯子工具整合:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}整合脚本${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 其他工具子菜单
show_other_tools_menu() {
    show_welcome
    echo -e "${GREEN}其他工具:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}BBR加速${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}Fail2ban安装${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}哪吒监控安装${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}SWAP设置${NC}"
    echo -e "${YELLOW}5.${NC} ${WHITE}哪吒Agent清理${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 脚本更新子菜单
show_update_scripts_menu() {
    show_welcome
    echo -e "${GREEN}脚本更新:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}触发自动更新${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}更新核心脚本${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}更新依赖环境${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}更新功能工具${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 卸载脚本子菜单
show_uninstall_scripts_menu() {
    show_welcome
    echo -e "${GREEN}卸载脚本:${NC}"
    echo -e "${YELLOW}1.${NC} ${WHITE}清理服务残留${NC}"
    echo -e "${YELLOW}2.${NC} ${WHITE}回滚系统环境${NC}"
    echo -e "${YELLOW}3.${NC} ${WHITE}清除配置文件${NC}"
    echo -e "${YELLOW}4.${NC} ${WHITE}完全卸载${NC}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${RED}0.${NC} ${WHITE}返回主菜单${NC}"
    echo -e "${CYAN}=====================================================${NC}"
}

# 执行系统工具子菜单选项
handle_system_tools_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/system_tools/system_info.sh" ;;
        2) source "$SCRIPTS_DIR/system_tools/install_deps.sh" ;;
        3) source "$SCRIPTS_DIR/system_tools/update_system.sh" ;;
        4) source "$SCRIPTS_DIR/system_tools/clean_system.sh" ;;
        5) source "$SCRIPTS_DIR/system_tools/optimize_system.sh" ;;
        6) source "$SCRIPTS_DIR/system_tools/change_hostname.sh" ;;
        7) source "$SCRIPTS_DIR/system_tools/set_timezone.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行网络测试子菜单选项
handle_network_test_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/network_test/backhaul_route_test.sh" ;;
        2) source "$SCRIPTS_DIR/network_test/bandwidth_test.sh" ;;
        3) source "$SCRIPTS_DIR/network_test/cdn_latency_test.sh" ;;
        4) source "$SCRIPTS_DIR/network_test/ip_quality_test.sh" ;;
        5) source "$SCRIPTS_DIR/network_test/network_connectivity_test.sh" ;;
        6) source "$SCRIPTS_DIR/network_test/network_quality_test.sh" ;;
        7) source "$SCRIPTS_DIR/network_test/network_security_scan.sh" ;;
        8) source "$SCRIPTS_DIR/network_test/network_speedtest.sh" ;;
        9) source "$SCRIPTS_DIR/network_test/network_traceroute.sh" ;;
        10) source "$SCRIPTS_DIR/network_test/port_scanner.sh" ;;
        11) source "$SCRIPTS_DIR/network_test/response_time_test.sh" ;;
        12) source "$SCRIPTS_DIR/network_test/streaming_unlock_test.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行性能测试子菜单选项
handle_performance_test_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/performance_test/cpu_benchmark.sh" ;;
        2) source "$SCRIPTS_DIR/performance_test/disk_io_benchmark.sh" ;;
        3) source "$SCRIPTS_DIR/performance_test/memory_benchmark.sh" ;;
        4) source "$SCRIPTS_DIR/performance_test/network_throughput_test.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行服务安装子菜单选项
handle_service_install_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/service_install/install_docker.sh" ;;
        2) source "$SCRIPTS_DIR/service_install/install_lnmp.sh" ;;
        3) source "$SCRIPTS_DIR/service_install/install_nodejs.sh" ;;
        4) source "$SCRIPTS_DIR/service_install/install_python.sh" ;;
        5) source "$SCRIPTS_DIR/service_install/install_redis.sh" ;;
        6) source "$SCRIPTS_DIR/service_install/install_bt_panel.sh" ;;
        7) source "$SCRIPTS_DIR/service_install/install_1panel.sh" ;;
        8) source "$SCRIPTS_DIR/service_install/install_wordpress.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行第三方优秀脚本整合子菜单选项
handle_good_scripts_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/good_scripts/good_scripts.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行梯子工具整合子菜单选项
handle_proxy_tools_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/proxy_tools/proxy_tools.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行其他工具子菜单选项
handle_other_tools_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/other_tools/bbr.sh" ;;
        2) source "$SCRIPTS_DIR/other_tools/fail2ban.sh" ;;
        3) source "$SCRIPTS_DIR/other_tools/nezha.sh" ;;
        4) source "$SCRIPTS_DIR/other_tools/swap.sh" ;;
        5) source "$SCRIPTS_DIR/other_tools/nezha_cleaner.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行脚本更新子菜单选项
handle_update_scripts_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/update_scripts/trigger_auto_update.sh" ;;
        2) source "$SCRIPTS_DIR/update_scripts/update_core_scripts.sh" ;;
        3) source "$SCRIPTS_DIR/update_scripts/update_dependencies.sh" ;;
        4) source "$SCRIPTS_DIR/update_scripts/update_functional_tools.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 执行卸载脚本子菜单选项
handle_uninstall_scripts_choice() {
    case $1 in
        1) source "$SCRIPTS_DIR/uninstall_scripts/clean_service_residues.sh" ;;
        2) source "$SCRIPTS_DIR/uninstall_scripts/rollback_system_environment.sh" ;;
        3) source "$SCRIPTS_DIR/uninstall_scripts/clear_configuration_files.sh" ;;
        4) source "$SCRIPTS_DIR/uninstall_scripts/full_uninstall.sh" ;;
        0) ;; # 返回主菜单
        *) echo -e "${RED}错误：无效选择！${NC}" && sleep 1 ;;
    esac
}

# 主程序逻辑
main() {
    while true; do
        show_main_menu
        read -p "请输入选择 [0-9]: " choice
        
        case $choice in
            1)  # 系统工具
                while true; do
                    show_system_tools_menu
                    read -p "请输入选择 [0-7]: " sub_choice
                    handle_system_tools_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            2)  # 网络测试
                while true; do
                    show_network_test_menu
                    read -p "请输入选择 [0-12]: " sub_choice
                    handle_network_test_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            3)  # 性能测试
                while true; do
                    show_performance_test_menu
                    read -p "请输入选择 [0-4]: " sub_choice
                    handle_performance_test_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            4)  # 服务安装
                while true; do
                    show_service_install_menu
                    read -p "请输入选择 [0-8]: " sub_choice
                    handle_service_install_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            5)  # 第三方优秀脚本整合
                while true; do
                    show_good_scripts_menu
                    read -p "请输入选择 [0-1]: " sub_choice
                    handle_good_scripts_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            6)  # 梯子工具整合
                while true; do
                    show_proxy_tools_menu
                    read -p "请输入选择 [0-1]: " sub_choice
                    handle_proxy_tools_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            7)  # 其他工具
                while true; do
                    show_other_tools_menu
                    read -p "请输入选择 [0-5]: " sub_choice
                    handle_other_tools_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            8)  # 脚本更新
                while true; do
                    show_update_scripts_menu
                    read -p "请输入选择 [0-4]: " sub_choice
                    handle_update_scripts_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            9)  # 卸载脚本
                while true; do
                    show_uninstall_scripts_menu
                    read -p "请输入选择 [0-4]: " sub_choice
                    handle_uninstall_scripts_choice $sub_choice
                    [[ $sub_choice -eq 0 ]] && break
                done
                ;;
            0)  # 退出
                echo -e "${GREEN}感谢使用 VPS 开发测试脚本！${NC}"
                exit 0
                ;;
            *)  # 无效选择
                echo -e "${RED}错误：无效选择！${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主程序
main    
