#!/bin/bash
#/scripts/system_tools/system_info.sh - VPS Scripts 系统信息脚本 - 显示详细的系统信息

# 获取脚本所在目录
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

# 加载核心功能库
if [[ -f "${PARENT_DIR}/lib/common_functions.sh" ]]; then
    source "${PARENT_DIR}/lib/common_functions.sh"
else
    echo "错误：无法找到核心功能库" >&2
    exit 1
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

            printf("接收: %.2f %s | 发送: %.2f %s", rx_total, rx_units, tx_total, tx_units);
        }' /proc/net/dev
}

# 获取TCP拥塞算法
get_tcp_congestion() {
    local congestion=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    local queue=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
    echo "${congestion} / ${queue}"
}

# 获取地理位置信息
get_location_info() {
    local country=$(curl -s --max-time 5 ipinfo.io/country 2>/dev/null || echo "未知")
    local city=$(curl -s --max-time 5 ipinfo.io/city 2>/dev/null || echo "未知")
    local isp=$(curl -s --max-time 5 ipinfo.io/org 2>/dev/null || echo "未知")
    
    echo "位置: ${country} ${city}"
    echo "ISP: ${isp}"
}

# 获取虚拟化类型
get_virtualization() {
    if command_exists systemd-detect-virt; then
        systemd-detect-virt || echo "未知"
    elif [[ -f /proc/cpuinfo ]]; then
        if grep -q "hypervisor" /proc/cpuinfo; then
            echo "虚拟化"
        else
            echo "物理机"
        fi
    else
        echo "未知"
    fi
}

# 获取系统负载
get_system_load() {
    local load=$(uptime | awk -F'load average:' '{print $2}')
    echo "$load"
}

# 主函数
main() {
    clear
    log INFO "正在收集系统信息..."
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_os
    
    # 获取各种信息
    get_system_info
    get_ip_address
    
    local cpu_usage=$(get_cpu_usage)
    local swap_info=$(get_swap_info)
    local network_stats=$(get_network_stats)
    local tcp_congestion=$(get_tcp_congestion)
    local virtualization=$(get_virtualization)
    local system_load=$(get_system_load)
    local current_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    local hostname=$(hostname)
    local kernel=$(uname -r)
    local arch=$(uname -m)
    
    # 显示信息
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}                         系统信息详情                               ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 基础信息
    echo -e "${CYAN}【基础信息】${NC}"
    echo -e "${WHITE}主机名称:${NC} ${YELLOW}${hostname}${NC}"
    echo -e "${WHITE}系统版本:${NC} ${YELLOW}${OS_PRETTY_NAME}${NC}"
    echo -e "${WHITE}内核版本:${NC} ${YELLOW}${kernel}${NC}"
    echo -e "${WHITE}系统架构:${NC} ${YELLOW}${arch}${NC}"
    echo -e "${WHITE}虚拟化类型:${NC} ${YELLOW}${virtualization}${NC}"
    echo -e "${WHITE}系统时间:${NC} ${YELLOW}${current_time}${NC}"
    echo -e "${WHITE}运行时长:${NC} ${YELLOW}${UPTIME}${NC}"
    echo ""
    
    # 硬件信息
    echo -e "${CYAN}【硬件信息】${NC}"
    echo -e "${WHITE}CPU型号:${NC} ${YELLOW}${CPU_INFO}${NC}"
    echo -e "${WHITE}CPU核心:${NC} ${YELLOW}${CPU_CORES}核${NC}"
    echo -e "${WHITE}CPU使用:${NC} ${YELLOW}${cpu_usage}${NC}"
    echo -e "${WHITE}系统负载:${NC} ${YELLOW}${system_load}${NC}"
    echo ""
    
    # 内存信息
    echo -e "${CYAN}【内存信息】${NC}"
    echo -e "${WHITE}物理内存:${NC} ${YELLOW}${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)${NC}"
    echo -e "${WHITE}交换分区:${NC} ${YELLOW}${swap_info}${NC}"
    echo ""
    
    # 磁盘信息
    echo -e "${CYAN}【磁盘信息】${NC}"
    echo -e "${WHITE}系统盘使用:${NC} ${YELLOW}${DISK_INFO}${NC}"
    echo ""
    
    # 网络信息
    echo -e "${CYAN}【网络信息】${NC}"
    echo -e "${WHITE}IPv4地址:${NC} ${YELLOW}${IPV4_ADDRESS:-未检测到}${NC}"
    echo -e "${WHITE}IPv6地址:${NC} ${YELLOW}${IPV6_ADDRESS:-未检测到}${NC}"
    echo -e "${WHITE}网络流量:${NC} ${YELLOW}${network_stats}${NC}"
    echo -e "${WHITE}TCP拥塞算法:${NC} ${YELLOW}${tcp_congestion}${NC}"
    
    # 获取地理位置（可选）
    if confirm_action "是否获取地理位置信息？" "n"; then
        echo ""
        echo -e "${CYAN}【地理位置】${NC}"
        local location_info=$(get_location_info)
        echo -e "${WHITE}${location_info}${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 保存报告（可选）
    if confirm_action "是否保存系统信息报告？" "n"; then
        local report_file="${LOG_DIR}/system_info_$(date +%Y%m%d_%H%M%S).txt"
        {
            echo "系统信息报告"
            echo "生成时间: $(date)"
            echo "================================"
            echo "主机名: ${hostname}"
            echo "系统: ${OS_PRETTY_NAME}"
            echo "内核: ${kernel}"
            echo "架构: ${arch}"
            echo "CPU: ${CPU_INFO}"
            echo "内存: ${MEM_USED}MB / ${MEM_TOTAL}MB"
            echo "磁盘: ${DISK_INFO}"
            echo "IPv4: ${IPV4_ADDRESS:-无}"
            echo "IPv6: ${IPV6_ADDRESS:-无}"
        } > "$report_file"
        
        log INFO "报告已保存到: $report_file"
    fi
    
    press_any_key
}

# 程序入口
main "$@"
