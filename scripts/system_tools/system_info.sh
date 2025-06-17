#!/bin/bash

#==============================================================================
# 脚本名称: system_info.sh
# 描述: VPS系统信息查看脚本 - 全面展示系统配置、硬件信息和资源使用情况
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/system_info.sh
# 使用方法: bash system_info.sh
# 更新日期: 2024-06-17
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}提示: 某些信息可能需要root权限才能完整显示${NC}"
        echo ""
    fi
}

# 打印分隔线
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 打印标题
print_title() {
    local title="$1"
    echo ""
    echo -e "${GREEN}▶ $title${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────${NC}"
}

# 获取系统基本信息
get_system_info() {
    print_title "系统基本信息"
    
    # 主机名
    echo -e "${CYAN}主机名称:${NC} $(hostname)"
    
    # 操作系统
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
    
    # 系统运行时间
    echo -e "${CYAN}运行时间:${NC} $(uptime -p 2>/dev/null || uptime)"
    
    # 当前时间
    echo -e "${CYAN}当前时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    # 时区
    if [ -f /etc/timezone ]; then
        echo -e "${CYAN}系统时区:${NC} $(cat /etc/timezone)"
    else
        echo -e "${CYAN}系统时区:${NC} $(timedatectl 2>/dev/null | grep "Time zone" | cut -d: -f2 | xargs)"
    fi
}

# 获取CPU信息
get_cpu_info() {
    print_title "CPU信息"
    
    # CPU型号
    cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    echo -e "${CYAN}CPU型号:${NC} ${cpu_model:-未知}"
    
    # CPU核心数
    cpu_cores=$(nproc 2>/dev/null || grep -c "processor" /proc/cpuinfo)
    echo -e "${CYAN}CPU核心:${NC} $cpu_cores 核"
    
    # CPU频率
    if [ -f /proc/cpuinfo ]; then
        cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [ -n "$cpu_freq" ]; then
            echo -e "${CYAN}CPU频率:${NC} ${cpu_freq} MHz"
        fi
    fi
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -n "$cpu_usage" ]; then
        echo -e "${CYAN}CPU使用率:${NC} ${cpu_usage}%"
    fi
    
    # 系统负载
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo -e "${CYAN}系统负载:${NC} $load_avg"
}

# 获取内存信息
get_memory_info() {
    print_title "内存信息"
    
    # 读取内存信息
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_free=$(grep MemFree /proc/meminfo | awk '{print $2}')
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_buffers=$(grep Buffers /proc/meminfo | awk '{print $2}')
    mem_cached=$(grep "^Cached" /proc/meminfo | awk '{print $2}')
    
    # 转换为MB
    mem_total_mb=$((mem_total / 1024))
    mem_free_mb=$((mem_free / 1024))
    mem_available_mb=$((mem_available / 1024))
    mem_used_mb=$((mem_total_mb - mem_available_mb))
    mem_usage=$((mem_used_mb * 100 / mem_total_mb))
    
    echo -e "${CYAN}总内存:${NC} ${mem_total_mb} MB"
    echo -e "${CYAN}已使用:${NC} ${mem_used_mb} MB (${mem_usage}%)"
    echo -e "${CYAN}可用内存:${NC} ${mem_available_mb} MB"
    echo -e "${CYAN}空闲内存:${NC} ${mem_free_mb} MB"
    
    # Swap信息
    swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
    
    if [ "$swap_total" -gt 0 ]; then
        swap_total_mb=$((swap_total / 1024))
        swap_free_mb=$((swap_free / 1024))
        swap_used_mb=$((swap_total_mb - swap_free_mb))
        swap_usage=$((swap_used_mb * 100 / swap_total_mb))
        
        echo ""
        echo -e "${CYAN}Swap总量:${NC} ${swap_total_mb} MB"
        echo -e "${CYAN}Swap已用:${NC} ${swap_used_mb} MB (${swap_usage}%)"
    else
        echo ""
        echo -e "${CYAN}Swap:${NC} 未配置"
    fi
}

# 获取磁盘信息
get_disk_info() {
    print_title "磁盘信息"
    
    # 磁盘使用情况
    df -h | grep -E '^/dev/' | while read line; do
        device=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        avail=$(echo $line | awk '{print $4}')
        usage=$(echo $line | awk '{print $5}')
        mount=$(echo $line | awk '{print $6}')
        
        echo -e "${CYAN}设备:${NC} $device"
        echo -e "  挂载点: $mount"
        echo -e "  总容量: $size | 已使用: $used | 可用: $avail | 使用率: $usage"
        echo ""
    done
    
    # 显示总磁盘使用情况
    total_disk=$(df -h --total 2>/dev/null | grep total | awk '{print $2}')
    used_disk=$(df -h --total 2>/dev/null | grep total | awk '{print $3}')
    avail_disk=$(df -h --total 2>/dev/null | grep total | awk '{print $4}')
    usage_disk=$(df -h --total 2>/dev/null | grep total | awk '{print $5}')
    
    if [ -n "$total_disk" ]; then
        echo -e "${PURPLE}磁盘总计:${NC} 总容量: $total_disk | 已使用: $used_disk | 可用: $avail_disk | 使用率: $usage_disk"
    fi
}

# 获取网络信息
get_network_info() {
    print_title "网络信息"
    
    # 获取所有网络接口
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        # 获取IP地址
        ip_addr=$(ip addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        ip6_addr=$(ip addr show $interface | grep -oP '(?<=inet6\s)[0-9a-fA-F:]+' | head -n1)
        
        # 获取MAC地址
        mac_addr=$(ip link show $interface | grep -oP '(?<=link/ether\s)[0-9a-fA-F:]+')
        
        # 获取接口状态
        status=$(ip link show $interface | grep -oP '(?<=state\s)\w+')
        
        echo -e "${CYAN}接口名称:${NC} $interface"
        [ -n "$ip_addr" ] && echo -e "  IPv4地址: $ip_addr"
        [ -n "$ip6_addr" ] && echo -e "  IPv6地址: $ip6_addr"
        [ -n "$mac_addr" ] && echo -e "  MAC地址: $mac_addr"
        echo -e "  状态: $status"
        echo ""
    done
    
    # 获取公网IP
    echo -e "${CYAN}公网IP地址:${NC}"
    public_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null || echo "获取失败")
    echo -e "  IPv4: $public_ip"
    
    public_ip6=$(curl -s -6 --max-time 5 ip.sb 2>/dev/null || echo "获取失败或不支持IPv6")
    echo -e "  IPv6: $public_ip6"
    
    # DNS服务器
    echo ""
    echo -e "${CYAN}DNS服务器:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    else
        echo "  无法获取DNS信息"
    fi
}

# 获取虚拟化信息
get_virtualization_info() {
    print_title "虚拟化信息"
    
    # 检测虚拟化类型
    virt_type="物理机"
    
    # 检查各种虚拟化标识
    if [ -f /proc/cpuinfo ]; then
        if grep -q "hypervisor" /proc/cpuinfo; then
            virt_type="虚拟机"
        fi
    fi
    
    # 检查systemd-detect-virt
    if command -v systemd-detect-virt &> /dev/null; then
        detected_virt=$(systemd-detect-virt 2>/dev/null)
        if [ "$detected_virt" != "none" ] && [ -n "$detected_virt" ]; then
            virt_type="$detected_virt"
        fi
    fi
    
    # 检查dmidecode（需要root权限）
    if [ $EUID -eq 0 ] && command -v dmidecode &> /dev/null; then
        dmi_info=$(dmidecode -s system-product-name 2>/dev/null)
        case "$dmi_info" in
            *"VirtualBox"*) virt_type="VirtualBox" ;;
            *"VMware"*) virt_type="VMware" ;;
            *"KVM"*) virt_type="KVM" ;;
            *"Xen"*) virt_type="Xen" ;;
            *"Microsoft Corporation"*) virt_type="Hyper-V" ;;
            *"QEMU"*) virt_type="QEMU" ;;
        esac
    fi
    
    echo -e "${CYAN}虚拟化类型:${NC} $virt_type"
    
    # 如果是容器环境
    if [ -f /.dockerenv ]; then
        echo -e "${CYAN}容器环境:${NC} Docker"
    elif [ -f /run/.containerenv ]; then
        echo -e "${CYAN}容器环境:${NC} Podman"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        echo -e "${CYAN}容器环境:${NC} LXC"
    fi
}

# 获取系统服务信息
get_service_info() {
    print_title "关键服务状态"
    
    # 定义要检查的服务列表
    services=("ssh" "sshd" "nginx" "apache2" "httpd" "mysql" "mariadb" "postgresql" "redis" "docker" "firewalld" "ufw")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            status=$(systemctl is-active $service 2>/dev/null)
            if [ "$status" = "active" ]; then
                echo -e "${GREEN}● $service${NC} - 运行中"
            elif [ "$status" = "inactive" ]; then
                echo -e "${YELLOW}● $service${NC} - 已停止"
            else
                echo -e "${RED}● $service${NC} - $status"
            fi
        fi
    done
}

# 获取用户信息
get_user_info() {
    print_title "用户信息"
    
    echo -e "${CYAN}当前用户:${NC} $(whoami)"
    echo -e "${CYAN}登录用户数:${NC} $(who | wc -l)"
    echo ""
    echo -e "${CYAN}最近登录:${NC}"
    last -n 5 | head -n 5
}

# 主函数
main() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS 系统信息查看工具 v1.0                          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    check_root
    
    get_system_info
    get_cpu_info
    get_memory_info
    get_disk_info
    get_network_info
    get_virtualization_info
    get_service_info
    get_user_info
    
    print_separator
    echo -e "${GREEN}系统信息收集完成！${NC}"
    echo ""
}

# 运行主函数
main
