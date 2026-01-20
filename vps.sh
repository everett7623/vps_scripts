#!/bin/bash
# ==============================================================================
# 脚本名称: vps.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: vps_scripts/vps.sh
# 描述: VPS 综合管理脚本 (Remote Launcher)
#       这是一个轻量级引导器。它不包含具体功能，而是动态从 GitHub 
#       拉取子脚本并在内存中执行，实现"即用即走"的无残留体验。
# 作者: Jensfrank (Optimized)
# 版本: 2.6.0 (Remote Edition)
# 更新日期: 2026-01-20
# ==============================================================================

# --- 核心配置 ---
# 远程仓库的 RAW 根地址 (确保此地址可以访问)
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main"

# --- 颜色定义 ---
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'

# --- 全局变量 ---
DOWNLOAD_CMD=""

# ==============================================================================
# 基础工具函数
# ==============================================================================

# 1. 环境检查 (启动时执行一次)
check_environment() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_CMD="curl -sSL"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_CMD="wget -qO-"
    else
        echo -e "${RED}[错误] 系统未安装 curl 或 wget，无法下载远程脚本。${RESET}"
        echo -e "请尝试手动安装: ${YELLOW}apt install curl${RESET} 或 ${YELLOW}yum install curl${RESET}"
        exit 1
    fi
}

# 2. 打印标准页头
print_header() {
    clear
    echo -e "${GREEN}==========================================================${RESET}"
    echo -e "${CYAN}               VPS 综合管理脚本 (远程加载版)              ${RESET}"
    echo -e "${CYAN}                  Author: Jensfrank                       ${RESET}"
    echo -e "${YELLOW}   Project: https://github.com/everett7623/vps_scripts    ${RESET}"
    echo -e "${GREEN}==========================================================${RESET}"
    echo ""
}

# 3. 执行仓库内的子脚本
# 参数: $1 = 脚本在仓库中的相对路径 (例如 scripts/system_tools/info.sh)
run_repo_script() {
    local script_rel_path="${1}"
    local full_url="${GITHUB_RAW_URL}/${script_rel_path}"

    print_header
    echo -e "${YELLOW}正在加载模块...${RESET}"
    echo -e "${WHITE}> ${script_rel_path}${RESET}\n"

    # 使用检测好的命令下载并执行
    # 注意: 这里使用 bash <(...) 方式在内存中执行，不落地文件
    bash <($DOWNLOAD_CMD "${full_url}")

    # 捕获执行错误 (如果是 404 等网络错误)
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}[错误] 脚本执行失败或远程文件不存在。${RESET}"
        echo -e "URL: ${full_url}"
    fi

    echo -e "\n${CYAN}[按任意键返回菜单]${RESET}"
    read -n 1 -s -r
}

# 4. 执行第三方远程命令
# 参数: $1 = 完整的 Shell 命令
run_remote_command() {
    local command_to_run="${1}"
    
    print_header
    echo -e "${YELLOW}正在启动第三方工具...${RESET}"
    echo -e "${WHITE}> ${command_to_run}${RESET}\n"
    
    eval "${command_to_run}"
    
    echo -e "\n${CYAN}[按任意键返回菜单]${RESET}"
    read -n 1 -s -r
}

# ==============================================================================
# 菜单定义
# ==============================================================================

# 系统工具菜单
system_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 系统工具 (System Tools) ---${RESET}"
        echo "1. 查看系统信息"
        echo "2. 安装常用依赖"
        echo "3. 更新系统软件包"
        echo "4. 清理系统垃圾"
        echo "5. 系统参数优化"
        echo "6. 修改主机名"
        echo "7. 设置系统时区"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/system_tools/system_info.sh" ;;
            2) run_repo_script "scripts/system_tools/install_deps.sh" ;;
            3) run_repo_script "scripts/system_tools/system_update.sh" ;;
            4) run_repo_script "scripts/system_tools/system_clean.sh" ;;
            5) run_repo_script "scripts/system_tools/system_optimize.sh" ;;
            6) run_repo_script "scripts/system_tools/change_hostname.sh" ;;
            7) run_repo_script "scripts/system_tools/set_timezone.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 网络测试菜单
network_test_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 网络测试 (Network Test) ---${RESET}"
        echo "1. 回程路由测试"
        echo "2. 带宽测速"
        echo "3. CDN 延迟测试"
        echo "4. IP 质量测试"
        echo "5. 网络连通性测试"
        echo "6. 综合质量测试"
        echo "7. 网络安全扫描"
        echo "8. 网络测速 (Speedtest)"
        echo "9. 路由追踪 (Traceroute)"
        echo "10. 端口扫描"
        echo "11. 响应时间测试"
        echo "12. 流媒体解锁测试"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/network_test/backhaul_route_test.sh" ;;
            2) run_repo_script "scripts/network_test/bandwidth_test.sh" ;;
            3) run_repo_script "scripts/network_test/cdn_latency_test.sh" ;;
            4) run_repo_script "scripts/network_test/ip_quality_test.sh" ;;
            5) run_repo_script "scripts/network_test/network_connectivity_test.sh" ;;
            6) run_repo_script "scripts/network_test/network_quality_test.sh" ;;
            7) run_repo_script "scripts/network_test/network_security_scan.sh" ;;
            8) run_repo_script "scripts/network_test/network_speedtest.sh" ;;
            9) run_repo_script "scripts/network_test/network_traceroute.sh" ;;
            10) run_repo_script "scripts/network_test/port_scanner.sh" ;;
            11) run_repo_script "scripts/network_test/response_time_test.sh" ;;
            12) run_repo_script "scripts/network_test/streaming_unlock_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 性能测试菜单
performance_test_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 性能测试 (Benchmark) ---${RESET}"
        echo "1. CPU 基准测试"
        echo "2. 磁盘 IO 基准测试"
        echo "3. 内存基准测试"
        echo "4. 网络吞吐量测试"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/performance_test/cpu_benchmark.sh" ;;
            2) run_repo_script "scripts/performance_test/disk_io_benchmark.sh" ;;
            3) run_repo_script "scripts/performance_test/memory_benchmark.sh" ;;
            4) run_repo_script "scripts/performance_test/network_throughput_test.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 服务安装菜单
service_install_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 服务安装 (Service Install) ---${RESET}"
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
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/service_install/install_docker.sh" ;;
            2) run_repo_script "scripts/service_install/install_lnmp.sh" ;;
            3) run_repo_script "scripts/service_install/install_nodejs.sh" ;;
            4) run_repo_script "scripts/service_install/install_python.sh" ;;
            5) run_repo_script "scripts/service_install/install_redis.sh" ;;
            6) run_repo_script "scripts/service_install/install_bt_panel.sh" ;;
            7) run_repo_script "scripts/service_install/install_1panel.sh" ;;
            8) run_repo_script "scripts/service_install/install_wordpress.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 优秀脚本菜单 (第三方)
good_scripts_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 优秀第三方脚本 (Community) ---${RESET}"
        echo "1. YABS 综合性能测试"
        echo "2. XY-IP 质量体检"
        echo "3. XY-网络质量检测"
        echo "4. NodeLoc 聚合测试"
        echo "5. 融合怪 (SpiritlHL)"
        echo "6. 流媒体解锁测试"
        echo "7. 响应时间测试"
        echo "8. SSH 工具箱"
        echo "9. Jcnf 常用工具包"
        echo "10. 科技Lion 工具箱"
        echo "11. BlueSkyXN 工具箱"
        echo "12. 三网测速 (多/单线程)"
        echo "13. AutoTrace 三网回程路由"
        echo "14. 超售检测"
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
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 梯子工具菜单
ladder_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 梯子工具 (Proxy Tools) ---${RESET}"
        echo "1. 勇哥 Singbox 脚本"
        echo "2. F佬 Singbox 脚本"
        echo "3. 勇哥 X-UI 脚本"
        echo "4. 3X-UI 官方脚本"
        echo "5. 3X-UI 优化版脚本"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)" ;;
            2) run_remote_command "bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)" ;;
            3) run_remote_command "bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh)" ;;
            4) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)" ;;
            5) run_remote_command "bash <(curl -Ls https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh)" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 其他工具菜单
other_tools_menu() {
    while true; do
        print_header
        echo -e "${PURPLE}--- 其他工具 (Other Tools) ---${RESET}"
        echo "1. BBR 加速安装"
        echo "2. Fail2ban 安装与配置"
        echo "3. 哪吒监控 Agent 安装"
        echo "4. 设置 SWAP 虚拟内存"
        echo "5. 哪吒 Agent 清理"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/other_tools/bbr.sh" ;;
            2) run_repo_script "scripts/other_tools/fail2ban.sh" ;;
            3) run_repo_script "scripts/other_tools/nezha.sh" ;;
            4) run_repo_script "scripts/other_tools/swap.sh" ;;
            5) run_remote_command "bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# 更新提示菜单
update_scripts_menu() {
    print_header
    echo -e "${PURPLE}--- 更新脚本 ---${RESET}"
    echo -e "${YELLOW}您当前正在以在线模式运行。${RESET}"
    echo -e "每次运行此脚本时，都会自动获取 GitHub 上最新的版本。"
    echo -e "因此，您不需要执行更新操作，只需重新运行启动命令即可。"
    echo -e "\n${WHITE}bash <(curl -sL ${GITHUB_RAW_URL}/vps.sh)${RESET}\n"
    echo -e "\n${CYAN}[按任意键返回]${RESET}"
    read -n 1 -s -r
}

# 卸载菜单
uninstall_scripts_menu() {
     while true; do
        print_header
        echo -e "${PURPLE}--- 卸载/清理菜单 ---${RESET}"
        echo -e "${YELLOW}提示: 此菜单用于清理本脚本安装的服务残留。${RESET}"
        echo "1. 清理服务残留"
        echo "2. 回滚系统环境"
        echo "3. 清除配置文件"
        echo "4. 执行完全卸载"
        echo "--------------------"
        echo "0. 返回主菜单"
        echo ""
        read -p "请输入选项: " choice

        case $choice in
            1) run_repo_script "scripts/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_repo_script "scripts/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_repo_script "scripts/uninstall_scripts/clear_configuration_files.sh" ;;
            4) run_repo_script "scripts/uninstall_scripts/full_uninstall.sh" ;;
            0) return ;;
            *) echo -e "${RED}无效输入!${RESET}" && sleep 1 ;;
        esac
    done
}

# ==============================================================================
# 主程序入口
# ==============================================================================
main_menu() {
    # 1. 检查运行环境
    check_environment

    # 2. 进入主循环
    while true; do
        print_header
        echo -e "${BOLD}请选择功能类别:${RESET}"
        echo -e " 1. ${CYAN}系统工具${RESET}       - 系统信息、更新、清理、优化"
        echo -e " 2. ${CYAN}网络测试${RESET}       - 路由、带宽、IP质量、流媒体检测"
        echo -e " 3. ${CYAN}性能测试${RESET}       - CPU、磁盘、内存基准测试"
        echo -e " 4. ${CYAN}服务安装${RESET}       - Docker、LNMP、面板等"
        echo -e " 5. ${CYAN}优秀脚本${RESET}       - 集成社区热门第三方脚本"
        echo -e " 6. ${CYAN}梯子工具${RESET}       - 代理工具一键安装"
        echo -e " 7. ${CYAN}其他工具${RESET}       - BBR、Fail2ban、监控等"
        echo -e " 8. ${PURPLE}更新说明${RESET}       - 获取最新版本说明"
        echo -e " 9. ${RED}卸载清理${RESET}       - 清理安装的服务残留"
        echo "--------------------------------------------------------"
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
                echo -e "\n${RED}无效输入, 请输入 0-9!${RESET}"
                sleep 1
                ;;
        esac
    done
}

# 捕获 Ctrl+C 信号
trap 'echo -e "\n${GREEN}用户退出。${RESET}"; exit 0' INT TERM

# 启动主菜单
main_menu
