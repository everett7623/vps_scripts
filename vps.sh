#!/bin/bash

# ==============================================================================
#                              VPS Management Scripts
#
#      Project: https://github.com/everett7623/vps_scripts/
#      Author: Jensfrank
#      Version: 2.0.0
#
#      This script is the main entry point for managing a VPS.
#      It provides a menu-driven interface to access various tools.
# ==============================================================================

# --- Colors for Terminal Output ---
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# --- Script Base Directory ---
# Detects the script's absolute path, making it runnable from anywhere.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
SUB_SCRIPTS_DIR="${SCRIPT_DIR}/vps_scripts/scripts"

# --- Function to display a header ---
print_header() {
    clear
    echo -e "${GREEN}====================================================${RESET}"
    echo -e "${CYAN}             VPS 综合管理脚本 (vps.sh)             ${RESET}"
    echo -e "${YELLOW}       Project: github.com/everett7623/vps_scripts       ${RESET}"
    echo -e "${GREEN}====================================================${RESET}"
    echo ""
}

# --- Function to execute a local script ---
run_script() {
    local script_path="${1}"
    if [ -f "${script_path}" ]; then
        # Ensure the script is executable
        chmod +x "${script_path}"
        # Execute the script
        print_header
        echo -e "${YELLOW}正在执行脚本: ${script_path}${RESET}\n"
        bash "${script_path}"
    else
        echo -e "${RED}错误: 脚本未找到: ${script_path}${RESET}"
    fi
    echo -e "\n${CYAN}按任意键返回...${RESET}"
    read -n 1 -s -r
}

# --- Function to execute a remote script/command ---
run_remote_command() {
    local command_to_run="${1}"
    print_header
    echo -e "${YELLOW}正在执行以下远程命令:${RESET}"
    echo -e "${WHITE}${command_to_run}${RESET}\n"
    if eval "${command_to_run}"; then
        echo -e "\n${GREEN}命令执行成功。${RESET}"
    else
        echo -e "\n${RED}命令执行失败。${RESET}"
    fi
    echo -e "\n${CYAN}按任意键返回...${RESET}"
    read -n 1 -s -r
}


# ==============================================================================
#                              SUB-MENU DEFINITIONS
# ==============================================================================

# --- System Tools Menu ---
system_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 系统工具菜单 ---${RESET}"
        echo "1. 查看系统信息"
        echo "2. 安装常用依赖"
        echo "3. 更新系统"
        echo "4. 清理系统"
        echo "5. 系统优化"
        echo "6. 修改主机名"
        echo "7. 设置时区"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-7]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/system_tools/system_info.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/system_tools/install_deps.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/system_tools/update_system.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/system_tools/system_clean.sh" ;;
            5) run_script "${SUB_SCRIPTS_DIR}/system_tools/system_optimize.sh" ;;
            6) run_script "${SUB_SCRIPTS_DIR}/system_tools/change_hostname.sh" ;;
            7) run_script "${SUB_SCRIPTS_DIR}/system_tools/set_timezone.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Network Test Menu ---
network_test_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 网络测试菜单 ---${RESET}"
        echo "1. 回程路由测试"
        echo "2. 带宽测试"
        echo "3. CDN 延迟测试"
        echo "4. IP 质量测试"
        echo "5. 网络连通性测试"
        echo "6. 综合质量测试"
        echo "7. 网络安全扫描"
        echo "8. 网络测速"
        echo "9. 路由追踪 (Traceroute)"
        echo "10. 端口扫描"
        echo "11. 响应时间测试"
        echo "12. 流媒体解锁测试"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-12]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/network_test/backhaul_route_test.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/network_test/bandwidth_test.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/network_test/cdn_latency_test.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/network_test/ip_quality_test.sh" ;;
            5) run_script "${SUB_SCRIPTS_DIR}/network_test/network_connectivity_test.sh" ;;
            6) run_script "${SUB_SCRIPTS_DIR}/network_test/network_quality_test.sh" ;;
            7) run_script "${SUB_SCRIPTS_DIR}/network_test/network_security_scan.sh" ;;
            8) run_script "${SUB_SCRIPTS_DIR}/network_test/network_speedtest.sh" ;;
            9) run_script "${SUB_SCRIPTS_DIR}/network_test/network_traceroute.sh" ;;
            10) run_script "${SUB_SCRIPTS_DIR}/network_test/port_scanner.sh" ;;
            11) run_script "${SUB_SCRIPTS_DIR}/network_test/response_time_test.sh" ;;
            12) run_script "${SUB_SCRIPTS_DIR}/network_test/streaming_unlock_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Performance Test Menu ---
performance_test_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 性能测试菜单 ---${RESET}"
        echo "1. CPU 基准测试"
        echo "2. 磁盘 IO 基准测试"
        echo "3. 内存基准测试"
        echo "4. 网络吞吐量测试"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-4]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/performance_test/cpu_benchmark.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/performance_test/disk_io_benchmark.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/performance_test/memory_benchmark.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/performance_test/network_throughput_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Service Install Menu ---
service_install_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 服务安装菜单 ---${RESET}"
        echo "1. 安装 Docker"
        echo "2. 安装 LNMP 环境"
        echo "3. 安装 Node.js"
        echo "4. 安装 Python"
        echo "5. 安装 Redis"
        echo "6. 安装 宝塔面板"
        echo "7. 安装 1Panel 面板"
        echo "8. 安装 Wordpress"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-8]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/service_install/install_docker.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/service_install/install_lnmp.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/service_install/install_nodejs.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/service_install/install_python.sh" ;;
            5) run_script "${SUB_SCRIPTS_DIR}/service_install/install_redis.sh" ;;
            6) run_script "${SUB_SCRIPTS_DIR}/service_install/install_bt_panel.sh" ;;
            7) run_script "${SUB_SCRIPTS_DIR}/service_install/install_1panel.sh" ;;
            8) run_script "${SUB_SCRIPTS_DIR}/service_install/install_wordpress.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Good Scripts Menu ---
good_scripts_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 第三方优秀脚本菜单 ---${RESET}"
        echo "1. Yabs (VPS 综合性能测试)"
        echo "2. XY-IP质量体检脚本"
        echo "3. XY-网络质量检测脚本"
        echo "4. NodeLoc聚合测试脚本"
        echo "5. 融合怪测试"
        echo "6. 流媒体解锁测试"
        echo "7. 响应测试脚本 (NodeBench)"
        echo "8. VPS一键脚本工具箱 (eooce)"
        echo "9. Jcnf 常用脚本工具包"
        echo "10. 科技Lion脚本"
        echo "11. BlueSkyXN脚本 (SKY-BOX)"
        echo "12. 三网测速 (多/单线程)"
        echo "13. AutoTrace三网回程路由"
        echo "14. 超售测试"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-14]: " choice

        case $choice in
            1) run_remote_command "wget -qO- yabs.sh | bash" ;;
            2) run_remote_command "bash <(curl -Ls IP.Check.Place)" ;;
            3) run_remote_command "bash <(curl -Ls Net.Check.Place)" ;;
            4) run_remote_command "curl -sSL abc.sd | bash" ;;
            5) run_remote_command "curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh" ;;
            6) run_remote_command "bash <(curl -L -s media.ispvps.com)" ;;
            7) run_remote_command "bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)" ;;
            8) run_remote_command "curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh" ;;
            9) run_remote_command "wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh" ;;
            10) run_remote_command "bash <(curl -sL kejilion.sh)" ;;
            11) run_remote_command "wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh" ;;
            12) run_remote_command "bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh)" ;;
            13) run_remote_command "wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh" ;;
            14) run_remote_command "wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Ladder Tools Menu ---
ladder_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 梯子工具菜单 ---${RESET}"
        echo "1. 勇哥 Singbox 脚本"
        echo "2. F佬 Singbox 脚本"
        echo "3. 勇哥 X-UI 脚本"
        echo "4. 3X-UI 官方脚本"
        echo "5. 3X-UI 优化版脚本"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-5]: " choice

        case $choice in
            1) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)" ;;
            2) run_remote_command "bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)" ;;
            3) run_remote_command "bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh)" ;;
            4) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)" ;;
            5) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh)" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Other Tools Menu ---
other_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 其他工具菜单 ---${RESET}"
        echo "1. BBR 加速"
        echo "2. Fail2ban 安装与配置"
        echo "3. 安装哪吒监控 Agent"
        echo "4. 设置 SWAP 虚拟内存"
        echo "5. 哪吒 Agent 清理"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-5]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/other_tools/bbr.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/other_tools/fail2ban.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/other_tools/nezha.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/other_tools/swap.sh" ;;
            5) run_remote_command "bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Update Scripts Menu ---
update_scripts_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 更新脚本菜单 ---${RESET}"
        echo "1. 触发自动更新"
        echo "2. 更新核心脚本"
        echo "3. 更新依赖环境"
        echo "4. 更新功能工具脚本"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-4]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/update_scripts/trigger_auto_update.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/update_scripts/update_core_scripts.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/update_scripts/update_dependencies.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/update_scripts/update_functional_tools.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}

# --- Uninstall Scripts Menu ---
uninstall_scripts_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 卸载脚本菜单 ---${RESET}"
        echo "1. 清理服务残留"
        echo "2. 回滚系统环境"
        echo "3. 清除配置文件"
        echo "4. !! 完全卸载此脚本 !! "
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项 [0-4]: " choice

        case $choice in
            1) run_script "${SUB_SCRIPTS_DIR}/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_script "${SUB_SCRIPTS_DIR}/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_script "${SUB_SCRIPTS_DIR}/uninstall_scripts/clear_configuration_files.sh" ;;
            4) run_script "${SUB_SCRIPTS_DIR}/uninstall_scripts/full_uninstall.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入, 请重新选择!${RESET}" && sleep 1 ;;
        esac
    done
}


# ==============================================================================
#                                MAIN MENU
# ==============================================================================
main_menu() {
    while true; do
        print_header
        echo -e "${YELLOW}请选择要执行的操作类别:${RESET}"
        echo -e " 1. ${CYAN}系统工具${RESET}       - 系统信息、更新、清理、优化等"
        echo -e " 2. ${CYAN}网络测试${RESET}       - 路由、带宽、延迟、IP质量、流媒体等"
        echo -e " 3. ${CYAN}性能测试${RESET}       - CPU、磁盘IO、内存、网络吞吐量基准测试"
        echo -e " 4. ${CYAN}服务安装${RESET}       - Docker、LNMP、面板、Wordpress等"
        echo -e " 5. ${CYAN}优秀脚本${RESET}       - 集成社区广受好评的第三方脚本"
        echo -e " 6. ${CYAN}梯子工具${RESET}       - 常用代理工具一键安装脚本"
        echo -e " 7. ${CYAN}其他工具${RESET}       - BBR、Fail2ban、SWAP、哪吒监控等"
        echo -e " 8. ${PURPLE}更新脚本${RESET}       - 更新此脚本套件"
        echo -e " 9. ${RED}卸载脚本${RESET}       - 从系统中移除此脚本或相关组件"
        echo "----------------------------------------------------"
        echo -e " 0. ${WHITE}退出脚本${RESET}"
        echo ""
        read -p "请输入选项 [0-9]: " choice

        case $choice in
            1) system_tools_menu ;;
            2) network_test_menu ;;
            3) performance_test_menu ;;
            4) service_install_menu ;;
            5) good_scripts_menu ;;
            6) ladder_tools_menu ;;
            7) other_tools_menu ;;
            8) update_scripts_menu ;;
            9) uninstall_scripts_menu ;;
            0)
                echo -e "\n${GREEN}感谢使用, 再见!${RESET}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}无效输入, 请输入 0-9 之间的数字!${RESET}"
                sleep 2
                ;;
        esac
    done
}

# --- Script Execution Start ---
main_menu
