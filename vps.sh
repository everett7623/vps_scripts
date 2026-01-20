#!/bin/bash
# ==============================================================================
# 脚本名称: vps.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: vps_scripts/vps.sh (项目根目录)
# 描述: VPS 综合管理工具箱 - 主入口脚本
#       负责环境初始化、依赖加载、主菜单显示以及子模块调度。
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.4.3 (GitHub Maintenance Edition)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心路径定位与环境初始化
#    (自动识别脚本所在目录为项目根目录，实现绿色免安装)
# ------------------------------------------------------------------------------

# 获取当前脚本文件的绝对物理路径
# readlink -f: 解析软链接，确保找到真实文件位置，而非快捷方式位置
SCRIPT_PATH=$(readlink -f "$0")

# 获取脚本所在的目录，作为"项目根目录" (Project Root)
# 在 GitHub 仓库结构中，这对应于 vps_scripts/ 根目录
PROJECT_ROOT=$(dirname "$SCRIPT_PATH")

# 定义核心依赖文件的绝对路径
# 对应仓库路径: vps_scripts/lib/common_functions.sh
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
# 对应仓库路径: vps_scripts/config/vps_scripts.conf
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

# ------------------------------------------------------------------------------
# 2. 依赖自检与加载
#    (确保 lib/ 和 config/ 目录在当前位置存在)
# ------------------------------------------------------------------------------

# 检查核心函数库是否存在
# 如果缺失，说明下载不完整或目录结构错误
if [ ! -f "$LIB_FILE" ]; then
    # 使用原生 echo 输出错误 (此时尚未加载颜色变量)
    echo -e "\033[0;31m[启动失败] 核心库丢失！\033[0m"
    echo "----------------------------------------------------"
    echo "无法找到文件: $LIB_FILE"
    echo "----------------------------------------------------"
    echo "请确保您克隆了完整的 GitHub 仓库，目录结构应如下："
    echo "  vps_scripts/            (项目根目录)"
    echo "  ├── vps.sh              (当前脚本)"
    echo "  ├── lib/                (库目录)"
    echo "  │   └── common_functions.sh"
    echo "  └── scripts/            (子脚本目录)"
    echo "----------------------------------------------------"
    exit 1
fi

# 加载公共函数库
# 导入颜色定义、日志函数(print_info/error)、系统检测等基础功能
source "$LIB_FILE"

# 加载配置文件
# 如果存在则加载，不存在则使用脚本内默认值并警告
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    print_warn "未找到配置文件: $CONFIG_FILE，将使用默认设置。"
fi

# 定义各功能模块的子目录路径
# 这些路径对应 GitHub 仓库中的 vps_scripts/scripts/ 下的子文件夹
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
SYSTEM_TOOLS_DIR="$SCRIPTS_DIR/system_tools"       # 对应 scripts/system_tools/
NETWORK_TEST_DIR="$SCRIPTS_DIR/network_test"       # 对应 scripts/network_test/
PERFORMANCE_TEST_DIR="$SCRIPTS_DIR/performance_test" # 对应 scripts/performance_test/
SERVICE_INSTALL_DIR="$SCRIPTS_DIR/service_install"   # 对应 scripts/service_install/
GOOD_SCRIPTS_DIR="$SCRIPTS_DIR/good_scripts"         # 对应 scripts/good_scripts/
OTHER_TOOLS_DIR="$SCRIPTS_DIR/other_tools"           # 对应 scripts/other_tools/
UPDATE_SCRIPTS_DIR="$SCRIPTS_DIR/update_scripts"     # 对应 scripts/update_scripts/
UNINSTALL_SCRIPTS_DIR="$SCRIPTS_DIR/uninstall_scripts" # 对应 scripts/uninstall_scripts/

# ------------------------------------------------------------------------------
# 3. 辅助功能函数定义
# ------------------------------------------------------------------------------

# 函数: run_script
# 功能: 安全地执行子脚本，包含权限检查和错误提示
# 参数: $1 = 脚本的绝对路径
run_script() {
    local script_path="$1"
    
    # 检查文件是否存在
    if [ -f "$script_path" ]; then
        # 自动赋予执行权限 (适配刚从 Git 拉取下来的情况)
        chmod +x "$script_path"
        
        # 使用 bash 新进程执行，防止变量污染
        bash "$script_path"
    else
        # 错误处理：提示缺失的文件名和预期路径
        print_error "子脚本丢失: $(basename "$script_path")"
        echo "预期路径: $script_path"
        echo "请检查 scripts/ 目录下是否包含该文件。"
        read -n 1 -s -r -p "按任意键返回菜单..."
    fi
}

# 函数: draw_dashboard
# 功能: 绘制主菜单顶部的系统实时状态看板
draw_dashboard() {
    clear
    print_header "VPS 综合管理工具箱 (Root版)"
    
    # 获取系统实时数据
    # 负载 (1/5/15分钟负载的第一个值)
    local load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
    # 内存使用率
    local mem_usage=$(free | awk '/Mem/{printf("%.1f%%"), $3/$2*100}')
    # 根分区磁盘使用率
    local disk_usage=$(df -h / | awk '/\//{print $(NF-1)}')
    # 获取本机IP (取第一个非回环IP)
    local ip_addr=$(hostname -I | awk '{print $1}')
    
    # 绘制状态栏表格
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}  ${BOLD}系统实时状态${NC}                                                                ${BLUE}│${NC}"
    echo -e "${BLUE}├──────────────────────┬───────────────────────┬───────────────────────────────┤${NC}"
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "Load: ${load}" "Mem: ${mem_usage}" "Disk: ${disk_usage}"
    printf "${BLUE}│${NC}  %-20s ${BLUE}│${NC}  %-21s ${BLUE}│${NC}  %-29s ${BLUE}│${NC}\n" \
        "IP: ${ip_addr}" "User: $(whoami)" "Dir: $(basename "$PROJECT_ROOT")"
    echo -e "${BLUE}└──────────────────────┴───────────────────────┴───────────────────────────────┘${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 4. 菜单逻辑定义
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
        
        read -p " 请选择: " choice
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

# 二级菜单: 扩展工具
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

# 二级菜单: 维护管理
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
# 5. 主程序入口
# ------------------------------------------------------------------------------

main() {
    # 检查 root 权限 (common_functions.sh 中定义)
    check_root
    
    # 检查必要依赖 (防止后续 wget/curl 报错)
    if ! command -v curl &> /dev/null; then
        echo "正在安装缺失的依赖: curl..."
        if command -v apt &> /dev/null; then apt update && apt install -y curl
        elif command -v yum &> /dev/null; then yum install -y curl
        fi
    fi

    # 进入主菜单循环
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
        
        case $choice in
            1) menu_system ;;
            2) menu_network ;;
            3) menu_performance ;;
            4) menu_install ;;
            5|6) menu_others ;;   # 合并 5/6 入口
            7|8) menu_maintain ;; # 合并 7/8 入口
            0) graceful_exit ;;
            *) ;;
        esac
    done
}

# 捕获 Ctrl+C 信号，优雅退出
trap 'echo ""; exit 0' INT TERM

# 启动主函数
main "$@"
