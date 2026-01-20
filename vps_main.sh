#!/bin/bash
# ======================================================================
# 📌 脚本名称: vps_main.sh (正式版)
# 📍 脚本路径: /vps_scripts/vps_main.sh
# 🚀 主要用途: VPS服务器管理主入口
# 🔧 适用系统: CentOS/Ubuntu/Debian
# 📅 版本信息: v2.0.0
# ======================================================================

# --- 1. 核心框架引导 ---
# 自动定位项目根目录 (兼容软链接、相对路径、绝对路径)
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 检查公共函数库是否存在
LIB_PATH="$PROJECT_ROOT/lib/common_functions.sh"
if [ ! -f "$LIB_PATH" ]; then
    echo -e "\033[0;31m[错误] 找不到公共函数库: $LIB_PATH\033[0m"
    echo -e "请确保项目结构完整，包含 lib/common_functions.sh"
    exit 1
fi

# 加载公共函数库 (自动获取颜色定义、日志函数、UI组件)
source "$LIB_PATH"

# 加载全局配置 (如果存在)
CONFIG_PATH="$PROJECT_ROOT/config/vps_scripts.conf"
if [ -f "$CONFIG_PATH" ]; then
    source "$CONFIG_PATH"
fi

# --- 2. 目录变量定义 ---
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
SYSTEM_TOOLS_DIR="$SCRIPTS_DIR/system_tools"
NETWORK_TEST_DIR="$SCRIPTS_DIR/network_test"
PERFORMANCE_TEST_DIR="$SCRIPTS_DIR/performance_test"
SERVICE_INSTALL_DIR="$SCRIPTS_DIR/service_install"
GOOD_SCRIPTS_DIR="$SCRIPTS_DIR/good_scripts"
PROXY_TOOLS_DIR="$SCRIPTS_DIR/proxy_tools"
OTHER_TOOLS_DIR="$SCRIPTS_DIR/other_tools"
UPDATE_SCRIPTS_DIR="$SCRIPTS_DIR/update_scripts"
UNINSTALL_SCRIPTS_DIR="$SCRIPTS_DIR/uninstall_scripts"

# --- 3. 界面显示函数 ---

# 清屏并显示标题 (使用公共库颜色变量)
show_title() {
    clear
    echo -e "${BOLD}${CYAN}======================================================================"
    echo -e "                 VPS 综合管理脚本 (v2.0.0 Local)                "
    echo -e "======================================================================${NC}"
    echo -e "${YELLOW}[提示] 本地安装模式 | 配置文件已加载${NC}"
    echo -e ""
}

# 主菜单函数
show_main_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 主菜单 - 功能选择 ====${NC}"
    echo -e "1. ${BOLD}系统工具${NC}         (查看信息、优化、清理、时区等)"
    echo -e "2. ${BOLD}网络测试${NC}         (带宽、路由、流媒体解锁、IP质量)"
    echo -e "3. ${BOLD}性能测试${NC}         (CPU、磁盘IO、内存、网络吞吐)"
    echo -e "4. ${BOLD}服务安装${NC}         (Docker、面板、数据库、语言环境)"
    echo -e "5. ${BOLD}第三方工具${NC}       (集成优秀的社区第三方脚本)"
    echo -e "6. ${BOLD}其他工具${NC}         (BBR、Fail2ban、哪吒监控、SWAP)"
    echo -e "7. ${BOLD}脚本更新${NC}         (更新核心代码与依赖环境)"
    echo -e "8. ${BOLD}卸载工具${NC}         (清理服务残留、回滚环境、卸载)"
    echo -e ""
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e "${YELLOW}[提示] 输入对应数字选择功能，按Enter确认${NC}"
}

# --- 4. 子菜单显示函数 ---

show_system_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 系统工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}查看系统信息${NC}        ($SYSTEM_TOOLS_DIR/system_info.sh)"
    echo -e "2. ${BOLD}安装常用依赖${NC}        ($SYSTEM_TOOLS_DIR/install_deps.sh)"
    echo -e "3. ${BOLD}更新系统${NC}            ($SYSTEM_TOOLS_DIR/update_system.sh)"
    echo -e "4. ${BOLD}清理系统${NC}            ($SYSTEM_TOOLS_DIR/clean_system.sh)"
    echo -e "5. ${BOLD}系统优化${NC}            ($SYSTEM_TOOLS_DIR/optimize_system.sh)"
    echo -e "6. ${BOLD}修改主机名${NC}          ($SYSTEM_TOOLS_DIR/change_hostname.sh)"
    echo -e "7. ${BOLD}设置时区${NC}            ($SYSTEM_TOOLS_DIR/set_timezone.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_network_test_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 网络测试 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}带宽测试${NC}            ($NETWORK_TEST_DIR/bandwidth_test.sh)"
    echo -e "2. ${BOLD}路由追踪${NC}            ($NETWORK_TEST_DIR/network_traceroute.sh)"
    echo -e "3. ${BOLD}回程路由测试${NC}        ($NETWORK_TEST_DIR/backhaul_route_test.sh)"
    echo -e "4. ${BOLD}CDN延迟测试${NC}         ($NETWORK_TEST_DIR/cdn_latency_test.sh)"
    echo -e "5. ${BOLD}IP质量测试${NC}          ($NETWORK_TEST_DIR/ip_quality_test.sh)"
    echo -e "6. ${BOLD}网络连通性测试${NC}      ($NETWORK_TEST_DIR/network_connectivity_test.sh)"
    echo -e "7. ${BOLD}网络综合质量测试${NC}    ($NETWORK_TEST_DIR/network_quality_test.sh)"
    echo -e "8. ${BOLD}流媒体解锁测试${NC}      ($NETWORK_TEST_DIR/streaming_unlock_test.sh)"
    echo -e "9. ${BOLD}网络测速${NC}            ($NETWORK_TEST_DIR/network_speedtest.sh)"
    echo -e "10. ${BOLD}端口扫描${NC}           ($NETWORK_TEST_DIR/port_scanner.sh)"
    echo -e "11. ${BOLD}响应时间测试${NC}       ($NETWORK_TEST_DIR/response_time_test.sh)"
    echo -e "12. ${BOLD}安全扫描${NC}           ($NETWORK_TEST_DIR/network_security_scan.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_performance_test_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 性能测试 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}CPU基准测试${NC}        ($PERFORMANCE_TEST_DIR/cpu_benchmark.sh)"
    echo -e "2. ${BOLD}磁盘IO测试${NC}         ($PERFORMANCE_TEST_DIR/disk_io_benchmark.sh)"
    echo -e "3. ${BOLD}内存测试${NC}           ($PERFORMANCE_TEST_DIR/memory_benchmark.sh)"
    echo -e "4. ${BOLD}网络吞吐量测试${NC}     ($PERFORMANCE_TEST_DIR/network_throughput_test.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_service_install_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 服务安装 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}Docker安装${NC}         ($SERVICE_INSTALL_DIR/docker.sh)"
    echo -e "2. ${BOLD}LNMP/LDNMP环境${NC}     ($SERVICE_INSTALL_DIR/ldnmp.sh)"
    echo -e "3. ${BOLD}Node.js安装${NC}        ($SERVICE_INSTALL_DIR/nodejs.sh)"
    echo -e "4. ${BOLD}Python安装${NC}         ($SERVICE_INSTALL_DIR/python.sh)"
    echo -e "5. ${BOLD}Redis安装${NC}          ($SERVICE_INSTALL_DIR/redis.sh)"
    echo -e "6. ${BOLD}宝塔面板安装${NC}       ($SERVICE_INSTALL_DIR/btpanel.sh)"
    echo -e "7. ${BOLD}1Panel面板安装${NC}     ($SERVICE_INSTALL_DIR/1panel.sh)"
    echo -e "8. ${BOLD}Wordpress安装${NC}      ($SERVICE_INSTALL_DIR/wordpress.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_third_party_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 第三方工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}优秀脚本整合${NC}        ($GOOD_SCRIPTS_DIR/good_scripts.sh)"
    echo -e "2. ${BOLD}梯子工具整合${NC}        ($PROXY_TOOLS_DIR/proxy_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_other_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 其他工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}BBR加速${NC}            ($OTHER_TOOLS_DIR/bbr.sh)"
    echo -e "2. ${BOLD}Fail2ban安装${NC}       ($OTHER_TOOLS_DIR/fail2ban.sh)"
    echo -e "3. ${BOLD}哪吒监控安装${NC}       ($OTHER_TOOLS_DIR/nezha.sh)"
    echo -e "4. ${BOLD}SWAP设置${NC}           ($OTHER_TOOLS_DIR/swap.sh)"
    echo -e "5. ${BOLD}哪吒Agent清理${NC}      ($OTHER_TOOLS_DIR/nezha_cleaner.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_update_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 脚本更新 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}触发自动更新${NC}        ($UPDATE_SCRIPTS_DIR/trigger_auto_update.sh)"
    echo -e "2. ${BOLD}更新核心脚本${NC}        ($UPDATE_SCRIPTS_DIR/update_core_scripts.sh)"
    echo -e "3. ${BOLD}更新依赖环境${NC}        ($UPDATE_SCRIPTS_DIR/update_dependencies.sh)"
    echo -e "4. ${BOLD}更新功能工具${NC}        ($UPDATE_SCRIPTS_DIR/update_functional_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

show_uninstall_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 卸载工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}清理服务残留${NC}        ($UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh)"
    echo -e "2. ${BOLD}回滚系统环境${NC}        ($UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh)"
    echo -e "3. ${BOLD}清除配置文件${NC}        ($UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh)"
    echo -e "4. ${BOLD}完全卸载${NC}            ($UNINSTALL_SCRIPTS_DIR/full_uninstall.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
}

# --- 5. 功能执行函数 ---

execute_system_tool() {
    case $1 in
        1) bash "$SYSTEM_TOOLS_DIR/system_info.sh" ;;
        2) bash "$SYSTEM_TOOLS_DIR/install_deps.sh" ;;
        3) bash "$SYSTEM_TOOLS_DIR/update_system.sh" ;;
        4) bash "$SYSTEM_TOOLS_DIR/clean_system.sh" ;;
        5) bash "$SYSTEM_TOOLS_DIR/optimize_system.sh" ;;
        6) bash "$SYSTEM_TOOLS_DIR/change_hostname.sh" ;;
        7) bash "$SYSTEM_TOOLS_DIR/set_timezone.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_network_test() {
    case $1 in
        1) bash "$NETWORK_TEST_DIR/bandwidth_test.sh" ;;
        2) bash "$NETWORK_TEST_DIR/network_traceroute.sh" ;;
        3) bash "$NETWORK_TEST_DIR/backhaul_route_test.sh" ;;
        4) bash "$NETWORK_TEST_DIR/cdn_latency_test.sh" ;;
        5) bash "$NETWORK_TEST_DIR/ip_quality_test.sh" ;;
        6) bash "$NETWORK_TEST_DIR/network_connectivity_test.sh" ;;
        7) bash "$NETWORK_TEST_DIR/network_quality_test.sh" ;;
        8) bash "$NETWORK_TEST_DIR/streaming_unlock_test.sh" ;;
        9) bash "$NETWORK_TEST_DIR/network_speedtest.sh" ;;
        10) bash "$NETWORK_TEST_DIR/port_scanner.sh" ;;
        11) bash "$NETWORK_TEST_DIR/response_time_test.sh" ;;
        12) bash "$NETWORK_TEST_DIR/network_security_scan.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_performance_test() {
    case $1 in
        1) bash "$PERFORMANCE_TEST_DIR/cpu_benchmark.sh" ;;
        2) bash "$PERFORMANCE_TEST_DIR/disk_io_benchmark.sh" ;;
        3) bash "$PERFORMANCE_TEST_DIR/memory_benchmark.sh" ;;
        4) bash "$PERFORMANCE_TEST_DIR/network_throughput_test.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_service_install() {
    # 修正：部分脚本名与菜单项的对应关系已更新为标准命名
    case $1 in
        1) bash "$SERVICE_INSTALL_DIR/docker.sh" ;;
        2) bash "$SERVICE_INSTALL_DIR/ldnmp.sh" ;;
        3) bash "$SERVICE_INSTALL_DIR/nodejs.sh" ;;
        4) bash "$SERVICE_INSTALL_DIR/python.sh" ;;
        5) bash "$SERVICE_INSTALL_DIR/redis.sh" ;;
        6) bash "$SERVICE_INSTALL_DIR/btpanel.sh" ;;
        7) bash "$SERVICE_INSTALL_DIR/1panel.sh" ;;
        8) bash "$SERVICE_INSTALL_DIR/wordpress.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_third_party_tools() {
    case $1 in
        1) bash "$GOOD_SCRIPTS_DIR/good_scripts.sh" ;;
        2) bash "$PROXY_TOOLS_DIR/proxy_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_other_tools() {
    case $1 in
        1) bash "$OTHER_TOOLS_DIR/bbr.sh" ;;
        2) bash "$OTHER_TOOLS_DIR/fail2ban.sh" ;;
        3) bash "$OTHER_TOOLS_DIR/nezha.sh" ;;
        4) bash "$OTHER_TOOLS_DIR/swap.sh" ;;
        5) bash "$OTHER_TOOLS_DIR/nezha_cleaner.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_update_scripts() {
    case $1 in
        1) bash "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
        2) bash "$UPDATE_SCRIPTS_DIR/update_core_scripts.sh" ;;
        3) bash "$UPDATE_SCRIPTS_DIR/update_dependencies.sh" ;;
        4) bash "$UPDATE_SCRIPTS_DIR/update_functional_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

execute_uninstall_scripts() {
    case $1 in
        1) bash "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
        2) bash "$UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh" ;;
        3) bash "$UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh" ;;
        4) bash "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 1 ;;
    esac
}

# --- 6. 主逻辑循环 ---

main() {
    # 检查基本依赖 (使用公共库函数)
    ensure_command "curl"
    
    while true; do
        show_main_menu
        read -p "请选择功能: " choice
        
        case $choice in
            1) # 系统工具
                while true; do
                    show_system_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_system_tool $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            2) # 网络测试
                while true; do
                    show_network_test_menu
                    read -p "请选择功能: " subchoice
                    execute_network_test $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            3) # 性能测试
                while true; do
                    show_performance_test_menu
                    read -p "请选择功能: " subchoice
                    execute_performance_test $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            4) # 服务安装
                while true; do
                    show_service_install_menu
                    read -p "请选择功能: " subchoice
                    execute_service_install $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            5) # 第三方工具
                while true; do
                    show_third_party_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_third_party_tools $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            6) # 其他工具
                while true; do
                    show_other_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_other_tools $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            7) # 脚本更新
                while true; do
                    show_update_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_update_scripts $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            8) # 卸载工具
                while true; do
                    show_uninstall_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_uninstall_scripts $subchoice
                    [ "$subchoice" == "0" ] && exit 0
                    [ "$subchoice" == "b" ] && break
                    echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                    read -r
                done
                ;;
            0) # 退出脚本
                print_success "感谢使用 VPS 综合管理脚本，再见！"
                exit 0
                ;;
            *)
                print_error "无效选择，请输入 1-8 或 0"
                sleep 1
                ;;
        esac
    done
}

# 启动主函数
main
