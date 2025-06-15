#!/bin/bash
# 系统信息脚本 - 显示详细的系统信息
# 位置：scripts/system_tools/system_info.sh

# 获取脚本所在目录
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 向上两级目录到达项目根目录
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_PATH")")"

# 尝试加载核心功能库
if [[ -f "${PROJECT_ROOT}/lib/common_functions.sh" ]]; then
    source "${PROJECT_ROOT}/lib/common_functions.sh"
    USE_LIB=true
else
    USE_LIB=false
    # 如果没有核心库，定义基础颜色和函数
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[1;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    NC='\033[0m' # No Color
    
    # 基础日志函数
    log() {
        local level="$1"
        shift
        local message="$*"
        
        case "$level" in
            INFO)
                echo -e "${GREEN}[INFO]${NC} ${message}"
                ;;
            WARN)
                echo -e "${YELLOW}[WARN]${NC} ${message}"
                ;;
            ERROR)
                echo -e "${RED}[ERROR]${NC} ${message}"
                ;;
        esac
    }
    
    # 基础按键函数
    press_any_key() {
        echo ""
        read -n 1 -s -r -p "按任意键返回主菜单..."
        echo ""
    }
fi

# 脚本信息
SCRIPT_NAME="system_info"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="显示详细的VPS系统信息"

# 获取CPU使用率
get_cpu_usage() {
    local cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
    printf "%.2f%%" "$cpu_usage"
}

# 获取系统信息（兼容原版）
get_system_info_local() {
    # CPU信息
    if [[ "$(uname -m)" == "x86_64" ]]; then
        CPU_INFO=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
    else
        CPU_INFO=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
    fi
    
    # CPU核心数
    CPU_CORES=$(nproc)
    
    # 内存信息
    MEM_TOTAL=$(free -b | awk 'NR==2{printf "%.2f", $2/1024/1024}')
    MEM_USED=$(free -b | awk 'NR==2{printf "%.2f", $3/1024/1024}')
    MEM_PERCENT=$(free -b | awk 'NR==2{printf "%.2f", $3*100/$2}')
    
    # 磁盘信息
    DISK_INFO=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    
    # 系统运行时间
    UPTIME=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分", run_minutes)}')
}

# 获取IP地址（兼容版本）
get_ip_address_local() {
    # IPv4地址
    IPV4_ADDRESS=$(curl -s --max-time 5 ipv4.ip.sb 2>/dev/null)
    if [[ -z "$IPV4_ADDRESS" ]]; then
        IPV4_ADDRESS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi
    
    # IPv6地址
    IPV6_ADDRESS=$(curl -s --max-time 5 ipv6.ip.sb 2>/dev/null)
    if [[ -z "$IPV6_ADDRESS" ]]; then
        IPV6_ADDRESS=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi
}

# 获取交换分区信息
get_swap_info() {
    local swap_used=$(free -m | awk 'NR==3{print $3}')
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    
    if [[ "$swap_total" -eq 0 ]]; then
        echo "未配置"
    else
        local swap_percentage=$((swap_used * 100 / swap_total))
        echo "${swap_used}MB/${swap_total}MB (${swap_percentage}%)"
    fi
}

# 获取网络流量统计
get_network_stats() {
    awk 'BEGIN { rx_total = 0; tx_total = 0 }
        NR > 2 { rx_total += $2; tx_total += $10 }
        END {
            rx_units = "B";
            tx_units = "B";
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
            if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

            if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
            if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

            printf("总接收: %.2f %s\n总发送: %.2f %s", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev
}

# 获取TCP拥塞算法
get_tcp_congestion() {
    local congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    local queue=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    echo "${congestion} ${queue}"
}

# 获取地理位置信息
get_location_info() {
    local country=$(curl -s --max-time 5 ipinfo.io/country 2>/dev/null || echo "未知")
    local city=$(curl -s --max-time 5 ipinfo.io/city 2>/dev/null || echo "未知")
    local isp=$(curl -s --max-time 5 ipinfo.io/org 2>/dev/null || echo "未知")
    
    echo "${country} ${city}|${isp}"
}

# 获取系统版本信息
get_os_info() {
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release && echo "$PRETTY_NAME"
    elif command -v lsb_release >/dev/null 2>&1; then
        lsb_release -ds 2>/dev/null
    elif [[ -f "/etc/debian_version" ]]; then
        echo "Debian $(cat /etc/debian_version)"
    elif [[ -f "/etc/redhat-release" ]]; then
        cat /etc/redhat-release
    else
        echo "Unknown"
    fi
}

# 主函数
main() {
    clear
    log INFO "正在收集系统信息..."
    
    # 使用核心库函数或本地函数
    if [[ "$USE_LIB" == true ]] && declare -f get_system_info > /dev/null; then
        get_system_info
        get_ip_address
    else
        get_system_info_local
        get_ip_address_local
    fi
    
    # 获取其他信息
    local cpu_usage=$(get_cpu_usage)
    local swap_info=$(get_swap_info)
    local network_stats=$(get_network_stats)
    local tcp_congestion=$(get_tcp_congestion)
    local current_time=$(date "+%Y-%m-%d %I:%M %p")
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    local os_info=$(get_os_info)
    
    # 获取地理位置
    local location_data=$(get_location_info)
    local location="${location_data%%|*}"
    local isp="${location_data##*|}"
    
    # 显示信息
    clear
    echo ""
    echo -e "${WHITE}系统信息详情${NC}"
    echo "------------------------"
    echo -e "${WHITE}主机名: ${YELLOW}${hostname}${NC}"
    echo -e "${WHITE}运营商: ${YELLOW}${isp}${NC}"
    echo "------------------------"
    echo -e "${WHITE}系统版本: ${YELLOW}${os_info}${NC}"
    echo -e "${WHITE}Linux版本: ${YELLOW}${kernel}${NC}"
    echo "------------------------"
    echo -e "${WHITE}CPU架构: ${YELLOW}${arch}${NC}"
    echo -e "${WHITE}CPU型号: ${YELLOW}${CPU_INFO}${NC}"
    echo -e "${WHITE}CPU核心数: ${YELLOW}${CPU_CORES}${NC}"
    echo "------------------------"
    echo -e "${WHITE}CPU占用: ${YELLOW}${cpu_usage}${NC}"
    echo -e "${WHITE}物理内存: ${YELLOW}${MEM_USED}MB/${MEM_TOTAL}MB (${MEM_PERCENT}%)${NC}"
    echo -e "${WHITE}虚拟内存: ${YELLOW}${swap_info}${NC}"
    echo -e "${WHITE}硬盘占用: ${YELLOW}${DISK_INFO}${NC}"
    echo "------------------------"
    echo -e "${PURPLE}${network_stats}${NC}"
    echo "------------------------"
    echo -e "${WHITE}网络拥堵算法: ${YELLOW}${tcp_congestion}${NC}"
    echo "------------------------"
    echo -e "${WHITE}公网IPv4地址: ${YELLOW}${IPV4_ADDRESS:-未检测到}${NC}"
    echo -e "${WHITE}公网IPv6地址: ${YELLOW}${IPV6_ADDRESS:-未检测到}${NC}"
    echo "------------------------"
    echo -e "${WHITE}地理位置: ${YELLOW}${location}${NC}"
    echo -e "${WHITE}系统时间: ${YELLOW}${current_time}${NC}"
    echo "------------------------"
    echo -e "${WHITE}系统运行时长: ${YELLOW}${UPTIME}${NC}"
    echo ""
    
    press_any_key
}

# 程序入口
main "$@"
