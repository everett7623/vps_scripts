#!/bin/bash

# 脚本名称: system_info.sh
# 用途: 查看系统详细信息，包括硬件配置、系统版本、网络信息等
# 脚本路径: vps_scripts/scripts/system_tools/system_info.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 获取项目根目录
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 尝试多种方式找到项目根目录
if [ ! -f "${PROJECT_ROOT}/lib/common_functions.sh" ]; then
    # 可能是通过临时目录运行
    if [[ "${SCRIPT_DIR}" == /tmp/vps_scripts_* ]]; then
        PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    fi
fi

# 加载公共函数库
if [ -f "${PROJECT_ROOT}/lib/common_functions.sh" ]; then
    source "${PROJECT_ROOT}/lib/common_functions.sh"
fi

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m'

# 分隔线
print_separator() {
    echo -e "${CYAN}=================================================${NC}"
}

# 打印标题
print_title() {
    echo -e "${YELLOW}$1${NC}"
}

# 获取系统基本信息
get_system_info() {
    print_separator
    print_title "系统基本信息"
    print_separator
    
    # 主机名
    echo -e "${GREEN}主机名:${NC} $(hostname)"
    
    # 系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${GREEN}系统版本:${NC} $PRETTY_NAME"
    elif [ -f /etc/redhat-release ]; then
        echo -e "${GREEN}系统版本:${NC} $(cat /etc/redhat-release)"
    else
        echo -e "${GREEN}系统版本:${NC} $(uname -s) $(uname -r)"
    fi
    
    # 内核版本
    echo -e "${GREEN}内核版本:${NC} $(uname -r)"
    
    # 系统架构
    echo -e "${GREEN}系统架构:${NC} $(uname -m)"
    
    # 当前时间
    echo -e "${GREEN}当前时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 时区
    echo -e "${GREEN}系统时区:${NC} $(timedatectl | grep "Time zone" | awk '{print $3}')"
    
    # 运行时间
    echo -e "${GREEN}运行时间:${NC} $(uptime -p)"
    
    echo
}

# 获取CPU信息
get_cpu_info() {
    print_separator
    print_title "CPU信息"
    print_separator
    
    # CPU型号
    cpu_model=$(cat /proc/cpuinfo | grep "model name" | head -1 | awk -F': ' '{print $2}')
    echo -e "${GREEN}CPU型号:${NC} $cpu_model"
    
    # CPU核心数
    cpu_cores=$(nproc)
    echo -e "${GREEN}CPU核心数:${NC} $cpu_cores"
    
    # CPU频率
    cpu_freq=$(cat /proc/cpuinfo | grep "cpu MHz" | head -1 | awk -F': ' '{print $2}')
    echo -e "${GREEN}CPU频率:${NC} ${cpu_freq} MHz"
    
    # CPU使用率
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${GREEN}CPU使用率:${NC} ${cpu_usage}%"
    
    # 负载平均值
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "${GREEN}负载平均值:${NC}$load_avg"
    
    echo
}

# 获取内存信息
get_memory_info() {
    print_separator
    print_title "内存信息"
    print_separator
    
    # 总内存
    total_mem=$(free -h | grep "^Mem:" | awk '{print $2}')
    echo -e "${GREEN}总内存:${NC} $total_mem"
    
    # 已用内存
    used_mem=$(free -h | grep "^Mem:" | awk '{print $3}')
    echo -e "${GREEN}已用内存:${NC} $used_mem"
    
    # 可用内存
    available_mem=$(free -h | grep "^Mem:" | awk '{print $7}')
    echo -e "${GREEN}可用内存:${NC} $available_mem"
    
    # 缓存
    cached_mem=$(free -h | grep "^Mem:" | awk '{print $6}')
    echo -e "${GREEN}缓存:${NC} $cached_mem"
    
    # Swap信息
    swap_total=$(free -h | grep "^Swap:" | awk '{print $2}')
    swap_used=$(free -h | grep "^Swap:" | awk '{print $3}')
    echo -e "${GREEN}Swap总量:${NC} $swap_total"
    echo -e "${GREEN}Swap已用:${NC} $swap_used"
    
    echo
}

# 获取磁盘信息
get_disk_info() {
    print_separator
    print_title "磁盘信息"
    print_separator
    
    # 磁盘使用情况
    echo -e "${GREEN}磁盘使用情况:${NC}"
    df -h | grep -E "^/dev/" | while read line; do
        device=$(echo $line | awk '{print $1}')
        size=$(echo $line | awk '{print $2}')
        used=$(echo $line | awk '{print $3}')
        avail=$(echo $line | awk '{print $4}')
        use_percent=$(echo $line | awk '{print $5}')
        mount=$(echo $line | awk '{print $6}')
        
        echo -e "  ${CYAN}$device${NC} - 挂载点: $mount"
        echo -e "    总容量: $size, 已用: $used, 可用: $avail, 使用率: $use_percent"
    done
    
    echo
}

# 获取网络信息
get_network_info() {
    print_separator
    print_title "网络信息"
    print_separator
    
    # 获取默认网卡
    default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # 内网IP
    internal_ip=$(ip addr show $default_interface 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    echo -e "${GREEN}内网IP:${NC} $internal_ip"
    
    # 外网IP
    echo -e "${GREEN}外网IP:${NC} 获取中..."
    external_ip=$(curl -s -4 ip.sb 2>/dev/null || curl -s -4 icanhazip.com 2>/dev/null || echo "获取失败")
    echo -e "\033[1A\033[K${GREEN}外网IP:${NC} $external_ip"
    
    # IPv6地址
    ipv6_address=$(ip -6 addr show $default_interface 2>/dev/null | grep "inet6" | grep -v "fe80" | awk '{print $2}' | cut -d'/' -f1 | head -1)
    if [ -n "$ipv6_address" ]; then
        echo -e "${GREEN}IPv6地址:${NC} $ipv6_address"
    else
        echo -e "${GREEN}IPv6地址:${NC} 未配置"
    fi
    
    # 网络接口信息
    echo -e "${GREEN}网络接口:${NC}"
    ip -brief link show | while read line; do
        interface=$(echo $line | awk '{print $1}')
        state=$(echo $line | awk '{print $2}')
        mac=$(echo $line | awk '{print $3}')
        echo -e "  ${CYAN}$interface${NC} - 状态: $state, MAC: $mac"
    done
    
    # DNS服务器
    echo -e "${GREEN}DNS服务器:${NC}"
    if [ -f /etc/resolv.conf ]; then
        grep "nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    else
        echo "  无法获取"
    fi
    
    echo
}

# 获取进程信息
get_process_info() {
    print_separator
    print_title "进程信息"
    print_separator
    
    # 总进程数
    total_processes=$(ps aux | wc -l)
    echo -e "${GREEN}总进程数:${NC} $((total_processes - 1))"
    
    # 运行中的进程
    running_processes=$(ps aux | grep -c " R ")
    echo -e "${GREEN}运行中:${NC} $running_processes"
    
    # 睡眠中的进程
    sleeping_processes=$(ps aux | grep -c " S ")
    echo -e "${GREEN}睡眠中:${NC} $sleeping_processes"
    
    echo
    echo -e "${GREEN}占用CPU最高的5个进程:${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5 | while read line; do
        user=$(echo $line | awk '{print $1}')
        cpu=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $4}')
        cmd=$(echo $line | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
        echo -e "  CPU: ${YELLOW}${cpu}%${NC}, MEM: ${YELLOW}${mem}%${NC}, USER: $user"
        echo -e "  CMD: ${CYAN}${cmd:0:60}${NC}"
    done
    
    echo
    echo -e "${GREEN}占用内存最高的5个进程:${NC}"
    ps aux --sort=-%mem | head -6 | tail -5 | while read line; do
        user=$(echo $line | awk '{print $1}')
        cpu=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $4}')
        cmd=$(echo $line | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
        echo -e "  MEM: ${YELLOW}${mem}%${NC}, CPU: ${YELLOW}${cpu}%${NC}, USER: $user"
        echo -e "  CMD: ${CYAN}${cmd:0:60}${NC}"
    done
    
    echo
}

# 获取服务状态
get_service_status() {
    print_separator
    print_title "主要服务状态"
    print_separator
    
    # 检查常见服务
    services=("ssh" "nginx" "apache2" "httpd" "mysql" "mariadb" "postgresql" "redis" "docker" "firewalld" "ufw")
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            status=$(systemctl is-active $service 2>/dev/null)
            if [ "$status" = "active" ]; then
                echo -e "${GREEN}$service:${NC} ${GREEN}运行中${NC}"
            else
                echo -e "${GREEN}$service:${NC} ${RED}未运行${NC}"
            fi
        fi
    done
    
    echo
}

# 获取安全信息
get_security_info() {
    print_separator
    print_title "安全信息"
    print_separator
    
    # SELinux状态
    if command -v getenforce &> /dev/null; then
        selinux_status=$(getenforce)
        echo -e "${GREEN}SELinux状态:${NC} $selinux_status"
    else
        echo -e "${GREEN}SELinux状态:${NC} 未安装"
    fi
    
    # 防火墙状态
    if command -v ufw &> /dev/null; then
        ufw_status=$(ufw status | grep "Status:" | awk '{print $2}')
        echo -e "${GREEN}UFW防火墙:${NC} $ufw_status"
    elif command -v firewall-cmd &> /dev/null; then
        firewall_status=$(firewall-cmd --state 2>/dev/null || echo "未运行")
        echo -e "${GREEN}Firewalld防火墙:${NC} $firewall_status"
    else
        echo -e "${GREEN}防火墙:${NC} 未检测到防火墙"
    fi
    
    # 最近登录
    echo -e "${GREEN}最近5次登录:${NC}"
    last -5 | head -5 | while read line; do
        echo "  $line"
    done
    
    echo
}

# 生成系统报告
generate_report() {
    print_separator
    echo -e "${CYAN}          系统信息总览报告          ${NC}"
    print_separator
    echo -e "${YELLOW}生成时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo
    
    get_system_info
    get_cpu_info
    get_memory_info
    get_disk_info
    get_network_info
    get_process_info
    get_service_status
    get_security_info
    
    print_separator
    echo -e "${GREEN}系统信息收集完成！${NC}"
    print_separator
}

# 主函数
main() {
    clear
    echo -e "${CYAN}===================================================${NC}"
    echo -e "${CYAN}#              系统信息查看工具                   #${NC}"
    echo -e "${CYAN}===================================================${NC}"
    echo
    
    generate_report
}

# 执行主函数
main
