#!/bin/bash

# 脚本名称: system_info.sh
# 用途: 查看系统详细信息，包括硬件、系统、网络等
# 脚本路径: vps_scripts/scripts/system_tools/system_info.sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 获取脚本所在目录（相对于项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 加载公共函数库
if [ -f "${SCRIPT_DIR}/lib/common_functions.sh" ]; then
    source "${SCRIPT_DIR}/lib/common_functions.sh"
else
    echo -e "${RED}错误: 无法找到公共函数库文件${NC}"
    exit 1
fi

# 函数：显示标题
show_title() {
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo -e "${CYAN}           系统信息查看工具              ${NC}"
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# 函数：获取系统基本信息
get_system_info() {
    echo -e "${GREEN}[系统基本信息]${NC}"
    echo -e "${YELLOW}主机名:${NC} $(hostname)"
    echo -e "${YELLOW}系统版本:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${YELLOW}内核版本:${NC} $(uname -r)"
    echo -e "${YELLOW}系统架构:${NC} $(uname -m)"
    echo -e "${YELLOW}当前时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}系统时区:${NC} $(timedatectl | grep "Time zone" | awk '{print $3}')"
    echo -e "${YELLOW}运行时间:${NC} $(uptime -p)"
    echo ""
}

# 函数：获取CPU信息
get_cpu_info() {
    echo -e "${GREEN}[CPU信息]${NC}"
    echo -e "${YELLOW}CPU型号:${NC} $(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d':' -f2 | xargs)"
    echo -e "${YELLOW}CPU核心数:${NC} $(nproc)"
    echo -e "${YELLOW}CPU频率:${NC} $(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | cut -d':' -f2 | xargs) MHz"
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    echo -e "${YELLOW}CPU使用率:${NC} ${cpu_usage}%"
    
    # 系统负载
    load_average=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "${YELLOW}系统负载:${NC}${load_average}"
    echo ""
}

# 函数：获取内存信息
get_memory_info() {
    echo -e "${GREEN}[内存信息]${NC}"
    
    # 获取内存信息
    total_mem=$(free -h | grep Mem | awk '{print $2}')
    used_mem=$(free -h | grep Mem | awk '{print $3}')
    free_mem=$(free -h | grep Mem | awk '{print $4}')
    available_mem=$(free -h | grep Mem | awk '{print $7}')
    
    # 计算使用百分比
    total_mem_kb=$(free | grep Mem | awk '{print $2}')
    used_mem_kb=$(free | grep Mem | awk '{print $3}')
    mem_percent=$((used_mem_kb * 100 / total_mem_kb))
    
    echo -e "${YELLOW}总内存:${NC} $total_mem"
    echo -e "${YELLOW}已使用:${NC} $used_mem (${mem_percent}%)"
    echo -e "${YELLOW}空闲:${NC} $free_mem"
    echo -e "${YELLOW}可用:${NC} $available_mem"
    
    # Swap信息
    total_swap=$(free -h | grep Swap | awk '{print $2}')
    used_swap=$(free -h | grep Swap | awk '{print $3}')
    free_swap=$(free -h | grep Swap | awk '{print $4}')
    
    echo -e "${YELLOW}Swap总量:${NC} $total_swap"
    echo -e "${YELLOW}Swap已用:${NC} $used_swap"
    echo -e "${YELLOW}Swap空闲:${NC} $free_swap"
    echo ""
}

# 函数：获取磁盘信息
get_disk_info() {
    echo -e "${GREEN}[磁盘信息]${NC}"
    df -h | grep -E '^/dev/' | while read line; do
        device=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        avail=$(echo $line | awk '{print $4}')
        use_percent=$(echo $line | awk '{print $5}')
        mount=$(echo $line | awk '{print $6}')
        
        echo -e "${YELLOW}设备:${NC} $device"
        echo -e "  挂载点: $mount"
        echo -e "  总大小: $size"
        echo -e "  已使用: $used ($use_percent)"
        echo -e "  可用: $avail"
        echo ""
    done
}

# 函数：获取网络信息
get_network_info() {
    echo -e "${GREEN}[网络信息]${NC}"
    
    # 获取所有网络接口
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
    
    for interface in $interfaces; do
        # 获取IP地址
        ip_addr=$(ip addr show $interface | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
        if [ ! -z "$ip_addr" ]; then
            echo -e "${YELLOW}接口:${NC} $interface"
            echo -e "  IPv4地址: $ip_addr"
            
            # 获取IPv6地址
            ipv6_addr=$(ip addr show $interface | grep "inet6 " | grep -v "fe80" | awk '{print $2}' | cut -d'/' -f1)
            if [ ! -z "$ipv6_addr" ]; then
                echo -e "  IPv6地址: $ipv6_addr"
            fi
            
            # 获取MAC地址
            mac_addr=$(ip link show $interface | grep "link/ether" | awk '{print $2}')
            if [ ! -z "$mac_addr" ]; then
                echo -e "  MAC地址: $mac_addr"
            fi
            echo ""
        fi
    done
    
    # 获取公网IP
    echo -e "${YELLOW}公网IP信息:${NC}"
    public_ip=$(curl -s -4 ip.sb 2>/dev/null || echo "获取失败")
    echo -e "  IPv4: $public_ip"
    
    public_ipv6=$(curl -s -6 ip.sb 2>/dev/null || echo "获取失败或不支持IPv6")
    echo -e "  IPv6: $public_ipv6"
    echo ""
}

# 函数：获取进程信息
get_process_info() {
    echo -e "${GREEN}[进程信息]${NC}"
    total_processes=$(ps aux | wc -l)
    running_processes=$(ps aux | grep -c " R ")
    
    echo -e "${YELLOW}总进程数:${NC} $total_processes"
    echo -e "${YELLOW}运行中进程:${NC} $running_processes"
    echo ""
    
    echo -e "${YELLOW}占用CPU最多的5个进程:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "  %-10s %5s%% %s\n", $1, $3, $11}'
    echo ""
    
    echo -e "${YELLOW}占用内存最多的5个进程:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "  %-10s %5s%% %s\n", $1, $4, $11}'
    echo ""
}

# 函数：获取服务状态
get_service_status() {
    echo -e "${GREEN}[常用服务状态]${NC}"
    
    # 定义要检查的服务列表
    services=("sshd" "nginx" "apache2" "mysql" "mariadb" "docker" "redis" "postgresql")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            status=$(systemctl is-active $service 2>/dev/null)
            if [ "$status" == "active" ]; then
                echo -e "${service}: ${GREEN}运行中${NC}"
            else
                echo -e "${service}: ${RED}未运行${NC}"
            fi
        fi
    done
    echo ""
}

# 函数：生成系统报告
generate_report() {
    local report_file="/tmp/system_info_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "===== 系统信息报告 ====="
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        get_system_info
        get_cpu_info
        get_memory_info
        get_disk_info
        get_network_info
        get_process_info
        get_service_status
    } > "$report_file"
    
    echo -e "${GREEN}系统信息报告已生成: ${report_file}${NC}"
}

# 主函数
main() {
    show_title
    
    while true; do
        echo -e "${CYAN}请选择要查看的信息:${NC}"
        echo -e "${CYAN}  1.${NC} 查看所有信息"
        echo -e "${CYAN}  2.${NC} 系统基本信息"
        echo -e "${CYAN}  3.${NC} CPU信息"
        echo -e "${CYAN}  4.${NC} 内存信息"
        echo -e "${CYAN}  5.${NC} 磁盘信息"
        echo -e "${CYAN}  6.${NC} 网络信息"
        echo -e "${CYAN}  7.${NC} 进程信息"
        echo -e "${CYAN}  8.${NC} 服务状态"
        echo -e "${CYAN}  9.${NC} 生成系统报告"
        echo -e "${RED}  0.${NC} 返回上级菜单"
        echo ""
        
        read -p "请输入选项 [0-9]: " choice
        
        case $choice in
            1)
                clear
                show_title
                get_system_info
                get_cpu_info
                get_memory_info
                get_disk_info
                get_network_info
                get_process_info
                get_service_status
                ;;
            2)
                clear
                show_title
                get_system_info
                ;;
            3)
                clear
                show_title
                get_cpu_info
                ;;
            4)
                clear
                show_title
                get_memory_info
                ;;
            5)
                clear
                show_title
                get_disk_info
                ;;
            6)
                clear
                show_title
                get_network_info
                ;;
            7)
                clear
                show_title
                get_process_info
                ;;
            8)
                clear
                show_title
                get_service_status
                ;;
            9)
                generate_report
                ;;
            0)
                echo -e "${GREEN}返回上级菜单...${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新输入${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ] && [ "$choice" != "9" ]; then
            echo ""
            read -p "按回车键继续..."
            clear
            show_title
        fi
    done
}

# 执行主函数
main
