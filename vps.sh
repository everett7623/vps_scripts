#!/bin/bash

# VPS Scripts - 优化版主脚本
# 作者: Jensfrank
# 版本: 2025-06-12 v2.0.0
# GitHub: https://github.com/everett7623/vps_scripts

VERSION="2025-06-12 v2.0.0"
SCRIPT_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh"
VERSION_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/update_log.sh"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 定义渐变颜色数组
colors=(
    '\033[38;2;0;255;0m'    # 绿色
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # 黄色
)

# 全局变量
MENU_LEVEL=0
STATS_FILE="$HOME/.vps_scripts_stats"
CONFIG_FILE="$HOME/.vps_scripts_config"
OS=""
VER=""
PKG_MANAGER=""
PKG_INSTALL=""
PKG_UPDATE=""

# 错误处理
set -euo pipefail
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_no=$2
    echo -e "${RED}错误: 脚本在第 $line_no 行出错，退出码: $exit_code${NC}"
    exit $exit_code
}

# 检查 root 权限
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${YELLOW}此脚本需要 root 权限运行。${NC}"
        if ! sudo -v; then
            echo -e "${RED}无法获取 sudo 权限，退出脚本。${NC}"
            exit 1
        fi
        echo -e "${GREEN}已获取 sudo 权限。${NC}"
    fi
}

# 增强的系统检测
detect_os() {
    echo -e "${YELLOW}正在检测操作系统...${NC}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        PRETTY_NAME=$PRETTY_NAME
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        VER=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
        PRETTY_NAME="CentOS $VER"
    elif [ -f /etc/centos-release ]; then
        OS="centos"
        VER=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides centos-release))
        PRETTY_NAME="CentOS $VER"
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        VER=$(uname -r)
        PRETTY_NAME="$OS $VER"
    fi
    
    # 检测包管理器
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        PKG_UPGRADE="apt-get upgrade -y"
        PKG_CLEAN="apt-get autoremove -y && apt-get clean -y"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update || true"
        PKG_UPGRADE="dnf upgrade -y"
        PKG_CLEAN="dnf autoremove -y && dnf clean all"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum check-update || true"
        PKG_UPGRADE="yum upgrade -y"
        PKG_CLEAN="yum autoremove -y && yum clean all"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
        PKG_UPGRADE="zypper update -y"
        PKG_CLEAN="zypper clean -a"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        PKG_UPGRADE="pacman -Syu --noconfirm"
        PKG_CLEAN="pacman -Sc --noconfirm"
    else
        echo -e "${RED}未检测到支持的包管理器！${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}检测到系统: $PRETTY_NAME${NC}"
    echo -e "${GREEN}包管理器: $PKG_MANAGER${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}正在检查并安装必要的依赖项...${NC}"
    
    # 基础依赖列表
    local deps="curl wget sudo"
    
    # 根据系统添加特定依赖
    case "$OS" in
        ubuntu|debian)
            deps="$deps net-tools dnsutils"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 安装 EPEL 仓库（CentOS/RHEL）
            if [[ "$OS" == "centos" || "$OS" == "rhel" ]] && ! rpm -qa | grep -q epel-release; then
                echo -e "${YELLOW}正在安装 EPEL 仓库...${NC}"
                $PKG_INSTALL epel-release
            fi
            deps="$deps net-tools bind-utils"
            ;;
        arch|manjaro)
            deps="$deps net-tools bind"
            ;;
        opensuse*)
            deps="$deps net-tools bind-utils"
            ;;
    esac
    
    # 更新包列表
    echo -e "${YELLOW}正在更新软件包列表...${NC}"
    eval $PKG_UPDATE
    
    # 安装依赖
    for dep in $deps; do
        if ! command -v $dep &> /dev/null; then
            echo -e "${YELLOW}正在安装 $dep...${NC}"
            eval $PKG_INSTALL $dep
        else
            echo -e "${GREEN}$dep 已安装。${NC}"
        fi
    done
    
    echo -e "${GREEN}依赖项检查和安装完成。${NC}"
}

# 初始化统计文件
init_stats() {
    if [ ! -f "$STATS_FILE" ]; then
        cat > "$STATS_FILE" << EOF
total_runs=0
daily_runs=0
last_run_date=$(date +%Y%m%d)
menu_stats=()
EOF
    fi
}

# 更新统计
update_stats() {
    init_stats
    
    # 读取现有统计
    source "$STATS_FILE"
    
    local current_date=$(date +%Y%m%d)
    
    # 检查是否是新的一天
    if [ "$current_date" != "$last_run_date" ]; then
        daily_runs=0
        last_run_date=$current_date
    fi
    
    # 增加计数
    ((total_runs++))
    ((daily_runs++))
    
    # 保存统计
    cat > "$STATS_FILE" << EOF
total_runs=$total_runs
daily_runs=$daily_runs
last_run_date=$last_run_date
menu_stats=(${menu_stats[@]})
EOF
}

# 记录功能使用统计
record_function_usage() {
    local function_name="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $function_name" >> "$HOME/.vps_scripts_usage.log"
}

# 获取IP地址
ip_address() {
    ipv4_address=$(curl -s --max-time 5 ipv4.ip.sb)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi

    ipv6_address=$(curl -s --max-time 5 ipv6.ip.sb)
    if [ -z "$ipv6_address" ]; then
        ipv6_address=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi
}

# 更新脚本
update_scripts() {
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    local REMOTE_VERSION=$(curl -s -m 10 $VERSION_URL | grep -oP 'v[\d.]+' | head -1)
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}无法获取远程版本信息。请检查您的网络连接。${NC}"
        return 1
    fi
    
    local CURRENT_VERSION=$(echo $VERSION | grep -oP 'v[\d.]+')
    
    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "${BLUE}发现新版本 $REMOTE_VERSION，当前版本 $CURRENT_VERSION${NC}"
        echo -e "${BLUE}正在更新...${NC}"
        
        if curl -s -m 30 -o /tmp/vps_new.sh $SCRIPT_URL; then
            if [ -s /tmp/vps_new.sh ]; then
                mv /tmp/vps_new.sh "$0"
                chmod +x "$0"
                echo -e "${GREEN}脚本更新成功！新版本: $REMOTE_VERSION${NC}"
                echo -e "${YELLOW}请重新运行脚本以应用更新。${NC}"
                exit 0
            else
                echo -e "${RED}下载的脚本文件为空。更新失败。${NC}"
                return 1
            fi
        else
            echo -e "${RED}下载新版本失败。请稍后重试。${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}脚本已是最新版本 $CURRENT_VERSION。${NC}"
    fi
}

# 系统信息显示
show_system_info() {
    clear
    echo -e "${PURPLE}正在获取系统信息...${NC}"
    
    ip_address
    
    # CPU信息
    if [ "$(uname -m)" == "x86_64" ]; then
        cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
    else
        cpu_info=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
    fi
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
    cpu_usage_percent=$(printf "%.2f" "$cpu_usage")%
    
    # 其他系统信息
    cpu_cores=$(nproc)
    mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f GB (%.2f%%)", $3/1024/1024/1024, $2/1024/1024/1024, $3*100/$2}')
    disk_info=$(df -h | awk '$NF=="/"{printf "%s/%s (%s)", $3,$2,$5}')
    
    # 地理信息
    country=$(curl -s --max-time 5 ipinfo.io/country || echo "未知")
    city=$(curl -s --max-time 5 ipinfo.io/city || echo "未知")
    isp_info=$(curl -s --max-time 5 ipinfo.io/org || echo "未知")
    
    # 系统信息
    hostname=$(hostname)
    kernel_version=$(uname -r)
    uptime_info=$(uptime -p | sed 's/up //')
    
    # 网络配置
    congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    queue_algorithm=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    
    clear
    echo ""
    echo -e "${WHITE}系统信息详情${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}主机名:${NC} ${YELLOW}${hostname}${NC}"
    echo -e "${WHITE}系统:${NC} ${YELLOW}${PRETTY_NAME}${NC}"
    echo -e "${WHITE}内核:${NC} ${YELLOW}${kernel_version}${NC}"
    echo -e "${WHITE}运行时间:${NC} ${YELLOW}${uptime_info}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}CPU型号:${NC} ${YELLOW}${cpu_info}${NC}"
    echo -e "${WHITE}CPU核心:${NC} ${YELLOW}${cpu_cores}核${NC}"
    echo -e "${WHITE}CPU使用率:${NC} ${YELLOW}${cpu_usage_percent}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}内存:${NC} ${YELLOW}${mem_info}${NC}"
    echo -e "${WHITE}硬盘:${NC} ${YELLOW}${disk_info}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}IPv4:${NC} ${YELLOW}${ipv4_address:-无}${NC}"
    echo -e "${WHITE}IPv6:${NC} ${YELLOW}${ipv6_address:-无}${NC}"
    echo -e "${WHITE}地区:${NC} ${YELLOW}${country} ${city}${NC}"
    echo -e "${WHITE}运营商:${NC} ${YELLOW}${isp_info}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${WHITE}TCP拥塞控制:${NC} ${YELLOW}${congestion_algorithm}${NC}"
    echo -e "${WHITE}队列算法:${NC} ${YELLOW}${queue_algorithm}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 更新系统
update_system() {
    echo -e "${PURPLE}开始更新系统...${NC}"
    
    echo -e "${YELLOW}正在更新软件包列表...${NC}"
    eval $PKG_UPDATE
    
    echo -e "${YELLOW}正在升级系统...${NC}"
    eval $PKG_UPGRADE
    
    echo -e "${YELLOW}正在清理不需要的软件包...${NC}"
    eval $PKG_CLEAN
    
    echo -e "${GREEN}系统更新完成！${NC}"
}

# 清理系统
clean_system() {
    echo -e "${PURPLE}开始清理系统...${NC}"
    
    # 清理包管理器缓存
    echo -e "${YELLOW}清理软件包缓存...${NC}"
    eval $PKG_CLEAN
    
    # 清理日志
    echo -e "${YELLOW}清理系统日志...${NC}"
    journalctl --vacuum-time=1d 2>/dev/null || true
    
    # 清理临时文件
    echo -e "${YELLOW}清理临时文件...${NC}"
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # 清理用户缓存
    echo -e "${YELLOW}清理用户缓存...${NC}"
    rm -rf ~/.cache/*
    
    echo -e "${GREEN}系统清理完成！${NC}"
}

# 运行第三方脚本的统一函数
run_third_party_script() {
    local script_name="$1"
    local script_cmd="$2"
    local script_desc="$3"
    
    clear
    echo -e "${PURPLE}执行 $script_desc...${NC}"
    echo -e "${YELLOW}提示: 这是第三方脚本，请自行评估风险${NC}"
    echo ""
    
    record_function_usage "$script_name"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    local current_dir=$(pwd)
    cd "$temp_dir"
    
    # 执行脚本
    eval "$script_cmd"
    
    # 返回原目录并清理
    cd "$current_dir"
    rm -rf "$temp_dir"
    
    echo ""
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# 显示欢迎信息
show_welcome() {
    clear
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━By'Jensfrank━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "VPS脚本集合 $VERSION"
    echo "GitHub: https://github.com/everett7623/vps_scripts"
    echo ""
    echo -e "${colors[0]} #     # #####   #####       #####   #####  #####   ### #####  #####  #####  ${NC}"
    echo -e "${colors[1]} #     # #    # #     #     #     # #     # #    #   #  #    #   #   #     # ${NC}"
    echo -e "${colors[2]} #     # #    # #           #       #       #    #   #  #    #   #   #       ${NC}"
    echo -e "${colors[3]} #     # #####   #####       #####  #       #####    #  #####    #    #####  ${NC}"
    echo -e "${colors[4]}  #   #  #            #           # #       #   #    #  #        #         # ${NC}"
    echo -e "${colors[3]}   # #   #      #     #     #     # #     # #    #   #  #        #   #     # ${NC}"
    echo -e "${colors[2]}    #    #       #####       #####   #####  #     # ### #        #    #####  ${NC}"
    echo ""
    echo -e "系统: ${GREEN}$PRETTY_NAME${NC}"
    
    # 显示统计信息
    source "$STATS_FILE" 2>/dev/null || true
    echo -e "今日运行: ${PURPLE}${daily_runs:-0}${NC} 次 | 累计运行: ${PURPLE}${total_runs:-0}${NC} 次"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━By'Jensfrank━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 主菜单
show_main_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━ 主菜单 ━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} 系统工具          ${YELLOW}5)${NC} 第三方脚本集"
    echo -e "${YELLOW}2)${NC} 网络测试          ${YELLOW}6)${NC} 系统设置"
    echo -e "${YELLOW}3)${NC} 性能测试          ${YELLOW}88)${NC} 更新脚本"
    echo -e "${YELLOW}4)${NC} 服务安装          ${YELLOW}99)${NC} 卸载脚本"
    echo ""
    echo -e "${YELLOW}0)${NC} 退出脚本"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 系统工具子菜单
show_system_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━ 系统工具 ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} 查看系统信息"
    echo -e "${YELLOW}2)${NC} 更新系统"
    echo -e "${YELLOW}3)${NC} 清理系统"
    echo -e "${YELLOW}4)${NC} 系统优化"
    echo -e "${YELLOW}5)${NC} 修改主机名"
    echo -e "${YELLOW}6)${NC} 设置时区"
    echo ""
    echo -e "${YELLOW}0)${NC} 返回主菜单"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 网络测试子菜单
show_network_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━ 网络测试 ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} IP质量检测"
    echo -e "${YELLOW}2)${NC} 流媒体解锁测试"
    echo -e "${YELLOW}3)${NC} 三网测速"
    echo -e "${YELLOW}4)${NC} 回程路由测试"
    echo -e "${YELLOW}5)${NC} 响应时间测试"
    echo -e "${YELLOW}6)${NC} 带宽测试(iperf3)"
    echo ""
    echo -e "${YELLOW}0)${NC} 返回主菜单"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 性能测试子菜单
show_performance_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━ 性能测试 ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} YABS 综合测试"
    echo -e "${YELLOW}2)${NC} 融合怪测试"
    echo -e "${YELLOW}3)${NC} 超售测试"
    echo -e "${YELLOW}4)${NC} CPU 性能测试"
    echo -e "${YELLOW}5)${NC} 内存性能测试"
    echo -e "${YELLOW}6)${NC} 硬盘性能测试"
    echo ""
    echo -e "${YELLOW}0)${NC} 返回主菜单"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 服务安装子菜单
show_service_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━ 服务安装 ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} 安装 Docker"
    echo -e "${YELLOW}2)${NC} 安装 Docker Compose"
    echo -e "${YELLOW}3)${NC} 安装 Nginx"
    echo -e "${YELLOW}4)${NC} 安装 Node.js"
    echo -e "${YELLOW}5)${NC} 安装 Python 3"
    echo -e "${YELLOW}6)${NC} 安装常用工具包"
    echo ""
    echo -e "${YELLOW}0)${NC} 返回主菜单"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 第三方脚本子菜单
show_scripts_menu() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━ 第三方脚本集 ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}1)${NC} VPS工具箱"
    echo -e "${YELLOW}2)${NC} 科技Lion脚本"
    echo -e "${YELLOW}3)${NC} BlueSkyXN脚本"
    echo -e "${YELLOW}4)${NC} 勇哥Singbox"
    echo -e "${YELLOW}5)${NC} 勇哥X-UI"
    echo -e "${YELLOW}6)${NC} 3X-UI面板"
    echo -e "${YELLOW}7)${NC} 哪吒Agent清理"
    echo -e "${YELLOW}66)${NC} NodeLoc聚合测试"
    echo -e "${YELLOW}77)${NC} XY网络体检脚本"
    echo ""
    echo -e "${YELLOW}0)${NC} 返回主菜单"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 处理菜单选择
handle_main_choice() {
    case $1 in
        1) MENU_LEVEL=1 ;;
        2) MENU_LEVEL=2 ;;
        3) MENU_LEVEL=3 ;;
        4) MENU_LEVEL=4 ;;
        5) MENU_LEVEL=5 ;;
        6) 
            echo -e "${YELLOW}系统设置功能开发中...${NC}"
            sleep 2
            ;;
        88) 
            update_scripts
            read -n 1 -s -r -p "按任意键继续..."
            ;;
        99) 
            uninstall_script
            ;;
        0) 
            echo -e "${GREEN}感谢使用VPS脚本集合！再见！${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 处理系统工具菜单
handle_system_choice() {
    case $1 in
        1) 
            show_system_info
            read -n 1 -s -r -p "按任意键返回..."
            ;;
        2) 
            update_system
            read -n 1 -s -r -p "按任意键返回..."
            ;;
        3) 
            clean_system
            read -n 1 -s -r -p "按任意键返回..."
            ;;
        4) 
            echo -e "${YELLOW}系统优化功能开发中...${NC}"
            sleep 2
            ;;
        5) 
            echo -e "${YELLOW}修改主机名功能开发中...${NC}"
            sleep 2
            ;;
        6) 
            echo -e "${YELLOW}设置时区功能开发中...${NC}"
            sleep 2
            ;;
        0) MENU_LEVEL=0 ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 处理网络测试菜单
handle_network_choice() {
    case $1 in
        1) 
            run_third_party_script "ip_quality" "bash <(curl -Ls IP.Check.Place)" "IP质量检测"
            ;;
        2) 
            run_third_party_script "media_unlock" "bash <(curl -L -s media.ispvps.com)" "流媒体解锁测试"
            ;;
        3) 
            run_third_party_script "speedtest" "bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh)" "三网测速"
            ;;
        4) 
            run_third_party_script "autotrace" "wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh" "回程路由测试"
            ;;
        5) 
            run_third_party_script "response_test" "bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)" "响应时间测试"
            ;;
        6) 
            install_iperf3
            ;;
        0) MENU_LEVEL=0 ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 处理性能测试菜单
handle_performance_choice() {
    case $1 in
        1) 
            run_third_party_script "yabs" "wget -qO- yabs.sh | bash" "YABS综合测试"
            ;;
        2) 
            run_third_party_script "fusion" "curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh" "融合怪测试"
            ;;
        3) 
            run_third_party_script "oversell" "wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh" "超售测试"
            ;;
        4) 
            echo -e "${YELLOW}CPU性能测试功能开发中...${NC}"
            sleep 2
            ;;
        5) 
            echo -e "${YELLOW}内存性能测试功能开发中...${NC}"
            sleep 2
            ;;
        6) 
            echo -e "${YELLOW}硬盘性能测试功能开发中...${NC}"
            sleep 2
            ;;
        0) MENU_LEVEL=0 ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 处理服务安装菜单
handle_service_choice() {
    case $1 in
        1) 
            install_docker
            ;;
        2) 
            install_docker_compose
            ;;
        3) 
            install_nginx
            ;;
        4) 
            install_nodejs
            ;;
        5) 
            install_python3
            ;;
        6) 
            install_common_tools
            ;;
        0) MENU_LEVEL=0 ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 处理第三方脚本菜单
handle_scripts_choice() {
    case $1 in
        1) 
            run_third_party_script "vps_toolbox" "curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh" "VPS工具箱"
            ;;
        2) 
            run_third_party_script "kejilion" "bash <(curl -sL kejilion.sh)" "科技Lion脚本"
            ;;
        3) 
            run_third_party_script "blueskyxn" "wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh" "BlueSkyXN脚本"
            ;;
        4) 
            run_third_party_script "singbox_yg" "bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)" "勇哥Singbox"
            ;;
        5) 
            run_third_party_script "xui_yg" "bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh)" "勇哥X-UI"
            ;;
        6) 
            run_third_party_script "3xui" "bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)" "3X-UI面板"
            ;;
        7) 
            run_third_party_script "nezha_cleaner" "bash <(curl -s https://raw.githubusercontent.com/everett7623/Nezha-cleaner/main/nezha-agent-cleaner.sh)" "哪吒Agent清理"
            ;;
        66) 
            run_third_party_script "nodeloc" "curl -sSL abc.sd | bash" "NodeLoc聚合测试"
            ;;
        77) 
            run_third_party_script "xy_check" "bash <(curl -sL Net.Check.Place)" "XY网络体检"
            ;;
        0) MENU_LEVEL=0 ;;
        *) 
            echo -e "${RED}无效选择，请重新输入。${NC}"
            sleep 1
            ;;
    esac
}

# 安装 Docker
install_docker() {
    clear
    echo -e "${PURPLE}安装 Docker...${NC}"
    
    # 官方安装脚本
    curl -fsSL https://get.docker.com | bash -s docker
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    
    # 添加当前用户到 docker 组
    usermod -aG docker $USER
    
    echo -e "${GREEN}Docker 安装完成！${NC}"
    docker --version
    
    read -n 1 -s -r -p "按任意键返回..."
}

# 安装 iperf3
install_iperf3() {
    clear
    echo -e "${PURPLE}安装并配置 iperf3 服务端...${NC}"
    
    # 安装 iperf3
    eval $PKG_INSTALL iperf3
    
    # 检查是否已在运行
    if pgrep -x "iperf3" > /dev/null; then
        echo -e "${YELLOW}iperf3 服务已经在运行。${NC}"
    else
        echo -e "${YELLOW}启动 iperf3 服务...${NC}"
        iperf3 -s -D
        echo -e "${GREEN}iperf3 服务启动成功，监听端口 5201。${NC}"
    fi
    
    # 显示使用说明
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━ 客户端使用说明 ━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Windows 客户端下载: https://iperf.fr/iperf-download.php"
    echo ""
    echo -e "${YELLOW}基础测试命令:${NC}"
    echo "iperf3 -c 服务器IP              # 下载测试"
    echo "iperf3 -c 服务器IP -R           # 上传测试"
    echo "iperf3 -c 服务器IP -P 4         # 多线程下载"
    echo "iperf3 -c 服务器IP -R -P 4      # 多线程上传"
    echo "iperf3 -c 服务器IP -t 60        # 60秒持续测试"
    echo ""
    
    read -n 1 -s -r -p "按任意键返回..."
}

# 卸载脚本
uninstall_script() {
    clear
    echo -e "${RED}警告: 即将卸载 VPS Scripts 及相关文件！${NC}"
    echo ""
    echo "将执行以下操作:"
    echo "1. 删除脚本文件"
    echo "2. 清理配置文件"
    echo "3. 删除统计数据"
    echo ""
    
    read -p "确定要继续吗？(y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "已取消卸载。"
        return
    fi
    
    echo -e "${YELLOW}正在卸载...${NC}"
    
    # 删除文件
    rm -f "$0"
    rm -f "$STATS_FILE"
    rm -f "$CONFIG_FILE"
    rm -f "$HOME/.vps_scripts_usage.log"
    
    # 删除可能存在的临时文件
    rm -f /tmp/vps*.sh
    rm -rf /tmp/vps_scripts*
    
    echo -e "${GREEN}卸载完成！感谢使用 VPS Scripts。${NC}"
    exit 0
}

# 主循环
main() {
    # 初始化
    check_root
    detect_os
    install_dependencies
    init_stats
    update_stats
    
    # 主循环
    while true; do
        show_welcome
        
        case $MENU_LEVEL in
            0) 
                show_main_menu
                read -p "请选择 [0-99]: " choice
                handle_main_choice "$choice"
                ;;
            1) 
                show_system_menu
                read -p "请选择 [0-6]: " choice
                handle_system_choice "$choice"
                ;;
            2) 
                show_network_menu
                read -p "请选择 [0-6]: " choice
                handle_network_choice "$choice"
                ;;
            3) 
                show_performance_menu
                read -p "请选择 [0-6]: " choice
                handle_performance_choice "$choice"
                ;;
            4) 
                show_service_menu
                read -p "请选择 [0-6]: " choice
                handle_service_choice "$choice"
                ;;
            5) 
                show_scripts_menu
                read -p "请选择 [0-77]: " choice
                handle_scripts_choice "$choice"
                ;;
        esac
    done
}

# 启动脚本
main "$@"
