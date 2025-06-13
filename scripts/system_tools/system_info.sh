#!/bin/bash

# ===================================================================
# 脚本名称: 系统信息查看
# 脚本描述: 查看VPS系统详细信息，包括硬件、网络、性能等
# 作者: everett7623
# 版本: 1.0.0
# 更新日期: 2025-01-10
# 使用方法: ./system_info.sh [选项]
# ===================================================================

# 严格模式
set -euo pipefail
IFS=$'\n\t'

# 加载核心库文件
source "vps_scripts/lib/common.sh"
source "vps_scripts/lib/system.sh"
source "vps_scripts/lib/menu.sh"

# ===================================================================
# 脚本配置
# ===================================================================

# 脚本元信息
readonly SCRIPT_NAME="系统信息查看"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DESCRIPTION="查看VPS系统详细信息"

# 显示选项
SHOW_BASIC=true
SHOW_CPU=true
SHOW_MEMORY=true
SHOW_DISK=true
SHOW_NETWORK=true
SHOW_PERFORMANCE=false

# ===================================================================
# 函数定义
# ===================================================================

# 显示使用帮助
show_usage() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}
${SCRIPT_DESCRIPTION}

使用方法:
    $(basename "$0") [选项]

选项:
    -h, --help          显示此帮助信息
    -v, --version       显示版本信息
    -d, --debug         启用调试模式
    -a, --all           显示所有信息（包括性能测试）
    -b, --basic         仅显示基本信息
    -p, --performance   包含性能测试

示例:
    $(basename "$0")              # 显示标准信息
    $(basename "$0") --all        # 显示所有信息
    $(basename "$0") --basic      # 仅显示基本信息

EOF
}

# 显示版本信息
show_version() {
    echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
}

# 初始化脚本
init_script() {
    log_info "正在初始化 ${SCRIPT_NAME}..."
    
    # 检查是否为root用户
    check_root
    
    # 检测操作系统
    detect_os
    
    log_success "初始化完成"
}

# ===================================================================
# 信息显示函数
# ===================================================================

# 显示基本系统信息
show_basic_info() {
    show_title "基本系统信息"
    
    echo -e "${WHITE}主机名:${NC} $(hostname)"
    echo -e "${WHITE}操作系统:${NC} $OS_TYPE $OS_VERSION ${OS_CODENAME:-}"
    echo -e "${WHITE}内核版本:${NC} $(uname -r)"
    echo -e "${WHITE}系统架构:${NC} $(detect_architecture)"
    echo -e "${WHITE}虚拟化类型:${NC} $(detect_virtualization)"
    echo -e "${WHITE}系统运行时间:${NC} $(get_system_uptime)"
    echo -e "${WHITE}系统负载:${NC} $(get_system_load)"
    echo -e "${WHITE}当前时间:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
}

# 显示CPU信息
show_cpu_info() {
    show_title "CPU 信息"
    
    get_cpu_info | while IFS=: read -r key value; do
        echo -e "${WHITE}$key:${NC}$value"
    done
    
    echo -e "${WHITE}CPU使用率:${NC} $(get_cpu_usage)%"
    echo ""
}

# 显示内存信息
show_memory_info() {
    show_title "内存信息"
    
    get_memory_info | while IFS=: read -r key value; do
        echo -e "${WHITE}$key:${NC}$value"
    done
    
    # 显示交换分区信息
    if [[ -f /proc/swaps ]]; then
        local swap_total=$(free -m | awk '/^Swap:/ {print $2}')
        local swap_used=$(free -m | awk '/^Swap:/ {print $3}')
        local swap_free=$(free -m | awk '/^Swap:/ {print $4}')
        
        if [[ $swap_total -gt 0 ]]; then
            echo ""
            echo -e "${WHITE}交换分区:${NC}"
            echo -e "  总计: ${swap_total}MB"
            echo -e "  已用: ${swap_used}MB"
            echo -e "  可用: ${swap_free}MB"
        fi
    fi
    echo ""
}

# 显示磁盘信息
show_disk_info() {
    show_title "磁盘信息"
    
    echo -e "${WHITE}根分区使用情况:${NC}"
    get_disk_info | while IFS=: read -r key value; do
        echo -e "  $key:$value"
    done
    
    echo ""
    echo -e "${WHITE}所有分区:${NC}"
    df -h | grep -E '^/dev/' | while read -r line; do
        echo "  $line"
    done
    echo ""
}

# 显示网络信息
show_network_info() {
    show_title "网络信息"
    
    get_network_info | while IFS=: read -r key value; do
        echo -e "${WHITE}$key:${NC}$value"
    done
    
    # 显示DNS服务器
    echo ""
    echo -e "${WHITE}DNS服务器:${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        grep "nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    fi
    
    # 显示网络流量统计
    echo ""
    echo -e "${WHITE}网络流量统计:${NC}"
    local rx_bytes tx_bytes
    
    for interface in $(ls /sys/class/net/ | grep -v lo); do
        if [[ -f "/sys/class/net/$interface/statistics/rx_bytes" ]]; then
            rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
            tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
            
            # 转换为人类可读格式
            rx_human=$(numfmt --to=iec-i --suffix=B "$rx_bytes" 2>/dev/null || echo "${rx_bytes}B")
            tx_human=$(numfmt --to=iec-i --suffix=B "$tx_bytes" 2>/dev/null || echo "${tx_bytes}B")
            
            echo -e "  ${interface}: 接收 $rx_human, 发送 $tx_human"
        fi
    done
    echo ""
}

# 显示性能测试结果
show_performance_info() {
    show_title "性能测试"
    
    echo -e "${WHITE}CPU性能测试:${NC}"
    log_info "执行CPU基准测试..."
    
    # 简单的CPU性能测试
    local start_time=$(date +%s.%N)
    local sum=0
    for i in {1..1000000}; do
        sum=$((sum + i))
    done
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo -e "  计算1到1000000的和: ${duration}秒"
    
    echo ""
    echo -e "${WHITE}磁盘I/O测试:${NC}"
    log_info "执行磁盘I/O测试..."
    
    # 简单的磁盘I/O测试
    local test_file="/tmp/vps_disk_test_$$"
    
    # 写入测试
    local write_start=$(date +%s.%N)
    dd if=/dev/zero of="$test_file" bs=1M count=100 &>/dev/null
    local write_end=$(date +%s.%N)
    local write_time=$(echo "$write_end - $write_start" | bc)
    local write_speed=$(echo "scale=2; 100 / $write_time" | bc)
    
    echo -e "  写入速度: ${write_speed} MB/s"
    
    # 读取测试
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
    local read_start=$(date +%s.%N)
    dd if="$test_file" of=/dev/null bs=1M &>/dev/null
    local read_end=$(date +%s.%N)
    local read_time=$(echo "$read_end - $read_start" | bc)
    local read_speed=$(echo "scale=2; 100 / $read_time" | bc)
    
    echo -e "  读取速度: ${read_speed} MB/s"
    
    # 清理测试文件
    rm -f "$test_file"
    
    echo ""
}

# ===================================================================
# 主要功能函数
# ===================================================================

# 主要功能函数
main_function() {
    show_title "${SCRIPT_NAME}"
    
    if [[ "$SHOW_BASIC" == "true" ]]; then
        show_basic_info
    fi
    
    if [[ "$SHOW_CPU" == "true" ]]; then
        show_cpu_info
    fi
    
    if [[ "$SHOW_MEMORY" == "true" ]]; then
        show_memory_info
    fi
    
    if [[ "$SHOW_DISK" == "true" ]]; then
        show_disk_info
    fi
    
    if [[ "$SHOW_NETWORK" == "true" ]]; then
        show_network_info
    fi
    
    if [[ "$SHOW_PERFORMANCE" == "true" ]]; then
        show_performance_info
    fi
    
    log_success "系统信息收集完成"
}

# ===================================================================
# 主程序入口
# ===================================================================

main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                export DEBUG="true"
                log_info "调试模式已启用"
                shift
                ;;
            -a|--all)
                SHOW_PERFORMANCE=true
                shift
                ;;
            -b|--basic)
                SHOW_CPU=false
                SHOW_MEMORY=false
                SHOW_DISK=false
                SHOW_NETWORK=false
                SHOW_PERFORMANCE=false
                shift
                ;;
            -p|--performance)
                SHOW_PERFORMANCE=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 初始化脚本
    init_script
    
    # 执行主要功能
    main_function
    
    # 询问是否返回主菜单
    if [[ "${RETURN_TO_MENU:-true}" == "true" ]]; then
        echo ""
        pause_menu "按任意键返回主菜单..."
    fi
}

# ===================================================================
# 执行主程序
# ===================================================================

# 只有在直接执行脚本时才运行main函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
