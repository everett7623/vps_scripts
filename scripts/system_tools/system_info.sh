#!/bin/bash
# ==============================================================================
# 脚本名称: system_info.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/system_info.sh
# 描述: VPS 系统信息深度检测脚本
#       提供硬件配置、网络状态、系统负载、虚拟化架构及关键服务运行状态的全面报告。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Standardized)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化与依赖加载
# ------------------------------------------------------------------------------

# 获取脚本真实路径（解决软链接问题）
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
# 定位项目根目录 (向上查找两级: scripts/system_tools/ -> scripts/ -> root/)
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
else
    # 如果找不到库文件（例如单独运行此脚本），则定义简易回退函数，防止报错
    echo "Warning: Common library not found. Using standalone mode."
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_title() { echo -e "\n${GREEN}▶ $1${NC}\n${BLUE}------------------------------------------------${NC}"; }
    print_separator() { echo -e "${BLUE}------------------------------------------------${NC}"; }
    get_public_ip() { curl -s -4 ip.sb; }
fi

# ------------------------------------------------------------------------------
# 2. 信息采集函数定义
# ------------------------------------------------------------------------------

# 获取系统基本概览
get_system_overview() {
    print_title "系统基本概览"
    
    # 主机名
    echo -e "${CYAN}主机名称:${NC} $(hostname)"
    
    # 操作系统 (优先读取 os-release)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${CYAN}操作系统:${NC} $PRETTY_NAME"
    else
        echo -e "${CYAN}操作系统:${NC} $(uname -s)"
    fi
    
    # 内核版本
    echo -e "${CYAN}内核版本:${NC} $(uname -r)"
    
    # 系统架构
    echo -e "${CYAN}系统架构:${NC} $(uname -m)"
    
    # 运行时间 (格式化输出)
    echo -e "${CYAN}运行时间:${NC} $(uptime -p | sed 's/up //')"
    
    # 系统时间
    echo -e "${CYAN}系统时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # 时区信息
    if [ -f /etc/timezone ]; then
        echo -e "${CYAN}系统时区:${NC} $(cat /etc/timezone)"
    else
        echo -e "${CYAN}系统时区:${NC} $(date +%Z)"
    fi
}

# 获取 CPU 详细信息
get_cpu_details() {
    print_title "CPU 处理器信息"
    
    # CPU 型号
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    echo -e "${CYAN}CPU 型号:${NC} ${cpu_model:-未知}"
    
    # CPU 核心数
    local cpu_cores=$(nproc 2>/dev/null || grep -c "processor" /proc/cpuinfo)
    echo -e "${CYAN}CPU 核心:${NC} ${cpu_cores} 核"
    
    # CPU 频率 (尝试获取)
    if [ -f /proc/cpuinfo ]; then
        local cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [ -n "$cpu_freq" ]; then
            echo -e "${CYAN}CPU 频率:${NC} ${cpu_freq} MHz"
        fi
    fi
    
    # CPU 实时使用率 (从 top 获取)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    echo -e "${CYAN}CPU 使用:${NC} ${cpu_usage}% (User+Sys)"
    
    # 系统负载
    local load_avg=$(uptime | grep -o 'load average:.*' | cut -d: -f2 | xargs)
    echo -e "${CYAN}系统负载:${NC} ${load_avg} (1/5/15 min)"
}

# 获取内存详细信息
get_memory_details() {
    print_title "内存与交换分区"
    
    # 从 /proc/meminfo 读取精确值 (单位 kB)
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    
    # 转换为 MB
    local mem_total_mb=$((mem_total / 1024))
    local mem_avail_mb=$((mem_avail / 1024))
    local mem_used_mb=$((mem_total_mb - mem_avail_mb))
    
    # 计算百分比
    local mem_usage_pct=0
    [ "$mem_total_mb" -gt 0 ] && mem_usage_pct=$((mem_used_mb * 100 / mem_total_mb))
    
    echo -e "${CYAN}物理内存:${NC} ${mem_used_mb}MB / ${mem_total_mb}MB (使用率: ${mem_usage_pct}%)"
    echo -e "${CYAN}可用内存:${NC} ${mem_avail_mb}MB"
    
    # Swap 信息
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    if [ "$swap_total" -gt 0 ]; then
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_total_mb=$((swap_total / 1024))
        local swap_used_mb=$(( (swap_total - swap_free) / 1024 ))
        local swap_usage_pct=$((swap_used_mb * 100 / swap_total_mb))
        
        echo -e "${CYAN}Swap交换:${NC} ${swap_used_mb}MB / ${swap_total_mb}MB (使用率: ${swap_usage_pct}%)"
    else
        echo -e "${CYAN}Swap交换:${NC} 未启用"
    fi
}

# 获取磁盘详细信息
get_disk_details() {
    print_title "磁盘存储状态"
    
    # 打印表头
    printf "${CYAN}%-15s %-9s %-9s %-9s %-6s %s${NC}\n" "挂载点" "总容量" "已用" "可用" "使用%" "设备"
    
    # 遍历物理磁盘 (排除 tmpfs, overlay 等)
    df -h | grep -E '^/dev/' | while read line; do
        local device=$(echo $line | awk '{print $1}')
        local size=$(echo $line | awk '{print $2}')
        local used=$(echo $line | awk '{print $3}')
        local avail=$(echo $line | awk '{print $4}')
        local usage=$(echo $line | awk '{print $5}')
        local mount=$(echo $line | awk '{print $6}')
        
        printf "  %-15s %-9s %-9s %-9s %-6s %s\n" "$mount" "$size" "$used" "$avail" "$usage" "$device"
    done
    
    # 显示汇总信息 (尝试使用 df --total)
    if df --help 2>&1 | grep -q -- "--total"; then
        local total_line=$(df -h --total 2>/dev/null | grep "total$")
        if [ -n "$total_line" ]; then
            local total_size=$(echo $total_line | awk '{print $2}')
            local total_used=$(echo $total_line | awk '{print $3}')
            local total_usage=$(echo $total_line | awk '{print $5}')
            echo ""
            echo -e "${PURPLE}磁盘汇总:${NC} 总计 ${total_size} | 已用 ${total_used} | 总使用率 ${total_usage}"
        fi
    fi
}

# 获取网络配置与 IP
get_network_details() {
    print_title "网络配置信息"
    
    # 遍历网络接口 (排除 lo)
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    for iface in $interfaces; do
        local ip4=$(ip addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        local ip6=$(ip addr show $iface | grep -oP '(?<=inet6\s)[0-9a-fA-F:]+' | head -n1)
        local mac=$(ip link show $iface | grep -oP '(?<=link/ether\s)[0-9a-fA-F:]+')
        local status=$(ip link show $iface | grep -oP '(?<=state\s)\w+')
        
        # 仅显示活动接口
        if [ -n "$ip4" ] || [ "$status" = "UP" ]; then
            echo -e "${CYAN}接口名称:${NC} $iface [状态: $status]"
            [ -n "$ip4" ] && echo -e "  IPv4: $ip4"
            [ -n "$ip6" ] && echo -e "  IPv6: $ip6"
            [ -n "$mac" ] && echo -e "  MAC : $mac"
            echo ""
        fi
    done
    
    # 公网 IP 检测 (复用库函数，支持 v4/v6)
    echo -e "${CYAN}公网出口 IP:${NC}"
    local pub_ip4=$(curl -s -4 --max-time 3 ip.sb 2>/dev/null || echo "检测失败")
    echo -e "  IPv4: $pub_ip4"
    
    local pub_ip6=$(curl -s -6 --max-time 3 ip.sb 2>/dev/null)
    [ -n "$pub_ip6" ] && echo -e "  IPv6: $pub_ip6"
    
    # IP 归属地查询
    if [[ "$pub_ip4" != "检测失败" ]]; then
        local region=$(curl -s --max-time 3 "https://ipapi.co/${pub_ip4}/country_name/" 2>/dev/null)
        [ -n "$region" ] && echo -e "  归属地: $region"
    fi
    
    # DNS 信息
    echo ""
    echo -e "${CYAN}DNS 服务器:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    else
        echo "  未检测到配置文件"
    fi
}

# 获取虚拟化环境信息
get_virtualization_details() {
    print_title "虚拟化环境检测"
    
    local virt_type="物理机 (Dedicated)"
    
    # 检测逻辑：systemd -> dmidecode -> cpuinfo
    if command -v systemd-detect-virt &> /dev/null; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        [ "$detected" != "none" ] && [ -n "$detected" ] && virt_type="$detected"
    elif [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
        virt_type="虚拟机 (Unknown Hypervisor)"
    fi
    
    # 尝试使用 dmidecode 获取更准确信息 (需 root)
    if [ "$EUID" -eq 0 ] && command -v dmidecode &> /dev/null; then
        local product=$(dmidecode -s system-product-name 2>/dev/null)
        case "$product" in
            *"VirtualBox"*) virt_type="VirtualBox" ;;
            *"VMware"*)     virt_type="VMware" ;;
            *"KVM"*)        virt_type="KVM" ;;
            *"Bochs"*)      virt_type="Bochs" ;;
            *"Alibaba"*)    virt_type="Aliyun ECS" ;;
            *"Tencent"*)    virt_type="Tencent CVM" ;;
        esac
    fi
    
    echo -e "${CYAN}架构类型:${NC} $virt_type"
    
    # 容器检测
    if [ -f /.dockerenv ]; then
        echo -e "${CYAN}运行环境:${NC} Docker 容器"
    elif [ -f /run/.containerenv ]; then
        echo -e "${CYAN}运行环境:${NC} Podman 容器"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        echo -e "${CYAN}运行环境:${NC} LXC 容器"
    fi
}

# 获取关键服务状态
get_service_status() {
    print_title "关键服务监控"
    
    # 定义常见服务列表
    local services=("ssh" "sshd" "nginx" "apache2" "docker" "mysql" "mariadb" "redis" "ufw" "iptables" "fail2ban" "cron")
    local found_any=false
    
    for service in "${services[@]}"; do
        # 仅检查系统中已安装的服务 (避免刷屏报错)
        if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
            found_any=true
            if systemctl is-active --quiet "$service"; then
                echo -e "  [${GREEN}RUNNING${NC}] $service"
            else
                echo -e "  [${YELLOW}STOPPED${NC}] $service"
            fi
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo -e "  ${YELLOW}未检测到预定义的常见服务。${NC}"
    fi
}

# 获取用户登录信息
get_user_details() {
    print_title "用户登录审计"
    
    echo -e "${CYAN}当前用户:${NC} $(whoami)"
    echo -e "${CYAN}在线会话:${NC} $(who | wc -l)"
    echo ""
    echo -e "${CYAN}最近登录记录 (前5条):${NC}"
    # 格式化输出 last 命令
    last -n 5 | head -n 5 | awk '{printf "  %-10s %-15s %s %s %s (%s)\n", $1, $3, $4, $5, $6, $10}'
}

# ------------------------------------------------------------------------------
# 3. 主程序入口
# ------------------------------------------------------------------------------

main() {
    # 检查权限 (非强制，但部分信息如 dmidecode 需要 root)
    # check_root # 如果希望非 root 也能看基本信息，可注释此行
    
    clear
    print_header "VPS 系统深度信息报告"
    
    get_system_overview
    get_cpu_details
    get_memory_details
    get_disk_details
    get_network_details
    get_virtualization_details
    get_service_status
    get_user_details
    
    echo ""
    print_separator
    print_msg "$GREEN" "信息采集完毕。"
    
    # 仅在独立运行时暂停
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo ""
        read -n 1 -s -r -p "按任意键退出..."
        echo ""
    fi
}

# 执行主函数
main "$@"
