#!/bin/bash
# ==============================================================================
# Script: vps.sh
# Project: https://github.com/everett7623/vps_scripts
# Purpose: Modular remote launcher for VPS Scripts.
# ==============================================================================

set -u

GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main"
PROJECT_URL="https://github.com/everett7623/vps_scripts"
LAUNCHER_STYLE_VERSION="2026.06"

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'

DOWNLOAD_TOOL=""
INSTALL_PREFIX="${VPS_INSTALL_PREFIX:-/usr/local}"
INSTALL_BIN_DIR="${INSTALL_PREFIX}/bin"
INSTALL_LIB_DIR="${INSTALL_PREFIX}/lib/vps-scripts"
INSTALL_LAUNCHER="${INSTALL_LIB_DIR}/vps.sh"
INSTALL_COMMAND="${INSTALL_BIN_DIR}/vps"

check_environment() {
    if command -v curl >/dev/null 2>&1; then
        DOWNLOAD_TOOL="curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOAD_TOOL="wget"
    else
        echo -e "${RED}[错误] 系统需要 curl 或 wget 才能下载脚本。${RESET}"
        exit 1
    fi
}

clear_screen() {
    command -v clear >/dev/null 2>&1 && clear
}

draw_rule() {
    local width="${1:-74}"
    local color="${2:-$BLUE}"
    printf '%b' "${color}"
    printf '%*s' "${width}" '' | tr ' ' '='
    printf '%b\n' "${RESET}"
}

print_header() {
    clear_screen
    draw_rule 74 "$CYAN"
    echo -e "${BOLD}${WHITE}  VPS 综合管理脚本${RESET}${DIM}  模块化启动器 | 界面 ${LAUNCHER_STYLE_VERSION}${RESET}"
    echo -e "${CYAN}  项目:${RESET} ${PROJECT_URL}"
    echo -e "${CYAN}  模式:${RESET} 安全下载官方模块 | 菜单校验 | 第三方脚本执行确认"
    draw_rule 74 "$CYAN"
    echo ""
}

print_panel_title() {
    echo -e "${BOLD}${PURPLE}$1${RESET}"
    draw_rule 74 "$PURPLE"
}

print_status_line() {
    echo -e "${DIM}下载工具:${RESET} ${DOWNLOAD_TOOL}  ${DIM}| 启动器:${RESET} 模块化  ${DIM}| 主题:${RESET} neon-shell"
    echo ""
}

pause_for_menu() {
    echo ""
    echo -e "${CYAN}[按任意键返回]${RESET}"
    read -n 1 -s -r
}

invalid_choice() {
    echo -e "${RED}无效选项，请重新输入。${RESET}"
    sleep 1
}

print_menu_item() {
    local key="${1}"
    local label="${2}"
    local detail="${3:-}"
    printf "%b%2s%b. %-24s" "${YELLOW}" "${key}" "${RESET}" "${label}"
    [ -n "${detail}" ] && printf "%b%s%b" "${DIM}" "${detail}" "${RESET}"
    printf "\n"
}

is_safe_repo_path() {
    local script_rel_path="${1}"
    [[ -n "${script_rel_path}" ]] && [[ "${script_rel_path}" != /* ]] && [[ "${script_rel_path}" != *".."* ]]
}

download_file_with_tool() {
    local url="${1}"
    local output="${2}"

    case "${DOWNLOAD_TOOL}" in
        curl)
            curl -fsSL --connect-timeout 10 --max-time 120 "${url}" -o "${output}"
            ;;
        wget)
            wget -q --timeout=120 -O "${output}" "${url}"
            ;;
        *)
            return 1
            ;;
    esac
}

require_install_permission() {
    if [ -n "${VPS_INSTALL_PREFIX:-}" ]; then
        return 0
    fi

    if [ -w "${INSTALL_PREFIX}" ] || { [ -d "${INSTALL_BIN_DIR}" ] && [ -w "${INSTALL_BIN_DIR}" ]; }; then
        return 0
    fi

    if [ "${EUID}" -ne 0 ]; then
        echo -e "${RED}[错误] 安装到 ${INSTALL_PREFIX} 需要 root 权限。${RESET}"
        echo -e "${DIM}请使用 sudo 重新运行，或将 VPS_INSTALL_PREFIX 设置为可写目录。${RESET}"
        return 1
    fi
}

install_vps_command() {
    local launcher_temp=""
    local command_temp=""
    local source_override="${VPS_INSTALL_SOURCE_OVERRIDE:-}"

    check_environment
    require_install_permission || return 1

    launcher_temp=$(mktemp "/tmp/vps_launcher.XXXXXX") || return 1
    command_temp=$(mktemp "/tmp/vps_command.XXXXXX") || {
        rm -f "${launcher_temp}"
        return 1
    }

    if [ -n "${source_override}" ]; then
        if [ ! -f "${source_override}" ]; then
            echo -e "${RED}[错误] 找不到安装源文件：${source_override}${RESET}"
            rm -f "${launcher_temp}" "${command_temp}"
            return 1
        fi
        cp "${source_override}" "${launcher_temp}"
    elif ! download_file_with_tool "${GITHUB_RAW_URL}/vps.sh" "${launcher_temp}"; then
        echo -e "${RED}[错误] 下载最新版启动器失败。${RESET}"
        rm -f "${launcher_temp}" "${command_temp}"
        return 1
    fi

    if [ ! -s "${launcher_temp}" ] || ! bash -n "${launcher_temp}"; then
        echo -e "${RED}[错误] 下载内容为空或语法无效，已拒绝安装。${RESET}"
        rm -f "${launcher_temp}" "${command_temp}"
        return 1
    fi

    printf '%s\n' \
        '#!/bin/bash' \
        "exec bash \"${INSTALL_LAUNCHER}\" \"\$@\"" > "${command_temp}"

    if ! mkdir -p "${INSTALL_BIN_DIR}" "${INSTALL_LIB_DIR}" ||
       ! install -m 0755 "${launcher_temp}" "${INSTALL_LAUNCHER}" ||
       ! install -m 0755 "${command_temp}" "${INSTALL_COMMAND}"; then
        echo -e "${RED}[错误] 安装 vps 快捷命令失败。${RESET}"
        rm -f "${launcher_temp}" "${command_temp}"
        return 1
    fi

    rm -f "${launcher_temp}" "${command_temp}"
    echo -e "${GREEN}[完成] 快捷命令已安装：${INSTALL_COMMAND}${RESET}"
    echo -e "${WHITE}现在可在任意目录输入 ${CYAN}vps${WHITE} 重新打开脚本。${RESET}"

    case ":${PATH}:" in
        *":${INSTALL_BIN_DIR}:"*) ;;
        *)
            echo -e "${YELLOW}[提示] ${INSTALL_BIN_DIR} 当前不在 PATH 中。${RESET}"
            echo -e "${DIM}请重新登录终端，或将该目录加入 shell 的 PATH。${RESET}"
            ;;
    esac
}

uninstall_vps_command() {
    require_install_permission || return 1

    rm -f "${INSTALL_COMMAND}" "${INSTALL_LAUNCHER}"
    rmdir "${INSTALL_LIB_DIR}" 2>/dev/null || true
    echo -e "${GREEN}[完成] vps 快捷命令已移除。${RESET}"
}

show_help() {
    printf '%s\n' \
        "用法：bash vps.sh [选项]" \
        "" \
        "选项：" \
        "  --install            安装或更新持久化 vps 快捷命令" \
        "  --uninstall-command  移除持久化 vps 快捷命令" \
        "  --help               显示此帮助信息"
}

run_repo_script() {
    local script_rel_path="${1}"
    local full_url="${GITHUB_RAW_URL}/${script_rel_path}"
    local temp_file=""

    print_header
    print_panel_title "官方模块"
    echo -e "${WHITE}> ${script_rel_path}${RESET}"
    echo ""

    if ! is_safe_repo_path "${script_rel_path}"; then
        echo -e "${RED}[错误] 仓库脚本路径无效。${RESET}"
        pause_for_menu
        return 1
    fi

    temp_file=$(mktemp "/tmp/vps_repo_script.XXXXXX") || {
        echo -e "${RED}[错误] 创建临时文件失败。${RESET}"
        pause_for_menu
        return 1
    }

    if ! download_file_with_tool "${full_url}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[错误] 下载模块失败。${RESET}"
        echo -e "${DIM}URL:${RESET} ${full_url}"
        pause_for_menu
        return 1
    fi

    if ! bash "${temp_file}"; then
        echo ""
        echo -e "${RED}[错误] 模块执行失败。${RESET}"
        echo -e "${DIM}URL:${RESET} ${full_url}"
    fi

    rm -f "${temp_file}"
    pause_for_menu
}

run_remote_script_url() {
    local url="${1}"
    local label="${2}"
    local temp_file=""

    print_header
    print_panel_title "第三方脚本"
    echo -e "${WHITE}> ${label}${RESET}"
    echo -e "${DIM}URL:${RESET} ${url}"
    echo ""
    read -r -p "是否下载并运行此第三方脚本？[y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消。${RESET}"
        pause_for_menu
        return 0
    fi

    temp_file=$(mktemp "/tmp/vps_remote_script.XXXXXX") || {
        echo -e "${RED}[错误] 创建临时文件失败。${RESET}"
        pause_for_menu
        return 1
    }

    if ! download_file_with_tool "${url}" "${temp_file}" || [ ! -s "${temp_file}" ]; then
        rm -f "${temp_file}"
        echo -e "${RED}[错误] 下载第三方脚本失败。${RESET}"
        pause_for_menu
        return 1
    fi

    chmod +x "${temp_file}" 2>/dev/null || true
    if ! bash "${temp_file}"; then
        echo ""
        echo -e "${RED}[错误] 第三方脚本执行失败。${RESET}"
    fi

    rm -f "${temp_file}"
    pause_for_menu
}

run_remote_command() {
    local command_to_run="${1}"
    local description="${2:-third-party command}"

    print_header
    print_panel_title "第三方命令"
    echo -e "${WHITE}> ${description}${RESET}"
    echo -e "${DIM}${command_to_run}${RESET}"
    echo ""
    read -r -p "是否运行此命令？[y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}已取消。${RESET}"
        pause_for_menu
        return 0
    fi

    eval "${command_to_run}"
    pause_for_menu
}

system_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "系统工具"
        print_menu_item 1 "查看系统信息" "硬件、内核与网络"
        print_menu_item 2 "安装常用依赖" "基础运行环境软件包"
        print_menu_item 3 "更新系统软件包" "安全的软件包更新流程"
        print_menu_item 4 "清理系统垃圾" "缓存与残留文件清理"
        print_menu_item 5 "优化系统参数" "内核与运行参数调优"
        print_menu_item 6 "修改主机名" "更新服务器名称"
        print_menu_item 7 "设置系统时区" "时钟与时区同步"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-7]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/system_tools/system_info.sh" ;;
            2) run_repo_script "scripts/system_tools/install_deps.sh" ;;
            3) run_repo_script "scripts/system_tools/update_system.sh" ;;
            4) run_repo_script "scripts/system_tools/clean_system.sh" ;;
            5) run_repo_script "scripts/system_tools/optimize_system.sh" ;;
            6) run_repo_script "scripts/system_tools/change_hostname.sh" ;;
            7) run_repo_script "scripts/system_tools/set_timezone.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

network_test_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "网络测试"
        print_menu_item 1 "回程路由测试" "查看网络返回路径"
        print_menu_item 2 "带宽测速" "测速节点与链路"
        print_menu_item 3 "IP 质量检测" "ASN、地区与黑名单提示"
        print_menu_item 4 "网络质量检测" "路由与延迟综合检查"
        print_menu_item 5 "流媒体解锁测试" "媒体服务地区检测"
        print_menu_item 0 "返回"
        echo ""
        echo -e "${DIM}更多第三方检测工具可在“社区脚本”菜单中使用。${RESET}"
        echo ""
        read -r -p "请选择 [0-5]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/network_test/backhaul_route_test.sh" ;;
            2) run_repo_script "scripts/network_test/bandwidth_test.sh" ;;
            3) run_repo_script "scripts/network_test/ip_quality_test.sh" ;;
            4) run_repo_script "scripts/network_test/network_quality_test.sh" ;;
            5) run_repo_script "scripts/network_test/streaming_unlock_test.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

performance_test_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "性能测试"
        print_menu_item 1 "CPU 基准测试" "单核与多核性能"
        print_menu_item 2 "磁盘 I/O 测试" "fio 与存储检查"
        print_menu_item 3 "内存基准测试" "吞吐量与延迟"
        print_menu_item 4 "网络吞吐测试" "iperf 类检测"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-4]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/performance_test/cpu_benchmark.sh" ;;
            2) run_repo_script "scripts/performance_test/disk_io_benchmark.sh" ;;
            3) run_repo_script "scripts/performance_test/memory_benchmark.sh" ;;
            4) run_repo_script "scripts/performance_test/network_throughput_test.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

service_install_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "服务安装"
        print_menu_item 1  "Docker" "容器运行环境"
        print_menu_item 2  "LDNMP" "轻量网站环境"
        print_menu_item 3  "Nginx" "Web 服务器"
        print_menu_item 4  "MySQL" "数据库服务器"
        print_menu_item 5  "PostgreSQL" "数据库服务器"
        print_menu_item 6  "Node.js" "JavaScript 运行环境"
        print_menu_item 7  "Python" "Python 运行环境"
        print_menu_item 8  "Redis" "缓存与队列"
        print_menu_item 9  "Go" "Go 运行环境"
        print_menu_item 10 "Java" "JDK 与开发工具"
        print_menu_item 11 "Ruby" "Ruby 运行环境"
        print_menu_item 12 "Rust" "Cargo 工具链"
        print_menu_item 13 "WordPress" "CMS 部署"
        print_menu_item 14 "aaPanel" "服务器控制面板"
        print_menu_item 15 "宝塔面板" "服务器控制面板"
        print_menu_item 16 "1Panel" "服务器控制面板"
        print_menu_item 17 "AMH" "服务器控制面板"
        print_menu_item 18 "CyberPanel" "服务器控制面板"
        print_menu_item 19 "Jenkins" "自动化服务"
        print_menu_item 20 "Kubernetes" "集群环境"
        print_menu_item 0  "返回"
        echo ""
        read -r -p "请选择 [0-20]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/service_install/docker.sh" ;;
            2) run_repo_script "scripts/service_install/ldnmp.sh" ;;
            3) run_repo_script "scripts/service_install/nginx.sh" ;;
            4) run_repo_script "scripts/service_install/mysql.sh" ;;
            5) run_repo_script "scripts/service_install/postgresql.sh" ;;
            6) run_repo_script "scripts/service_install/nodejs.sh" ;;
            7) run_repo_script "scripts/service_install/python.sh" ;;
            8) run_repo_script "scripts/service_install/redis.sh" ;;
            9) run_repo_script "scripts/service_install/go.sh" ;;
            10) run_repo_script "scripts/service_install/java.sh" ;;
            11) run_repo_script "scripts/service_install/ruby.sh" ;;
            12) run_repo_script "scripts/service_install/rust.sh" ;;
            13) run_repo_script "scripts/service_install/wordpress.sh" ;;
            14) run_repo_script "scripts/service_install/aapanel.sh" ;;
            15) run_repo_script "scripts/service_install/btpanel.sh" ;;
            16) run_repo_script "scripts/service_install/1panel.sh" ;;
            17) run_repo_script "scripts/service_install/amh.sh" ;;
            18) run_repo_script "scripts/service_install/cyberpanel.sh" ;;
            19) run_repo_script "scripts/service_install/jenkins.sh" ;;
            20) run_repo_script "scripts/service_install/kubernetes.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

community_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "社区脚本"
        print_menu_item 1  "YABS 性能测试" "综合基准脚本"
        print_menu_item 2  "XY-IP 质量检测" "IP 综合检查"
        print_menu_item 3  "XY 网络质量检测" "路由与质量"
        print_menu_item 4  "NodeLoc 综合测试" "多项目测试脚本"
        print_menu_item 5  "spiritLHLS ecs" "综合性能测试"
        print_menu_item 6  "流媒体解锁测试" "流媒体服务检测"
        print_menu_item 7  "响应时间测试" "curl 请求耗时"
        print_menu_item 8  "SSH 工具" "远程访问辅助"
        print_menu_item 9  "JCNF 工具箱" "社区综合工具箱"
        print_menu_item 10 "科技 Lion 工具箱" "社区综合工具箱"
        print_menu_item 11 "BlueSkyXN 工具箱" "社区综合工具箱"
        print_menu_item 12 "多线路测速" "多节点网络测速"
        print_menu_item 13 "AutoTrace" "路由追踪工具"
        print_menu_item 14 "超售检测" "内存压力测试"
        print_menu_item 0  "返回"
        echo ""
        read -r -p "请选择 [0-14]: " choice

        case "${choice}" in
            1) run_remote_script_url "https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh" "YABS benchmark" ;;
            2) run_remote_script_url "https://IP.Check.Place" "XY-IP quality" ;;
            3) run_remote_script_url "https://Net.Check.Place" "XY network quality" ;;
            4) run_remote_command "curl -sSL https://abc.sd | bash" "NodeLoc benchmark" ;;
            5) run_remote_script_url "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh" "spiritLHLS ecs" ;;
            6) run_remote_script_url "https://media.ispvps.com" "Media unlock test" ;;
            7) run_remote_script_url "https://nodebench.mereith.com/scripts/curltime.sh" "Response time test" ;;
            8) run_remote_command "curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh" "SSH tool" ;;
            9) run_remote_command "wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh" "JCNF toolbox" ;;
            10) run_remote_script_url "https://kejilion.sh" "KejiLion toolbox" ;;
            11) run_remote_command "wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh" "BlueSkyXN toolbox" ;;
            12) run_remote_script_url "https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh" "Multi-line speedtest" ;;
            13) run_remote_command "wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh" "AutoTrace" ;;
            14) run_remote_command "wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh" "Oversell check" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

proxy_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "代理工具"
        print_menu_item 1 "勇哥 sing-box" "第三方社区脚本"
        print_menu_item 2 "fscarmen sing-box" "第三方社区脚本"
        print_menu_item 3 "勇哥 x-ui" "第三方社区脚本"
        print_menu_item 4 "官方 3x-ui" "第三方社区脚本"
        print_menu_item 5 "xeefei 3x-ui" "第三方社区脚本"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-5]: " choice

        case "${choice}" in
            1) run_remote_script_url "https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh" "yonggekkk sing-box" ;;
            2) run_remote_script_url "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" "fscarmen sing-box" ;;
            3) run_remote_script_url "https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh" "yonggekkk x-ui" ;;
            4) run_remote_script_url "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" "Official 3x-ui" ;;
            5) run_remote_script_url "https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh" "xeefei 3x-ui" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

other_tools_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "其他工具"
        print_menu_item 1 "BBR" "网络加速"
        print_menu_item 2 "Fail2ban" "基础安全防护"
        print_menu_item 3 "哪吒探针" "服务器监控"
        print_menu_item 4 "Swap" "虚拟内存管理"
        print_menu_item 5 "哪吒清理工具" "第三方清理脚本"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-5]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/other_tools/bbr.sh" ;;
            2) run_repo_script "scripts/other_tools/fail2ban.sh" ;;
            3) run_repo_script "scripts/other_tools/nezha.sh" ;;
            4) run_repo_script "scripts/other_tools/swap.sh" ;;
            5) run_remote_script_url "https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh" "Nezha cleaner" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

update_info_menu() {
    print_header
    print_panel_title "更新说明"
    echo -e "${WHITE}启动器会在运行时获取最新的官方模块。${RESET}"
    echo -e "${DIM}如需刷新主界面，可重新运行以下命令：${RESET}"
    echo ""
    echo -e "${CYAN}bash <(curl -fsSL ${GITHUB_RAW_URL}/vps.sh)${RESET}"
    pause_for_menu
}

command_setup_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "快捷命令管理"
        echo -e "${DIM}持久化命令:${RESET} ${INSTALL_COMMAND}"
        echo ""
        print_menu_item 1 "安装或更新命令" "可在任意目录输入 vps"
        print_menu_item 2 "移除快捷命令" "仅删除启动快捷方式"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-2]: " choice

        case "${choice}" in
            1) install_vps_command; pause_for_menu ;;
            2) uninstall_vps_command; pause_for_menu ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

uninstall_menu() {
    while true; do
        print_header
        print_status_line
        print_panel_title "清理与卸载"
        print_menu_item 1 "清理服务残留" "移除遗留文件"
        print_menu_item 2 "回滚系统环境" "撤销运行环境变更"
        print_menu_item 3 "清理配置文件" "移除项目配置"
        print_menu_item 4 "完整卸载" "深度清理流程"
        print_menu_item 0 "返回"
        echo ""
        read -r -p "请选择 [0-4]: " choice

        case "${choice}" in
            1) run_repo_script "scripts/uninstall_scripts/clean_service_residues.sh" ;;
            2) run_repo_script "scripts/uninstall_scripts/rollback_system_environment.sh" ;;
            3) run_repo_script "scripts/uninstall_scripts/clear_configuration_files.sh" ;;
            4) run_repo_script "scripts/uninstall_scripts/full_uninstall.sh" ;;
            0) return ;;
            *) invalid_choice ;;
        esac
    done
}

main_menu() {
    check_environment

    while true; do
        print_header
        print_status_line
        print_panel_title "主菜单"
        print_menu_item 1 "系统工具" "信息、优化与更新"
        print_menu_item 2 "网络测试" "质量、路由与流媒体"
        print_menu_item 3 "性能测试" "CPU、磁盘与内存"
        print_menu_item 4 "服务安装" "语言与应用环境"
        print_menu_item 5 "社区脚本" "常用第三方工具"
        print_menu_item 6 "代理工具" "sing-box 与 x-ui 系列"
        print_menu_item 7 "其他工具" "BBR、Fail2ban、Swap"
        print_menu_item 8 "快捷命令管理" "安装持久化 vps 命令"
        print_menu_item 9 "更新说明" "启动器更新方式"
        print_menu_item 10 "清理与卸载" "残留清理"
        print_menu_item 0 "退出"
        echo ""
        echo -e "${DIM}官方模块会先安全下载到临时文件，通过检查后再执行。${RESET}"
        echo ""
        read -r -p "请选择 [0-10]: " choice

        case "${choice}" in
            1) system_tools_menu ;;
            2) network_test_menu ;;
            3) performance_test_menu ;;
            4) service_install_menu ;;
            5) community_menu ;;
            6) proxy_tools_menu ;;
            7) other_tools_menu ;;
            8) command_setup_menu ;;
            9) update_info_menu ;;
            10) uninstall_menu ;;
            0)
                echo ""
                echo -e "${GREEN}已退出 VPS 综合管理脚本。${RESET}"
                exit 0
                ;;
            *) invalid_choice ;;
        esac
    done
}

trap 'echo -e "\n${GREEN}用户已中断操作。${RESET}"; exit 0' INT TERM

case "${1:-}" in
    --install)
        install_vps_command
        ;;
    --uninstall-command)
        uninstall_vps_command
        ;;
    --help|-h)
        show_help
        ;;
    "")
        main_menu
        ;;
    *)
        echo -e "${RED}[错误] 未知选项：$1${RESET}" >&2
        show_help
        exit 1
        ;;
esac
