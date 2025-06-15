#!/bin/bash
# vps_dev.sh - VPS管理工具开发测试版
# 路径: vps_scripts/vps_dev.sh
# 功能: 提供VPS系统管理、网络测试、性能测试等功能的开发测试界面

# 导入配置和公共函数
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/lib/common_functions.sh"
source "$SCRIPT_DIR/config/vps_scripts.conf"

# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示分隔线
show_separator() {
    echo -e "${GREEN}================================================================================${NC}"
}

# 显示标题
show_title() {
    clear
    show_separator
    echo -e "${CYAN}                  $1                  ${NC}"
    show_separator
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查依赖
check_dependencies() {
    local dependencies=("curl" "wget" "jq")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}警告: 缺少以下依赖: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}某些功能可能无法正常工作。建议先安装这些依赖。${NC}"
        read -p "按Enter键继续..."
    fi
}

# 获取系统信息（如果common_functions.sh中未定义）
get_os_info() {
    if command_exists lsb_release; then
        lsb_release -ds
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        echo "$DISTRIB_DESCRIPTION"
    else
        echo "未知系统"
    fi
}

# 获取公网IP（如果common_functions.sh中未定义）
get_public_ip() {
    local ip=$(curl -s https://api.ipify.org)
    echo "${ip:-未获取到}"
}

# 运行脚本函数
run_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    show_title "正在执行: $script_name"
    echo -e "${YELLOW}脚本路径: ${script_path}${NC}"
    echo
    
    if [[ -f "$script_path" ]]; then
        source "$script_path"
    else
        echo -e "${RED}错误: 脚本文件不存在!${NC}"
    fi
    
    echo
    echo -e "${GREEN}操作完成!${NC}"
    read -p "按Enter键返回..."
}

# 主菜单
main_menu() {
    while true; do
        show_title "VPS管理工具 - 开发测试版"
        echo -e "${YELLOW}当前系统: $(get_os_info)${NC}"
        echo -e "${YELLOW}主机名: $(hostname)${NC}"
        echo -e "${YELLOW}IP地址: $(get_public_ip)${NC}"
        echo
        
        echo -e "${CYAN}主菜单:${NC}"
        echo "  1. ${BLUE}系统工具${NC} (vps_scripts/scripts/system_tools/)"
        echo "  2. ${BLUE}网络测试${NC} (vps_scripts/scripts/network_test/)"
        echo "  3. ${BLUE}性能测试${NC} (vps_scripts/scripts/performance_test/)"
        echo "  4. ${BLUE}服务安装${NC} (vps_scripts/scripts/service_install/)"
        echo "  5. ${BLUE}优秀脚本${NC} (vps_scripts/scripts/good_scripts/)"
        echo "  6. ${BLUE}梯子工具${NC} (vps_scripts/scripts/proxy_tools/)"
        echo "  7. ${BLUE}其他工具${NC} (vps_scripts/scripts/other_tools/)"
        echo "  8. ${BLUE}更新脚本${NC} (vps_scripts/scripts/update_scripts/)"
        echo "  9. ${BLUE}卸载脚本${NC} (vps_scripts/scripts/uninstall_scripts/)"
        echo "  0. ${RED}退出程序${NC}"
        
        show_separator
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1) system_tools_menu ;;
            2) network_test_menu ;;
            3) performance_test_menu ;;
            4) service_install_menu ;;
            5) good_scripts_menu ;;
            6) proxy_tools_menu ;;
            7) other_tools_menu ;;
            8) update_scripts_menu ;;
            9) uninstall_scripts_menu ;;
            0) echo -e "${GREEN}感谢使用VPS管理工具!${NC}"; exit 0 ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 系统工具子菜单
system_tools_menu() {
    while true; do
        show_title "系统工具"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/system_tools/)"
        echo
        echo "  1. ${BLUE}查看系统信息${NC} (system_info.sh)"
        echo "  2. ${BLUE}安装常用依赖${NC} (install_deps.sh)"
        echo "  3. ${BLUE}更新系统${NC} (update_system.sh)"
        echo "  4. ${BLUE}清理系统${NC} (clean_system.sh)"
        echo "  5. ${BLUE}系统优化${NC} (optimize_system.sh)"
        echo "  6. ${BLUE}修改主机名${NC} (change_hostname.sh)"
        echo "  7. ${BLUE}设置时区${NC} (set_timezone.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-7/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/system_tools/system_info.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/system_tools/install_deps.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/system_tools/update_system.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/system_tools/clean_system.sh" ;;
            5) run_script "$SCRIPT_DIR/scripts/system_tools/optimize_system.sh" ;;
            6) run_script "$SCRIPT_DIR/scripts/system_tools/change_hostname.sh" ;;
            7) run_script "$SCRIPT_DIR/scripts/system_tools/set_timezone.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 网络测试子菜单
network_test_menu() {
    while true; do
        show_title "网络测试"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/network_test/)"
        echo
        echo "  1. ${BLUE}回程路由测试${NC} (backhaul_route_test.sh)"
        echo "  2. ${BLUE}带宽测试${NC} (bandwidth_test.sh)"
        echo "  3. ${BLUE}CDN延迟测试${NC} (cdn_latency_test.sh)"
        echo "  4. ${BLUE}IP质量测试${NC} (ip_quality_test.sh)"
        echo "  5. ${BLUE}网络连通性测试${NC} (network_connectivity_test.sh)"
        echo "  6. ${BLUE}网络质量测试${NC} (network_quality_test.sh)"
        echo "  7. ${BLUE}网络安全扫描${NC} (network_security_scan.sh)"
        echo "  8. ${BLUE}网络测速${NC} (network_speedtest.sh)"
        echo "  9. ${BLUE}路由追踪${NC} (network_traceroute.sh)"
        echo " 10. ${BLUE}端口扫描器${NC} (port_scanner.sh)"
        echo " 11. ${BLUE}响应时间测试${NC} (response_time_test.sh)"
        echo " 12. ${BLUE}流媒体解锁测试${NC} (streaming_unlock_test.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-12/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/network_test/backhaul_route_test.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/network_test/bandwidth_test.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/network_test/cdn_latency_test.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/network_test/ip_quality_test.sh" ;;
            5) run_script "$SCRIPT_DIR/scripts/network_test/network_connectivity_test.sh" ;;
            6) run_script "$SCRIPT_DIR/scripts/network_test/network_quality_test.sh" ;;
            7) run_script "$SCRIPT_DIR/scripts/network_test/network_security_scan.sh" ;;
            8) run_script "$SCRIPT_DIR/scripts/network_test/network_speedtest.sh" ;;
            9) run_script "$SCRIPT_DIR/scripts/network_test/network_traceroute.sh" ;;
            10) run_script "$SCRIPT_DIR/scripts/network_test/port_scanner.sh" ;;
            11) run_script "$SCRIPT_DIR/scripts/network_test/response_time_test.sh" ;;
            12) run_script "$SCRIPT_DIR/scripts/network_test/streaming_unlock_test.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 性能测试子菜单
performance_test_menu() {
    while true; do
        show_title "性能测试"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/performance_test/)"
        echo
        echo "  1. ${BLUE}CPU基准测试${NC} (cpu_benchmark.sh)"
        echo "  2. ${BLUE}磁盘IO基准测试${NC} (disk_io_benchmark.sh)"
        echo "  3. ${BLUE}内存基准测试${NC} (memory_benchmark.sh)"
        echo "  4. ${BLUE}网络吞吐量测试${NC} (network_throughput_test.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-4/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/performance_test/cpu_benchmark.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/performance_test/disk_io_benchmark.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/performance_test/memory_benchmark.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/performance_test/network_throughput_test.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 服务安装子菜单
service_install_menu() {
    while true; do
        show_title "服务安装"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/service_install/)"
        echo
        echo "  1. ${BLUE}Docker安装${NC} (install_docker.sh)"
        echo "  2. ${BLUE}LNMP环境安装${NC} (install_lnmp.sh)"
        echo "  3. ${BLUE}Node.js安装${NC} (install_nodejs.sh)"
        echo "  4. ${BLUE}Python安装${NC} (install_python.sh)"
        echo "  5. ${BLUE}Redis安装${NC} (install_redis.sh)"
        echo "  6. ${BLUE}宝塔面板安装${NC} (install_bt_panel.sh)"
        echo "  7. ${BLUE}1Panel面板安装${NC} (install_1panel.sh)"
        echo "  8. ${BLUE}WordPress安装${NC} (install_wordpress.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-8/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/service_install/install_docker.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/service_install/install_lnmp.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/service_install/install_nodejs.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/service_install/install_python.sh" ;;
            5) run_script "$SCRIPT_DIR/scripts/service_install/install_redis.sh" ;;
            6) run_script "$SCRIPT_DIR/scripts/service_install/install_bt_panel.sh" ;;
            7) run_script "$SCRIPT_DIR/scripts/service_install/install_1panel.sh" ;;
            8) run_script "$SCRIPT_DIR/scripts/service_install/install_wordpress.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 优秀脚本子菜单
good_scripts_menu() {
    while true; do
        show_title "优秀脚本"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/good_scripts/)"
        echo
        echo "  1. ${BLUE}Yabs${NC} (wget -qO- yabs.sh | bash)"
        echo "  2. ${BLUE}XY-IP质量体检脚本${NC} (bash <(curl -Ls IP.Check.Place))"
        echo "  3. ${BLUE}XY-网络质量检测脚本${NC} (bash <(curl -Ls Net.Check.Place))"
        echo "  4. ${BLUE}NodeLoc聚合测试脚本${NC} (curl -sSL abc.sd | bash)"
        echo "  5. ${BLUE}融合怪测试${NC} (curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh | bash)"
        echo "  6. ${BLUE}流媒体解锁${NC} (bash <(curl -L -s media.ispvps.com))"
        echo "  7. ${BLUE}响应测试脚本${NC} (bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh))"
        echo "  8. ${BLUE}VPS一键脚本工具箱${NC} (curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh | bash)"
        echo "  9. ${BLUE}Jcnf常用脚本工具包${NC} (wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && bash jcnfbox.sh)"
        echo " 10. ${BLUE}科技Lion脚本${NC} (bash <(curl -sL kejilion.sh))"
        echo " 11. ${BLUE}BlueSkyXN脚本${NC} (wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && bash box.sh)"
        echo " 12. ${BLUE}三网测速${NC} (bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh))"
        echo " 13. ${BLUE}AutoTrace三网回程路由${NC} (wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && bash AutoTrace.sh)"
        echo " 14. ${BLUE}超售测试${NC} (wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && bash memoryCheck.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-14/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 1" ;;
            2) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 2" ;;
            3) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 3" ;;
            4) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 4" ;;
            5) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 5" ;;
            6) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 6" ;;
            7) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 7" ;;
            8) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 8" ;;
            9) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 9" ;;
            10) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 10" ;;
            11) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 11" ;;
            12) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 12" ;;
            13) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 13" ;;
            14) run_script "$SCRIPT_DIR/scripts/good_scripts/good_scripts.sh 14" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 梯子工具子菜单
proxy_tools_menu() {
    while true; do
        show_title "梯子工具"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/proxy_tools/)"
        echo
        echo "  1. ${BLUE}勇哥Singbox${NC} (bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh))"
        echo "  2. ${BLUE}F佬Singbox${NC} (bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh))"
        echo "  3. ${BLUE}勇哥X-UI${NC} (bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh))"
        echo "  4. ${BLUE}3X-UI${NC} (bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh))"
        echo "  5. ${BLUE}3X-UI优化版${NC} (bash <(curl -Ls https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh))"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-5/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/proxy_tools/proxy_tools.sh 1" ;;
            2) run_script "$SCRIPT_DIR/scripts/proxy_tools/proxy_tools.sh 2" ;;
            3) run_script "$SCRIPT_DIR/scripts/proxy_tools/proxy_tools.sh 3" ;;
            4) run_script "$SCRIPT_DIR/scripts/proxy_tools/proxy_tools.sh 4" ;;
            5) run_script "$SCRIPT_DIR/scripts/proxy_tools/proxy_tools.sh 5" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 其他工具子菜单
other_tools_menu() {
    while true; do
        show_title "其他工具"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/other_tools/)"
        echo
        echo "  1. ${BLUE}BBR加速${NC} (bbr.sh)"
        echo "  2. ${BLUE}Fail2ban${NC} (fail2ban.sh)"
        echo "  3. ${BLUE}安装哪吒监控${NC} (nezha.sh)"
        echo "  4. ${BLUE}设置SWAP${NC} (swap.sh)"
        echo "  5. ${BLUE}哪吒Agent清理${NC} (bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh))"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-5/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/other_tools/bbr.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/other_tools/fail2ban.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/other_tools/nezha.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/other_tools/swap.sh" ;;
            5) run_script "$SCRIPT_DIR/scripts/other_tools/nezha_cleaner.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 更新脚本子菜单
update_scripts_menu() {
    while true; do
        show_title "更新脚本"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/update_scripts/)"
        echo
        echo "  1. ${BLUE}触发自动更新${NC} (trigger_auto_update.sh)"
        echo "  2. ${BLUE}更新核心脚本${NC} (update_core_scripts.sh)"
        echo "  3. ${BLUE}更新依赖环境${NC} (update_dependencies.sh)"
        echo "  4. ${BLUE}更新功能工具脚本${NC} (update_functional_tools.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-4/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/update_scripts/trigger_auto_update.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/update_scripts/update_core_scripts.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/update_scripts/update_dependencies.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/update_scripts/update_functional_tools.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 卸载脚本子菜单
uninstall_scripts_menu() {
    while true; do
        show_title "卸载脚本"
        echo -e "${CYAN}子菜单:${NC} (vps_scripts/scripts/uninstall_scripts/)"
        echo
        echo "  1. ${BLUE}清理服务残留${NC} (clean_service_residues.sh)"
        echo "  2. ${BLUE}回滚系统环境${NC} (rollback_system_environment.sh)"
        echo "  3. ${BLUE}清除配置文件${NC} (clear_configuration_files.sh)"
        echo "  4. ${BLUE}完全卸载模式${NC} (full_uninstall.sh)"
        echo "  b. ${RED}返回主菜单${NC}"
        
        show_separator
        read -p "请输入选项 [1-4/b]: " choice
        
        case $choice in
            1) run_script "$SCRIPT_DIR/scripts/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_script "$SCRIPT_DIR/scripts/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_script "$SCRIPT_DIR/scripts/uninstall_scripts/clear_configuration_files.sh" ;;
            4) run_script "$SCRIPT_DIR/scripts/uninstall_scripts/full_uninstall.sh" ;;
            b) return ;;
            *) echo -e "${RED}错误: 无效选项，请重新输入!${NC}"; sleep 1 ;;
        esac
    done
}

# 主程序入口
check_dependencies
main_menu
