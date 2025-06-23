#!/bin/bash
#==============================================================================
# 脚本名称: 1panel.sh
# 脚本描述: 1Panel 现代化Linux服务器运维管理面板安装脚本
# 脚本路径: vps_scripts/scripts/service_install/1panel.sh
# 作者: Jensfrank
# 使用方法: bash 1panel.sh [选项]
# 选项说明:
#   --port <端口>         面板端口 (默认: 10086)
#   --entrance <入口>     安全入口路径
#   --username <用户名>   管理员用户名
#   --password <密码>     管理员密码
#   --install-docker     安装Docker (如未安装)
#   --app-store <源>     应用商店源 (default/china)
#   --ssl-panel          为面板启用SSL
#   --install-apps       安装常用应用
#   --backup-path        备份路径 (默认: /opt/1panel/backup)
#   --data-path          数据路径 (默认: /opt/1panel/data)
#   --china-mirror       使用中国镜像源
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
PANEL_PORT="10086"
SECURITY_ENTRANCE=""
PANEL_USER=""
PANEL_PASSWORD=""
INSTALL_DOCKER=false
APP_STORE="default"
SSL_PANEL=false
INSTALL_APPS=false
BACKUP_PATH="/opt/1panel/backup"
DATA_PATH="/opt/1panel/data"
USE_CHINA_MIRROR=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/1panel_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
INSTALL_PATH="/opt/1panel"
CONFIG_FILE="/opt/1panel/conf/app.yaml"
DOCKER_COMPOSE_FILE="/opt/1panel/docker-compose.yml"
DEFAULT_APPS=("nginx" "mysql" "redis" "postgresql" "mongodb")

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    1Panel 面板安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash 1panel.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --port <端口>         面板端口 (默认: 10086)"
    echo "  --entrance <入口>     安全入口路径"
    echo "  --username <用户名>   管理员用户名"
    echo "  --password <密码>     管理员密码"
    echo "  --install-docker     安装Docker (如未安装)"
    echo "  --app-store <源>     应用商店源:"
    echo "                       default - 官方源"
    echo "                       china   - 中国镜像源"
    echo "  --ssl-panel          为面板启用SSL"
    echo "  --install-apps       安装常用应用"
    echo "  --backup-path        备份路径"
    echo "  --data-path          数据路径"
    echo "  --china-mirror       使用中国镜像源"
    echo "  --force              强制重新安装"
    echo "  --help               显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash 1panel.sh                                      # 默认安装"
    echo "  bash 1panel.sh --username admin --password MyPass"
    echo "  bash 1panel.sh --port 8888 --entrance mySecret"
    echo "  bash 1panel.sh --china-mirror --install-apps"
    echo "  bash 1panel.sh --ssl-panel --install-docker"
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
            if [[ "$VER" != "20.04" ]] && [[ "$VER" != "22.04" ]]; then
                log "${YELLOW}警告: 推荐使用 Ubuntu 20.04 或 22.04${NC}"
            fi
            ;;
        debian)
            if [[ "$VER_MAJOR" -lt 10 ]]; then
                log "${RED}错误: 需要 Debian 10 或更高版本${NC}"
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
            log "${YELLOW}警告: 未经测试的系统类型 ${OS}${NC}"
            ;;
    esac
    
    # 检查系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH_TYPE="amd64"
            ;;
        aarch64)
            ARCH_TYPE="arm64"
            ;;
        armv7l)
            ARCH_TYPE="armv7"
            ;;
        *)
            log "${RED}错误: 不支持的系统架构 ${ARCH}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}检测到系统: ${OS} ${VER} (${ARCH})${NC}"
}

# 检查系统要求
check_system_requirements() {
    log "${CYAN}检查系统要求...${NC}"
    
    # 检查CPU
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 1 ]]; then
        log "${RED}错误: CPU核心数不足${NC}"
        exit 1
    fi
    
    # 检查内存
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_MEM -lt 1024 ]]; then
        log "${YELLOW}警告: 建议至少1GB内存${NC}"
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 10 ]]; then
        log "${YELLOW}警告: 建议至少10GB可用磁盘空间${NC}"
    fi
    
    # 检查必要的命令
    for cmd in curl wget tar systemctl; do
        if ! command -v $cmd &> /dev/null; then
            log "${RED}错误: 缺少必要的命令 $cmd${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}系统要求检查通过${NC}"
}

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# 检查是否已安装
check_1panel_installed() {
    if [[ -d "$INSTALL_PATH" ]] || systemctl list-units --type=service | grep -q "1panel"; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到1Panel已安装${NC}"
            if [[ -f "$INSTALL_PATH/1panel" ]]; then
                $INSTALL_PATH/1panel version 2>/dev/null || true
            fi
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop 1panel 2>/dev/null || true
        
        # 备份现有数据
        if [[ -d "$DATA_PATH" ]]; then
            log "${YELLOW}备份现有数据...${NC}"
            mv "$DATA_PATH" "${DATA_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        fi
    fi
}

# 安装Docker
install_docker_if_needed() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        log "${GREEN}Docker已安装${NC}"
        docker --version
        docker-compose --version
        return
    fi
    
    if [[ "$INSTALL_DOCKER" != true ]]; then
        log "${RED}错误: Docker未安装，请使用 --install-docker 选项安装${NC}"
        exit 1
    fi
    
    log "${CYAN}安装Docker...${NC}"
    
    # 使用官方脚本安装Docker
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        export DOWNLOAD_URL="https://mirrors.aliyun.com/docker-ce"
    fi
    
    curl -fsSL https://get.docker.com | bash -s docker
    
    # 安装docker-compose
    log "${CYAN}安装docker-compose...${NC}"
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        curl -L "https://github.com.cnpmjs.org/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    else
        curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    fi
    chmod +x /usr/local/bin/docker-compose
    
    # 配置Docker
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    }
}
EOF
    fi
    
    # 启动Docker
    systemctl enable docker
    systemctl start docker
    
    log "${GREEN}Docker安装完成${NC}"
}

# 下载并安装1Panel
install_1panel() {
    log "${CYAN}开始安装1Panel...${NC}"
    
    # 创建安装目录
    mkdir -p "$INSTALL_PATH"
    cd "$INSTALL_PATH"
    
    # 获取最新版本
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        LATEST_VERSION=$(curl -s https://resource.fit2cloud.com/1panel/package/stable/latest)
        DOWNLOAD_URL="https://resource.fit2cloud.com/1panel/package/stable/${LATEST_VERSION}/1panel-${LATEST_VERSION}-linux-${ARCH_TYPE}.tar.gz"
    else
        LATEST_VERSION=$(curl -s https://api.github.com/repos/1Panel-dev/1Panel/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        DOWNLOAD_URL="https://github.com/1Panel-dev/1Panel/releases/download/${LATEST_VERSION}/1panel-${LATEST_VERSION}-linux-${ARCH_TYPE}.tar.gz"
    fi
    
    log "${YELLOW}下载1Panel ${LATEST_VERSION}...${NC}"
    wget -O 1panel.tar.gz "$DOWNLOAD_URL"
    
    if [[ ! -f 1panel.tar.gz ]]; then
        log "${RED}错误: 1Panel下载失败${NC}"
        exit 1
    fi
    
    # 解压安装包
    tar -xzf 1panel.tar.gz
    rm -f 1panel.tar.gz
    
    # 设置权限
    chmod +x 1panel
    
    log "${GREEN}1Panel下载完成${NC}"
}

# 初始化配置
initialize_config() {
    log "${CYAN}初始化配置...${NC}"
    
    # 生成默认配置
    mkdir -p "$(dirname $CONFIG_FILE)"
    mkdir -p "$DATA_PATH"
    mkdir -p "$BACKUP_PATH"
    
    # 生成随机密码（如果未指定）
    if [[ -z "$PANEL_PASSWORD" ]]; then
        PANEL_PASSWORD=$(generate_password)
        log "${YELLOW}生成的管理员密码: $PANEL_PASSWORD${NC}"
    fi
    
    # 生成安全入口
    if [[ -z "$SECURITY_ENTRANCE" ]]; then
        SECURITY_ENTRANCE=$(generate_password | tr '[:upper:]' '[:lower:]' | head -c 8)
        log "${YELLOW}生成的安全入口: $SECURITY_ENTRANCE${NC}"
    fi
    
    # 设置默认用户名
    if [[ -z "$PANEL_USER" ]]; then
        PANEL_USER="admin"
    fi
    
    # 初始化面板
    cd "$INSTALL_PATH"
    ./1panel init \
        --port "$PANEL_PORT" \
        --user "$PANEL_USER" \
        --password "$PANEL_PASSWORD" \
        --entrance "$SECURITY_ENTRANCE"
    
    # 配置应用商店源
    if [[ "$APP_STORE" == "china" ]] || [[ "$USE_CHINA_MIRROR" = true ]]; then
        log "${CYAN}配置中国应用商店源...${NC}"
        # 1Panel会自动处理应用商店配置
    fi
}

# 创建systemd服务
create_systemd_service() {
    log "${CYAN}创建systemd服务...${NC}"
    
    cat > /etc/systemd/system/1panel.service << EOF
[Unit]
Description=1Panel Linux Server Management Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_PATH
ExecStart=$INSTALL_PATH/1panel server
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable 1panel
}

# 配置防火墙
configure_firewall() {
    log "${CYAN}配置防火墙...${NC}"
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian防火墙
        ufw allow "$PANEL_PORT/tcp"
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 22/tcp
        log "${GREEN}UFW防火墙规则已添加${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL防火墙
        firewall-cmd --permanent --add-port="$PANEL_PORT/tcp"
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=22/tcp
        firewall-cmd --reload
        log "${GREEN}Firewalld防火墙规则已添加${NC}"
    else
        log "${YELLOW}未检测到防火墙，请手动配置${NC}"
    fi
}

# 配置SSL证书
configure_ssl() {
    if [[ "$SSL_PANEL" != true ]]; then
        return
    fi
    
    log "${CYAN}配置面板SSL证书...${NC}"
    
    # 生成自签名证书
    mkdir -p "$INSTALL_PATH/ssl"
    cd "$INSTALL_PATH/ssl"
    
    # 生成私钥
    openssl genrsa -out server.key 2048
    
    # 生成证书请求
    openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=1panel"
    
    # 生成自签名证书
    openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
    
    # 修改配置以启用SSL
    # 1Panel会自动处理SSL配置
    
    log "${GREEN}SSL证书配置完成${NC}"
}

# 安装常用应用
install_common_apps() {
    if [[ "$INSTALL_APPS" != true ]]; then
        return
    fi
    
    log "${CYAN}安装常用应用...${NC}"
    
    # 等待面板启动
    sleep 10
    
    # 通过1Panel CLI安装应用
    for app in "${DEFAULT_APPS[@]}"; do
        log "${YELLOW}安装应用: $app${NC}"
        cd "$INSTALL_PATH"
        ./1panel app install "$app" --yes 2>/dev/null || log "${YELLOW}应用 $app 安装失败或已存在${NC}"
    done
    
    log "${GREEN}常用应用安装完成${NC}"
}

# 配置自动备份
configure_backup() {
    log "${CYAN}配置自动备份...${NC}"
    
    # 创建备份脚本
    cat > /usr/local/bin/1panel_backup.sh << EOF
#!/bin/bash
# 1Panel自动备份脚本

BACKUP_DIR="$BACKUP_PATH"
DATE=\$(date +%Y%m%d_%H%M%S)
INSTALL_PATH="$INSTALL_PATH"

# 执行备份
cd "\$INSTALL_PATH"
./1panel backup create --name "auto_backup_\$DATE"

# 清理30天前的备份
find "\$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "备份完成: \$(date)"
EOF
    
    chmod +x /usr/local/bin/1panel_backup.sh
    
    # 添加cron任务
    echo "0 2 * * * /usr/local/bin/1panel_backup.sh >> $BACKUP_PATH/backup.log 2>&1" | crontab -
    
    log "${GREEN}自动备份配置完成${NC}"
}

# 创建快捷命令
create_shortcuts() {
    log "${CYAN}创建快捷命令...${NC}"
    
    # 创建1panel命令链接
    ln -sf "$INSTALL_PATH/1panel" /usr/bin/1panel
    
    # 创建1pctl命令（兼容旧版本）
    ln -sf "$INSTALL_PATH/1panel" /usr/bin/1pctl
    
    # 创建面板管理脚本
    cat > /usr/local/bin/1p << 'EOF'
#!/bin/bash
# 1Panel快捷管理命令

case "$1" in
    start)
        systemctl start 1panel
        ;;
    stop)
        systemctl stop 1panel
        ;;
    restart)
        systemctl restart 1panel
        ;;
    status)
        systemctl status 1panel
        ;;
    info)
        1panel info
        ;;
    update)
        1panel update
        ;;
    backup)
        1panel backup create --name "manual_$(date +%Y%m%d_%H%M%S)"
        ;;
    *)
        echo "Usage: 1p {start|stop|restart|status|info|update|backup}"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/1p
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 创建配置信息文件
    cat > /root/1panel_info.txt << EOF
1Panel 面板信息
===============

访问地址: http://${SERVER_IP}:${PANEL_PORT}/${SECURITY_ENTRANCE}
${SSL_PANEL:+SSL地址: https://${SERVER_IP}:${PANEL_PORT}/${SECURITY_ENTRANCE}}
用户名: ${PANEL_USER}
密码: ${PANEL_PASSWORD}

安全入口: /${SECURITY_ENTRANCE}
面板端口: ${PANEL_PORT}
安装路径: ${INSTALL_PATH}
数据目录: ${DATA_PATH}
备份目录: ${BACKUP_PATH}

快捷命令:
- 1panel      # 面板命令行工具
- 1p          # 快捷管理命令

常用命令:
- 1p start    # 启动面板
- 1p stop     # 停止面板
- 1p restart  # 重启面板
- 1p status   # 查看状态
- 1p info     # 查看信息
- 1p update   # 更新面板
- 1p backup   # 手动备份

应用商店: ${APP_STORE}
${INSTALL_APPS:+已安装应用: ${DEFAULT_APPS[@]}}

安全设置:
${SSL_PANEL:+- SSL: 已启用}
- 防火墙: 已配置
- 自动备份: 每天凌晨2点

日志查看:
- journalctl -u 1panel -f

备份脚本: /usr/local/bin/1panel_backup.sh
EOF
    
    chmod 600 /root/1panel_info.txt
}

# 启动面板服务
start_panel_service() {
    log "${CYAN}启动面板服务...${NC}"
    
    systemctl start 1panel
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet 1panel; then
        log "${GREEN}面板服务启动成功${NC}"
    else
        log "${RED}面板服务启动失败${NC}"
        systemctl status 1panel
        exit 1
    fi
}

# 验证安装
verify_installation() {
    log "${CYAN}验证安装...${NC}"
    
    # 检查服务状态
    if ! systemctl is-active --quiet 1panel; then
        log "${RED}错误: 面板服务未运行${NC}"
        return 1
    fi
    
    # 检查端口监听
    if ! netstat -tlnp | grep -q ":${PANEL_PORT}"; then
        log "${RED}错误: 面板端口未监听${NC}"
        return 1
    fi
    
    # 检查面板响应
    local panel_url="http://localhost:${PANEL_PORT}/${SECURITY_ENTRANCE}"
    if curl -s -o /dev/null -w "%{http_code}" "$panel_url" | grep -q "200\|302"; then
        log "${GREEN}面板Web界面响应正常${NC}"
    else
        log "${YELLOW}面板Web界面可能需要更多时间启动${NC}"
    fi
    
    log "${GREEN}安装验证通过${NC}"
    return 0
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}1Panel安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}访问信息:${NC}"
    echo "- 面板地址: http://$(hostname -I | awk '{print $1}'):${PANEL_PORT}/${SECURITY_ENTRANCE}"
    if [[ "$SSL_PANEL" = true ]]; then
        echo "- SSL地址: https://$(hostname -I | awk '{print $1}'):${PANEL_PORT}/${SECURITY_ENTRANCE}"
    fi
    echo "- 用户名: ${PANEL_USER}"
    echo "- 密码: ${PANEL_PASSWORD}"
    echo
    echo -e "${CYAN}重要提示:${NC}"
    echo -e "${YELLOW}请记住安全入口: /${SECURITY_ENTRANCE}${NC}"
    echo -e "${YELLOW}不加安全入口将无法访问面板${NC}"
    echo
    echo -e "${CYAN}快捷命令:${NC}"
    echo "- 1panel      # 完整命令行工具"
    echo "- 1p          # 快捷管理命令"
    echo "- 1p info     # 查看面板信息"
    echo "- 1p restart  # 重启面板"
    echo
    echo -e "${CYAN}常用操作:${NC}"
    echo "1. 应用商店: 可一键安装各种应用"
    echo "2. 文件管理: Web界面管理服务器文件"
    echo "3. 终端工具: Web SSH终端"
    echo "4. 监控面板: 实时系统监控"
    echo "5. 定时任务: 计划任务管理"
    echo
    
    if [[ "$INSTALL_APPS" = true ]]; then
        echo -e "${CYAN}已安装应用:${NC}"
        for app in "${DEFAULT_APPS[@]}"; do
            echo "- $app"
        done
        echo
    fi
    
    echo -e "${CYAN}安全建议:${NC}"
    echo "1. 定期更新面板版本"
    echo "2. 使用强密码保护账户"
    echo "3. 定期备份重要数据"
    echo "4. 限制面板访问IP"
    echo "5. 启用两步验证"
    echo
    echo -e "${CYAN}更新升级:${NC}"
    echo "- 检查更新: 1panel update"
    echo "- 自动升级: 面板内设置"
    echo
    echo -e "${YELLOW}配置信息: /root/1panel_info.txt${NC}"
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
            --entrance)
                SECURITY_ENTRANCE="$2"
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
            --install-docker)
                INSTALL_DOCKER=true
                shift
                ;;
            --app-store)
                APP_STORE="$2"
                shift 2
                ;;
            --ssl-panel)
                SSL_PANEL=true
                shift
                ;;
            --install-apps)
                INSTALL_APPS=true
                shift
                ;;
            --backup-path)
                BACKUP_PATH="$2"
                shift 2
                ;;
            --data-path)
                DATA_PATH="$2"
                shift 2
                ;;
            --china-mirror)
                USE_CHINA_MIRROR=true
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
    check_1panel_installed
    
    # 安装Docker
    install_docker_if_needed
    
    # 下载安装1Panel
    install_1panel
    
    # 初始化配置
    initialize_config
    
    # 创建systemd服务
    create_systemd_service
    
    # 配置防火墙
    configure_firewall
    
    # 配置SSL
    configure_ssl
    
    # 启动服务
    start_panel_service
    
    # 安装常用应用
    install_common_apps
    
    # 配置备份
    configure_backup
    
    # 创建快捷命令
    create_shortcuts
    
    # 保存配置信息
    save_config_info
    
    # 验证安装
    verify_installation
    
    # 显示安装后说明
    show_post_install_info
}

# 执行主函数
main "$@"