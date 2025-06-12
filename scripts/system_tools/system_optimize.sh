#!/bin/bash
#/scripts/system_tools/system_optimize.sh - VPS Scripts 系统工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        # 大多数现代Linux发行版使用此文件
        . /etc/os-release
        os_type="$ID"
    elif type lsb_release >/dev/null 2>&1; then
        # lsb_release命令
        os_type=$(lsb_release -si)
    elif [ -f /etc/debian_version ]; then
        # Debian系统
        os_type="debian"
    elif [ -f /etc/redhat-release ]; then
        # Red Hat系统
        os_type="redhat"
    else
        # 尝试使用uname
        os_type=$(uname -s)
    fi
    
    # 转换为小写
    os_type=$(echo "$os_type" | tr '[:upper:]' '[:lower:]')
    
    # 处理一些特殊情况
    case "$os_type" in
        *ubuntu*) os_type="ubuntu" ;;
        *debian*) os_type="debian" ;;
        *centos*) os_type="centos" ;;
        *rhel*) os_type="rhel" ;;
        *fedora*) os_type="fedora" ;;
        *arch*) os_type="arch" ;;
        *manjaro*) os_type="manjaro" ;;
        *linuxmint*) os_type="linuxmint" ;;
        *elementary*) os_type="elementary" ;;
        *pop*) os_type="pop" ;;
    esac
}

# 备份文件
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup_file"
        echo -e "${YELLOW}已备份 $file 到 $backup_file${NC}"
    fi
}

# 优化内核参数
optimize_kernel() {
    echo -e "${BLUE}正在优化内核参数...${NC}"
    
    # 备份现有sysctl配置
    backup_file /etc/sysctl.conf
    
    # 创建优化配置
    cat > /etc/sysctl.d/99-vps-optimize.conf << 'EOF'
# 网络优化
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 32768
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.optmem_max = 65536

# TCP优化
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_slow_start_after_idle = 0

# IPv6
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0

# 文件系统
fs.file-max = 1000000
fs.inotify.max_user_watches = 524288

# 安全设置
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF

    # 应用新配置
    sysctl -p /etc/sysctl.d/99-vps-optimize.conf
    
    echo -e "${GREEN}内核参数优化完成。${NC}"
}

# 优化系统限制
optimize_limits() {
    echo -e "${BLUE}正在优化系统资源限制...${NC}"
    
    # 备份现有配置
    backup_file /etc/security/limits.conf
    
    # 创建优化配置
    cat > /etc/security/limits.d/99-vps-optimize.conf << 'EOF'
# 增加文件描述符限制
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
root soft nofile 65535
root hard nofile 65535
root soft nproc 65535
root hard nproc 65535
EOF

    echo -e "${GREEN}系统资源限制优化完成。${NC}"
}

# 优化系统服务
optimize_services() {
    echo -e "${BLUE}正在优化系统服务...${NC}"
    
    # 检测是否使用systemd
    if command -v systemctl &>/dev/null; then
        # 禁用不必要的服务 (根据系统类型)
        case "${os_type,,}" in
            ubuntu|debian|linuxmint|elementary|pop)
                # 禁用不需要的服务
                services_to_disable=(
                    apport
                    avahi-daemon
                    bluetooth
                    cups
                    cups-browsed
                    nfs-common
                    rpcbind
                    snapd
                    lxcfs
                    lxd
                    docker
                    docker.socket
                )
                
                for service in "${services_to_disable[@]}"; do
                    if systemctl list-unit-files | grep -q "^${service}.service"; then
                        systemctl disable "$service" --now &>/dev/null
                        echo -e "${YELLOW}已禁用服务: $service${NC}"
                    fi
                done
                ;;
                
            centos|rhel|fedora|rocky|almalinux|openeuler)
                # 禁用不需要的服务
                services_to_disable=(
                    avahi-daemon
                    cups
                    firewalld
                    postfix
                    rpcbind
                    nfs
                    nfs-server
                    chronyd
                    docker
                    docker.socket
                )
                
                for service in "${services_to_disable[@]}"; do
                    if systemctl list-unit-files | grep -q "^${service}.service"; then
                        systemctl disable "$service" --now &>/dev/null
                        echo -e "${YELLOW}已禁用服务: $service${NC}"
                    fi
                done
                ;;
                
            arch|manjaro)
                # 禁用不需要的服务
                services_to_disable=(
                    avahi-daemon
                    cups
                    dhcpcd
                    docker
                    docker.socket
                    firewalld
                    gdm
                    NetworkManager
                    sddm
                    systemd-timesyncd
                )
                
                for service in "${services_to_disable[@]}"; do
                    if systemctl list-unit-files | grep -q "^${service}.service"; then
                        systemctl disable "$service" --now &>/dev/null
                        echo -e "${YELLOW}已禁用服务: $service${NC}"
                    fi
                done
                ;;
        esac
    else
        echo -e "${YELLOW}未检测到systemd，跳过服务优化${NC}"
    fi
    
    echo -e "${GREEN}系统服务优化完成。${NC}"
}

# 优化网络设置
optimize_network() {
    echo -e "${BLUE}正在优化网络设置...${NC}"
    
    # 备份现有网络配置
    if [ -d /etc/sysctl.d ]; then
        backup_file /etc/sysctl.d/99-network-optimize.conf
    fi
    
    # 检测网络接口类型
    if command -v ip &>/dev/null; then
        interface=$(ip -o route get to 8.8.8.8 | sed -n 's/.*dev \([^ ]*\).*/\1/p')
    else
        interface=$(route -n | awk '$1 == "0.0.0.0" {print $8}')
    fi
    
    if [ -n "$interface" ]; then
        # 为网络接口设置MTU (适用于VPS)
        ifconfig "$interface" mtu 1450 &>/dev/null || ip link set "$interface" mtu 1450 &>/dev/null
        echo -e "${YELLOW}已设置网络接口 $interface 的MTU为1450${NC}"
    fi
    
    # 优化TCP拥塞控制算法
    echo "tcp_bbr" > /etc/modules-load.d/tcp-bbr.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-vps-optimize.conf
    sysctl -p /etc/sysctl.d/99-vps-optimize.conf
    
    echo -e "${GREEN}网络设置优化完成。${NC}"
}

# 优化磁盘I/O
optimize_disk() {
    echo -e "${BLUE}正在优化磁盘I/O...${NC}"
    
    # 获取根分区
    root_disk=$(df -h / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//')
    
    # 备份fstab
    backup_file /etc/fstab
    
    # 检测文件系统类型
    fs_type=$(df -T / | awk 'NR==2 {print $2}')
    
    # 为SSD优化 (如果适用)
    if [ "$fs_type" = "ext4" ] || [ "$fs_type" = "xfs" ]; then
        # 添加noatime和discard选项
        sed -i 's/\(.*\)defaults\(.*\)/\1defaults,noatime,discard\2/' /etc/fstab
        echo -e "${YELLOW}已为根分区添加noatime和discard选项${NC}"
    fi
    
    # 为swap设置合适的swappiness
    echo "vm.swappiness = 10" >> /etc/sysctl.d/99-vps-optimize.conf
    sysctl -p /etc/sysctl.d/99-vps-optimize.conf
    
    echo -e "${GREEN}磁盘I/O优化完成。${NC}"
}

# 清理系统
clean_system() {
    echo -e "${BLUE}正在清理系统...${NC}"
    
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            apt autoremove --purge -y && apt clean -y && apt autoclean -y
            apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y
            journalctl --vacuum-time=1s
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            if command -v dnf &>/dev/null; then
                dnf autoremove -y && dnf clean all
            else
                yum autoremove -y && yum clean all
            fi
            journalctl --vacuum-time=1s
            ;;
        arch|manjaro)
            pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || echo "没有可移除的孤立包"
            pacman -Sc --noconfirm
            ;;
    esac
    
    # 清理临时文件
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    
    echo -e "${GREEN}系统清理完成。${NC}"
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}         VPS 系统优化工具                     ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    echo -e "${YELLOW}警告: 系统优化可能会影响某些服务的正常运行。${NC}"
    echo -e "${YELLOW}请确保您了解可能的风险，并在操作前备份重要数据。${NC}"
    echo ""
    
    read -p "确定要优化系统吗? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        detect_os
        echo -e "${YELLOW}检测到操作系统: ${os_type}${NC}"
        echo ""
        
        # 显示优化选项菜单
        echo "请选择要执行的优化项目:"
        echo "1. 全部优化"
        echo "2. 仅优化内核参数"
        echo "3. 仅优化系统限制"
        echo "4. 仅优化系统服务"
        echo "5. 仅优化网络设置"
        echo "6. 仅优化磁盘I/O"
        echo "7. 仅清理系统"
        echo ""
        
        read -p "请输入选项 (1-7): " option
        
        case $option in
            1)
                optimize_kernel
                optimize_limits
                optimize_services
                optimize_network
                optimize_disk
                clean_system
                ;;
            2) optimize_kernel ;;
            3) optimize_limits ;;
            4) optimize_services ;;
            5) optimize_network ;;
            6) optimize_disk ;;
            7) clean_system ;;
            *)
                echo -e "${RED}无效选项，操作已取消。${NC}"
                exit 1
                ;;
        esac
        
        echo -e "${GREEN}系统优化完成!${NC}"
        echo -e "${YELLOW}部分优化需要重启系统才能完全生效。${NC}"
        read -p "是否立即重启系统? (y/n): " reboot_confirm
        if [[ $reboot_confirm =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}系统将在5秒后重启...${NC}"
            sleep 5
            reboot
        fi
    else
        echo -e "${YELLOW}操作已取消。${NC}"
    fi
    
    read -n 1 -s -r -p "按任意键返回..."
}

# 执行主函数
main
