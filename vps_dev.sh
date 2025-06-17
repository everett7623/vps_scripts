#!/bin/bash
# ======================================================================
# 📌 脚本名称: vps_dev.sh (测试版)
# 📍 脚本路径: /vps_scripts/vps_dev.sh
# 🚀 主要用途: VPS服务器测试与开发功能集成
# 🔧 适用系统: CentOS/Ubuntu/Debian
# 📅 更新时间: 2025年06月18日
# ======================================================================

# 颜色定义 - 保持与vps.sh一致的视觉风格
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'      # 恢复默认颜色
BOLD='\033[1m'    # 加粗

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

# 执行网络测试脚本
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
                    if [ $subchoice == "0" ]; then exit 0; fi
                    if [ $subchoice != "b" ]; then
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
                    if [ $subchoice == "0" ]; then exit 0; fi
                    if [ $subchoice != "b" ]; then
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
                    if [ $subchoice == "0" ]; then exit 0; fi
                    if [ $subchoice != "b" ]; then
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
main
