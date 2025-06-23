#!/bin/bash
#==============================================================================
# 脚本名称: cyberpanel.sh
# 脚本描述: Cyberpanel面板安装脚本 - 提供交互式和半自动化安装Cyberpanel
# 脚本路径: vps_scripts/scripts/service_install/cyberpanel.sh
# 作者: Jensfrank
# 使用方法: bash cyberpanel.sh [选项]
# 选项: --check (仅检查系统要求)
#       --prepare (安装前准备，包括依赖和优化)
#       --info (显示安装后的信息)
#       --uninstall (卸载Cyberpanel面板)
# 更新日期: 2025-01-23
#==============================================================================

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_PORT="8090"
INSTALL_DIR="/usr/local/CyberCP"
CYBERPANEL_URL="https://cyberpanel.net/install.sh"
ACTION="install"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# 显示标题
show_banner() {
    clear
    echo "=================================================="
    echo -e "${PURPLE}    Cyberpanel 面板安装助手${NC}"
    echo "=================================================="
    echo "    作者: Jensfrank"
    echo "    版本: 1.0"
    echo "    更新: 2025-01-23"
    echo "=================================================="
    echo ""
}

# 帮助信息
show_help() {
    show_banner
    echo "使用方法: bash cyberpanel.sh [选项]"
    echo ""
    echo "选项说明:"
    echo "  无参数           - 交互式安装向导"
    echo "  --check         - 仅检查系统是否满足安装要求"
    echo "  --prepare       - 执行安装前准备（优化系统、安装依赖）"
    echo "  --info          - 显示已安装的Cyberpanel信息"
    echo "  --uninstall     - 卸载Cyberpanel面板"
    echo "  --help          - 显示此帮助信息"
    echo ""
    echo "安装流程:"
    echo "  1. 运行 bash cyberpanel.sh --check 检查系统"
    echo "  2. 运行 bash cyberpanel.sh --prepare 准备环境"
    echo "  3. 运行 bash cyberpanel.sh 开始安装"
    echo ""
    echo "注意事项:"
    echo "  - 需要root权限运行"
    echo "  - 建议在全新系统上安装"
    echo "  - 至少需要1GB内存和10GB磁盘空间"
    echo "=================================================="
}

# 解析命令行参数
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        ACTION="install"
        return
    fi
    
    case $1 in
        --check)
            ACTION="check"
            ;;
        --prepare)
            ACTION="prepare"
            ;;
        --info)
            ACTION="info"
            ;;
        --uninstall)
            ACTION="uninstall"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

# 检查系统要求
check_system() {
    local CHECK_ONLY=${1:-false}
    
    if [[ "$CHECK_ONLY" == true ]]; then
        show_banner
        echo -e "${CYAN}系统要求检查${NC}"
        echo "=================================================="
    fi
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "需要root权限运行"
        return 1
    fi
    log_success "✓ Root权限检查通过"
    
    # 检查系统版本
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "✗ 无法检测系统版本"
        return 1
    fi
    
    # 检查支持的系统
    SUPPORTED_OS=false
    case "$OS" in
        "Ubuntu")
            if [[ "$VER" == "18.04" || "$VER" == "20.04" || "$VER" == "22.04" ]]; then
                SUPPORTED_OS=true
                PKG_MANAGER="apt"
            fi
            ;;
        "CentOS Linux"|"CentOS Stream")
            if [[ ${VER%%.*} -ge 7 ]]; then
                SUPPORTED_OS=true
                PKG_MANAGER="yum"
            fi
            ;;
        "AlmaLinux"|"Rocky Linux")
            if [[ ${VER%%.*} -ge 8 ]]; then
                SUPPORTED_OS=true
                PKG_MANAGER="dnf"
            fi
            ;;
    esac
    
    if [[ "$SUPPORTED_OS" == true ]]; then
        log_success "✓ 操作系统: $OS $VER (支持)"
    else
        log_error "✗ 不支持的操作系统: $OS $VER"
        log_info "  支持: Ubuntu 18.04/20.04/22.04, CentOS 7/8, AlmaLinux 8/9"
        return 1
    fi
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -ge 1024 ]]; then
        log_success "✓ 内存检查: ${TOTAL_MEM}MB (满足要求)"
    else
        log_error "✗ 内存不足: ${TOTAL_MEM}MB (需要至少1024MB)"
        return 1
    fi
    
    # 检查磁盘空间
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $FREE_SPACE -ge 10 ]]; then
        log_success "✓ 磁盘空间: ${FREE_SPACE}GB (满足要求)"
    else
        log_error "✗ 磁盘空间不足: ${FREE_SPACE}GB (需要至少10GB)"
        return 1
    fi
    
    # 检查网络连接
    if curl -s --head https://cyberpanel.net >/dev/null; then
        log_success "✓ 网络连接正常"
    else
        log_error "✗ 无法连接到Cyberpanel官网"
        return 1
    fi
    
    # 检查端口占用
    PORTS_TO_CHECK=("8090" "7080" "80" "443" "3306" "21")
    OCCUPIED_PORTS=()
    
    for port in "${PORTS_TO_CHECK[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            OCCUPIED_PORTS+=($port)
        fi
    done
    
    if [[ ${#OCCUPIED_PORTS[@]} -eq 0 ]]; then
        log_success "✓ 所需端口均未被占用"
    else
        log_warning "⚠ 以下端口已被占用: ${OCCUPIED_PORTS[*]}"
        log_info "  安装时可能需要处理端口冲突"
    fi
    
    # 检查现有安装
    if [[ -d "$INSTALL_DIR" ]] || command -v cyberpanel &> /dev/null; then
        log_warning "⚠ 检测到已安装的Cyberpanel"
    else
        log_success "✓ 未检测到Cyberpanel安装"
    fi
    
    if [[ "$CHECK_ONLY" == true ]]; then
        echo ""
        echo "=================================================="
        log_info "系统检查完成"
    fi
    
    return 0
}

# 系统准备
prepare_system() {
    show_banner
    echo -e "${CYAN}系统准备和优化${NC}"
    echo "=================================================="
    
    # 更新系统
    log_info "更新系统软件包..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt update -y && apt upgrade -y
    else
        $PKG_MANAGER update -y
    fi
    log_success "系统更新完成"
    
    # 安装基础依赖
    log_info "安装基础依赖..."
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt install -y wget curl git unzip software-properties-common \
            build-essential python3 python3-pip
    else
        $PKG_MANAGER install -y wget curl git unzip gcc gcc-c++ \
            make python3 python3-pip
    fi
    log_success "基础依赖安装完成"
    
    # 配置系统参数
    log_info "优化系统参数..."
    
    # 设置文件描述符限制
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    # 优化内核参数
    cat > /etc/sysctl.d/99-cyberpanel.conf << EOF
# Cyberpanel优化参数
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fastopen = 3
EOF
    
    sysctl -p /etc/sysctl.d/99-cyberpanel.conf >/dev/null 2>&1
    log_success "系统参数优化完成"
    
    # 创建swap（如果内存小于2GB）
    if [[ $TOTAL_MEM -lt 2048 ]]; then
        if ! swapon -s | grep -q swapfile; then
            log_info "创建2GB Swap文件..."
            dd if=/dev/zero of=/swapfile bs=1M count=2048 >/dev/null 2>&1
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null 2>&1
            swapon /swapfile
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
            log_success "Swap文件创建完成"
        fi
    fi
    
    # 禁用SELinux（如果存在）
    if command -v getenforce &> /dev/null; then
        if [[ $(getenforce) != "Disabled" ]]; then
            log_info "禁用SELinux..."
            setenforce 0
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            log_success "SELinux已禁用"
        fi
    fi
    
    echo ""
    echo "=================================================="
    log_success "系统准备完成！"
    log_info "建议重启系统后再执行安装"
    echo "=================================================="
}

# 安装向导
install_wizard() {
    show_banner
    
    # 再次检查系统
    if ! check_system; then
        log_error "系统检查未通过，请先解决上述问题"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}Cyberpanel 安装配置${NC}"
    echo "=================================================="
    
    # 选择版本
    echo "请选择要安装的版本:"
    echo "1) OpenLiteSpeed (免费版，推荐)"
    echo "2) LiteSpeed Enterprise (企业版，需要许可证)"
    read -p "请输入选择 [1-2]: " version_choice
    
    # 是否安装全套服务
    echo ""
    read -p "是否安装完整服务套件(PowerDNS/Postfix/Pure-FTPd)? [Y/n]: " full_service
    full_service=${full_service:-Y}
    
    # 提示密码设置
    echo ""
    echo -e "${YELLOW}提示：${NC}"
    echo "1. 安装过程中会要求设置管理员密码"
    echo "2. 建议使用强密码并妥善保管"
    echo "3. 默认用户名为: admin"
    echo "4. 安装完成后可通过 https://IP:8090 访问"
    echo ""
    
    read -p "是否继续安装? [Y/n]: " confirm
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "取消安装"
        exit 0
    fi
    
    # 记录安装选项
    cat > /tmp/cyberpanel_install_options.txt << EOF
版本选择: $version_choice
完整服务: $full_service
安装时间: $(date)
EOF
    
    # 执行安装
    log_info "开始下载并执行Cyberpanel官方安装脚本..."
    echo ""
    echo -e "${YELLOW}请根据提示进行选择：${NC}"
    echo "1. Installation: 选择 1"
    echo "2. Version: 选择 $version_choice"
    echo "3. Full Service: 选择 $full_service"
    echo "4. Remote MySQL: 通常选择 N"
    echo "5. Password: 选择 s 设置自定义密码"
    echo ""
    
    # 执行官方安装脚本
    sh <(curl -s "$CYBERPANEL_URL" || wget -q -O - "$CYBERPANEL_URL")
    
    # 安装后处理
    if [[ -d "$INSTALL_DIR" ]]; then
        log_success "Cyberpanel安装完成！"
        configure_after_install
        show_install_info
    else
        log_error "Cyberpanel安装失败"
        exit 1
    fi
}

# 安装后配置
configure_after_install() {
    log_info "执行安装后配置..."
    
    # 配置防火墙
    configure_firewall
    
    # 创建快捷命令
    if [[ ! -f /usr/local/bin/cyberctl ]]; then
        cat > /usr/local/bin/cyberctl << 'EOF'
#!/bin/bash
# Cyberpanel控制脚本

case "$1" in
    start)
        systemctl start lscpd
        echo "Cyberpanel started"
        ;;
    stop)
        systemctl stop lscpd
        echo "Cyberpanel stopped"
        ;;
    restart)
        systemctl restart lscpd
        echo "Cyberpanel restarted"
        ;;
    status)
        systemctl status lscpd
        ;;
    *)
        echo "Usage: cyberctl {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF
        chmod +x /usr/local/bin/cyberctl
        log_success "创建快捷命令 cyberctl"
    fi
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 需要开放的端口
    TCP_PORTS=("8090" "80" "443" "21" "25" "587" "465" "110" "143" "993" "3306" "7080")
    UDP_PORTS=("53")
    
    # 检查并配置firewalld
    if command -v firewall-cmd &> /dev/null && systemctl is-active firewalld &>/dev/null; then
        for port in "${TCP_PORTS[@]}"; do
            firewall-cmd --permanent --add-port=$port/tcp &>/dev/null
        done
        for port in "${UDP_PORTS[@]}"; do
            firewall-cmd --permanent --add-port=$port/udp &>/dev/null
        done
        firewall-cmd --reload
        log_success "firewalld防火墙规则已配置"
    fi
    
    # 检查并配置ufw
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        for port in "${TCP_PORTS[@]}"; do
            ufw allow $port/tcp &>/dev/null
        done
        for port in "${UDP_PORTS[@]}"; do
            ufw allow $port/udp &>/dev/null
        done
        log_success "ufw防火墙规则已配置"
    fi
}

# 显示安装信息
show_install_info() {
    local SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    clear
    echo "=================================================="
    echo -e "${GREEN}    Cyberpanel 安装成功！${NC}"
    echo "=================================================="
    echo ""
    echo -e "${CYAN}访问信息：${NC}"
    echo "面板地址: https://$SERVER_IP:8090"
    echo "用户名: admin"
    echo "密码: (您在安装时设置的密码)"
    echo ""
    echo -e "${CYAN}重要端口：${NC}"
    echo "8090 - Cyberpanel面板"
    echo "7080 - OpenLiteSpeed/LiteSpeed管理面板"
    echo "80   - HTTP"
    echo "443  - HTTPS"
    echo "3306 - MySQL/MariaDB"
    echo "21   - FTP"
    echo ""
    echo -e "${CYAN}常用命令：${NC}"
    echo "cyberctl start    - 启动Cyberpanel"
    echo "cyberctl stop     - 停止Cyberpanel"
    echo "cyberctl restart  - 重启Cyberpanel"
    echo "cyberctl status   - 查看状态"
    echo ""
    echo -e "${CYAN}管理面板：${NC}"
    echo "Cyberpanel: https://$SERVER_IP:8090"
    echo "phpMyAdmin: https://$SERVER_IP:8090/dataBases/phpMyAdmin"
    echo "Rainloop: https://$SERVER_IP:8090/rainloop"
    echo ""
    echo -e "${YELLOW}安全建议：${NC}"
    echo "1. 立即修改所有默认密码"
    echo "2. 配置SSL证书"
    echo "3. 定期备份数据"
    echo "4. 保持系统和面板更新"
    echo ""
    echo "=================================================="
    
    # 保存信息到文件
    cat > /root/cyberpanel_info.txt << EOF
Cyberpanel Installation Information
===================================
Installation Date: $(date)
Server IP: $SERVER_IP
Panel URL: https://$SERVER_IP:8090
Username: admin

Quick Commands:
- cyberctl start/stop/restart/status

Important URLs:
- Cyberpanel: https://$SERVER_IP:8090
- phpMyAdmin: https://$SERVER_IP:8090/dataBases/phpMyAdmin
- Rainloop: https://$SERVER_IP:8090/rainloop
- LiteSpeed Admin: https://$SERVER_IP:7080
===================================
EOF
    
    log_info "安装信息已保存到: /root/cyberpanel_info.txt"
}

# 显示已安装信息
show_existing_info() {
    show_banner
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_error "未检测到Cyberpanel安装"
        exit 1
    fi
    
    local SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo -e "${CYAN}Cyberpanel 信息${NC}"
    echo "=================================================="
    
    # 检查服务状态
    if systemctl is-active lscpd &>/dev/null; then
        echo -e "面板状态: ${GREEN}运行中${NC}"
    else
        echo -e "面板状态: ${RED}已停止${NC}"
    fi
    
    # 显示版本信息
    if [[ -f /usr/local/CyberCP/version.txt ]]; then
        local version=$(cat /usr/local/CyberCP/version.txt)
        echo "版本: $version"
    fi
    
    echo ""
    echo "访问地址: https://$SERVER_IP:8090"
    echo "用户名: admin"
    echo ""
    
    # 显示已安装的服务
    echo -e "${CYAN}已安装服务：${NC}"
    systemctl is-active lscpd &>/dev/null && echo "✓ Cyberpanel"
    systemctl is-active lsws &>/dev/null && echo "✓ LiteSpeed/OpenLiteSpeed"
    systemctl is-active mysql &>/dev/null || systemctl is-active mariadb &>/dev/null && echo "✓ MySQL/MariaDB"
    systemctl is-active postfix &>/dev/null && echo "✓ Postfix (邮件服务)"
    systemctl is-active pure-ftpd &>/dev/null && echo "✓ Pure-FTPd (FTP服务)"
    systemctl is-active pdns &>/dev/null && echo "✓ PowerDNS (DNS服务)"
    
    echo ""
    echo "=================================================="
}

# 卸载Cyberpanel
uninstall_cyberpanel() {
    show_banner
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_error "未检测到Cyberpanel安装"
        exit 1
    fi
    
    echo -e "${RED}警告：卸载操作${NC}"
    echo "=================================================="
    echo "此操作将删除："
    echo "- Cyberpanel面板及所有配置"
    echo "- 所有网站数据"
    echo "- 所有数据库"
    echo "- 所有邮件数据"
    echo ""
    echo -e "${RED}此操作不可恢复！${NC}"
    echo ""
    
    read -p "请输入 'YES' 确认卸载: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "开始卸载Cyberpanel..."
    
    # 停止所有服务
    services=(lscpd lsws mysql mariadb postfix pure-ftpd pdns)
    for service in "${services[@]}"; do
        systemctl stop $service 2>/dev/null
        systemctl disable $service 2>/dev/null
    done
    
    # 删除文件和目录
    rm -rf /usr/local/CyberCP
    rm -rf /usr/local/lsws
    rm -rf /home/cyberpanel
    rm -rf /etc/cyberpanel
    rm -rf /var/log/cyberpanel
    rm -f /usr/local/bin/cyberpanel
    rm -f /usr/local/bin/cyberctl
    rm -f /etc/systemd/system/lscpd.service
    
    # 删除数据库
    if command -v mysql &> /dev/null; then
        mysql -e "DROP DATABASE IF EXISTS cyberpanel;" 2>/dev/null
        mysql -e "DROP DATABASE IF EXISTS rainloop;" 2>/dev/null
    fi
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "Cyberpanel已完全卸载"
    
    echo ""
    echo "如需重新安装，请运行："
    echo "bash cyberpanel.sh"
}

# 主函数
main() {
    # 解析参数
    parse_arguments "$@"
    
    # 根据操作执行
    case "$ACTION" in
        check)
            check_system true
            ;;
        prepare)
            prepare_system
            ;;
        info)
            show_existing_info
            ;;
        uninstall)
            uninstall_cyberpanel
            ;;
        install)
            install_wizard
            ;;
    esac
}

# 执行主函数
main "$@"