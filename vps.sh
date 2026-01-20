#!/bin/bash
# ==============================================================================
# 脚本名称: vps.sh (主入口)
# 脚本路径: /opt/vps_scripts/vps.sh (建议路径)
# 描述: VPS 综合管理工具箱 - 生产环境主菜单
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.3.0 (Production)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心环境初始化 (Core Init)
# ------------------------------------------------------------------------------

# 获取脚本绝对路径 (处理软链接)
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 递归向上查找库文件 (确保无论在哪运行都能找到依赖)
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/lib/common_functions.sh" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# 依赖检查
if [ "$PROJECT_ROOT" = "/" ]; then
    echo -e "\033[0;31m[致命错误] 无法找到项目根目录或 lib/common_functions.sh 缺失。\033[0m"
    echo "请确保脚本位于正确的目录结构中 (例如: /opt/vps_scripts/vps.sh)"
    exit 1
fi

# 加载核心库
source "$PROJECT_ROOT/lib/common_functions.sh"

# 加载配置文件
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # 如果没找到配置文件，定义一些默认路径以防报错
    SCRIPTS_DIR="$PROJECT_ROOT/scripts"
fi

# 定义各功能模块路径 (基于 PROJECT_ROOT)
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

# ------------------------------------------------------------------------------
# 2. 辅助函数 (Helper Functions)
# ------------------------------------------------------------------------------

# 执行子脚本的通用包装器
# 参数: $1 = 脚本绝对路径
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    if [ -f "$script_path" ]; then
        # 赋予执行权限 (防止新拉取的脚本没权限)
        chmod +x "$script_path"
        # 执行脚本，并传入当前环境 (source 方式可能污染变量，建议用 bash 新进程)
        bash "$script_path"
    else
        print_error "未找到脚本文件: $script_name"
        print_warn "路径检查: $script_path"
        echo ""
        read -n 1 -s -r -p "按任意键继续..."
    fi
}

# 显示主标题
show_main_title() {
    clear
    print_header "VPS 综合管理工具箱 v${SCRIPT_VERSION:-2.3.0}"
    echo -e "${CYAN}项目路径:${NC} $PROJECT_ROOT"
    echo -e "${CYAN}系统时间:${NC} $(date "+%Y-%m-%d %H:%M")"
    echo -e "${CYAN}当前用户:${NC} $(whoami)"
    print_separator
}

# ------------------------------------------------------------------------------
# 3. 子菜单定义 (Sub-Menus)
# ------------------------------------------------------------------------------

# [1] 系统工具菜单
menu_system_tools() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[1] 系统运维工具${NC}"
        echo "------------------------------------------------"
        echo -e "1. 查看系统信息    (详细硬件、网络、负载)"
        echo -e "2. 安装常用依赖    (Curl, Wget, Git, Vim 等)"
        echo -e "3. 系统更新升级    (软件包、内核更新)"
        echo -e "4. 系统垃圾清理    (清理缓存、日志、旧内核)"
        echo -e "5. 系统参数优化    (TCP拥塞、文件句柄优化)"
        echo -e "6. 修改主机名      (Hostname)"
        echo -e "7. 设置系统时区    (NTP同步)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
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
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [2] 网络测试菜单
menu_network_test() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[2] 网络质量测试${NC}"
        echo "------------------------------------------------"
        echo -e "1. 带宽测速        (Speedtest/下载测试)"
        echo -e "2. 回程路由追踪    (TCP/ICMP/UDP 路由)"
        echo -e "3. IP 质量检测     (欺诈值、黑名单、流媒体)"
        echo -e "4. 流媒体解锁检测  (Netflix, Disney+, YouTube)"
        echo -e "5. 综合网络体检    (Ping, 丢包, 端口, 延迟)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$NETWORK_TEST_DIR/bandwidth_test.sh" ;;
            2) run_script "$NETWORK_TEST_DIR/backhaul_route_test.sh" ;;
            3) run_script "$NETWORK_TEST_DIR/ip_quality_test.sh" ;;
            4) run_script "$NETWORK_TEST_DIR/streaming_unlock_test.sh" ;;
            5) run_script "$NETWORK_TEST_DIR/network_quality_test.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [3] 性能测试菜单
menu_performance_test() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[3] 硬件性能测试${NC}"
        echo "------------------------------------------------"
        echo -e "1. CPU 基准测试    (Sysbench/加密/计算)"
        echo -e "2. 磁盘 I/O 测试   (FIO/DD 读写速度)"
        echo -e "3. 内存性能测试    (读写带宽、延迟)"
        echo -e "4. 网络吞吐量测试  (iperf3)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$PERFORMANCE_TEST_DIR/cpu_benchmark.sh" ;;
            2) run_script "$PERFORMANCE_TEST_DIR/disk_io_benchmark.sh" ;;
            3) run_script "$PERFORMANCE_TEST_DIR/memory_benchmark.sh" ;;
            4) run_script "$PERFORMANCE_TEST_DIR/network_throughput_test.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [4] 服务安装菜单
menu_service_install() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[4] 服务与环境安装${NC}"
        echo "------------------------------------------------"
        echo -e "1. Docker 环境     (Docker Engine + Compose)"
        echo -e "2. Web 环境 (LNMP) (Nginx+MySQL+PHP)"
        echo -e "3. Node.js 环境    (NVM/Node/PM2)"
        echo -e "4. Python 环境     (Pyenv/Conda)"
        echo -e "5. Go 语言环境     (Golang)"
        echo -e "6. 数据库服务      (MySQL/MariaDB/Redis/PGSQL)"
        echo -e "7. 宝塔面板        (Bt-Panel 官方版/开心版)"
        echo -e "8. 1Panel 面板     (现代化容器面板)"
        echo -e "9. WordPress       (一键建站)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$SERVICE_INSTALL_DIR/docker.sh" ;;
            2) run_script "$SERVICE_INSTALL_DIR/ldnmp.sh" ;;
            3) run_script "$SERVICE_INSTALL_DIR/nodejs.sh" ;;
            4) run_script "$SERVICE_INSTALL_DIR/python.sh" ;;
            5) run_script "$SERVICE_INSTALL_DIR/go.sh" ;;
            6) 
               echo -e "\n请选择数据库类型:\n1. MySQL\n2. Redis\n3. PostgreSQL"
               read -p "选择: " db_choice
               case $db_choice in
                   1) run_script "$SERVICE_INSTALL_DIR/mysql.sh" ;;
                   2) run_script "$SERVICE_INSTALL_DIR/redis.sh" ;;
                   3) run_script "$SERVICE_INSTALL_DIR/postgresql.sh" ;;
               esac
               ;;
            7) run_script "$SERVICE_INSTALL_DIR/btpanel.sh" ;;
            8) run_script "$SERVICE_INSTALL_DIR/1panel.sh" ;;
            9) run_script "$SERVICE_INSTALL_DIR/wordpress.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [5] 第三方脚本菜单
menu_third_party() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[5] 社区优秀脚本 (集成)${NC}"
        echo "------------------------------------------------"
        echo -e "1. 融合怪评测      (SpiritlHL 综合评测)"
        echo -e "2. YABS 性能测试   (Yet Another Bench Script)"
        echo -e "3. SuperSpeed      (全网测速脚本)"
        echo -e "4. 科技Lion工具箱  (多功能合一)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        # 这里可以直接调用 scripts/good_scripts/ 下的包装器
        # 或者直接 curl 调用，取决于您是否下载了 wrapper
        case $choice in
            1) run_script "$GOOD_SCRIPTS_DIR/fusion_bench.sh" ;; 
            2) run_script "$GOOD_SCRIPTS_DIR/yabs.sh" ;;
            3) run_script "$GOOD_SCRIPTS_DIR/superspeed.sh" ;;
            4) run_script "$GOOD_SCRIPTS_DIR/kejilion.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [6] 其他工具菜单
menu_other_tools() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[6] 安全与辅助工具${NC}"
        echo "------------------------------------------------"
        echo -e "1. BBR 加速管理    (开启/关闭/切换内核)"
        echo -e "2. Fail2ban 防护   (防 SSH 爆破)"
        echo -e "3. 哪吒监控 Agent  (安装/配置/卸载)"
        echo -e "4. SWAP 内存管理   (增加/删除 Swap)"
        echo -e "5. 哪吒 Agent 清理 (深度清理残留)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$OTHER_TOOLS_DIR/bbr.sh" ;;
            2) run_script "$OTHER_TOOLS_DIR/fail2ban.sh" ;;
            3) run_script "$OTHER_TOOLS_DIR/nezha.sh" ;;
            4) run_script "$OTHER_TOOLS_DIR/swap.sh" ;;
            5) run_script "$OTHER_TOOLS_DIR/nezha_cleaner.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [7] 更新与维护菜单
menu_update_maintain() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[7] 脚本维护与更新${NC}"
        echo "------------------------------------------------"
        echo -e "1. 检查脚本更新    (Git Pull)"
        echo -e "2. 更新核心组件    (Core Scripts)"
        echo -e "3. 更新依赖环境    (Dependencies)"
        echo -e "4. 重新加载配置    (Reload Config)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
            2) run_script "$UPDATE_SCRIPTS_DIR/update_core_scripts.sh" ;;
            3) run_script "$UPDATE_SCRIPTS_DIR/update_dependencies.sh" ;;
            4) 
                print_info "正在重新加载配置..."
                source "$CONFIG_FILE"
                print_success "配置已重新加载"
                sleep 1
                ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# [8] 卸载与清理菜单
menu_uninstall() {
    while true; do
        show_main_title
        echo -e "${BOLD}${BLUE}[8] 卸载与环境清理${NC}"
        echo "------------------------------------------------"
        echo -e "1. 清理服务残留    (Docker/Web/DB等)"
        echo -e "2. 还原系统配置    (撤销 Hostname/Sysctl 等修改)"
        echo -e "3. 回滚系统环境    (尝试还原到初始状态)"
        echo -e "4. ${RED}完全卸载脚本${NC}    (删除所有脚本文件和日志)"
        echo "------------------------------------------------"
        echo -e "b. 返回主菜单"
        echo -e "0. 退出脚本"
        echo ""
        read -p "请输入选项: " choice
        
        case $choice in
            1) run_script "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
            2) run_script "$UNINSTALL_SCRIPTS_DIR/clear_configuration_files.sh" ;;
            3) run_script "$UNINSTALL_SCRIPTS_DIR/rollback_system_environment.sh" ;;
            4) run_script "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
            b|B) return ;;
            0) graceful_exit ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 4. 主程序入口 (Main Entry)
# ------------------------------------------------------------------------------

main() {
    # 基础环境检查
    check_root
    ensure_command "curl"
    ensure_command "wget"
    
    # 无限循环显示主菜单
    while true; do
        show_main_title
        echo -e "${BOLD}${PURPLE}请选择要执行的功能类别:${NC}"
        echo "------------------------------------------------"
        echo -e " ${GREEN}1.${NC} 系统工具       (System Tools)"
        echo -e " ${GREEN}2.${NC} 网络测试       (Network Test)"
        echo -e " ${GREEN}3.${NC} 性能测试       (Benchmarks)"
        echo -e " ${GREEN}4.${NC} 服务安装       (Install Services)"
        echo -e " ${GREEN}5.${NC} 优秀脚本       (3rd Party Tools)"
        echo -e " ${GREEN}6.${NC} 其他工具       (Security & Misc)"
        echo -e " ${GREEN}7.${NC} 脚本更新       (Update)"
        echo -e " ${GREEN}8.${NC} 卸载清理       (Uninstall)"
        echo "------------------------------------------------"
        echo -e " ${RED}0. 退出脚本 (Exit)${NC}"
        echo ""
        read -p "请输入选项 [0-8]: " choice
        
        case $choice in
            1) menu_system_tools ;;
            2) menu_network_test ;;
            3) menu_performance_test ;;
            4) menu_service_install ;;
            5) menu_third_party ;;
            6) menu_other_tools ;;
            7) menu_update_maintain ;;
            8) menu_uninstall ;;
            0) graceful_exit ;;
            *) print_error "无效选项，请重新输入"; sleep 1 ;;
        esac
    done
}

# 捕获 Ctrl+C 信号
trap 'echo ""; graceful_exit 1 "用户取消操作"' INT TERM

# 启动主程序
main "$@"
