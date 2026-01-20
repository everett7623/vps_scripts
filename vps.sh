#!/bin/bash
# ==============================================================================
# 脚本名称: vps.sh (主入口/控制台)
# 脚本路径: /opt/vps_scripts/vps.sh
# 描述: VPS 综合管理工具箱 - 包含状态看板与模块化菜单
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.4.0 (Dashboard Edition)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心环境初始化
# ------------------------------------------------------------------------------

# 获取脚本绝对路径 (处理软链接)
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 递归向上查找库文件
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/lib/common_functions.sh" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# 依赖检查
if [ "$PROJECT_ROOT" = "/" ]; then
    echo -e "\033[0;31m[致命错误] 无法找到 lib/common_functions.sh。\033[0m"
    echo "请确保脚本安装在正确的目录 (推荐: /opt/vps_scripts/)"
    exit 1
fi

# 加载核心库与配置
source "$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# 定义模块路径
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
SYSTEM_TOOLS_DIR="$SCRIPTS_DIR/system_tools"
NETWORK_TEST_DIR="$SCRIPTS_DIR/network_test"
PERFORMANCE_TEST_DIR="$SCRIPTS_DIR/performance_test"
SERVICE_INSTALL_DIR="$SCRIPTS_DIR/service_install"
GOOD_SCRIPTS_DIR="$SCRIPTS_DIR/good_scripts"
OTHER_TOOLS_DIR="$SCRIPTS_DIR/other_tools"
UPDATE_SCRIPTS_DIR="$SCRIPTS_DIR/update_scripts"
UNINSTALL_SCRIPTS_DIR="$SCRIPTS_DIR/uninstall_scripts"

# ------------------------------------------------------------------------------
# 2. 辅助功能函数
# ------------------------------------------------------------------------------

# 执行子脚本包装器 (增强版)
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        # 使用 bash 执行，避免变量污染
        bash "$script_path"
        # 子脚本执行完后，按键返回 (除非子脚本自己处理了)
        # 这里我们假设子脚本都是独立运行的工具，跑完直接返回菜单
    else
        print_error "功能脚本未找到: $script_name"
        print_warn "路径: $script_path"
        print_info "请检查 scripts 目录是否完整，或运行更新脚本。"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 绘制系统状态看板 (Dashboard)
draw_dashboard() {
    clear
    print_header "VPS 综合管理工具箱 v${SCRIPT_VERSION:-2.4.0}"
    
    # 获取实时数据
    local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    local mem_usage=$(free | awk '/Mem/{printf("%.1f%%"), $3/$2*100}')
    local disk_usage=$(df -h / | awk '/\//{print $(NF-1)}')
    local uptime_sys=$(uptime -p | sed 's/up //')
    local os_info=$(get_os_release)
    
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}系统信息${NC}                                                                    ${BLUE}│${NC}"
    echo -e "${BLUE}├──────────────────────┬───────────────────────┬───────────────────────────────┤${NC}"
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "OS: ${os_info}" "Load: ${load}" "Uptime: ${uptime_sys}"
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "Mem: ${mem_usage}" "Disk: ${disk_usage}" "User: $(whoami)"
    echo -e "${BLUE}└──────────────────────┴───────────────────────┴───────────────────────────────┘${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 3. 菜单定义
# ------------------------------------------------------------------------------

menu_system() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[1] 系统运维工具${NC}"
        echo "------------------------------------------------"
        echo -e " 1. 查看系统信息 ${CYAN}(Info)${NC}    5. 系统参数优化 ${CYAN}(Optimize)${NC}"
        echo -e " 2. 安装常用依赖 ${CYAN}(Deps)${NC}    6. 修改主机名   ${CYAN}(Hostname)${NC}"
        echo -e " 3. 系统更新升级 ${CYAN}(Update)${NC}  7. 设置时区     ${CYAN}(Timezone)${NC}"
        echo -e " 4. 系统垃圾清理 ${CYAN}(Clean)${NC}   "
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo -e " 0. 退出程序"
        echo ""
        read -p " 请选择 [1-7]: " choice
        case $choice in
            1) run_script "$SYSTEM_TOOLS_DIR/system_info.sh" ;;
            2) run_script "$SYSTEM_TOOLS_DIR/install_deps.sh" ;;
            3) run_script "$SYSTEM_TOOLS_DIR/update_system.sh" ;;
            4) run_script "$SYSTEM_TOOLS_DIR/clean_system.sh" ;;
            5) run_script "$SYSTEM_TOOLS_DIR/optimize_system.sh" ;;
            6) run_script "$SYSTEM_TOOLS_DIR/change_hostname.sh" ;;
            7) run_script "$SYSTEM_TOOLS_DIR/set_timezone.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) ;;
        esac
    done
}

menu_network() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[2] 网络质量测试${NC}"
        echo "------------------------------------------------"
        echo -e " 1. 带宽测速 ${CYAN}(Speedtest)${NC}      4. 流媒体解锁检测 ${CYAN}(Unlock)${NC}"
        echo -e " 2. 回程路由追踪 ${CYAN}(Trace)${NC}      5. 综合网络体检   ${CYAN}(Check)${NC}"
        echo -e " 3. IP 质量检测 ${CYAN}(IP Quality)${NC}"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择 [1-5]: " choice
        case $choice in
            1) run_script "$NETWORK_TEST_DIR/bandwidth_test.sh" ;;
            2) run_script "$NETWORK_TEST_DIR/backhaul_route_test.sh" ;;
            3) run_script "$NETWORK_TEST_DIR/ip_quality_test.sh" ;;
            4) run_script "$NETWORK_TEST_DIR/streaming_unlock_test.sh" ;;
            5) run_script "$NETWORK_TEST_DIR/network_quality_test.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

menu_performance() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[3] 硬件性能测试${NC}"
        echo "------------------------------------------------"
        echo -e " 1. CPU 基准测试 ${CYAN}(Benchmark)${NC}  3. 内存性能测试 ${CYAN}(RAM)${NC}"
        echo -e " 2. 磁盘 I/O 测试 ${CYAN}(Disk IO)${NC}   4. 网络吞吐测试 ${CYAN}(Throughput)${NC}"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择 [1-4]: " choice
        case $choice in
            1) run_script "$PERFORMANCE_TEST_DIR/cpu_benchmark.sh" ;;
            2) run_script "$PERFORMANCE_TEST_DIR/disk_io_benchmark.sh" ;;
            3) run_script "$PERFORMANCE_TEST_DIR/memory_benchmark.sh" ;;
            4) run_script "$PERFORMANCE_TEST_DIR/network_throughput_test.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

menu_install() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[4] 服务与环境安装${NC}"
        echo "------------------------------------------------"
        echo -e " 1. Docker 环境 ${CYAN}(Engine+Compose)${NC}  6. 数据库服务 ${CYAN}(MySQL/Redis)${NC}"
        echo -e " 2. Web 环境 ${CYAN}(LNMP/LDNMP)${NC}        7. 宝塔面板   ${CYAN}(Bt-Panel)${NC}"
        echo -e " 3. Node.js 环境 ${CYAN}(NVM/PM2)${NC}       8. 1Panel面板 ${CYAN}(Container)${NC}"
        echo -e " 4. Python 环境 ${CYAN}(Pyenv)${NC}          9. WordPress  ${CYAN}(CMS)${NC}"
        echo -e " 5. Go 语言环境 ${CYAN}(Golang)${NC}"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择 [1-9]: " choice
        case $choice in
            1) run_script "$SERVICE_INSTALL_DIR/docker.sh" ;;
            2) run_script "$SERVICE_INSTALL_DIR/ldnmp.sh" ;;
            3) run_script "$SERVICE_INSTALL_DIR/nodejs.sh" ;;
            4) run_script "$SERVICE_INSTALL_DIR/python.sh" ;;
            5) run_script "$SERVICE_INSTALL_DIR/go.sh" ;;
            6) 
               echo -e "\n ${CYAN}数据库选择:${NC} 1.MySQL  2.Redis  3.PostgreSQL"
               read -p " 请选择: " db_type
               [ "$db_type" == "1" ] && run_script "$SERVICE_INSTALL_DIR/mysql.sh"
               [ "$db_type" == "2" ] && run_script "$SERVICE_INSTALL_DIR/redis.sh"
               [ "$db_type" == "3" ] && run_script "$SERVICE_INSTALL_DIR/postgresql.sh"
               ;;
            7) run_script "$SERVICE_INSTALL_DIR/btpanel.sh" ;;
            8) run_script "$SERVICE_INSTALL_DIR/1panel.sh" ;;
            9) run_script "$SERVICE_INSTALL_DIR/wordpress.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

menu_others() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[5-6] 扩展工具${NC}"
        echo "------------------------------------------------"
        echo -e " ${YELLOW}--- 第三方脚本 (Community) ---${NC}"
        echo -e " 1. 融合怪评测 ${CYAN}(Fusion)${NC}       2. YABS 跑分 ${CYAN}(Benchmark)${NC}"
        echo -e " 3. SuperSpeed ${CYAN}(Speedtest)${NC}    4. 科技Lion  ${CYAN}(Toolbox)${NC}"
        echo ""
        echo -e " ${YELLOW}--- 安全与辅助 (Security) ---${NC}"
        echo -e " 5. BBR 加速管理              6. Fail2ban 防护"
        echo -e " 7. 哪吒监控 Agent            8. SWAP 内存管理"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择 [1-8]: " choice
        case $choice in
            1) run_script "$GOOD_SCRIPTS_DIR/fusion_bench.sh" ;;
            2) run_script "$GOOD_SCRIPTS_DIR/yabs.sh" ;;
            3) run_script "$GOOD_SCRIPTS_DIR/superspeed.sh" ;;
            4) run_script "$GOOD_SCRIPTS_DIR/kejilion.sh" ;;
            5) run_script "$OTHER_TOOLS_DIR/bbr.sh" ;;
            6) run_script "$OTHER_TOOLS_DIR/fail2ban.sh" ;;
            7) run_script "$OTHER_TOOLS_DIR/nezha.sh" ;;
            8) run_script "$OTHER_TOOLS_DIR/swap.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

menu_maintain() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[7-8] 维护与管理${NC}"
        echo "------------------------------------------------"
        echo -e " ${YELLOW}--- 更新 (Update) ---${NC}"
        echo -e " 1. 检查脚本更新              2. 更新核心组件"
        echo -e " 3. 更新依赖环境              4. 重载配置文件"
        echo ""
        echo -e " ${YELLOW}--- 卸载 (Uninstall) ---${NC}"
        echo -e " 5. 清理服务残留              6. 还原系统配置"
        echo -e " 7. 回滚系统环境              8. ${RED}完全卸载脚本${NC}"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择 [1-8]: " choice
        case $choice in
            1) run_script "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
            2) run_script "$UPDATE_SCRIPTS_DIR/update_core_scripts.sh" ;;
            3) run_script "$UPDATE_SCRIPTS_DIR/update_dependencies.sh" ;;
            4) source "$CONFIG_FILE"; print_success "配置已重载"; sleep 1 ;;
            5) run_script "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
            6) run_script "$UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh" ;;
            7) run_script "$UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh" ;;
            8) run_script "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 4. 主循环入口
# ------------------------------------------------------------------------------

main() {
    check_root
    
    while true; do
        draw_dashboard
        echo -e "${BOLD}请选择功能模块:${NC}"
        echo "--------------------------------------------------------"
        echo -e " ${GREEN}1.${NC} 系统工具 ${WHITE}(System Tools)${NC}      ${GREEN}5.${NC} 社区脚本 ${WHITE}(3rd Party)${NC}"
        echo -e " ${GREEN}2.${NC} 网络测试 ${WHITE}(Network Test)${NC}      ${GREEN}6.${NC} 其他工具 ${WHITE}(Security)${NC}"
        echo -e " ${GREEN}3.${NC} 性能测试 ${WHITE}(Benchmark)${NC}         ${GREEN}7.${NC} 脚本更新 ${WHITE}(Update)${NC}"
        echo -e " ${GREEN}4.${NC} 服务安装 ${WHITE}(Service Install)${NC}   ${GREEN}8.${NC} 卸载清理 ${WHITE}(Uninstall)${NC}"
        echo "--------------------------------------------------------"
        echo -e " ${RED}0. 退出脚本 (Exit)${NC}"
        echo ""
        read -p " 请输入选项 [0-8]: " choice
        
        case $choice in
            1) menu_system ;;
            2) menu_network ;;
            3) menu_performance ;;
            4) menu_install ;;
            5|6) menu_others ;;  # 合并入口
            7|8) menu_maintain ;; # 合并入口
            0) graceful_exit ;;
            *) ;;
        esac
    done
}

trap 'graceful_exit 1 "操作被中断"' INT TERM
main "$@"
