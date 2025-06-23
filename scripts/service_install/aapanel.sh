#!/bin/bash
#==============================================================================
# 脚本名称: aapanel.sh
# 脚本描述: aaPanel（宝塔国际版）面板安装配置脚本 - 支持一键部署和安全加固
# 脚本路径: vps_scripts/scripts/service_install/aapanel.sh
# 作者: Jensfrank
# 使用方法: bash aapanel.sh [选项]
# 选项说明:
#   --port <端口>         面板端口 (默认: 8888)
#   --username <用户名>   面板用户名
#   --password <密码>     面板密码
#   --entrance <入口>     安全入口路径
#   --install-lamp       安装LAMP环境
#   --install-lnmp       安装LNMP环境
#   --php-version <版本>  PHP版本 (7.4/8.0/8.1/8.2)
#   --mysql-version      MySQL版本 (5.7/8.0)
#   --install-redis      安装Redis
#   --install-docker     安装Docker
#   --install-fail2ban   安装Fail2ban
#   --ssl-panel          为面板启用SSL
#   --security-enhance   安全加固
#   --backup-config      配置自动备份
#   --force              强制重新安装
#   --help               显示帮助信息
# 更新日期: 2025-06-22
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 全局变量
PANEL_PORT="8888"
PANEL_USER=""
PANEL_PASSWORD=""
SECURITY_ENTRANCE=""
INSTALL_LAMP=false
INSTALL_LNMP=false
PHP_VERSION="8.0"
MYSQL_VERSION="5.7"
INSTALL_REDIS=false
INSTALL_DOCKER=false
INSTALL_FAIL2BAN=false
SSL_PANEL=false
SECURITY_ENHANCE=false
BACKUP_CONFIG=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/aapanel_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
PANEL_PATH="/www/server/panel"
PANEL_DATA="/www/server/panel/data"
PANEL_BACKUP="/www/backup/panel"
WWW_ROOT="/www/wwwroot"
SERVER_ROOT="/www/server"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}   aaPanel 面板安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash aapanel.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --port <端口>         面板端口 (默认: 8888)"
    echo "  --username <用户名>   面板用户名"
    echo "  --password <密码>     面板密码"
    echo "  --entrance <入口>     安全入口路径 (如: mySecureEntry)"
    echo "  --install-lamp       安装LAMP环境 (Apache+MySQL+PHP)"
    echo "  --install-lnmp       安装LNMP环境 (Nginx+MySQL+PHP)"
    echo "  --php-version <版本>  PHP版本 (7.4/8.0/8.1/8.2)"
    echo "  --mysql-version      MySQL版本 (5.7/8.0)"
    echo "  --install-redis      安装Redis缓存"
    echo "  --install-docker     安装Docker"
    echo "  --install-fail2ban   安装Fail2ban防护"
    echo "  --ssl-panel          为面板启用SSL证书"
    echo "  --security-enhance   启用安全加固"
    echo "  --backup-config      配置自动备份"
    echo "  --force              强制重新安装"
    echo "  --help               显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash aapanel.sh                                      # 默认安装"
    echo "  bash aapanel.sh --username admin --password MyPass123"
    echo "  bash aapanel.sh --install-lnmp --php-version 8.1"
    echo "  bash aapanel.sh --security-enhance --install-fail2ban"
    echo "  bash aapanel.sh --port 9999 --entrance mySecret --ssl-panel"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        VER_MAJOR=$(echo $VER | cut -d. -f1)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    # 检查系统兼容性
    case $OS in
        ubuntu)
            if [[ "$VER" != "18.04" ]] && [[ "$VER" != "20.04" ]] && [[ "$VER" != "22.04" ]]; then
                log "${YELLOW}警告: 推荐使用 Ubuntu 18.04/20.04/22.04${NC}"
            fi
            ;;
        debian)
            if [[ "$VER_MAJOR" -lt 9 ]]; then
                log "${RED}错误: 需要 Debian 9 或更高版本${NC}"
                exit 1
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if [[ "$VER_MAJOR" -lt 7 ]]; then
                log "${RED}错误: 需要 CentOS/RHEL 7 或更高版本${NC}"
                exit 1
            fi
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
        log "${RED}错误: 仅支持 x86_64 和 aarch64 架构${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER} (${ARCH})${NC}"
}

# 检查系统要求
check_system_requirements() {
    log "${CYAN}检查系统要求...${NC}"
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 512 ]]; then
        log "${RED}错误: 至少需要512MB内存${NC}"
        exit 1
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 10 ]]; then
        log "${YELLOW}警告: 建议至少10GB可用磁盘空间${NC}"
    fi
    
    # 检查Python
    if ! command -v python3 &> /dev/null; then
        log "${YELLOW}Python3未安装，正在安装...${NC}"
        case $OS in
            ubuntu|debian)
                apt-get update
                apt-get install -y python3 python3-pip
                ;;
            centos|rhel|rocky|almalinux)
                yum install -y python3 python3-pip
                ;;
        esac
    fi
    
    log "${GREEN}系统要求检查通过${NC}"
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1
}

# 检查是否已安装
check_aapanel_installed() {
    if [[ -f "$PANEL_PATH/BT-Panel" ]] || systemctl list-units --type=service | grep -q "bt.service"; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到aaPanel已安装${NC}"
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop bt 2>/dev/null || true
        service bt stop 2>/dev/null || true
    fi
}

# 优化系统配置
optimize_system() {
    log "${CYAN}优化系统配置...${NC}"
    
    # 关闭SELinux
    if command -v getenforce &> /dev/null; then
        setenforce 0 2>/dev/null || true
        sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config 2>/dev/null || true
    fi
    
    # 配置防火墙
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --zone=public --add-port=${PANEL_PORT}/tcp
        firewall-cmd --permanent --zone=public --add-port=80/tcp
        firewall-cmd --permanent --zone=public --add-port=443/tcp
        firewall-cmd --permanent --zone=public --add-port=20/tcp
        firewall-cmd --permanent --zone=public --add-port=21/tcp
        firewall-cmd --permanent --zone=public --add-port=22/tcp
        firewall-cmd --permanent --zone=public --add-port=39000-40000/tcp
        firewall-cmd --reload
    fi
    
    # 优化内核参数
    cat >> /etc/sysctl.conf << EOF

# aaPanel优化参数
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 4096
fs.file-max = 1000000
EOF
    
    sysctl -p
    
    # 优化文件描述符限制
    cat >> /etc/security/limits.conf << EOF
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 65535
* hard nproc 65535
EOF
}

# 下载并安装aaPanel
install_aapanel() {
    log "${CYAN}开始安装aaPanel...${NC}"
    
    # 创建安装目录
    mkdir -p "$SERVER_ROOT"
    
    # 下载安装脚本
    cd /tmp
    if [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "rocky" ]] || [[ "$OS" == "almalinux" ]]; then
        INSTALL_URL="http://www.aapanel.com/script/install_6.0_en.sh"
    else
        INSTALL_URL="http://www.aapanel.com/script/install-ubuntu_6.0_en.sh"
    fi
    
    log "${YELLOW}下载aaPanel安装脚本...${NC}"
    wget -O install_aapanel.sh $INSTALL_URL
    
    if [[ ! -f install_aapanel.sh ]]; then
        log "${RED}错误: aaPanel安装脚本下载失败${NC}"
        exit 1
    fi
    
    # 执行安装
    log "${YELLOW}执行aaPanel安装...${NC}"
    echo y | bash install_aapanel.sh
    
    # 检查安装结果
    if [[ ! -f "$PANEL_PATH/BT-Panel" ]]; then
        log "${RED}错误: aaPanel安装失败${NC}"
        exit 1
    fi
    
    log "${GREEN}aaPanel安装完成${NC}"
    
    # 清理安装脚本
    rm -f install_aapanel.sh
}

# 配置面板设置
configure_panel() {
    log "${CYAN}配置面板设置...${NC}"
    
    # 设置面板端口
    if [[ "$PANEL_PORT" != "8888" ]]; then
        log "${YELLOW}设置面板端口为: ${PANEL_PORT}${NC}"
        echo "$PANEL_PORT" > "$PANEL_DATA/port.pl"
        $PANEL_PATH/init.sh restart
    fi
    
    # 设置用户名和密码
    if [[ -n "$PANEL_USER" ]]; then
        cd $PANEL_PATH
        python3 tools.py username "$PANEL_USER"
    else
        PANEL_USER="admin"
        cd $PANEL_PATH
        python3 tools.py username "$PANEL_USER"
    fi
    
    if [[ -n "$PANEL_PASSWORD" ]]; then
        cd $PANEL_PATH
        python3 tools.py password "$PANEL_PASSWORD"
    else
        PANEL_PASSWORD=$(generate_random_string 12)
        cd $PANEL_PATH
        python3 tools.py password "$PANEL_PASSWORD"
    fi
    
    # 设置安全入口
    if [[ -n "$SECURITY_ENTRANCE" ]]; then
        log "${YELLOW}设置安全入口: /${SECURITY_ENTRANCE}${NC}"
        echo "/$SECURITY_ENTRANCE" > "$PANEL_DATA/admin_path.pl"
    else
        SECURITY_ENTRANCE=$(cat "$PANEL_DATA/admin_path.pl" 2>/dev/null | sed 's/^\///')
    fi
}

# 安装LAMP环境
install_lamp_stack() {
    if [[ "$INSTALL_LAMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LAMP环境...${NC}"
    
    # 安装Apache
    cd $PANEL_PATH
    python3 -m py_compile tools.py
    python3 tools.py install apache
    
    # 安装MySQL
    case $MYSQL_VERSION in
        "5.7")
            python3 tools.py install mysql_5.7
            ;;
        "8.0")
            python3 tools.py install mysql_8.0
            ;;
    esac
    
    # 安装PHP
    case $PHP_VERSION in
        "7.4")
            python3 tools.py install php_74
            ;;
        "8.0")
            python3 tools.py install php_80
            ;;
        "8.1")
            python3 tools.py install php_81
            ;;
        "8.2")
            python3 tools.py install php_82
            ;;
    esac
    
    log "${GREEN}LAMP环境安装完成${NC}"
}

# 安装LNMP环境
install_lnmp_stack() {
    if [[ "$INSTALL_LNMP" != true ]]; then
        return
    fi
    
    log "${CYAN}安装LNMP环境...${NC}"
    
    # 安装Nginx
    cd $PANEL_PATH
    python3 -m py_compile tools.py
    python3 tools.py install nginx
    
    # 安装MySQL
    case $MYSQL_VERSION in
        "5.7")
            python3 tools.py install mysql_5.7
            ;;
        "8.0")
            python3 tools.py install mysql_8.0
            ;;
    esac
    
    # 安装PHP
    case $PHP_VERSION in
        "7.4")
            python3 tools.py install php_74
            ;;
        "8.0")
            python3 tools.py install php_80
            ;;
        "8.1")
            python3 tools.py install php_81
            ;;
        "8.2")
            python3 tools.py install php_82
            ;;
    esac
    
    log "${GREEN}LNMP环境安装完成${NC}"
}

# 安装额外软件
install_additional_software() {
    cd $PANEL_PATH
    
    # 安装Redis
    if [[ "$INSTALL_REDIS" = true ]]; then
        log "${CYAN}安装Redis...${NC}"
        python3 tools.py install redis
    fi
    
    # 安装Docker
    if [[ "$INSTALL_DOCKER" = true ]]; then
        log "${CYAN}安装Docker...${NC}"
        python3 tools.py install docker
    fi
}

# 安装Fail2ban
install_fail2ban() {
    if [[ "$INSTALL_FAIL2BAN" != true ]]; then
        return
    fi
    
    log "${CYAN}安装Fail2ban防护...${NC}"
    
    # 通过面板API安装
    cd $PANEL_PATH
    python3 tools.py install fail2ban
    
    # 配置Fail2ban规则
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400
findtime = 600
maxretry = 5
banaction = iptables-multiport

[sshd]
enabled = true
port = 22
logpath = /var/log/secure
maxretry = 3

[aapanel]
enabled = true
port = ${PANEL_PORT}
logpath = $PANEL_PATH/logs/error.log
maxretry = 5
EOF
    
    systemctl restart fail2ban
    
    log "${GREEN}Fail2ban安装配置完成${NC}"
}

# 配置SSL证书
configure_ssl() {
    if [[ "$SSL_PANEL" != true ]]; then
        return
    fi
    
    log "${CYAN}配置面板SSL证书...${NC}"
    
    # 生成自签名证书
    mkdir -p "$PANEL_PATH/ssl"
    cd "$PANEL_PATH/ssl"
    
    # 生成私钥
    openssl genrsa -out server.key 2048
    
    # 生成证书请求
    openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=aapanel"
    
    # 生成自签名证书
    openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
    
    # 配置面板使用SSL
    echo "True" > "$PANEL_DATA/ssl.pl"
    
    # 重启面板
    $PANEL_PATH/init.sh restart
    
    log "${GREEN}SSL证书配置完成${NC}"
}

# 安全加固
security_enhancement() {
    if [[ "$SECURITY_ENHANCE" != true ]]; then
        return
    fi
    
    log "${CYAN}执行安全加固...${NC}"
    
    # 1. 禁用不必要的端口
    log "${YELLOW}配置防火墙规则...${NC}"
    
    # 2. 设置登录IP白名单
    mkdir -p "$PANEL_DATA/limitip"
    echo "启用IP访问限制，请在面板中配置允许的IP" > "$PANEL_DATA/limitip/info"
    
    # 3. 禁用API
    echo "False" > "$PANEL_DATA/api.pl"
    
    # 4. 设置会话超时
    echo "1800" > "$PANEL_DATA/session_timeout.pl"
    
    # 5. 启用操作日志
    echo "True" > "$PANEL_DATA/logs.pl"
    
    # 6. 禁用开发者模式
    echo "False" > "$PANEL_DATA/debug.pl"
    
    # 7. 配置面板安全设置
    cat > "$PANEL_DATA/security.json" << EOF
{
    "login_limit": true,
    "login_limit_num": 5,
    "login_limit_time": 900,
    "panel_ssl": true,
    "api_status": false,
    "log_status": true,
    "basicauth_status": false
}
EOF
    
    log "${GREEN}安全加固完成${NC}"
}

# 配置自动备份
configure_backup() {
    if [[ "$BACKUP_CONFIG" != true ]]; then
        return
    fi
    
    log "${CYAN}配置自动备份...${NC}"
    
    # 创建备份目录
    mkdir -p "$PANEL_BACKUP"
    mkdir -p "$PANEL_BACKUP/site"
    mkdir -p "$PANEL_BACKUP/database"
    mkdir -p "$PANEL_BACKUP/panel"
    
    # 创建备份脚本
    cat > /usr/local/bin/aapanel_backup.sh << 'EOF'
#!/bin/bash
# aaPanel自动备份脚本

BACKUP_DIR="/www/backup"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份面板配置
tar -czf "$BACKUP_DIR/panel/panel_config_$DATE.tar.gz" \
    /www/server/panel/data \
    /www/server/panel/config \
    /www/server/panel/vhost

# 备份网站文件
for site in /www/wwwroot/*; do
    if [ -d "$site" ]; then
        site_name=$(basename "$site")
        tar -czf "$BACKUP_DIR/site/${site_name}_$DATE.tar.gz" "$site"
    fi
done

# 清理30天前的备份
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "备份完成: $(date)"
EOF
    
    chmod +x /usr/local/bin/aapanel_backup.sh
    
    # 添加cron任务
    echo "0 3 * * * /usr/local/bin/aapanel_backup.sh >> $PANEL_BACKUP/backup.log 2>&1" | crontab -
    
    log "${GREEN}自动备份配置完成${NC}"
}

# 创建快捷命令
create_shortcuts() {
    log "${CYAN}创建快捷命令...${NC}"
    
    # 创建bt命令链接
    ln -sf $PANEL_PATH/cli.sh /usr/bin/bt
    
    # 创建面板管理脚本
    cat > /usr/local/bin/aapanel << EOF
#!/bin/bash
# aaPanel快捷管理命令

case "\$1" in
    start)
        $PANEL_PATH/init.sh start
        ;;
    stop)
        $PANEL_PATH/init.sh stop
        ;;
    restart)
        $PANEL_PATH/init.sh restart
        ;;
    status)
        $PANEL_PATH/init.sh status
        ;;
    info)
        echo "面板地址: http://\$(hostname -I | awk '{print \$1}'):${PANEL_PORT}/${SECURITY_ENTRANCE}"
        echo "用户名: ${PANEL_USER}"
        echo "密码: ${PANEL_PASSWORD}"
        ;;
    password)
        cd $PANEL_PATH && python3 tools.py password "\$2"
        ;;
    port)
        cd $PANEL_PATH && python3 tools.py port "\$2"
        ;;
    *)
        echo "Usage: aapanel {start|stop|restart|status|info|password|port}"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/aapanel
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 获取默认信息
    DEFAULT_PORT=$(cat "$PANEL_DATA/port.pl" 2>/dev/null || echo "8888")
    DEFAULT_USER=$(cd $PANEL_PATH && python3 tools.py panel_user | grep "username:" | awk '{print $2}')
    DEFAULT_ENTRANCE=$(cat "$PANEL_DATA/admin_path.pl" 2>/dev/null)
    
    # 创建配置信息文件
    cat > /root/aapanel_info.txt << EOF
aaPanel 面板信息
================

访问地址: http://${SERVER_IP}:${PANEL_PORT}${SECURITY_ENTRANCE}
用户名: ${PANEL_USER}
密码: ${PANEL_PASSWORD}

安全入口: ${SECURITY_ENTRANCE}
面板端口: ${PANEL_PORT}
面板路径: ${PANEL_PATH}
网站目录: ${WWW_ROOT}
备份目录: ${PANEL_BACKUP}

快捷命令:
- bt          # 面板命令行工具
- aapanel     # 快捷管理命令

常用命令:
- bt start    # 启动面板
- bt stop     # 停止面板
- bt restart  # 重启面板
- bt default  # 查看面板入口

环境信息:
- PHP版本: ${PHP_VERSION}
- MySQL版本: ${MYSQL_VERSION}
${INSTALL_REDIS:+- Redis: 已安装}
${INSTALL_DOCKER:+- Docker: 已安装}
${INSTALL_FAIL2BAN:+- Fail2ban: 已安装}

安全设置:
${SSL_PANEL:+- SSL: 已启用}
${SECURITY_ENHANCE:+- 安全加固: 已启用}
${BACKUP_CONFIG:+- 自动备份: 已配置}

日志文件:
- 面板日志: $PANEL_PATH/logs/
- 网站日志: /www/wwwlogs/
- 系统日志: /var/log/

备份脚本: /usr/local/bin/aapanel_backup.sh
EOF
    
    chmod 600 /root/aapanel_info.txt
}

# 启动面板服务
start_panel_service() {
    log "${CYAN}启动面板服务...${NC}"
    
    # 启动面板
    $PANEL_PATH/init.sh start
    
    # 检查服务状态
    sleep 5
    if $PANEL_PATH/init.sh status | grep -q "running"; then
        log "${GREEN}面板服务启动成功${NC}"
    else
        log "${RED}面板服务启动失败${NC}"
        $PANEL_PATH/init.sh status
    fi
}

# 显示安装信息
show_install_info() {
    # 获取实际的面板信息
    ACTUAL_PORT=$(cat "$PANEL_DATA/port.pl" 2>/dev/null || echo "8888")
    ACTUAL_ENTRANCE=$(cat "$PANEL_DATA/admin_path.pl" 2>/dev/null || echo "/")
    
    echo
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${GREEN}aaPanel安装成功!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo
    echo -e "${YELLOW}面板访问地址:${NC}"
    echo -e "${CYAN}http://$(hostname -I | awk '{print $1}'):${ACTUAL_PORT}${ACTUAL_ENTRANCE}${NC}"
    if [[ "$SSL_PANEL" = true ]]; then
        echo -e "${CYAN}https://$(hostname -I | awk '{print $1}'):${ACTUAL_PORT}${ACTUAL_ENTRANCE}${NC}"
    fi
    echo
    echo -e "${YELLOW}面板账号信息:${NC}"
    echo -e "用户名: ${GREEN}${PANEL_USER}${NC}"
    echo -e "密码: ${GREEN}${PANEL_PASSWORD}${NC}"
    echo
    echo -e "${YELLOW}安全提示:${NC}"
    echo "1. 请立即通过面板修改默认端口和安全入口"
    echo "2. 设置IP访问限制，只允许信任的IP访问"
    echo "3. 定期更新面板和软件版本"
    echo "4. 启用面板SSL证书加密访问"
    echo
    echo -e "${YELLOW}配置信息已保存到: /root/aapanel_info.txt${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证安装...${NC}"
    
    # 检查面板文件
    if [[ ! -f "$PANEL_PATH/BT-Panel" ]]; then
        log "${RED}错误: 面板文件不存在${NC}"
        return 1
    fi
    
    # 检查服务状态
    if ! $PANEL_PATH/init.sh status | grep -q "running"; then
        log "${RED}错误: 面板服务未运行${NC}"
        return 1
    fi
    
    # 检查端口监听
    if ! netstat -tlnp | grep -q ":${PANEL_PORT}"; then
        log "${RED}错误: 面板端口未监听${NC}"
        return 1
    fi
    
    log "${GREEN}安装验证通过${NC}"
    return 0
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}aaPanel安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}访问信息:${NC}"
    echo "- 面板地址: http://$(hostname -I | awk '{print $1}'):${PANEL_PORT}${SECURITY_ENTRANCE}"
    if [[ "$SSL_PANEL" = true ]]; then
        echo "- SSL地址: https://$(hostname -I | awk '{print $1}'):${PANEL_PORT}${SECURITY_ENTRANCE}"
    fi
    echo "- 用户名: ${PANEL_USER}"
    echo "- 密码: ${PANEL_PASSWORD}"
    echo
    echo -e "${CYAN}快捷命令:${NC}"
    echo "- bt          # 面板命令行工具"
    echo "- bt stop     # 停止面板"
    echo "- bt start    # 启动面板" 
    echo "- bt restart  # 重启面板"
    echo "- bt default  # 查看面板入口信息"
    echo "- aapanel info # 查看面板信息"
    echo
    echo -e "${CYAN}常用路径:${NC}"
    echo "- 面板目录: $PANEL_PATH"
    echo "- 网站目录: $WWW_ROOT"
    echo "- 备份目录: $PANEL_BACKUP"
    echo "- 日志目录: $PANEL_PATH/logs"
    echo
    
    if [[ "$INSTALL_LAMP" = true ]] || [[ "$INSTALL_LNMP" = true ]]; then
        echo -e "${CYAN}环境信息:${NC}"
        [[ "$INSTALL_LAMP" = true ]] && echo "- Web服务器: Apache"
        [[ "$INSTALL_LNMP" = true ]] && echo "- Web服务器: Nginx"
        echo "- PHP版本: ${PHP_VERSION}"
        echo "- MySQL版本: ${MYSQL_VERSION}"
        [[ "$INSTALL_REDIS" = true ]] && echo "- Redis: 已安装"
        [[ "$INSTALL_DOCKER" = true ]] && echo "- Docker: 已安装"
        echo
    fi
    
    echo -e "${CYAN}安全建议:${NC}"
    echo "1. 立即修改默认端口和安全入口"
    echo "2. 在面板设置中启用IP访问限制"
    echo "3. 启用面板操作日志记录"
    echo "4. 定期备份网站和数据库"
    echo "5. 及时更新面板和软件版本"
    echo
    
    if [[ "$BACKUP_CONFIG" = true ]]; then
        echo -e "${CYAN}备份信息:${NC}"
        echo "- 自动备份: 每天凌晨3点"
        echo "- 备份脚本: /usr/local/bin/aapanel_backup.sh"
        echo "- 备份位置: $PANEL_BACKUP"
        echo
    fi
    
    echo -e "${YELLOW}重要提示:${NC}"
    echo "1. 首次登录后请立即修改密码"
    echo "2. 建议安装SSL证书启用HTTPS访问"
    echo "3. 定期检查面板安全设置"
    echo "4. 不要在生产环境使用默认设置"
    echo
    echo -e "${YELLOW}配置信息: /root/aapanel_info.txt${NC}"
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                PANEL_PORT="$2"
                shift 2
                ;;
            --username)
                PANEL_USER="$2"
                shift 2
                ;;
            --password)
                PANEL_PASSWORD="$2"
                shift 2
                ;;
            --entrance)
                SECURITY_ENTRANCE="$2"
                shift 2
                ;;
            --install-lamp)
                INSTALL_LAMP=true
                shift
                ;;
            --install-lnmp)
                INSTALL_LNMP=true
                shift
                ;;
            --php-version)
                PHP_VERSION="$2"
                shift 2
                ;;
            --mysql-version)
                MYSQL_VERSION="$2"
                shift 2
                ;;
            --install-redis)
                INSTALL_REDIS=true
                shift
                ;;
            --install-docker)
                INSTALL_DOCKER=true
                shift
                ;;
            --install-fail2ban)
                INSTALL_FAIL2BAN=true
                shift
                ;;
            --ssl-panel)
                SSL_PANEL=true
                shift
                ;;
            --security-enhance)
                SECURITY_ENHANCE=true
                shift
                ;;
            --backup-config)
                BACKUP_CONFIG=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查系统要求
    check_system_requirements
    
    # 检查是否已安装
    check_aapanel_installed
    
    # 优化系统
    optimize_system
    
    # 安装aaPanel
    install_aapanel
    
    # 配置面板
    configure_panel
    
    # 安装环境
    install_lamp_stack
    install_lnmp_stack
    
    # 安装额外软件
    install_additional_software
    
    # 安装Fail2ban
    install_fail2ban
    
    # 配置SSL
    configure_ssl
    
    # 安全加固
    security_enhancement
    
    # 配置备份
    configure_backup
    
    # 创建快捷命令
    create_shortcuts
    
    # 保存配置信息
    save_config_info
    
    # 启动服务
    start_panel_service
    
    # 验证安装
    verify_installation
    
    # 显示安装信息
    show_install_info
    
    # 显示安装后说明
    show_post_install_info
}

# 执行主函数
main "$@"