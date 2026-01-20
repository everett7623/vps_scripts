#!/bin/bash
# ==============================================================================
# 脚本名称: system_info.sh
# 脚本路径: scripts/system_tools/system_info.sh
# 描述: VPS系统信息查看脚本 - 全面展示系统配置、硬件信息和资源使用情况
# 作者: Jensfrank (Optimized by AI)
# 版本: 2.2.0 (Full Comments & Logic)
# 更新日期: 2026-01-20
# 依赖库: lib/common_functions.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 核心框架引导 (Boilerplate)
# ------------------------------------------------------------------------------

# 获取当前脚本的绝对物理路径（解决软链接导致路径错误的问题）
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT="$SCRIPT_DIR"

# 向上递归查找项目根目录，直到找到 lib/common_functions.sh 或到达根目录 /
# 这样设计是为了确保脚本无论在哪个层级目录下执行，都能准确找到公共函数库
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/lib/common_functions.sh" ]; do
    PROJECT_ROOT=$(dirname "$PROJECT_ROOT")
done

# 如果找不到项目根目录（缺少公共库），则报错退出
if [ "$PROJECT_ROOT" = "/" ]; then
    echo "Error: 无法找到项目根目录 (缺失 lib/common_functions.sh)"
    exit 1
fi

# 加载公共函数库 (提供颜色定义、日志函数、check_root 等基础功能)
source "$PROJECT_ROOT/lib/common_functions.sh"

# 加载全局配置文件 (如果存在，用于读取用户自定义设置，如日志路径等)
if [ -f "$PROJECT_ROOT/config/vps_scripts.conf" ]; then
    source "$PROJECT_ROOT/config/vps_scripts.conf"
fi

# ------------------------------------------------------------------------------
# 2. 功能函数定义
# ------------------------------------------------------------------------------

# 函数：获取CPU详细信息
# 功能：读取 /proc/cpuinfo 和 top 命令，显示型号、核心数、频率和实时使用率
get_cpu_detailed_info() {
    print_title "CPU 硬件与性能信息"
    
    # 获取 CPU 型号
    # grep -m1: 只匹配第一行
    # cut -d: -f2: 以冒号分隔，取第二部分
    # xargs: 去除首尾空白字符
    local cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
    echo -e "${CYAN}CPU 型号:${NC} ${cpu_model:-未知}"
    
    # 获取 CPU 物理核心数
    # 使用公共库中的 get_cpu_cores 函数，或者直接统计 processor 数量
    local cpu_cores=$(get_cpu_cores)
    echo -e "${CYAN}CPU 核心:${NC} ${cpu_cores} 核"
    
    # 获取 CPU 频率
    # 注意：某些 VPS 可能不显示频率信息
    if [ -f /proc/cpuinfo ]; then
        local cpu_freq=$(grep -m1 "cpu MHz" /proc/cpuinfo | cut -d: -f2 | xargs)
        if [ -n "$cpu_freq" ]; then
            echo -e "${CYAN}CPU 频率:${NC} ${cpu_freq} MHz"
        fi
    fi
    
    # 获取 CPU 实时使用率
    # top -bn1: 批处理模式运行一次 top
    # awk '{print $2}': 提取 Cpu(s) 行的 user+sys 占用
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if [ -n "$cpu_usage" ]; then
        echo -e "${CYAN}实时使用:${NC} ${cpu_usage}%"
    fi
    
    # 获取系统负载
    # uptime 输出格式示例: 22:00:00 up 1 day, 1:00,  1 user,  load average: 0.00, 0.01, 0.05
    local load_avg=$(uptime | grep -o 'load average:.*' | cut -d: -f2 | xargs)
    echo -e "${CYAN}系统负载:${NC} ${load_avg} (1分/5分/15分)"
}

# 函数：获取内存详细信息
# 功能：读取 /proc/meminfo 和 free 命令，显示物理内存和 Swap 的使用情况
get_memory_detailed_info() {
    print_title "内存与交换分区信息"
    
    # 从 /proc/meminfo 直接读取精确数值 (单位 kB)
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    # 将单位转换为 MB 进行显示
    local mem_total_mb=$((mem_total / 1024))
    local mem_available_mb=$((mem_available / 1024))
    local mem_used_mb=$((mem_total_mb - mem_available_mb))
    
    # 计算使用百分比
    local mem_usage=0
    if [ "$mem_total_mb" -gt 0 ]; then
        mem_usage=$((mem_used_mb * 100 / mem_total_mb))
    fi
    
    echo -e "${CYAN}物理内存:${NC} ${mem_used_mb}MB / ${mem_total_mb}MB (使用率: ${mem_usage}%)"
    echo -e "${CYAN}可用内存:${NC} ${mem_available_mb}MB"
    
    # 检查 Swap (交换分区) 信息
    local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    
    if [ "$swap_total" -gt 0 ]; then
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_total_mb=$((swap_total / 1024))
        # 计算已用 Swap
        local swap_used_mb=$(( (swap_total - swap_free) / 1024 ))
        local swap_usage=$((swap_used_mb * 100 / swap_total_mb))
        
        echo -e "${CYAN}Swap交换:${NC} ${swap_used_mb}MB / ${swap_total_mb}MB (使用率: ${swap_usage}%)"
    else
        echo -e "${CYAN}Swap交换:${NC} 未配置 (建议开启以提升稳定性)"
    fi
}

# 函数：获取磁盘详细信息
# 功能：使用 df 命令显示物理磁盘分区的使用情况，并汇总总容量
get_disk_detailed_info() {
    print_title "磁盘存储使用详情"
    
    # 打印表头
    printf "${CYAN}%-15s %-10s %-10s %-8s %s${NC}\n" "挂载点" "总容量" "已使用" "使用率" "设备路径"
    echo "--------------------------------------------------------"
    
    # 逐行读取物理磁盘信息 (过滤掉 tmpfs, overlay 等虚拟文件系统)
    # df -h: 人类可读格式
    # grep -E '^/dev/': 只显示以 /dev/ 开头的物理设备
    df -h | grep -E '^/dev/' | while read line; do
        local device=$(echo $line | awk '{print $1}')
        local size=$(echo $line | awk '{print $2}')
        local used=$(echo $line | awk '{print $3}')
        local usage=$(echo $line | awk '{print $5}')
        local mount=$(echo $line | awk '{print $6}')
        
        # 格式化输出
        printf "  %-15s %-10s %-10s %-8s %s\n" "$mount" "$size" "$used" "$usage" "$device"
    done
    
    # 显示磁盘汇总信息 (使用 df --total 功能)
    # 注意：某些精简版 df 可能不支持 --total，此处做兼容性处理
    if df --help 2>&1 | grep -q -- "--total"; then
        local total_line=$(df -h --total 2>/dev/null | grep "total$")
        if [ -n "$total_line" ]; then
            local total_size=$(echo $total_line | awk '{print $2}')
            local total_used=$(echo $total_line | awk '{print $3}')
            local total_usage=$(echo $total_line | awk '{print $5}')
            
            echo ""
            echo -e "${PURPLE}磁盘汇总:${NC} 总容量 $total_size / 已用 $total_used (总使用率: $total_usage)"
        fi
    fi
}

# 函数：获取网络接口详细信息
# 功能：遍历系统网卡，显示 IP 地址、MAC 地址和连接状态
get_network_detailed_info() {
    print_title "网络接口与 IP 信息"
    
    # 获取所有网络接口名称 (排除回环接口 lo)
    # ip -o link show: 单行显示链路信息
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
    
    for interface in $interfaces; do
        # 获取 IPv4 地址 (inet)
        local ip_addr=$(ip addr show $interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        # 获取 MAC 地址 (link/ether)
        local mac_addr=$(ip link show $interface | grep -oP '(?<=link/ether\s)[0-9a-fA-F:]+')
        # 获取接口状态 (UP/DOWN)
        local status=$(ip link show $interface | grep -oP '(?<=state\s)\w+')
        
        # 仅显示处于 UP 状态或配置了 IP 的接口，避免显示无用的虚拟接口
        if [ -n "$ip_addr" ] || [ "$status" = "UP" ]; then
            echo -e "${CYAN}接口名称:${NC} $interface [状态: $status]"
            
            if [ -n "$ip_addr" ]; then
                echo -e "  IPv4地址: $ip_addr"
            else
                echo -e "  IPv4地址: 未配置"
            fi
            
            if [ -n "$mac_addr" ]; then
                echo -e "  MAC 地址: $mac_addr"
            fi
            echo ""
        fi
    done
    
    # 获取公网出口 IP (调用公共库中的 get_public_ip 函数)
    echo -e "${CYAN}公网出口 IP:${NC}"
    local public_ip=$(get_public_ip)
    echo -e "  IPv4: ${public_ip:-获取失败}"
    
    # 尝试获取地理位置信息
    if [ -n "$public_ip" ] && [ "$public_ip" != "获取失败" ]; then
        local country=$(curl -s --max-time 2 "https://ipapi.co/${public_ip}/country_name/" 2>/dev/null)
        if [ -n "$country" ]; then
             echo -e "  归属地: $country"
        fi
    fi
}

# 函数：获取虚拟化架构信息
# 功能：通过多种方式 (cpuinfo, systemd, dmidecode) 检测是物理机还是虚拟机/容器
get_virtualization_info() {
    print_title "虚拟化架构检测"
    
    local virt_type="物理机 (Dedicated)"
    
    # 方法1: 检查 /proc/cpuinfo 中的 hypervisor 标志
    if [ -f /proc/cpuinfo ] && grep -q "hypervisor" /proc/cpuinfo; then
        virt_type="虚拟机 (Unknown Hypervisor)"
    fi
    
    # 方法2: 使用 systemd-detect-virt (如果可用)
    if command -v systemd-detect-virt &> /dev/null; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        if [ "$detected" != "none" ] && [ -n "$detected" ]; then
            virt_type="$detected"
        fi
    fi
    
    # 方法3: 使用 dmidecode 获取更详细的硬件信息 (需要 root 权限)
    if [ "$EUID" -eq 0 ] && command -v dmidecode &> /dev/null; then
        local dmi_info=$(dmidecode -s system-product-name 2>/dev/null)
        case "$dmi_info" in
            *"VirtualBox"*) virt_type="VirtualBox" ;;
            *"VMware"*)     virt_type="VMware" ;;
            *"KVM"*)        virt_type="KVM" ;;
            *"Bochs"*)      virt_type="Bochs" ;;
            *"QEMU"*)       virt_type="QEMU/KVM" ;;
            *"HVM"*)        virt_type="Xen HVM" ;;
            *"Microsoft Corporation"*) virt_type="Hyper-V" ;;
            *"Alibaba Cloud"*) virt_type="Aliyun ECS" ;;
        esac
    fi
    
    echo -e "${CYAN}架构类型:${NC} $virt_type"
    
    # 检测容器环境 (Docker/LXC/OpenVZ)
    if [ -f /.dockerenv ]; then
        echo -e "${CYAN}运行环境:${NC} Docker 容器"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        echo -e "${CYAN}运行环境:${NC} LXC 容器"
    elif [ -d "/proc/vz" ]; then
        echo -e "${CYAN}运行环境:${NC} OpenVZ 容器"
    fi
}

# 函数：获取用户信息
# 功能：显示当前用户、在线用户数及最近登录记录
get_user_info() {
    print_title "用户登录信息"
    
    echo -e "${CYAN}当前用户:${NC} $(whoami)"
    echo -e "${CYAN}在线会话:${NC} $(who | wc -l)"
    echo ""
    echo -e "${CYAN}最近登录记录 (前3条):${NC}"
    # last 命令显示最近登录的用户
    # awk 格式化输出: 用户名, IP地址, 登录时间, 持续时间
    last -n 3 | head -n 3 | awk '{printf "  %-10s %-15s %s %s %s (%s)\n", $1, $3, $4, $5, $6, $10}'
}

# 函数：获取关键服务状态
# 功能：检查常见服务 (Web, DB, Docker, SSH) 是否正在运行
get_service_detailed_status() {
    print_title "关键服务监控状态"
    
    # 定义需要检查的服务名称数组
    local services=("ssh" "sshd" "nginx" "apache2" "docker" "mysql" "mariadb" "redis" "ufw" "iptables" "fail2ban")
    
    local found_any=false
    
    for service in "${services[@]}"; do
        # systemctl list-unit-files: 检查服务是否已安装 (避免报错)
        if systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
            found_any=true
            # systemctl is-active: 检查运行状态
            if systemctl is-active --quiet "$service"; then
                echo -e "  [${GREEN}运行中${NC}] $service"
            else
                echo -e "  [${RED}已停止${NC}] $service"
            fi
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo -e "  ${YELLOW}未检测到预定义的常用服务。${NC}"
    fi
}

# ------------------------------------------------------------------------------
# 3. 主逻辑入口 (Main)
# ------------------------------------------------------------------------------

main() {
    # 检查是否以 root 权限运行 (虽然查看信息不一定需要，但部分硬件信息需要 root)
    # 调用 common_functions 中的 check_root 函数
    # check_root (可选: 如果只是查看信息，可以不强制 root，这里注释掉)
    
    # 清屏并打印脚本 Header
    clear
    print_header "VPS 系统深度信息检测报告"
    
    # 1. 显示基础系统信息
    print_title "系统基础概览"
    echo -e "${CYAN}主机名称:${NC}   $(hostname)"
    echo -e "${CYAN}发行版本:${NC}   $(get_os_release) $(get_os_version)"
    echo -e "${CYAN}内核版本:${NC}   $(uname -r)"
    echo -e "${CYAN}系统架构:${NC}   $(get_arch)"
    echo -e "${CYAN}系统时间:${NC}   $(date "+%Y-%m-%d %H:%M:%S %Z")"
    echo -e "${CYAN}运行时长:${NC}   $(uptime -p | sed 's/up //')" # sed 去掉 'up ' 前缀
    
    # 2. 显示 CPU 信息
    get_cpu_detailed_info
    
    # 3. 显示内存信息
    get_memory_detailed_info
    
    # 4. 显示磁盘信息
    get_disk_detailed_info
    
    # 5. 显示网络信息
    get_network_detailed_info
    
    # 6. 显示虚拟化架构
    get_virtualization_info
    
    # 7. 显示服务状态
    get_service_detailed_status
    
    # 8. 显示用户信息
    get_user_info
    
    # 结束分割线
    echo ""
    print_separator
    print_msg "$GREEN" "所有信息采集完毕。"
    
    # 交互逻辑：如果脚本是被直接运行的 (非 source 调用)，则暂停等待用户确认
    # BASH_SOURCE[0] 是当前脚本文件名，0 是执行命令 ($0)
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo ""
        read -n 1 -s -r -p "按任意键返回主菜单..."
        echo ""
    fi
}

# 执行主函数，并将所有命令行参数传递给它
main "$@"
