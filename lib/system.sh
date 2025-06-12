#!/bin/bash
# lib/system.sh - VPS Scripts 系统检测和兼容性库

# 防止重复加载
if [ -n "$VPS_SCRIPTS_SYSTEM_LOADED" ]; then
    return 0
fi
VPS_SCRIPTS_SYSTEM_LOADED=1

# 加载依赖
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 系统信息全局变量
export OS=""
export OS_VERSION=""
export OS_CODENAME=""
export OS_PRETTY_NAME=""
export ARCH=""
export KERNEL=""
export PKG_MANAGER=""
export PKG_INSTALL=""
export PKG_UPDATE=""
export PKG_UPGRADE=""
export PKG_SEARCH=""
export PKG_REMOVE=""
export PKG_CLEAN=""
export INIT_SYSTEM=""
export SERVICE_CMD=""

# 检测操作系统详细信息
detect_os_detailed() {
    # 架构检测
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        i686) ARCH="386" ;;
    esac
    
    # 内核版本
    KERNEL=$(uname -r)
    
    # 发行版检测
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_CODENAME=$VERSION_CODENAME
        OS_PRETTY_NAME=$PRETTY_NAME
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        OS_VERSION=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides redhat-release))
        OS_PRETTY_NAME="CentOS Linux $OS_VERSION"
    elif [ -f /etc/centos-release ]; then
        OS="centos"
        OS_VERSION=$(rpm -q --qf "%{VERSION}" $(rpm -q --whatprovides centos-release))
        OS_PRETTY_NAME="CentOS Linux $OS_VERSION"
    elif command_exists lsb_release; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
        OS_CODENAME=$(lsb_release -sc)
        OS_PRETTY_NAME=$(lsb_release -sd)
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(uname -r)
        OS_PRETTY_NAME="$OS $OS_VERSION"
    fi
    
    # 标准化系统名称
    case "$OS" in
        ubuntu|debian|raspbian)
            OS_FAMILY="debian"
            ;;
        centos|rhel|fedora|rocky|almalinux|oracle|cloudlinux)
            OS_FAMILY="rhel"
            ;;
        opensuse*|sles)
            OS_FAMILY="suse"
            ;;
        arch|manjaro|endeavouros)
            OS_FAMILY="arch"
            ;;
        alpine)
            OS_FAMILY="alpine"
            ;;
        *)
            OS_FAMILY="unknown"
            ;;
    esac
    
    export OS_FAMILY
}

# 检测包管理器
detect_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
        PKG_UPDATE="apt-get update"
        PKG_UPGRADE="apt-get upgrade -y"
        PKG_SEARCH="apt-cache search"
        PKG_REMOVE="apt-get remove -y"
        PKG_CLEAN="apt-get autoremove -y && apt-get clean"
        export DEBIAN_FRONTEND=noninteractive
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf check-update || true"
        PKG_UPGRADE="dnf upgrade -y"
        PKG_SEARCH="dnf search"
        PKG_REMOVE="dnf remove -y"
        PKG_CLEAN="dnf autoremove -y && dnf clean all"
    elif command_exists yum; then
        PKG_MANAGER="yum"
        PKG_INSTALL="yum install -y"
        PKG_UPDATE="yum check-update || true"
        PKG_UPGRADE="yum upgrade -y"
        PKG_SEARCH="yum search"
        PKG_REMOVE="yum remove -y"
        PKG_CLEAN="yum autoremove -y && yum clean all"
    elif command_exists zypper; then
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_UPDATE="zypper refresh"
        PKG_UPGRADE="zypper update -y"
        PKG_SEARCH="zypper search"
        PKG_REMOVE="zypper remove -y"
        PKG_CLEAN="zypper clean -a"
    elif command_exists pacman; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_UPDATE="pacman -Sy"
        PKG_UPGRADE="pacman -Syu --noconfirm"
        PKG_SEARCH="pacman -Ss"
        PKG_REMOVE="pacman -R --noconfirm"
        PKG_CLEAN="pacman -Sc --noconfirm"
    elif command_exists apk; then
        PKG_MANAGER="apk"
        PKG_INSTALL="apk add --no-cache"
        PKG_UPDATE="apk update"
        PKG_UPGRADE="apk upgrade"
        PKG_SEARCH="apk search"
        PKG_REMOVE="apk del"
        PKG_CLEAN="apk cache clean"
    else
        error_exit "未找到支持的包管理器"
    fi
}

# 检测init系统
detect_init_system() {
    if command_exists systemctl && systemctl --version >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
        SERVICE_CMD="systemctl"
    elif command_exists service; then
        INIT_SYSTEM="sysvinit"
        SERVICE_CMD="service"
    elif command_exists rc-service; then
        INIT_SYSTEM="openrc"
        SERVICE_CMD="rc-service"
    else
        INIT_SYSTEM="unknown"
        SERVICE_CMD=""
    fi
}

# 完整的系统检测
detect_system() {
    info "正在检测系统环境..."
    
    detect_os_detailed
    detect_package_manager
    detect_init_system
    
    debug "操作系统: $OS_PRETTY_NAME"
    debug "系统家族: $OS_FAMILY"
    debug "架构: $ARCH"
    debug "内核: $KERNEL"
    debug "包管理器: $PKG_MANAGER"
    debug "Init系统: $INIT_SYSTEM"
}

# 检查系统兼容性
check_system_compatibility() {
    local supported_os=("ubuntu" "debian" "centos" "rhel" "fedora" "rocky" "almalinux" "opensuse" "arch" "manjaro" "alpine")
    local supported_arch=("amd64" "arm64")
    
    # 检查操作系统
    local os_supported=false
    for supported in "${supported_os[@]}"; do
        if [[ "$OS" == "$supported"* ]]; then
            os_supported=true
            break
        fi
    done
    
    if [ "$os_supported" = false ]; then
        warning "当前操作系统 ($OS) 可能不被完全支持"
    fi
    
    # 检查架构
    local arch_supported=false
    for supported in "${supported_arch[@]}"; do
        if [ "$ARCH" = "$supported" ]; then
            arch_supported=true
            break
        fi
    done
    
    if [ "$arch_supported" = false ]; then
        warning "当前架构 ($ARCH) 可能不被完全支持"
    fi
    
    # 检查最小内核版本
    local min_kernel="3.10"
    if version_compare "$KERNEL" "$min_kernel" && [ $? -eq 2 ]; then
        warning "内核版本过低 ($KERNEL < $min_kernel)，某些功能可能无法使用"
    fi
    
    return 0
}

# 安装软件包
install_package() {
    local packages=("$@")
    
    info "安装软件包: ${packages[*]}"
    
    # 更新包列表（对于某些系统）
    case "$PKG_MANAGER" in
        apt|apk)
            run_command "$PKG_UPDATE" "更新软件包列表" || true
            ;;
    esac
    
    # 安装包
    for package in "${packages[@]}"; do
        if ! package_installed "$package"; then
            debug "正在安装: $package"
            if ! run_command "$PKG_INSTALL $package" "安装 $package"; then
                warning "无法安装 $package"
            fi
        else
            debug "$package 已安装"
        fi
    done
}

# 检查软件包是否已安装
package_installed() {
    local package="$1"
    
    case "$PKG_MANAGER" in
        apt)
            dpkg -l | grep -q "^ii\s\+$package"
            ;;
        yum|dnf)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$package" >/dev/null 2>&1
            ;;
        zypper)
            zypper se -i "$package" >/dev/null 2>&1
            ;;
        *)
            command_exists "$package"
            ;;
    esac
}

# 系统服务管理
manage_service() {
    local action="$1"
    local service="$2"
    
    case "$INIT_SYSTEM" in
        systemd)
            case "$action" in
                start)   systemctl start "$service" ;;
                stop)    systemctl stop "$service" ;;
                restart) systemctl restart "$service" ;;
                enable)  systemctl enable "$service" ;;
                disable) systemctl disable "$service" ;;
                status)  systemctl status "$service" ;;
                *)       error_exit "未知的服务操作: $action" ;;
            esac
            ;;
        sysvinit)
            case "$action" in
                start|stop|restart|status)
                    service "$service" "$action"
                    ;;
                enable)
                    if command_exists update-rc.d; then
                        update-rc.d "$service" enable
                    elif command_exists chkconfig; then
                        chkconfig "$service" on
                    fi
                    ;;
                disable)
                    if command_exists update-rc.d; then
                        update-rc.d "$service" disable
                    elif command_exists chkconfig; then
                        chkconfig "$service" off
                    fi
                    ;;
                *)
                    error_exit "未知的服务操作: $action"
                    ;;
            esac
            ;;
        openrc)
            case "$action" in
                start|stop|restart|status)
                    rc-service "$service" "$action"
                    ;;
                enable)
                    rc-update add "$service" default
                    ;;
                disable)
                    rc-update del "$service" default
                    ;;
                *)
                    error_exit "未知的服务操作: $action"
                    ;;
            esac
            ;;
        *)
            error_exit "不支持的init系统: $INIT_SYSTEM"
            ;;
    esac
}

# 获取系统资源信息
get_system_resources() {
    local resource="$1"
    
    case "$resource" in
        cpu_usage)
            if command_exists mpstat; then
                mpstat 1 1 | awk 'END{print 100-$NF"%"}'
            else
                top -bn1 | grep 'Cpu(s)' | awk '{print $2+$4"%"}'
            fi
            ;;
        memory_usage)
            free | awk 'NR==2{printf "%.2f%%", $3*100/$2}'
            ;;
        disk_usage)
            df -h / | awk 'NR==2{print $5}'
            ;;
        load_average)
            uptime | awk -F'load average:' '{print $2}'
            ;;
        network_interfaces)
            ip -o link show | awk -F': ' '{print $2}' | grep -v lo
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# 系统优化建议
suggest_system_optimization() {
    info "系统优化建议："
    
    # 检查交换空间
    local swap_total=$(free -b | awk 'NR==3{print $2}')
    if [ "$swap_total" -eq 0 ]; then
        warning "未配置交换空间，建议添加交换文件"
    fi
    
    # 检查文件描述符限制
    local fd_limit=$(ulimit -n)
    if [ "$fd_limit" -lt 65536 ]; then
        warning "文件描述符限制较低 ($fd_limit)，建议增加到 65536"
    fi
    
    # 检查内核参数
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        local tcp_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
        if [ "$tcp_cc" != "bbr" ] && [ "$tcp_cc" != "bbr2" ]; then
            info "当前TCP拥塞控制: $tcp_cc，可考虑使用 BBR"
        fi
    fi
    
    # 检查时区
    if command_exists timedatectl; then
        local timezone=$(timedatectl | grep "Time zone" | awk '{print $3}')
        if [ "$timezone" = "UTC" ]; then
            info "系统时区为 UTC，可能需要调整为本地时区"
        fi
    fi
}

# 安装基础依赖
install_base_dependencies() {
    info "安装基础依赖..."
    
    local base_deps=()
    
    # 通用依赖
    base_deps+=("curl" "wget" "sudo" "ca-certificates")
    
    # 根据系统添加特定依赖
    case "$OS_FAMILY" in
        debian)
            base_deps+=("apt-transport-https" "gnupg" "lsb-release")
            base_deps+=("net-tools" "dnsutils" "iputils-ping")
            ;;
        rhel)
            base_deps+=("epel-release" "net-tools" "bind-utils" "iputils")
            # CentOS 8+ 需要 PowerTools/CRB
            if [ "$OS" = "centos" ] && [ "${OS_VERSION%%.*}" -ge 8 ]; then
                dnf config-manager --set-enabled powertools 2>/dev/null || \
                dnf config-manager --set-enabled crb 2>/dev/null || true
            fi
            ;;
        arch)
            base_deps+=("net-tools" "bind" "iputils")
            ;;
        alpine)
            base_deps+=("net-tools" "bind-tools" "iputils")
            ;;
        suse)
            base_deps+=("net-tools" "bind-utils" "iputils")
            ;;
    esac
    
    # 安装依赖
    install_package "${base_deps[@]}"
}

# 系统更新
system_update() {
    info "更新系统..."
    
    case "$PKG_MANAGER" in
        apt)
            run_command "$PKG_UPDATE" "更新软件包列表"
            run_command "$PKG_UPGRADE" "升级软件包"
            ;;
        yum|dnf)
            run_command "$PKG_UPDATE" "检查更新"
            run_command "$PKG_UPGRADE" "升级软件包"
            ;;
        pacman)
            run_command "$PKG_UPDATE" "更新软件包数据库"
            run_command "$PKG_UPGRADE" "升级系统"
            ;;
        apk)
            run_command "$PKG_UPDATE" "更新软件包索引"
            run_command "$PKG_UPGRADE" "升级软件包"
            ;;
        zypper)
            run_command "$PKG_UPDATE" "刷新软件源"
            run_command "$PKG_UPGRADE" "升级软件包"
            ;;
    esac
    
    success "系统更新完成"
}

# 系统清理
system_cleanup() {
    info "清理系统..."
    
    # 清理包管理器缓存
    run_command "$PKG_CLEAN" "清理软件包缓存"
    
    # 清理日志
    if command_exists journalctl; then
        journalctl --vacuum-time=7d 2>/dev/null || true
    fi
    
    # 清理临时文件
    find /tmp -type f -atime +7 -delete 2>/dev/null || true
    find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # 清理旧内核（仅限某些系统）
    case "$OS_FAMILY" in
        debian)
            if command_exists apt-get; then
                apt-get autoremove --purge -y $(dpkg -l | awk '/^rc/ {print $2}') 2>/dev/null || true
            fi
            ;;
        rhel)
            if command_exists package-cleanup; then
                package-cleanup --oldkernels --count=2 -y 2>/dev/null || true
            fi
            ;;
    esac
    
    success "系统清理完成"
}

# 配置系统限制
configure_system_limits() {
    local limits_file="/etc/security/limits.conf"
    
    info "配置系统限制..."
    
    # 备份原文件
    backup_file "$limits_file"
    
    # 添加优化配置
    cat >> "$limits_file" << EOF

# VPS Scripts Optimization
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    # 应用当前会话
    ulimit -n 65535
    ulimit -u 65535
    
    success "系统限制配置完成"
}

# 启用 BBR
enable_bbr() {
    info "检查并启用 BBR..."
    
    # 检查内核版本
    local kernel_version=$(uname -r | cut -d. -f1,2)
    if version_compare "$kernel_version" "4.9" && [ $? -eq 2 ]; then
        warning "内核版本过低，无法启用 BBR"
        return 1
    fi
    
    # 检查是否已启用
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        local current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
        if [ "$current_cc" = "bbr" ]; then
            success "BBR 已启用"
            return 0
        fi
    fi
    
    # 加载 BBR 模块
    modprobe tcp_bbr 2>/dev/null || true
    
    # 配置 sysctl
    cat >> /etc/sysctl.conf << EOF

# Enable BBR
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    
    # 应用配置
    sysctl -p
    
    # 验证
    local new_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [ "$new_cc" = "bbr" ]; then
        success "BBR 启用成功"
    else
        warning "BBR 启用失败"
        return 1
    fi
}

# 导出所有函数
export -f detect_os_detailed detect_package_manager detect_init_system
export -f detect_system check_system_compatibility
export -f install_package package_installed manage_service
export -f get_system_resources suggest_system_optimization
export -f install_base_dependencies system_update system_cleanup
export -f configure_system_limits enable_bbr
