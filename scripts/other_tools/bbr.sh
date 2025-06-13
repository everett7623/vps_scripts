#!/bin/bash
#/vps_scripts/scripts/other_tools/bbr.sh - VPS Scripts BBR网络加速工具

# 检查是否有root权限
if [ "$(id -u)" != "0" ]; then
    echo "错误: 此脚本需要root权限运行!"
    echo "请使用sudo或root用户执行此脚本。"
    exit 1
fi

echo "============================================="
echo "            BBR网络优化工具                  "
echo "============================================="
echo ""

# 检查系统内核版本
kernel_version=$(uname -r | cut -d. -f1-2)
echo "当前内核版本: $(uname -r)"

# BBR需要4.9或更高版本的内核
if (( $(echo "$kernel_version >= 4.9" | bc -l) )); then
    echo "内核版本符合BBR要求。"
else
    echo "警告: 内核版本过低，可能无法支持BBR。"
    echo "建议升级到4.9或更高版本的内核。"
fi

echo ""
echo "正在配置BBR网络优化..."

# 备份原配置文件
if [ -f /etc/sysctl.conf ]; then
    cp /etc/sysctl.conf /etc/sysctl.conf.bak
    echo "已备份原配置文件到 /etc/sysctl.conf.bak"
fi

# 写入BBR配置
cat > /etc/sysctl.conf << EOF
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
net.ipv4.ip_forward=1
net.ipv4.conf.all.route_localnet=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.default.forwarding=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF

# 应用配置
echo "正在应用BBR配置..."
if sysctl -p && sysctl --system; then
    echo "BBR配置已成功应用!"
    
    # 显示BBR状态
    echo ""
    echo "BBR当前状态:"
    echo "TCP拥塞控制算法: $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')"
    echo "默认队列规则: $(sysctl net.core.default_qdisc | awk '{print $3}')"
    
    if lsmod | grep -q tcp_bbr; then
        echo "BBR模块已加载。"
    else
        echo "BBR模块未加载或不可用。"
    fi
    
    echo ""
    echo "建议重启系统以确保所有设置生效。"
    echo "您可以运行 'reboot' 命令重启系统。"
else
    echo "应用BBR配置失败!"
    echo "请检查配置文件或手动应用配置。"
fi
