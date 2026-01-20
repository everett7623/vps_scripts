#!/bin/bash
# ==============================================================================
# 脚本名称: system_info.sh
# 脚本路径: scripts/system_tools/system_info.sh
# 描述: VPS系统信息查看脚本 - 全面展示系统配置、硬件信息和资源使用情况
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.3.0 (Fixed: DNS & IPv6 & Logins)
# 更新日期: 2026-01-20
# 依赖库: lib/common_functions.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心框架引导 (Boilerplate)
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 向上查找 lib 目录
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/lib/common_functions.sh" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

if [ "$PROJECT_ROOT" = "/" ]; then
    echo "Error: Cannot find project root (lib/common_functions.sh missing)."
    exit 1
fi

source "$PROJECT_ROOT/lib/common_functions.sh"
[ -f "$PROJECT_ROOT/config/vps_scripts.conf" ] && source "$PROJECT_ROOT/config/vps_scripts.conf"

# ------------------------------------------------------------------------------
# 2. 功能函数定义
# ------------------------------------------------------------------------------

# 获取CPU详细信息
get_cpu_detailed_info() {
    print_title "CPU 硬件与性能信息"
    
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    echo -e "${CYAN}CPU 型号:${NC} ${cpu_model:-未知}"
    
    echo -e "${CYAN}CPU 核心:${NC} $(get_cpu_cores) 核"
    
    if [ -f /proc/cpuinfo ]; then
        local cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [ -n "$cpu_freq" ]; then
            echo -e "${CYAN}CPU 频率:${NC} ${cpu_freq} MHz"
        fi
    fi
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -n "$cpu_usage" ]; then
        echo -e "${CYAN}实时使用:${NC} ${cpu_usage}%"
    fi
    
    local load_avg=$(uptime | grep -o 'load average:.*' | cut -d: -f2 | xargs)
    echo -e "${CYAN}系统负载:${NC} ${load_avg}"
}

# 获取内存详细信息
get_memory_detailed_info() {
    print_title "内存与交换分区信息"
    
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    
    local mem_total_mb=$((mem_total / 1024))
    local mem_available_mb=$((mem_available / 1024))
    local mem_free_mb=$((mem_free / 1024))
    local mem_used_mb=$((mem_total_mb - mem_available_mb))
    
    local mem_usage=0
    if [ "$mem_total_mb" -gt 0 ]; then
        mem_usage=$((mem_used_mb * 100 / mem_total_mb))
    fi
    
    echo -e "${CYAN}物理内存:${NC} ${mem_used_mb}MB / ${mem_total_mb}MB (使用率: ${mem_usage}%)"
    echo -e "${CYAN}可用内存:${NC} ${mem_available_mb}MB"
    echo -e "${CYAN}空闲内存:${NC} ${mem_free_mb}MB"
    
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    if [ "$swap_total" -gt 0 ]; then
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_total_mb=$((swap_total / 1024))
        local swap_used_mb=$(( (swap_total - swap_free) / 1024 ))
        local swap_usage=$((swap_used_mb * 100 / swap_total_mb))
        
        echo -e "${CYAN}Swap交换:${NC} ${swap_used_mb}MB / ${swap_total_mb}MB (使用率: ${swap_usage}%)"
    else
        echo -e "${CYAN}Swap交换:${NC} 未配置"
    fi
}

# 获取磁盘详细信息
get_disk_detailed_info() {
    print_title "磁盘存储使用详情"
    
    # 逐行读取物理磁盘信息
    df -h | grep -E '^/dev/' | while read line; do
        local device=$(echo $line | awk '{print $1}')
        local size=$(echo $line | awk '{print $2}')
        local used=$(echo $line | awk '{print $3}')
        local avail=$(echo $line | awk '{print $4}')
        local usage=$(echo $line | awk '{print $5}')
        local mount=$(echo $line | awk '{print $6}')
        
        echo -e "${CYAN}设备:${NC} $device"
        echo -e "  挂载点: $mount"
        echo -e "  容量: $size | 已用: $used | 可用: $avail | 使用率: $usage"
    done
    
    # 显示汇总
    if df --help 2>&1 | grep -q -- "--total"; then
        local total_line=$(df -h --total 2>/dev/null | grep "total$")
        if [ -n "$total_line" ]; then
            local total_size=$(echo $total_line | awk '{print $2}')
            local total_used=$(echo $total_line | awk '{print $3}')
            local total_avail=$(echo $total_line | awk '{print $4}')
            local total_usage=$(echo $total_line | awk '{print $5}')
            
            echo ""
            echo -e "${PURPLE}磁盘汇总:${NC} 总容量 $total_size | 已用 $total_used | 可用 $total_avail | 总使用率 $total_usage"
        fi
    fi
}

# 获取网络接口与DNS信息 (已修复 DNS 和 IPv6)
get_network_detailed_info() {
    print_title "网络接口与 IP 信息"
    
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
    
    for interface in $interfaces; do
        local ip_addr=$(ip addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        local ip6_addr=$(ip addr show $interface | grep -oP '(?<=inet6\s)[0-9a-fA-F:]+' | head -n1)
        local mac_addr=$(ip link show $interface | grep -oP '(?<=link/ether\s)[0-9a-fA-F:]+')
        local status=$(ip link show $interface | grep -oP '(?<=state\s)\w+')
        
        echo -e "${CYAN}接口名称:${NC} $interface"
        [ -n "$ip_addr" ] && echo -e "  IPv4地址: $ip_addr"
        [ -n "$ip6_addr" ] && echo -e "  IPv6地址: $ip6_addr"
        [ -n "$mac_addr" ] && echo -e "  MAC 地址: $mac_addr"
        echo -e "  接口状态: $status"
        echo ""
    done
    
    # 公网 IP 检测 (v4 和 v6)
    echo -e "${CYAN}公网出口 IP:${NC}"
    local public_ip4=$(get_public_ip 4)
    echo -e "  IPv4: ${public_ip4}"
    
    local public_ip6=$(get_public_ip 6)
    echo -e "  IPv6: ${public_ip6}"
    
    # 尝试获取地理位置
    if [[ "$public_ip4" != *"失败"* ]]; then
        local country=$(curl -s --max-time 2 "https://ipapi.co/${public_ip4}/country_name/" 2>/dev/null)
        [ -n "$country" ] && echo -e "  归属地: $country"
    fi

    # DNS 信息 (已补全)
    echo ""
    echo -e "${CYAN}DNS 服务器:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    else
        echo "  无法获取 DNS 信息"
    fi
}

# 获取虚拟化架构信息
get_virtualization_info() {
    print_title "虚拟化架构检测"
    
    local virt_type="物理机"
    
    if [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
        virt_type="虚拟机"
    fi
    
    if command -v systemd-detect-virt &> /dev/null; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        [ "$detected" != "none" ] && [ -n "$detected" ] && virt_type="$detected"
    fi
    
    if [ "$EUID" -eq 0 ] && command -v dmidecode &> /dev/null; then
        local dmi_info=$(dmidecode -s system-product-name 2>/dev/null)
        case "$dmi_info" in
            *"VirtualBox"*) virt_type="VirtualBox" ;;
            *"VMware"*)     virt_type="VMware" ;;
            *"KVM"*)        virt_type="KVM" ;;
            *"Xen"*)        virt_type="Xen" ;;
            *"Microsoft Corporation"*) virt_type="Hyper-V" ;;
            *"QEMU"*)       virt_type="QEMU/KVM" ;;
        esac
    fi
    
    echo -e "${CYAN}架构类型:${NC} $virt_type"
    
    if [ -f /.dockerenv ]; then
        echo -e "${CYAN}容器环境:${NC} Docker"
    elif [ -f /run/.containerenv ]; then
        echo -e "${CYAN}容器环境:${NC} Podman"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        echo -e "${CYAN}容器环境:${NC} LXC"
    fi
}

# 获取用户信息 (已恢复显示前5条)
get_user_info() {
    print_title "用户登录信息"
    echo -e "${CYAN}当前用户:${NC} $(whoami)"
    echo -e "${CYAN}在线用户:${NC} $(who | wc -l)"
    echo ""
    echo -e "${CYAN}最近登录记录 (前5条):${NC}"
    last -n 5 | head -n 5 | awk '{printf "  %-10s %-15s %s %s %s (%s)\n", $1, $3, $4, $5, $6, $10}'
}

# 获取关键服务状态
get_service_detailed_status() {
    print_title "关键服务监控"
    local services=("ssh" "sshd" "nginx" "apache2" "httpd" "mysql" "mariadb" "postgresql" "redis" "docker" "firewalld" "ufw" "fail2ban")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
            local status=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$status" = "active" ]; then
                echo -e "  [${GREEN}RUNNING${NC}] $service"
            elif [ "$status" = "inactive" ]; then
                echo -e "  [${YELLOW}STOPPED${NC}] $service"
            else
                echo -e "  [${RED}$status${NC}] $service"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 3. 主程序
# ------------------------------------------------------------------------------

main() {
    # 检查权限 (查看部分硬件信息建议root)
    check_root
    
    clear
    print_header "VPS 系统深度信息检测报告"
    
    # 1. 基础信息
    print_title "系统基础概览"
    echo -e "${CYAN}主机名称:${NC}   $(hostname)"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${CYAN}操作系统:${NC}   $PRETTY_NAME"
    else
        echo -e "${CYAN}操作系统:${NC}   $(uname -s)"
    fi
    
    echo -e "${CYAN}内核版本:${NC}   $(uname -r)"
    echo -e "${CYAN}系统架构:${NC}   $(uname -m)"
    echo -e "${CYAN}系统时间:${NC}   $(date "+%Y-%m-%d %H:%M:%S %Z")"
    echo -e "${CYAN}运行时长:${NC}   $(uptime -p | sed 's/up //')"
    
    if [ -f /etc/timezone ]; then
        echo -e "${CYAN}系统时区:${NC}   $(cat /etc/timezone)"
    fi
    
    # 2. 硬件资源
    get_cpu_detailed_info
    get_memory_detailed_info
    get_disk_detailed_info
    
    # 3. 网络与架构
    get_network_detailed_info
    get_virtualization_info
    
    # 4. 服务与用户
    get_service_detailed_status
    get_user_info
    
    echo ""
    print_separator
    print_msg "$GREEN" "系统信息收集完成！"
    
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo ""
        read -n 1 -s -r -p "按任意键返回主菜单..."
        echo ""
    fi
}

main "$@"
