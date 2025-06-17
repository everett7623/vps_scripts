#!/bin/bash

# ==================================================================
# 脚本名称: 系统信息查看脚本
# 脚本文件: system_info.sh
# 脚本路径: scripts/system_tools/system_info.sh
# 脚本用途: 查看VPS系统信息，包括系统版本、硬件配置、网络信息等
# 作者: Jensfrank
# 项目地址: https://github.com/everett7623/vps_scripts/
# 版本: 1.0.0
# 更新日期: 2025-01-17
# 
# 功能说明:
#   - 显示系统基本信息（发行版、内核版本等）
#   - 显示硬件信息（CPU、内存、磁盘等）
#   - 显示网络信息（IP地址、网络接口等）
#   - 显示系统负载和进程信息
#   - 显示虚拟化类型
# ==================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 加载公共函数库（如果存在）
if [[ -f "${ROOT_DIR}/lib/common_functions.sh" ]]; then
    source "${ROOT_DIR}/lib/common_functions.sh"
else
    # 如果没有公共函数库，使用本地定义
    :
fi

# 分隔线函数
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 显示脚本信息头
show_script_header() {
    echo ""
    print_separator
    echo -e "${CYAN}${BOLD}                              系统信息查看工具                                    ${NC}"
    echo -e "${CYAN}                          脚本路径: $(basename $0)                               ${NC}"
    print_separator
    echo ""
}

# 获取系统基本信息
get_system_info() {
    echo -e "${GREEN}${BOLD}[系统基本信息]${NC}"
    echo -e "${CYAN}主机名:${NC} $(hostname)"
    
    # 获取系统发行版信息
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${CYAN}操作系统:${NC} $NAME $VERSION"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${CYAN}操作系统:${NC} $(cat /etc/redhat-release)"
    else
        echo -e "${CYAN}操作系统:${NC} $(uname -s)"
    fi
    
    echo -e "${CYAN}内核版本:${NC} $(uname -r)"
    echo -e "${CYAN}系统架构:${NC} $(uname -m)"
    echo -e "${CYAN}当前时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}运行时间:${NC} $(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | awk -F',' '{print $1}')"
    echo ""
}

# 获取CPU信息
get_cpu_info() {
    echo -e "${GREEN}${BOLD}[CPU信息]${NC}"
    
    # CPU型号
    cpu_model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')
    echo -e "${CYAN}CPU型号:${NC} $cpu_model"
    
    # CPU核心数
    cpu_cores=$(nproc)
    echo -e "${CYAN}CPU核心:${NC} $cpu_cores 核"
    
    # CPU频率
    if [ -f /proc/cpuinfo ]; then
        cpu_freq=$(grep -m1 'cpu MHz' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//' | cut -d. -f1)
        if [ -n "$cpu_freq" ]; then
            echo -e "${CYAN}CPU频率:${NC} ${cpu_freq} MHz"
        fi
    fi
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${CYAN}CPU使用率:${NC} ${cpu_usage}%"
    
    # 负载平均值
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "${CYAN}系统负载:${NC}$load_avg"
    echo ""
}

# 获取内存信息
get_memory_info() {
    echo -e "${GREEN}${BOLD}[内存信息]${NC}"
    
    # 获取内存信息
    mem_total=$(free -h | grep '^Mem:' | awk '{print $2}')
    mem_used=$(free -h | grep '^Mem:' | awk '{print $3}')
    mem_free=$(free -h | grep '^Mem:' | awk '{print $4}')
    mem_available=$(free -h | grep '^Mem:' | awk '{print $7}')
    
    echo -e "${CYAN}总内存:${NC} $mem_total"
    echo -e "${CYAN}已使用:${NC} $mem_used"
    echo -e "${CYAN}空闲:${NC} $mem_free"
    echo -e "${CYAN}可用:${NC} $mem_available"
    
    # SWAP信息
    swap_total=$(free -h | grep '^Swap:' | awk '{print $2}')
    swap_used=$(free -h | grep '^Swap:' | awk '{print $3}')
    swap_free=$(free -h | grep '^Swap:' | awk '{print $4}')
    
    if [ "$swap_total" != "0B" ] && [ -n "$swap_total" ]; then
        echo -e "${CYAN}Swap总量:${NC} $swap_total"
        echo -e "${CYAN}Swap已用:${NC} $swap_used"
        echo -e "${CYAN}Swap空闲:${NC} $swap_free"
    else
        echo -e "${CYAN}Swap:${NC} 未配置"
    fi
    echo ""
}

# 获取磁盘信息
get_disk_info() {
    echo -e "${GREEN}${BOLD}[磁盘信息]${NC}"
    
    # 显示磁盘使用情况
    df -h | grep -E '^/dev/' | while read line; do
        device=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        avail=$(echo $line | awk '{print $4}')
        use_percent=$(echo $line | awk '{print $5}')
        mount=$(echo $line | awk '{print $6}')
        
        echo -e "${CYAN}设备:${NC} $device"
        echo -e "  ${CYAN}挂载点:${NC} $mount"
        echo -e "  ${CYAN}总容量:${NC} $size | ${CYAN}已使用:${NC} $used | ${CYAN}可用:${NC} $avail | ${CYAN}使用率:${NC} $use_percent"
        echo ""
    done
}

# 获取网络信息
get_network_info() {
    echo -e "${GREEN}${BOLD}[网络信息]${NC}"
    
    # 获取默认网络接口
    default_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    # 显示所有网络接口
    for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
        echo -e "${CYAN}接口:${NC} $interface"
        
        # 获取IP地址
        ip_addr=$(ip addr show $interface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$ip_addr" ]; then
            echo -e "  ${CYAN}IPv4地址:${NC} $ip_addr"
        fi
        
        # 获取IPv6地址
        ipv6_addr=$(ip addr show $interface | grep 'inet6 ' | grep -v 'fe80:' | awk '{print $2}' | cut -d/ -f1 | head -n1)
        if [ -n "$ipv6_addr" ]; then
            echo -e "  ${CYAN}IPv6地址:${NC} $ipv6_addr"
        fi
        
        # 获取MAC地址
        mac_addr=$(ip link show $interface | grep 'link/ether' | awk '{print $2}')
        if [ -n "$mac_addr" ]; then
            echo -e "  ${CYAN}MAC地址:${NC} $mac_addr"
        fi
        
        echo ""
    done
    
    # 获取公网IP
    echo -e "${CYAN}正在获取公网IP...${NC}"
    public_ip=$(curl -s -4 --max-time 5 ifconfig.me || echo "获取失败")
    echo -e "${CYAN}公网IPv4:${NC} $public_ip"
    
    public_ipv6=$(curl -s -6 --max-time 5 ifconfig.me || echo "获取失败")
    if [ "$public_ipv6" != "获取失败" ]; then
        echo -e "${CYAN}公网IPv6:${NC} $public_ipv6"
    fi
    echo ""
}

# 检测虚拟化类型
get_virtualization_info() {
    echo -e "${GREEN}${BOLD}[虚拟化信息]${NC}"
    
    # 使用systemd-detect-virt检测
    if command -v systemd-detect-virt &> /dev/null; then
        virt_type=$(systemd-detect-virt)
        echo -e "${CYAN}虚拟化类型:${NC} $virt_type"
    else
        # 备用检测方法
        if [ -f /proc/cpuinfo ]; then
            if grep -q "hypervisor" /proc/cpuinfo; then
                echo -e "${CYAN}虚拟化类型:${NC} 虚拟机 (具体类型未知)"
            else
                echo -e "${CYAN}虚拟化类型:${NC} 物理机或无法检测"
            fi
        fi
    fi
    
    # 检测具体的虚拟化平台
    if [ -f /sys/class/dmi/id/product_name ]; then
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        if [ -n "$product_name" ]; then
            echo -e "${CYAN}产品名称:${NC} $product_name"
        fi
    fi
    echo ""
}

# 获取进程信息
get_process_info() {
    echo -e "${GREEN}${BOLD}[进程信息]${NC}"
    
    # 总进程数
    total_processes=$(ps aux | wc -l)
    echo -e "${CYAN}总进程数:${NC} $((total_processes - 1))"
    
    # 运行中的进程数
    running_processes=$(ps aux | grep -c " R ")
    echo -e "${CYAN}运行中:${NC} $running_processes"
    
    # 显示占用资源最多的进程
    echo -e "\n${CYAN}CPU占用最高的5个进程:${NC}"
    ps aux --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "  %-8s %5s%% %s\n", $1, $3, $11}'
    
    echo -e "\n${CYAN}内存占用最高的5个进程:${NC}"
    ps aux --sort=-%mem | head -n 6 | tail -n 5 | awk '{printf "  %-8s %5s%% %s\n", $1, $4, $11}'
    echo ""
}

# 主函数
main() {
    # 显示脚本头部信息
    show_script_header
    
    # 收集并显示系统信息
    get_system_info
    get_cpu_info
    get_memory_info
    get_disk_info
    get_network_info
    get_virtualization_info
    get_process_info
    
    # 显示完成信息
    print_separator
    echo -e "${GREEN}${BOLD}系统信息收集完成！${NC}"
    echo ""
}

# 执行主函数
main
