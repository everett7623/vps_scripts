#!/bin/bash
#==============================================================================
# 脚本名称: cyberpanel.sh
# 脚本描述: Cyberpanel面板自动安装脚本 - 一键安装Cyberpanel Web控制面板
# 脚本路径: vps_scripts/scripts/service_install/cyberpanel.sh
# 作者: Jensfrank
# 使用方法: bash cyberpanel.sh [选项]
# 选项: --version [openlitespeed|enterprise] (默认openlitespeed)
#       --password [密码] (设置管理员密码)
#       --port [端口] (默认8090)
#       --full-service [yes|no] (安装全套服务，默认yes)
#       --remote-mysql [yes|no] (远程MySQL，默认no)
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
CYBERPANEL_VERSION="openlitespeed"  # openlitespeed 或 enterprise
ADMIN_PASSWORD=""
DEFAULT_PORT="8090"
FULL_SERVICE="yes"
REMOTE_MYSQL="no"
ACTION="install"
INSTALL_DIR="/usr/local/CyberCP"
CYBERPANEL_URL="https://cyberpanel.net/install.sh"

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

# 帮助信息
show_help() {
    echo "=================================================="
    echo -e "${PURPLE}Cyberpanel面板安装脚本${NC}"
    echo "=================================================="
    echo "使用方法: bash cyberpanel.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --version [type]      选择版本类型:"
    echo "                        openlitespeed - 免费版 (默认)"
    echo "                        enterprise - 企业版"
    echo "  --password [密码]     设置管理员密码"
    echo "  --port [端口]         设置面板端口 (默认: 8090)"
    echo "  --full-service [y/n]  安装全套服务 (默认: yes)"
    echo "                        包括PowerDNS, Postfix, Pure-FTPd"
    echo "  --remote-mysql [y/n]  使用远程MySQL (默认: no)"
    echo "  --uninstall          卸载Cyberpanel面板"
    echo "  --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  bash cyberpanel.sh                          # 默认安装"
    echo "  bash cyberpanel.sh --version enterprise     # 安装企业版"
    echo "  bash cyberpanel.sh --password MyPass123    # 设置密码"
    echo "  bash cyberpanel.sh --uninstall             # 卸载面板"
    echo "=================================================="
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                if [[ "$2" == "openlitespeed" || "$2" == "enterprise" ]]; then
                    CYBERPANEL_VERSION="$2"
                else
                    log_error "无效的版本类型: $2"
                    log_error "请使用 'openlitespeed' 或 'enterprise'"
                    exit 1
                fi
                shift 2
                ;;
            --password)
                ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --port)
                DEFAULT_PORT="$2"
                shift 2
                ;;
            --full-service)
                if [[ "$2" =~ ^(yes|y|no|n)$ ]]; then
                    FULL_SERVICE="$2"
                else
                    log_error "无效的参数: $2 (使用 yes 或 no)"
                    exit 1
                fi
                shift 2
                ;;
            --remote-mysql)
                if [[ "$2" =~ ^(yes|y|no|n)$ ]]; then
                    REMOTE_MYSQL="$2"
                else
                    log_error "无效的参数: $2 (使用 yes 或 no)"
                    exit 1
                fi
                shift 2
                ;;
            --uninstall)
                ACTION="uninstall"
                shift
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
    done
}

# 检查系统要求
check_system() {
    log_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        exit 1
    fi
    
    # 检查系统版本
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测系统版本"
        exit 1
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
                PKG_MANAGER="yum"
            fi
            ;;
        "CloudLinux")
            SUPPORTED_OS=true
            PKG_MANAGER="yum"
            ;;
    esac
    
    if [[ "$SUPPORTED_OS" == false ]]; then
        log_error "不支持的操作系统: $OS $VER"
        log_error "支持的系统: Ubuntu 18.04/20.04/22.04, CentOS 7/8, AlmaLinux 8/9, CloudLinux 7/8"
        exit 1
    fi
    
    log_info "系统检查通过: $OS $VER"
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 1024 ]]; then
        log_error "内存不足！需要至少1024MB内存，当前: ${TOTAL_MEM}MB"
        exit 1
    fi
    
    # 检查磁盘空间
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $FREE_SPACE -lt 10 ]]; then
        log_error "磁盘空间不足！需要至少10GB可用空间，当前: ${FREE_SPACE}GB"
        exit 1
    fi
    
    # 检查网络连接
    log_info "检查网络连接..."
    if ! curl -s --head https://cyberpanel.net >/dev/null; then
        log_error "无法连接到Cyberpanel官网，请检查网络设置"
        exit 1
    fi
    
    # 检查端口占用
    if ss -tlnp | grep -q ":$DEFAULT_PORT "; then
        log_warning "端口 $DEFAULT_PORT 已被占用"
        read -p "是否继续安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检查现有安装
check_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]] || command -v cyberpanel &> /dev/null; then
        log_warning "检测到已安装的Cyberpanel"
        read -p "是否要重新安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# 生成密码
generate_password() {
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        log_info "生成随机密码..."
        ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
        log_info "生成的密码为: $ADMIN_PASSWORD"
    fi
}

# 创建自动安装响应文件
create_install_responses() {
    local RESPONSE_FILE="/tmp/cyberpanel_responses.txt"
    
    log_info "创建自动安装配置..."
    
    # 清空响应文件
    > "$RESPONSE_FILE"
    
    # 写入安装响应
    echo "1" >> "$RESPONSE_FILE"  # 确认安装
    
    # 选择版本
    if [[ "$CYBERPANEL_VERSION" == "openlitespeed" ]]; then
        echo "1" >> "$RESPONSE_FILE"  # OpenLiteSpeed
    else
        echo "2" >> "$RESPONSE_FILE"  # Enterprise
        # 如果是企业版，可能需要输入许可证
        log_warning "请确保您有有效的LiteSpeed Enterprise许可证"
    fi
    
    # Full service选项
    if [[ "$FULL_SERVICE" =~ ^(yes|y)$ ]]; then
        echo "Y" >> "$RESPONSE_FILE"
    else
        echo "N" >> "$RESPONSE_FILE"
    fi
    
    # Remote MySQL选项
    if [[ "$REMOTE_MYSQL" =~ ^(yes|y)$ ]]; then
        echo "Y" >> "$RESPONSE_FILE"
    else
        echo "N" >> "$RESPONSE_FILE"
    fi
    
    # 版本选择（默认最新版）
    echo "" >> "$RESPONSE_FILE"
    
    # 密码设置
    echo "s" >> "$RESPONSE_FILE"  # 选择设置密码
    echo "$ADMIN_PASSWORD" >> "$RESPONSE_FILE"
    echo "$ADMIN_PASSWORD" >> "$RESPONSE_FILE"  # 确认密码
    
    # 设置RAM Swap (默认)
    echo "Y" >> "$RESPONSE_FILE"
    
    # Memcached选项
    echo "Y" >> "$RESPONSE_FILE"
    
    # Redis选项
    echo "Y" >> "$RESPONSE_FILE"
    
    # Watchdog选项
    echo "Y" >> "$RESPONSE_FILE"
}

# 执行安装
install_cyberpanel() {
    log_info "开始安装Cyberpanel面板..."
    
    # 创建响应文件
    create_install_responses
    
    # 下载并执行安装脚本
    log_info "下载Cyberpanel安装脚本..."
    cd /tmp
    
    if [[ -f "/tmp/cyberpanel_responses.txt" ]]; then
        # 使用自动响应文件执行安装
        curl -s "$CYBERPANEL_URL" | sh -s -- < /tmp/cyberpanel_responses.txt
    else
        log_error "响应文件创建失败"
        exit 1
    fi
    
    # 检查安装结果
    if [[ $? -eq 0 ]] && [[ -d "$INSTALL_DIR" ]]; then
        log_success "Cyberpanel安装完成！"
        
        # 如果需要修改端口
        if [[ "$DEFAULT_PORT" != "8090" ]]; then
            modify_port
        fi
    else
        log_error "Cyberpanel安装失败"
        exit 1
    fi
    
    # 清理临时文件
    rm -f /tmp/cyberpanel_responses.txt
}

# 修改端口
modify_port() {
    log_info "修改面板端口为: $DEFAULT_PORT"
    
    # 修改配置文件
    if [[ -f "/usr/local/lsws/conf/httpd_config.conf" ]]; then
        sed -i "s/:8090/:$DEFAULT_PORT/g" /usr/local/lsws/conf/httpd_config.conf
    fi
    
    # 重启服务
    systemctl restart lscpd 2>/dev/null || service lscpd restart 2>/dev/null
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 需要开放的端口
    PORTS=("$DEFAULT_PORT" "80" "443" "21" "25" "587" "465" "110" "143" "993" "53" "8090")
    
    # 检查并配置firewalld
    if command -v firewall-cmd &> /dev/null && systemctl is-active firewalld &>/dev/null; then
        for port in "${PORTS[@]}"; do
            firewall-cmd --permanent --add-port=$port/tcp &>/dev/null
        done
        firewall-cmd --permanent --add-port=53/udp &>/dev/null
        firewall-cmd --reload
        log_info "firewalld防火墙规则已配置"
    fi
    
    # 检查并配置ufw
    if command -v ufw &> /dev/null; then
        for port in "${PORTS[@]}"; do
            ufw allow $port/tcp &>/dev/null
        done
        ufw allow 53/udp &>/dev/null
        log_info "ufw防火墙规则已配置"
    fi
    
    # 检查并配置iptables
    if command -v iptables &> /dev/null && ! command -v firewall-cmd &> /dev/null; then
        for port in "${PORTS[@]}"; do
            iptables -I INPUT -p tcp --dport $port -j ACCEPT &>/dev/null
        done
        iptables -I INPUT -p udp --dport 53 -j ACCEPT &>/dev/null
        
        # 保存规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
            iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
        log_info "iptables防火墙规则已配置"
    fi
}

# 显示安装信息
show_install_info() {
    local SERVER_IP=$(curl -s ip.sb 2>/dev/null || curl -s ifconfig.me 2>/dev/null)
    
    echo ""
    echo "=================================================="
    echo -e "${GREEN}Cyberpanel面板安装成功！${NC}"
    echo "=================================================="
    echo -e "${CYAN}面板信息：${NC}"
    echo "访问地址: https://$SERVER_IP:$DEFAULT_PORT"
    echo "用户名: admin"
    echo "密码: $ADMIN_PASSWORD"
    echo ""
    echo -e "${CYAN}版本信息：${NC}"
    if [[ "$CYBERPANEL_VERSION" == "openlitespeed" ]]; then
        echo "Web服务器: OpenLiteSpeed (免费版)"
    else
        echo "Web服务器: LiteSpeed Enterprise (企业版)"
    fi
    echo ""
    if [[ "$FULL_SERVICE" =~ ^(yes|y)$ ]]; then
        echo -e "${CYAN}已安装服务：${NC}"
        echo "- PowerDNS (DNS服务器)"
        echo "- Postfix (邮件服务器)"
        echo "- Pure-FTPd (FTP服务器)"
    fi
    echo ""
    echo -e "${CYAN}常用命令：${NC}"
    echo "  systemctl status lscpd    - 查看面板状态"
    echo "  systemctl restart lscpd   - 重启面板"
    echo "  cyberpanel help          - 查看帮助"
    echo ""
    echo -e "${YELLOW}重要提示：${NC}"
    echo "1. 请立即登录面板修改默认设置"
    echo "2. 建议配置SSL证书以确保安全"
    echo "3. 定期更新系统和面板版本"
    echo "=================================================="
    
    # 保存安装信息
    save_install_info "$SERVER_IP"
}

# 保存安装信息
save_install_info() {
    local INFO_FILE="/root/cyberpanel_info.txt"
    local SERVER_IP=$1
    
    cat > "$INFO_FILE" << EOF
Cyberpanel Installation Information
===================================
Installation Date: $(date)
Panel URL: https://$SERVER_IP:$DEFAULT_PORT
Username: admin
Password: $ADMIN_PASSWORD
Version: $CYBERPANEL_VERSION
Full Service: $FULL_SERVICE
Remote MySQL: $REMOTE_MYSQL
===================================
EOF
    
    chmod 600 "$INFO_FILE"
    log_info "安装信息已保存到: $INFO_FILE"
}

# 卸载Cyberpanel
uninstall_cyberpanel() {
    log_warning "准备卸载Cyberpanel面板..."
    echo -e "${RED}警告：此操作将删除所有网站数据、数据库和邮件！${NC}"
    read -p "确定要卸载Cyberpanel面板吗？(yes/no): " -r
    
    if [[ ! "$REPLY" == "yes" ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "开始卸载Cyberpanel面板..."
    
    # 停止所有服务
    systemctl stop lscpd 2>/dev/null
    systemctl stop lsws 2>/dev/null
    systemctl stop mysql 2>/dev/null
    systemctl stop mariadb 2>/dev/null
    systemctl stop postfix 2>/dev/null
    systemctl stop pure-ftpd 2>/dev/null
    systemctl stop pdns 2>/dev/null
    
    # 禁用服务
    systemctl disable lscpd 2>/dev/null
    systemctl disable lsws 2>/dev/null
    systemctl disable pure-ftpd 2>/dev/null
    systemctl disable pdns 2>/dev/null
    
    # 删除文件和目录
    rm -rf /usr/local/CyberCP
    rm -rf /usr/local/lsws
    rm -rf /home/cyberpanel
    rm -rf /etc/cyberpanel
    rm -rf /var/log/cyberpanel
    rm -f /usr/local/bin/cyberpanel
    rm -f /etc/systemd/system/lscpd.service
    
    # 删除数据库
    if command -v mysql &> /dev/null; then
        mysql -e "DROP DATABASE IF EXISTS cyberpanel;" 2>/dev/null
        mysql -e "DROP DATABASE IF EXISTS rainloop;" 2>/dev/null
    fi
    
    # 删除用户
    userdel -r cyberpanel 2>/dev/null
    userdel -r lscpd 2>/dev/null
    
    # 清理cron任务
    crontab -u root -l | grep -v cyberpanel | crontab -u root -
    
    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "Cyberpanel面板已完全卸载"
}

# 主函数
main() {
    # 显示脚本标题
    echo "=================================================="
    echo -e "${PURPLE}Cyberpanel面板安装脚本${NC}"
    echo "作者: Jensfrank"
    echo "版本: 1.0"
    echo "=================================================="
    
    # 解析参数
    parse_arguments "$@"
    
    # 根据操作执行
    if [[ "$ACTION" == "uninstall" ]]; then
        uninstall_cyberpanel
    else
        # 执行安装流程
        check_system
        check_existing_installation
        generate_password
        install_cyberpanel
        configure_firewall
        show_install_info
    fi
}

# 捕获错误
set -euo pipefail
trap 'log_error "脚本执行出错，错误代码: $?"' ERR

# 执行主函数
main "$@"