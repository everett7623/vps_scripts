#!/bin/bash
# ==============================================================================
# 脚本名称: vps.sh
# 脚本路径: vps_scripts/vps.sh
# 描述: VPS 综合管理工具箱
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.4.2 (Full Comment Edition)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心路径定位与环境初始化
#    (这一步决定了脚本能不能找到它的"零件")
# ------------------------------------------------------------------------------

# 获取当前脚本文件的绝对物理路径
# readlink -f: 能够解析软链接，确保即使是通过 ln -s 创建的快捷方式运行，也能找到真实的物理文件位置
SCRIPT_PATH=$(readlink -f "$0")

# 获取脚本所在的目录，我们将其视为"项目根目录" (Project Root)
# 所有依赖文件(lib, config)和子脚本(scripts)都应该在这个目录下
PROJECT_ROOT=$(dirname "$SCRIPT_PATH")

# 定义关键依赖文件的路径
# LIB_FILE: 公共函数库，包含颜色定义、打印函数、系统检测等基础功能
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
# CONFIG_FILE: 配置文件，包含日志路径、下载源、默认设置等
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

# ------------------------------------------------------------------------------
# 2. 依赖自检与加载
#    (防止脚本在缺失核心文件的情况下盲目运行)
# ------------------------------------------------------------------------------

# 检查公共函数库是否存在
# 如果 lib 文件不存在，脚本实际上无法进行任何美观的输出或逻辑操作，必须终止
if [ ! -f "$LIB_FILE" ]; then
    # 使用原生 echo 输出红色错误提示 (此时还没加载颜色变量，只能用原生 ANSI 码)
    echo -e "\033[0;31m[启动失败] 核心库丢失！\033[0m"
    echo "----------------------------------------------------"
    echo "脚本试图加载核心库: $LIB_FILE"
    echo "但该文件不存在。这通常是因为下载不完整或目录结构错误导致的。"
    echo "----------------------------------------------------"
    echo -e "\033[0;33m[解决方法]\033[0m"
    echo "请确保目录结构完整，当前目录 ($PROJECT_ROOT) 下应包含："
    echo "  ├── vps.sh                  (主程序)"
    echo "  ├── lib/                    (库文件夹)"
    echo "  │   └── common_functions.sh (核心函数库)"
    echo "  └── scripts/                (功能脚本文件夹)"
    echo "----------------------------------------------------"
    # 退出脚本，返回错误码 1
    exit 1
fi

# 加载公共函数库
# source 命令会将目标文件的内容导入到当前 Shell 环境中，
# 这样我们就可以直接使用 print_info, check_root 等函数了。
source "$LIB_FILE"

# 加载配置文件
# 这是一个可选操作，如果配置文件丢失，脚本将使用硬编码的默认值，但会给出警告。
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # print_warn 来自 common_functions.sh
    print_warn "未找到配置文件: config/vps_scripts.conf，脚本将使用默认设置运行。"
fi

# 定义各功能模块的子目录路径
# 这些变量将用于在菜单中定位具体的执行脚本
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
SYSTEM_TOOLS_DIR="$SCRIPTS_DIR/system_tools"       # 系统工具
NETWORK_TEST_DIR="$SCRIPTS_DIR/network_test"       # 网络测试
PERFORMANCE_TEST_DIR="$SCRIPTS_DIR/performance_test" # 性能测试
SERVICE_INSTALL_DIR="$SCRIPTS_DIR/service_install"   # 服务安装
GOOD_SCRIPTS_DIR="$SCRIPTS_DIR/good_scripts"         # 第三方脚本
OTHER_TOOLS_DIR="$SCRIPTS_DIR/other_tools"           # 其他/安全工具
UPDATE_SCRIPTS_DIR="$SCRIPTS_DIR/update_scripts"     # 更新维护
UNINSTALL_SCRIPTS_DIR="$SCRIPTS_DIR/uninstall_scripts" # 卸载清理

# ------------------------------------------------------------------------------
# 3. 辅助功能函数定义
# ------------------------------------------------------------------------------

# 函数: run_script
# 功能: 安全地执行子脚本
# 参数: $1 = 脚本的绝对路径
run_script() {
    local script_path="$1"
    
    # 检查目标脚本文件是否存在
    if [ -f "$script_path" ]; then
        # 赋予目标脚本执行权限，防止因权限不足导致 "Permission denied"
        chmod +x "$script_path"
        
        # 使用 bash 新进程执行脚本
        # 为什么不用 source? 
        # 因为子脚本可能有自己的变量名(如 $ver)，使用 source 会污染主菜单的变量环境。
        # 使用 bash 开启子进程更安全隔离。
        bash "$script_path"
    else
        # 如果找不到脚本，打印错误信息方便调试
        print_error "子脚本丢失: $(basename "$script_path")"
        echo "预期路径: $script_path"
        echo "请检查 scripts/ 目录下是否包含该文件，或重新下载完整包。"
        
        # 暂停等待用户确认，防止错误信息一闪而过
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 函数: draw_dashboard
# 功能: 绘制主菜单顶部的系统状态看板
draw_dashboard() {
    # 清屏，确保界面整洁
    clear
    
    # 打印主标题 (print_header 来自 common_functions.sh)
    print_header "VPS 综合管理工具箱 (Root版)"
    
    # 获取系统实时数据 (使用 awk 提取关键字段)
    # 1. 获取系统负载 (Load Average)
    local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    
    # 2. 获取内存使用率 (Memory Usage Percentage)
    local mem_usage=$(free | awk '/Mem/{printf("%.1f%%"), $3/$2*100}')
    
    # 3. 获取根目录磁盘使用率 (Root Disk Usage)
    local disk_usage=$(df -h / | awk '/\//{print $(NF-1)}')
    
    # 4. 获取本机首选 IP 地址
    local ip_addr=$(hostname -I | awk '{print $1}')
    
    # 绘制蓝色边框的信息表格
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}系统实时状态${NC}                                                                ${BLUE}│${NC}"
    echo -e "${BLUE}├──────────────────────┬───────────────────────┬───────────────────────────────┤${NC}"
    
    # 使用 printf 进行格式化输出，确保表格对齐
    # %-20s 表示左对齐，占用20个字符宽度
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "Load: ${load}" "Mem: ${mem_usage}" "Disk: ${disk_usage}"
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "IP: ${ip_addr}" "User: $(whoami)" "Dir: $(basename "$PROJECT_ROOT")"
        
    echo -e "${BLUE}└──────────────────────┴───────────────────────┴───────────────────────────────┘${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 4. 菜单逻辑定义
#    (每个函数对应一个二级菜单)
# ------------------------------------------------------------------------------

# 二级菜单: 系统工具
menu_system() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[1] 系统运维工具${NC}"
        echo "------------------------------------------------"
        echo -e " 1. 查看系统信息    5. 系统参数优化"
        echo -e " 2. 安装常用依赖    6. 修改主机名"
        echo -e " 3. 系统更新升级    7. 设置时区"
        echo -e " 4. 系统垃圾清理"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo -e " 0. 退出程序"
        echo ""
        
        # 读取用户输入
        read -p " 请选择: " choice
        
        # 根据输入执行相应逻辑
        case $choice in
            1) run_script "$SYSTEM_TOOLS_DIR/system_info.sh" ;;
            2) run_script "$SYSTEM_TOOLS_DIR/install_deps.sh" ;;
            3) run_script "$SYSTEM_TOOLS_DIR/update_system.sh" ;;
            4) run_script "$SYSTEM_TOOLS_DIR/clean_system.sh" ;;
            5) run_script "$SYSTEM_TOOLS_DIR/optimize_system.sh" ;;
            6) run_script "$SYSTEM_TOOLS_DIR/change_hostname.sh" ;;
            7) run_script "$SYSTEM_TOOLS_DIR/set_timezone.sh" ;;
            b|B) return ;; # 返回上一级菜单
            0) graceful_exit ;; # 完全退出脚本
            *) ;; # 无效输入，不做反应，重新循环
        esac
    done
}

# 二级菜单: 网络测试
menu_network() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[2] 网络质量测试${NC}"
        echo "------------------------------------------------"
        echo -e " 1. 带宽测速        4. 流媒体解锁检测"
        echo -e " 2. 回程路由追踪    5. 综合网络体检"
        echo -e " 3. IP 质量检测"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择: " choice
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

# 二级菜单: 性能测试
menu_performance() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[3] 硬件性能测试${NC}"
        echo "------------------------------------------------"
        echo -e " 1. CPU 基准测试    3. 内存性能测试"
        echo -e " 2. 磁盘 I/O 测试   4. 网络吞吐测试"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择: " choice
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

# 二级菜单: 服务安装
menu_install() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[4] 服务与环境安装${NC}"
        echo "------------------------------------------------"
        echo -e " 1. Docker 环境     6. 数据库服务"
        echo -e " 2. Web 环境        7. 宝塔面板"
        echo -e " 3. Node.js 环境    8. 1Panel面板"
        echo -e " 4. Python 环境     9. WordPress"
        echo -e " 5. Go 语言环境"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择: " choice
        case $choice in
            1) run_script "$SERVICE_INSTALL_DIR/docker.sh" ;;
            2) run_script "$SERVICE_INSTALL_DIR/ldnmp.sh" ;;
            3) run_script "$SERVICE_INSTALL_DIR/nodejs.sh" ;;
            4) run_script "$SERVICE_INSTALL_DIR/python.sh" ;;
            5) run_script "$SERVICE_INSTALL_DIR/go.sh" ;;
            6) 
               # 数据库有多种选择，加一个小交互
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

# 二级菜单: 扩展工具 (合并了 社区脚本 和 其他工具)
menu_others() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[5-6] 扩展工具${NC}"
        echo "------------------------------------------------"
        echo -e " ${YELLOW}--- 社区脚本 ---${NC}"
        echo -e " 1. 融合怪评测      3. SuperSpeed"
        echo -e " 2. YABS 跑分       4. 科技Lion"
        echo ""
        echo -e " ${YELLOW}--- 安全辅助 ---${NC}"
        echo -e " 5. BBR 加速管理    7. 哪吒监控 Agent"
        echo -e " 6. Fail2ban 防护   8. SWAP 内存管理"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择: " choice
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

# 二级菜单: 维护管理 (合并了 更新 和 卸载)
menu_maintain() {
    while true; do
        draw_dashboard
        echo -e "${BOLD}${CYAN}[7-8] 维护与管理${NC}"
        echo "------------------------------------------------"
        echo -e " ${YELLOW}--- 更新 ---${NC}"
        echo -e " 1. 检查更新        2. 重载配置"
        echo ""
        echo -e " ${YELLOW}--- 卸载 ---${NC}"
        echo -e " 3. 清理残留        4. 完全卸载"
        echo "------------------------------------------------"
        echo -e " b. 返回主菜单"
        echo ""
        read -p " 请选择: " choice
        case $choice in
            1) run_script "$UPDATE_SCRIPTS_DIR/trigger_auto_update.sh" ;;
            2) source "$CONFIG_FILE"; print_success "配置已重载"; sleep 1 ;;
            3) run_script "$UNINSTALL_SCRIPTS_DIR/clean_service_residues.sh" ;;
            4) run_script "$UNINSTALL_SCRIPTS_DIR/full_uninstall.sh" ;;
            b|B) return ;;
            *) ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 5. 主程序入口 (Entry Point)
# ------------------------------------------------------------------------------

main() {
    # 1. 基础环境检查
    # 如果没有 root 权限，很多系统级操作无法执行，check_root 来自 common_functions.sh
    check_root
    
    # 2. 检查必要的网络工具
    # 为了防止后续下载脚本或测试网络时出错，先确保 curl/wget 存在
    if ! command -v curl &> /dev/null; then
        echo "正在安装缺失的依赖: curl..."
        if command -v apt &> /dev/null; then apt update && apt install -y curl
        elif command -v yum &> /dev/null; then yum install -y curl
        fi
    fi

    # 3. 进入主菜单循环
    while true; do
        draw_dashboard
        echo -e "${BOLD}功能主菜单:${NC}"
        echo "--------------------------------------------------------"
        echo -e " ${GREEN}1.${NC} 系统工具       ${GREEN}5.${NC} 社区脚本"
        echo -e " ${GREEN}2.${NC} 网络测试       ${GREEN}6.${NC} 其他工具"
        echo -e " ${GREEN}3.${NC} 性能测试       ${GREEN}7.${NC} 脚本更新"
        echo -e " ${GREEN}4.${NC} 服务安装       ${GREEN}8.${NC} 卸载清理"
        echo "--------------------------------------------------------"
        echo -e " ${RED}0. 退出脚本${NC}"
        echo ""
        read -p " 请输入选项: " choice
        
        # 路由到对应的子菜单函数
        case $choice in
            1) menu_system ;;
            2) menu_network ;;
            3) menu_performance ;;
            4) menu_install ;;
            5|6) menu_others ;;   # 为了界面整洁，5和6使用同一个扩展工具菜单
            7|8) menu_maintain ;; # 7和8合并为维护菜单
            0) graceful_exit ;;   # 优雅退出
            *) ;;                 # 无效输入，循环重试
        esac
    done
}

# 设置信号捕获
# 当用户按下 Ctrl+C 时，不显示乱码，而是执行优雅退出逻辑
trap 'echo ""; exit 0' INT TERM

# 启动主函数，并传递所有命令行参数
main "$@"
