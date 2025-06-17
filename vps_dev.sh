#!/bin/bash
# ======================================================================
# 📌 脚本名称: vps_dev.sh (测试版)
# 📍 脚本路径: /vps_scripts/vps_dev.sh
# 🚀 主要用途: VPS服务器测试与开发功能集成
# 🔧 适用系统: CentOS/Ubuntu/Debian
# 📅 更新时间: 2025年06月18日
# ======================================================================

# 颜色定义 - 保持与vps.sh一致的视觉风格
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[0;33m\'
BLUE=\'\\033[0;34m\'
PURPLE=\'\\033[0;35m\'
CYAN=\'\\033[0;36m\'
NC=\'\\033[0m\'      # 恢复默认颜色
BOLD=\'\\033[1m\'    # 加粗

# 【关键修复】正确获取脚本所在目录，兼容软链接等情况
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# 重新拼接各功能目录路径
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
SYSTEM_TOOLS_DIR="$SCRIPTS_DIR/system_tools"
NETWORK_TEST_DIR="$SCRIPTS_DIR/network_test"
PERFORMANCE_TEST_DIR="$SCRIPTS_DIR/performance_test"
SERVICE_INSTALL_DIR="$SCRIPTS_DIR/service_install"
GOOD_SCRIPTS_DIR="$SCRIPTS_DIR/good_scripts"
PROXY_TOOLS_DIR="$SCRIPTS_DIR/proxy_tools"
OTHER_TOOLS_DIR="$SCRIPTS_DIR/other_tools"
UPDATE_SCRIPTS_DIR="$SCRIPTS_DIR/update_scripts"
UNINSTALL_SCRIPTS_DIR="$SCRIPTS_DIR/uninstall_scripts"

# 检查脚本依赖
check_dependencies() {
    echo -e "${YELLOW}[信息] 正在检查脚本运行依赖...${NC}"
    # 这里可以添加依赖检查逻辑，示例检查curl
    command -v curl >/dev/null 2>&1 || { echo -e "${RED}[错误] 未找到curl命令，请先安装curl${NC}"; exit 1; }
    echo -e "${GREEN}[成功] 依赖检查完成${NC}"
}

# 清屏并显示标题
show_title() {
    clear
    echo -e "${BOLD}${CYAN}======================================================================"
    echo -e "                  VPS_DEV.SH - 测试开发脚本 (v1.0.0-dev)                "
    echo -e "======================================================================${NC}"
    echo -e "${YELLOW}[提示] 这是开发测试版本，用于功能验证和调试${NC}"
    echo -e ""
}

# 主菜单函数
show_main_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 主菜单 - VPS 开发测试工具 ====${NC}"
    echo -e "1. ${BOLD}系统工具${NC}         (查看系统信息、优化系统等)"
    echo -e "2. ${BOLD}网络测试${NC}         (带宽、路由、CDN延迟等)"
    echo -e "3. ${BOLD}性能测试${NC}         (CPU、磁盘、内存基准测试)"
    echo -e "4. ${BOLD}服务安装${NC}         (Docker、LNMP、Node.js等)"
    echo -e "5. ${BOLD}第三方工具${NC}       (整合优秀第三方脚本)"
    echo -e "6. ${BOLD}其他工具${NC}         (BBR加速、哪吒监控等)"
    echo -e "7. ${BOLD}脚本更新${NC}         (更新核心脚本、依赖环境)"
    echo -e "8. ${BOLD}卸载工具${NC}         (清理服务残留、回滚环境)"
    echo -e ""
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
    echo -e "${YELLOW}[提示] 输入对应数字选择功能，按Enter确认${NC}"
}

# 系统工具子菜单
show_system_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 系统工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}查看系统信息${NC}       ($SYSTEM_TOOLS_DIR/system_info.sh)"
    echo -e "2. ${BOLD}安装常用依赖${NC}       ($SYSTEM_TOOLS_DIR/install_deps.sh)"
    echo -e "3. ${BOLD}更新系统${NC}           ($SYSTEM_TOOLS_DIR/update_system.sh)"
    echo -e "4. ${BOLD}清理系统${NC}           ($SYSTEM_TOOLS_DIR/clean_system.sh)"
    echo -e "5. ${BOLD}系统优化${NC}           ($SYSTEM_TOOLS_DIR/optimize_system.sh)"
    echo -e "6. ${BOLD}修改主机名${NC}         ($SYSTEM_TOOLS_DIR/change_hostname.sh)"
    echo -e "7. ${BOLD}设置时区${NC}           ($SYSTEM_TOOLS_DIR/set_timezone.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 网络测试子菜单（优化合并重复功能）
show_network_test_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 网络测试 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}带宽测试${NC}           ($NETWORK_TEST_DIR/bandwidth_test.sh)"
    echo -e "2. ${BOLD}路由追踪${NC}           ($NETWORK_TEST_DIR/network_traceroute.sh)"
    echo -e "3. ${BOLD}回程路由测试${NC}       ($NETWORK_TEST_DIR/backhaul_route_test.sh)"
    echo -e "4. ${BOLD}CDN延迟测试${NC}       ($NETWORK_TEST_DIR/cdn_latency_test.sh)"
    echo -e "5. ${BOLD}IP质量测试${NC}         ($NETWORK_TEST_DIR/ip_quality_test.sh)"
    echo -e "6. ${BOLD}网络连通性测试${NC}     ($NETWORK_TEST_DIR/network_connectivity_test.sh)"
    echo -e "7. ${BOLD}网络综合质量测试${NC}   ($NETWORK_TEST_DIR/network_quality_test.sh)"
    echo -e "8. ${BOLD}流媒体解锁测试${NC}     ($NETWORK_TEST_DIR/streaming_unlock_test.sh)"
    echo -e "9. ${BOLD}网络测速${NC}           ($NETWORK_TEST_DIR/network_speedtest.sh)"
    echo -e "10. ${BOLD}端口扫描${NC}          ($NETWORK_TEST_DIR/port_scanner.sh)"
    echo -e "11. ${BOLD}响应时间测试${NC}      ($NETWORK_TEST_DIR/response_time_test.sh)"
    echo -e "12. ${BOLD}安全扫描${NC}          ($NETWORK_TEST_DIR/network_security_scan.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 性能测试子菜单
show_performance_test_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 性能测试 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}CPU基准测试${NC}       ($PERFORMANCE_TEST_DIR/cpu_benchmark.sh)"
    echo -e "2. ${BOLD}磁盘IO测试${NC}         ($PERFORMANCE_TEST_DIR/disk_io_benchmark.sh)"
    echo -e "3. ${BOLD}内存测试${NC}           ($PERFORMANCE_TEST_DIR/memory_benchmark.sh)"
    echo -e "4. ${BOLD}网络吞吐量测试${NC}     ($PERFORMANCE_TEST_DIR/network_throughput_test.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 服务安装子菜单
show_service_install_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 服务安装 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}Docker安装${NC}         ($SERVICE_INSTALL_DIR/install_docker.sh)"
    echo -e "2. ${BOLD}LNMP环境安装${NC}       ($SERVICE_INSTALL_DIR/install_lnmp.sh)"
    echo -e "3. ${BOLD}Node.js安装${NC}        ($SERVICE_INSTALL_DIR/install_nodejs.sh)"
    echo -e "4. ${BOLD}Python安装${NC}         ($SERVICE_INSTALL_DIR/install_python.sh)"
    echo -e "5. ${BOLD}Redis安装${NC}          ($SERVICE_INSTALL_DIR/install_redis.sh)"
    echo -e "6. ${BOLD}宝塔面板安装${NC}       ($SERVICE_INSTALL_DIR/install_bt_panel.sh)"
    echo -e "7. ${BOLD}1Panel面板安装${NC}     ($SERVICE_INSTALL_DIR/install_1panel.sh)"
    echo -e "8. ${BOLD}Wordpress安装${NC}      ($SERVICE_INSTALL_DIR/install_wordpress.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 服务安装子菜单
show_service_install_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 服务安装 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}Docker安装${NC}         ($SERVICE_INSTALL_DIR/install_docker.sh)"
    echo -e "2. ${BOLD}LNMP环境安装${NC}       ($SERVICE_INSTALL_DIR/install_lnmp.sh)"
    echo -e "3. ${BOLD}Node.js安装${NC}        ($SERVICE_INSTALL_DIR/install_nodejs.sh)"
    echo -e "4. ${BOLD}Python安装${NC}         ($SERVICE_INSTALL_DIR/install_python.sh)"
    echo -e "5. ${BOLD}Redis安装${NC}          ($SERVICE_INSTALL_DIR/install_redis.sh)"
    echo -e "6. ${BOLD}宝塔面板安装${NC}       ($SERVICE_INSTALL_DIR/install_bt_panel.sh)"
    echo -e "7. ${BOLD}1Panel面板安装${NC}     ($SERVICE_INSTALL_DIR/install_1panel.sh)"
    echo -e "8. ${BOLD}Wordpress安装${NC}      ($SERVICE_INSTALL_DIR/install_wordpress.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 第三方工具子菜单 (整合good_scripts和proxy_tools)
show_third_party_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 第三方工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}优秀脚本整合${NC}       ($GOOD_SCRIPTS_DIR/good_scripts.sh)"
    echo -e "2. ${BOLD}梯子工具整合${NC}       ($PROXY_TOOLS_DIR/proxy_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 其他工具子菜单
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
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 脚本更新子菜单
show_update_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 脚本更新 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}触发自动更新${NC}       ($UPDATE_SCRIPTS_DIR/trigger_auto_update.sh)"
    echo -e "2. ${BOLD}更新核心脚本${NC}       ($UPDATE_SCRIPTS_DIR/update_core_scripts.sh)"
    echo -e "3. ${BOLD}更新依赖环境${NC}       ($UPDATE_SCRIPTS_DIR/update_dependencies.sh)"
    echo -e "4. ${BOLD}更新功能工具${NC}       ($UPDATE_SCRIPTS_DIR/update_functional_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 卸载工具子菜单
show_uninstall_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 卸载工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}清理服务残留${NC}       ($UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh)"
    echo -e "2. ${BOLD}回滚系统环境${NC}       ($UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh)"
    echo -e "3. ${BOLD}清除配置文件${NC}       ($UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh)"
    echo -e "4. ${BOLD}完全卸载${NC}           ($UNINSTALL_SCRIPTS_DIR/full_uninstall.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 执行系统工具脚本
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
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行网络测execute_network_test() {
    case $1 in
        1) bash "$NETWORK_TEST_DIR/bandwidth_test.sh" ;;
        2) bash "$NETWORK_TEST_DIR/network_traceroute.sh" ;;
        3) bash "$NETWORK_TEST_DIR/backhaul_route_test.sh" ;;
        4) bash "$NETWORK_TEST_DIR/cdn_latency_test.sh" ;;
        5) bash "$NETWORK_TEST_DIR/ip_quality_test.sh" ;;
        6) bash "$NETWORK_TEST_DIR/network_connectivity_test.sh" ;;
        7) bash "$NETWORK_TEST_DIR/network_quality_test.sh" ;;
        8) bash "$NETWexecute_network_test() {
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
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行性能测试脚本
execute_performance_test() {
    case $1 in
        1) bash "$PERFORMANCE_TEST_DIR/cpu_benchmark.sh" ;;
        2) bash "$PERFORMANCE_TEST_DIR/disk_io_benchmark.sh" ;;
        3) bash "$PERFORMANCE_TEST_DIR/memory_benchmark.sh" ;;
        4) bash "$PERFORMANCE_TEST_DIR/network_throughput_test.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行服务安装脚本
execute_service_install() {
    case $1 in
        1) bash "$SERVICE_INSTALL_DIR/install_docker.sh" ;;
        2) bash "$SERVICE_INSTALL_DIR/install_lnmp.sh" ;;
        3) bash "$SERVICE_INSTALL_DIR/install_nodejs.sh" ;;
        4) bash "$SERVICE_INSTALL_DIR/install_python.sh" ;;
        5) bash "$SERVICE_INSTALL_DIR/install_redis.sh" ;;
        6) bash "$SERVICE_INSTALL_DIR/install_bt_panel.sh" ;;
        7) bash "$SERVICE_INSTALL_DIR/install_1panel.sh" ;;
        8) bash "$SERVICE_INSTALL_DIR/install_wordpress.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行第三方工具脚本
execute_third_party_tools() {
    case $1 in
        1) bash "$GOOD_SCRIPTS_DIR/good_scripts.sh" ;;
        2) bash "$PROXY_TOOLS_DIR/proxy_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行其他工具脚本
execute_other_tools() {
    case $1 in
        1) bash "$OTHER_TOOLS_DIR/bbr.sh" ;;
        2) bash "$OTHER_TOOLS_DIR/fail2ban.sh" ;;
        3) bash "$OTHER_TOOLS_DIR/nezha.sh" ;;
        4) bash "$OTHER_TOOLS_DIR/swap.sh" ;;
        5) bash "$OTHER_TOOLS_DIR/nezha_cleaner.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行脚本更新脚本
execute_update_scripts() {
    case $1 in
        1) bash "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
        2) bash "$UPDATE_SCRIPTS_DIR/update_core_scripts.sh" ;;
        3) bash "$UPDATE_SCRIPTS_DIR/update_dependencies.sh" ;;
        4) bash "$UPDATE_SCRIPTS_DIR/update_functional_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行卸载工具脚本
execute_uninstall_scripts() {
    case $1 in
        1) bash "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
        2) bash "$UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh" ;;
        3) bash "$UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh" ;;
        4) bash "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行服务安装脚本
execute_service_install() {
    case $1 in
        1) bash "$SERVICE_INSTALL_DIR/install_docker.sh" ;;
        2) bash "$SERVICE_INSTALL_DIR/install_lnmp.sh" ;;
        3) bash "$SERVICE_INSTALL_DIR/install_nodejs.sh" ;;
        4) bash "$SERVICE_INSTALL_DIR/install_python.sh" ;;
        5) bash "$SERVICE_INSTALL_DIR/install_redis.sh" ;;
        6) bash "$SERVICE_INSTALL_DIR/install_bt_panel.sh" ;;
        7) bash "$SERVICE_INSTALL_DIR/install_1panel.sh" ;;
        8) bash "$SERVICE_INSTALL_DIR/install_wordpress.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行第三方工具脚本
execute_third_party_tools() {
    case $1 in
        1) bash "$GOOD_SCRIPTS_DIR/good_scripts.sh" ;;
        2) bash "$PROXY_TOOLS_DIR/proxy_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行其他工具脚本
execute_other_tools() {
    case $1 in
        1) bash "$OTHER_TOOLS_DIR/bbr.sh" ;;
        2) bash "$OTHER_TOOLS_DIR/fail2ban.sh" ;;
        3) bash "$OTHER_TOOLS_DIR/nezha.sh" ;;
        4) bash "$OTHER_TOOLS_DIR/swap.sh" ;;
        5) bash "$OTHER_TOOLS_DIR/nezha_cleaner.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行脚本更新脚本
execute_update_scripts() {
    case $1 in
        1) bash "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
        2) bash "$UPDATE_SCRIPTS_DIR/update_core_scripts.sh" ;;
        3) bash "$UPDATE_SCRIPTS_DIR/update_dependencies.sh" ;;
        4) bash "$UPDATE_SCRIPTS_DIR/update_functional_tools.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 执行卸载工具脚本
execute_uninstall_scripts() {
    case $1 in
        1) bash "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
        2) bash "$UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh" ;;
        3) bash "$UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh" ;;
        4) bash "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
        b) return ;;
        0) exit 0 ;;
        *) echo -e "${RED}[错误] 无效选择，请重新输入${NC}"; sleep 2 ;;
    esac
}

# 主函数
main() {
    check_dependencies
    
    while true; do
        show_main_menu
        read -p "请选择功能: " choice
        
        case $choice in
            1) # 系统工具
                while true; do
                    show_system_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_system_tool $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            2) # 网络测试
                while true; do
                    show_network_test_menu
                    read -p "请选择功能: " subchoice
                    execute_network_test $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            3) # 性能测试
                while true; do
                    show_performance_test_menu
                    read -p "请选择功能: " subchoice
                    execute_performance_test $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            4) # 服务安装
                while true; do
                    show_service_install_menu
                    read -p "请选择功能: " subchoice
                    execute_service_install $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            5) # 第三方工具
                while true; do
                    show_third_party_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_third_party_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            6) # 其他工具
                while true; do
                    show_other_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_other_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            7) # 脚本更新
                while true; do
                    show_update_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_update_scripts $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
             3) # 性能测试
                while true; do
                    show_performance_test_menu
                    read -p "请选择功能: " subchoice
                    execute_performance_test $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            4) # 服务安装
                while true; do
                    show_service_install_menu
                    read -p "请选择功能: " subchoice
                    execute_service_install $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            5) # 第三方工具
                while true; do
                    show_third_party_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_third_party_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            6) # 其他工具
                while true; do
                    show_other_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_other_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            7) # 脚本更新
                while true; do
                    show_update_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_update_scripts $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            8) # 卸载工具
                while true; do
                    show_uninstall_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_uninstall_scripts $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            0) # 退出脚本
                echo -e "${GREEN}[信息] 感谢使用vps_dev.sh测试脚本，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[错误] 无效选择，请输入1-8或0${NC}"
                sleep 2
                ;;
        esac
    done
}

# 启动脚本
mainn




# 服务安装子菜单
show_service_install_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 服务安装 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}Docker安装${NC}         ($SERVICE_INSTALL_DIR/install_docker.sh)"
    echo -e "2. ${BOLD}LNMP环境安装${NC}       ($SERVICE_INSTALL_DIR/install_lnmp.sh)"
    echo -e "3. ${BOLD}Node.js安装${NC}        ($SERVICE_INSTALL_DIR/install_nodejs.sh)"
    echo -e "4. ${BOLD}Python安装${NC}         ($SERVICE_INSTALL_DIR/install_python.sh)"
    echo -e "5. ${BOLD}Redis安装${NC}          ($SERVICE_INSTALL_DIR/install_redis.sh)"
    echo -e "6. ${BOLD}宝塔面板安装${NC}       ($SERVICE_INSTALL_DIR/install_bt_panel.sh)"
    echo -e "7. ${BOLD}1Panel面板安装${NC}     ($SERVICE_INSTALL_DIR/install_1panel.sh)"
    echo -e "8. ${BOLD}Wordpress安装${NC}      ($SERVICE_INSTALL_DIR/install_wordpress.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 第三方工具子菜单 (整合good_scripts和proxy_tools)
show_third_party_tools_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 第三方工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}优秀脚本整合${NC}       ($GOOD_SCRIPTS_DIR/good_scripts.sh)"
    echo -e "2. ${BOLD}梯子工具整合${NC}       ($PROXY_TOOLS_DIR/proxy_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 其他工具子菜单
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
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 脚本更新子菜单
show_update_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 脚本更新 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}触发自动更新${NC}       ($UPDATE_SCRIPTS_DIR/trigger_auto_update.sh)"
    echo -e "2. ${BOLD}更新核心脚本${NC}       ($UPDATE_SCRIPTS_DIR/update_core_scripts.sh)"
    echo -e "3. ${BOLD}更新依赖环境${NC}       ($UPDATE_SCRIPTS_DIR/update_dependencies.sh)"
    echo -e "4. ${BOLD}更新功能工具${NC}       ($UPDATE_SCRIPTS_DIR/update_functional_tools.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}

# 卸载工具子菜单
show_uninstall_scripts_menu() {
    show_title
    echo -e "${BOLD}${BLUE}===== 卸载工具 - 子菜单 ====${NC}"
    echo -e "1. ${BOLD}清理服务残留${NC}       ($UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh)"
    echo -e "2. ${BOLD}回滚系统环境${NC}       ($UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh)"
    echo -e "3. ${BOLD}清除配置文件${NC}       ($UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh)"
    echo -e "4. ${BOLD}完全卸载${NC}           ($UNINSTALL_SCRIPTS_DIR/full_uninstall.sh)"
    echo -e ""
    echo -e "b. ${BOLD}返回主菜单${NC}"
    echo -e "0. ${RED}退出脚本${NC}"
    echo -e "${BOLD}${BLUE}============================================${NC}"
}



            4) # 服务安装
                while true; do
                    show_service_install_menu
                    read -p "请选择功能: " subchoice
                    execute_service_install $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            5) # 第三方工具
                while true; do
                    show_third_party_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_third_party_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            6) # 其他工具
                while true; do
                    show_other_tools_menu
                    read -p "请选择功能: " subchoice
                    execute_other_tools $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            7) # 脚本更新
                while true; do
                    show_update_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_update_scripts $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
            8) # 卸载工具
                while true; do
                    show_uninstall_scripts_menu
                    read -p "请选择功能: " subchoice
                    execute_uninstall_scripts $subchoice
                    if [ "$subchoice" == "0" ]; then exit 0; fi
                    if [ "$subchoice" != "b" ]; then
                        echo -e "${YELLOW}[提示] 按Enter键继续...${NC}"
                        read -r
                    else
                        break
                    fi
                done
                ;;
