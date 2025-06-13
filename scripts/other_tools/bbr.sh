#!/bin/bash
#/vps_scripts/scripts/other_tools/bbr.sh - VPS Scripts BBR网络加速工具

# 模块信息
MODULE_NAME="BBR网络加速"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="启用Google BBR拥塞控制算法，优化网络性能"

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "此脚本需要root权限运行"
        exit 1
    fi
}

# 显示标题
show_header() {
    clear
    draw_menu_border "BBR网络加速工具"
    echo ""
}

# 确认操作
confirm_action() {
    warning "启用BBR可能会影响现有网络配置"
    if ! confirm "确定要启用BBR网络加速吗?"; then
        info "已取消操作"
        exit 0
    fi
}

# 检查内核版本
check_kernel() {
    local current_kernel=$(uname -r)
    info "当前内核版本: $current_kernel"
    
    if [[ "$current_kernel" > "4.9" ]]; then
        success "当前内核版本支持BBR"
        return 0
    else
        warning "当前内核版本可能不支持BBR，需要升级内核"
        return 1
    fi
}

# 升级内核
upgrade_kernel() {
    info "正在检测系统类型..."
    
    if [ -f /etc/redhat-release ]; then
        system_type="centos"
    elif [ -f /etc/debian_version ]; then
        if grep -q "ubuntu" /etc/os-release; then
            system_type="ubuntu"
        else
            system_type="debian"
        fi
    else
        error "不支持的操作系统类型"
        exit 1
    fi
    
    info "检测到系统类型: $system_type"
    info "开始升级内核..."
    
    if [ "$system_type" == "centos" ]; then
        execute "yum -y update" "更新系统软件包"
        execute "yum -y install kernel" "安装最新内核"
    else
        execute "apt-get update" "更新软件源"
        execute "apt-get -y upgrade" "升级系统软件"
    fi
    
    warning "内核已更新，请重启系统后再次运行此脚本"
    
    if confirm "是否立即重启系统?"; then
        success "系统将在5秒后重启..."
        sleep 5
        reboot
    else
        info "请在适当的时候手动重启系统"
        exit 0
    fi
}

# 配置BBR和网络优化参数
configure_bbr() {
    info "配置BBR和网络优化参数..."
    
    # 创建配置文件
    cat > /etc/sysctl.d/99-network-optimization.conf << EOF
# BBR拥塞控制
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 网络性能优化
fs.file-max = 6815744
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.core.rmem_max=33554432
net.core.wmem_max=33554432
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 16384 33554432
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# IP转发设置
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
    
    # 应用配置
    execute "sysctl -p /etc/sysctl.d/99-network-optimization.conf" "应用网络优化配置"
    execute "sysctl --system" "重新加载所有系统配置"
}

# 验证BBR是否启用
verify_bbr() {
    info "验证BBR是否成功启用..."
    
    if lsmod | grep -q tcp_bbr; then
        success "BBR模块已加载"
    else
        warning "BBR模块未加载，可能需要重启系统"
    fi
    
    local tcp_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local default_qdisc=$(sysctl -n net.core.default_qdisc)
    
    if [ "$tcp_cc" == "bbr" ] && [ "$default_qdisc" == "fq" ]; then
        success "TCP拥塞控制和队列规则配置正确"
    else
        error "TCP拥塞控制或队列规则配置不正确"
        return 1
    fi
    
    info "当前TCP拥塞控制: $tcp_cc"
    info "当前默认队列规则: $default_qdisc"
    return 0
}

# 主函数
main() {
    check_root
    show_header
    confirm_action
    
    if ! check_kernel; then
        upgrade_kernel
    fi
    
    configure_bbr
    
    if verify_bbr; then
        success "BBR网络加速配置完成！"
        info "网络性能优化参数已应用"
        info "重启系统后配置将完全生效"
    else
        warning "BBR配置可能未完全生效"
        info "请检查内核版本是否支持BBR"
        info "或尝试重启系统后再次运行此脚本"
    fi
    
    record_function_usage "bbr_enable"
    pause_for_continue
}

# 执行主函数
main
