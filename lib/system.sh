#!/bin/bash

# ===================================================================
# 文件名: lib/system.sh
# 描述: 系统检测与操作库
# 作者: everett7623
# 版本: 1.0.0
# 更新日期: 2025-01-10
# ===================================================================

# 加载公共函数库
source "${LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/common.sh"

# ===================================================================
# 系统检测函数
# ===================================================================

# 检测操作系统
detect_os() {
    local os_type=""
    local os_version=""
    local os_codename=""
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        os_type="${ID,,}"
        os_version="$VERSION_ID"
        os_codename="${VERSION_CODENAME:-$UBUNTU_CODENAME}"
    elif command_exists lsb_release; then
        os_type="$(lsb_release -si | tr '[:upper:]' '[:lower:]')"
        os_version="$(lsb_release -sr)"
        os_codename="$(lsb_release -sc)"
    elif [[ -f /etc/debian_version ]]; then
        os_type="debian"
        os_version="$(cat /etc/debian_version)"
    elif [[ -f /etc/redhat-release ]]; then
        os_type="centos"
        os_version="$(rpm -q --qf "%{VERSION}" centos-release)"
    else
        os_type="unknown"
        os_version="unknown"
    fi
    
    export OS_TYPE="$os_type"
    export OS_VERSION="$os_version"
    export OS_CODENAME="$os_codename"
    
    log_info "检测到操作系统: $OS_TYPE $OS_VERSION ($OS_CODENAME)"
}

# 获取包管理器
get_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists apk; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# 检测系统架构
detect_architecture() {
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*|armhf)
            echo "armv7"
            ;;
        i386|i686)
            echo "i386"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# 检测虚拟化类型
detect_virtualization() {
    if command_exists systemd-detect-virt; then
        systemd-detect-virt
    elif [[ -f /proc/cpuinfo ]]; then
        if grep -q "hypervisor" /proc/cpuinfo; then
            echo "vm"
        else
            echo "physical"
        fi
    else
        echo "unknown"
    fi
}

# ===================================================================
# 系统信息获取函数
# ===================================================================

# 获取系统负载
get_system_load() {
    local load_1min load_5min load_15min
    read load_1min load_5min load_15min _ < /proc/loadavg
    echo "$load_1min $load_5min $load_15min"
}

# 获取系统运行时间
get_system_uptime() {
    local uptime_seconds=$(cat /proc/uptime | cut -d. -f1)
    local days=$((uptime_seconds / 86400))
    local hours=$(((uptime_seconds % 86400) / 3600))
    local minutes=$(((uptime_seconds % 3600) / 60))
    
    if [[ $days -gt 0 ]]; then
        printf "%d天 %d小时 %d分钟" $days $hours $minutes
    elif [[ $hours -gt 0 ]]; then
        printf "%d小时 %d分钟" $hours $minutes
    else
        printf "%d分钟" $minutes
    fi
}

# 获取CPU信息
get_cpu_info() {
    local cpu_model=""
    local cpu_cores=""
    local cpu_threads=""
    
    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        cpu_threads=$(grep -c "^processor" /proc/cpuinfo)
    fi
    
    echo "型号: $cpu_model"
    echo "核心数: $cpu_cores"
    echo "线程数: $cpu_threads"
}

# 获取内存信息
get_memory_info() {
    local total used free available
    
    if [[ -f /proc/meminfo ]]; then
        total=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        
        # 转换为MB
        total=$((total / 1024))
        available=$((available / 1024))
        used=$((total - available))
        
        echo "总计: ${total}MB"
        echo "已用: ${used}MB"
        echo "可用: ${available}MB"
        echo "使用率: $(awk "BEGIN {printf \"%.1f\", ($used/$total)*100}")%"
    fi
}

# 获取磁盘信息
get_disk_info() {
    local disk_info=$(df -h / | awk 'NR==2 {print $2" "$3" "$4" "$5}')
    local total=$(echo $disk_info | awk '{print $1}')
    local used=$(echo $disk_info | awk '{print $2}')
    local available=$(echo $disk_info | awk '{print $3}')
    local usage=$(echo $disk_info | awk '{print $4}')
    
    echo "总计: $total"
    echo "已用: $used"
    echo "可用: $available"
    echo "使用率: $usage"
}

# 获取网络信息
get_network_info() {
    local ipv4_address=""
    local ipv6_address=""
    local default_interface=""
    
    # 获取默认网络接口
    default_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    
    # 获取IPv4地址
    ipv4_address=$(ip -4 addr show "$default_interface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    
    # 获取IPv6地址
    ipv6_address=$(ip -6 addr show "$default_interface" 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^fe80' | head -n1)
    
    # 尝试获取公网IP
    local public_ipv4=$(curl -s -4 --max-time 5 ifconfig.me 2>/dev/null || echo "未知")
    local public_ipv6=$(curl -s -6 --max-time 5 ifconfig.me 2>/dev/null || echo "未知")
    
    echo "默认接口: $default_interface"
    echo "内网IPv4: ${ipv4_address:-无}"
    echo "内网IPv6: ${ipv6_address:-无}"
    echo "公网IPv4: $public_ipv4"
    echo "公网IPv6: $public_ipv6"
}

# ===================================================================
# 系统操作函数
# ===================================================================

# 更新系统包索引
update_package_index() {
    local pm=$(get_package_manager)
    
    log_info "正在更新包索引..."
    
    case "$pm" in
        apt)
            apt-get update -qq
            ;;
        yum)
            yum makecache -q
            ;;
        dnf)
            dnf makecache -q
            ;;
        pacman)
            pacman -Sy --noconfirm
            ;;
        zypper)
            zypper --quiet refresh
            ;;
        apk)
            apk update -q
            ;;
        *)
            log_error "不支持的包管理器: $pm"
            return 1
            ;;
    esac
    
    log_success "包索引更新完成"
}

# 安装软件包
install_package() {
    local package="$1"
    local pm=$(get_package_manager)
    
    log_info "正在安装: $package"
    
    case "$pm" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
            ;;
        yum)
            yum install -y "$package"
            ;;
        dnf)
            dnf install -y "$package"
            ;;
        pacman)
            pacman -S --noconfirm "$package"
            ;;
        zypper)
            zypper --non-interactive install "$package"
            ;;
        apk)
            apk add --no-cache "$package"
            ;;
        *)
            log_error "不支持的包管理器: $pm"
            return 1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_success "$package 安装成功"
        return 0
    else
        log_error "$package 安装失败"
        return 1
    fi
}

# 卸载软件包
remove_package() {
    local package="$1"
    local pm=$(get_package_manager)
    
    log_info "正在卸载: $package"
    
    case "$pm" in
        apt)
            apt-get remove -y "$package"
            apt-get autoremove -y
            ;;
        yum)
            yum remove -y "$package"
            ;;
        dnf)
            dnf remove -y "$package"
            ;;
        pacman)
            pacman -R --noconfirm "$package"
            ;;
        zypper)
            zypper --non-interactive remove "$package"
            ;;
        apk)
            apk del "$package"
            ;;
        *)
            log_error "不支持的包管理器: $pm"
            return 1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        log_success "$package 卸载成功"
        return 0
    else
        log_error "$package 卸载失败"
        return 1
    fi
}

# 检查服务状态
check_service_status() {
    local service="$1"
    
    if command_exists systemctl; then
        if systemctl is-active --quiet "$service"; then
            echo "running"
        else
            echo "stopped"
        fi
    elif command_exists service; then
        if service "$service" status &>/dev/null; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "unknown"
    fi
}

# 启动服务
start_service() {
    local service="$1"
    
    log_info "正在启动服务: $service"
    
    if command_exists systemctl; then
        systemctl start "$service"
    elif command_exists service; then
        service "$service" start
    else
        log_error "无法启动服务，系统不支持 systemctl 或 service 命令"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "$service 启动成功"
        return 0
    else
        log_error "$service 启动失败"
        return 1
    fi
}

# 停止服务
stop_service() {
    local service="$1"
    
    log_info "正在停止服务: $service"
    
    if command_exists systemctl; then
        systemctl stop "$service"
    elif command_exists service; then
        service "$service" stop
    else
        log_error "无法停止服务，系统不支持 systemctl 或 service 命令"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "$service 停止成功"
        return 0
    else
        log_error "$service 停止失败"
        return 1
    fi
}

# 重启服务
restart_service() {
    local service="$1"
    
    log_info "正在重启服务: $service"
    
    if command_exists systemctl; then
        systemctl restart "$service"
    elif command_exists service; then
        service "$service" restart
    else
        log_error "无法重启服务，系统不支持 systemctl 或 service 命令"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "$service 重启成功"
        return 0
    else
        log_error "$service 重启失败"
        return 1
    fi
}

# 启用服务自启动
enable_service() {
    local service="$1"
    
    log_info "正在启用服务自启动: $service"
    
    if command_exists systemctl; then
        systemctl enable "$service"
    elif command_exists chkconfig; then
        chkconfig "$service" on
    elif command_exists update-rc.d; then
        update-rc.d "$service" enable
    else
        log_error "无法启用服务自启动，系统不支持相关命令"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "$service 自启动已启用"
        return 0
    else
        log_error "$service 自启动启用失败"
        return 1
    fi
}

# 禁用服务自启动
disable_service() {
    local service="$1"
    
    log_info "正在禁用服务自启动: $service"
    
    if command_exists systemctl; then
        systemctl disable "$service"
    elif command_exists chkconfig; then
        chkconfig "$service" off
    elif command_exists update-rc.d; then
        update-rc.d "$service" disable
    else
        log_error "无法禁用服务自启动，系统不支持相关命令"
        return 1
    fi
    
    if [[ $? -eq 0 ]]; then
        log_success "$service 自启动已禁用"
        return 0
    else
        log_error "$service 自启动禁用失败"
        return 1
    fi
}

# ===================================================================
# 系统优化函数
# ===================================================================

# 优化系统参数
optimize_system_parameters() {
    log_info "正在优化系统参数..."
    
    # 备份原始配置
    backup_file "/etc/sysctl.conf"
    
    # 网络优化参数
    cat >> /etc/sysctl.conf <<EOF

# VPS Scripts 系统优化参数
# 网络优化
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# 系统优化
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    # 应用参数
    sysctl -p &>/dev/null
    
    log_success "系统参数优化完成"
}

# 清理系统垃圾
cleanup_system() {
    log_info "正在清理系统垃圾..."
    
    local pm=$(get_package_manager)
    
    case "$pm" in
        apt)
            apt-get autoremove -y &>/dev/null
            apt-get autoclean -y &>/dev/null
            apt-get clean -y &>/dev/null
            ;;
        yum|dnf)
            yum clean all -y &>/dev/null
            ;;
        pacman)
            pacman -Sc --noconfirm &>/dev/null
            ;;
        zypper)
            zypper clean -a &>/dev/null
            ;;
        apk)
            apk cache clean &>/dev/null
            ;;
    esac
    
    # 清理日志
    find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
    
    # 清理临时文件
    find /tmp -type f -atime +7 -delete 2>/dev/null
    find /var/tmp -type f -atime +7 -delete 2>/dev/null
    
    # 清理系统日志
    if command_exists journalctl; then
        journalctl --vacuum-time=7d &>/dev/null
    fi
    
    log_success "系统清理完成"
}

# ===================================================================
# 导出所有函数
# ===================================================================

export -f detect_os get_package_manager detect_architecture detect_virtualization
export -f get_system_load get_system_uptime get_cpu_info get_memory_info
export -f get_disk_info get_network_info
export -f update_package_index install_package remove_package
export -f check_service_status start_service stop_service restart_service
export -f enable_service disable_service
export -f optimize_system_parameters cleanup_system
