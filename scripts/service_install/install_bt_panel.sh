#!/bin/bash
#==============================================================================
# 脚本名称: install_bt_panel.sh
# 脚本描述: 宝塔面板安装配置脚本 - 支持免费版和专业版，包含安全加固和插件管理
# 脚本路径: vps_scripts/scripts/service_install/install_bt_panel.sh
# 作者: Jensfrank
# 使用方法: bash install_bt_panel.sh [选项]
# 选项: 
#   --version VERSION    面板版本 (free/pro, 默认: free)
#   --port PORT          面板端口 (默认: 8888)
#   --username USERNAME  面板用户名 (默认: 自动生成)
#   --password PASSWORD  面板密码 (默认: 自动生成)
#   --path PATH          安全入口 (默认: 随机生成)
#   --ssl                启用面板SSL
#   --plugins PLUGINS    预装插件列表
#   --safe-mode          安全模式安装
#   --cn                 使用国内下载源
#   --remove             卸载宝塔面板
#   --info               显示面板信息
# 更新日期: 2025-01-17
#==============================================================================

# 严格模式
set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# 全局变量
readonly SCRIPT_NAME="宝塔面板安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/bt_panel_install_$(date +%Y%m%d_%H%M%S).log"
readonly BT_SETUP_PATH="/www"
readonly BT_PANEL_PATH="/www/server/panel"

# 默认配置
BT_VERSION="free"
BT_PORT=8888
BT_USERNAME=""
BT_PASSWORD=""
BT_PATH=""
ENABLE_SSL=false
INSTALL_PLUGINS=""
SAFE_MODE=false
USE_CN_MIRROR=true  # 默认使用国内源
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""
PYTHON_VERSION=""

# 下载源
BT_DOWNLOAD_URL=""
BT_INSTALL_SCRIPT=""

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --version VERSION    面板版本
                        - free: 免费版（默认）
                        - pro: 专业版（需要授权）
    
    --port PORT         面板访问端口（默认: 8888）
    --username USERNAME 面板登录用户名（默认: 自动生成）
    --password PASSWORD 面板登录密码（默认: 自动生成）
    --path PATH         安全入口路径（默认: 随机生成）
    
    --ssl               启用面板SSL证书
    --safe-mode         安全模式（限制IP访问、强密码等）
    
    --plugins PLUGINS   预装插件，用逗号分隔
                        可选: nginx,mysql,php,redis,docker,firewall
                        示例: --plugins nginx,mysql,php
    
    --cn                使用国内下载源（默认启用）
    --remove            完全卸载宝塔面板
    --info              显示面板登录信息
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                          # 默认安装免费版
    $(basename "$0") --port 8899              # 自定义端口
    $(basename "$0") --safe-mode              # 安全模式安装
    $(basename "$0") --plugins nginx,mysql    # 预装插件
    $(basename "$0") --remove                 # 卸载面板

EOF
}

# 日志记录
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 错误处理
error_exit() {
    log ERROR "$1"
    log ERROR "安装日志已保存到: $LOG_FILE"
    exit 1
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    openssl rand -base64 48 | tr -d "=+/" | cut -c1-$length
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本需要root权限运行，请使用 sudo bash $0"
    fi
}

# 检测系统信息
detect_system() {
    log INFO "检测系统信息..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error_exit "无法检测操作系统信息"
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *) error_exit "不支持的系统架构: $ARCH" ;;
    esac
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查系统兼容性
check_compatibility() {
    log INFO "检查系统兼容性..."
    
    local supported=false
    case $OS in
        ubuntu)
            case $VERSION in
                16.04|18.04|20.04|22.04) supported=true ;;
            esac
            ;;
        debian)
            case $VERSION in
                9|10|11|12) supported=true ;;
            esac
            ;;
        centos)
            case $VERSION in
                7|8) supported=true ;;
            esac
            ;;
        almalinux|rocky)
            case $VERSION in
                8|9) supported=true ;;
            esac
            ;;
    esac
    
    if [[ $supported == false ]]; then
        error_exit "宝塔面板不支持当前系统: $OS $VERSION"
    fi
    
    # 检查内存
    local mem_total=$(free -m | grep "^Mem:" | awk '{print $2}')
    if [[ $mem_total -lt 512 ]]; then
        error_exit "系统内存不足，至少需要512MB内存"
    fi
    
    log SUCCESS "系统兼容性检查通过"
}

# 检查是否已安装
check_existing_installation() {
    if [[ -f "$BT_PANEL_PATH/BT-Panel" ]]; then
        log WARNING "检测到宝塔面板已安装"
        echo -e "${YELLOW}是否重新安装？这将覆盖现有安装 [y/N]:${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log INFO "用户取消安装"
            exit 0
        fi
    fi
}

# 设置下载源
setup_download_source() {
    log INFO "设置下载源..."
    
    if [[ $USE_CN_MIRROR == true ]]; then
        BT_DOWNLOAD_URL="http://download.bt.cn/install/install_panel.sh"
        log INFO "使用国内下载源"
    else
        BT_DOWNLOAD_URL="http://www.aapanel.com/script/install_panel.sh"
        log INFO "使用国际下载源"
    fi
}

# 安装依赖
install_dependencies() {
    log INFO "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq wget curl screen unzip lsof
            ;;
        centos|almalinux|rocky)
            yum install -y -q wget curl screen unzip lsof
            ;;
    esac
    
    log SUCCESS "依赖安装完成"
}

# 优化系统设置
optimize_system() {
    log INFO "优化系统设置..."
    
    # 关闭SELinux
    if command_exists setenforce; then
        setenforce 0 2>/dev/null || true
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config 2>/dev/null || true
    fi
    
    # 设置文件描述符限制
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    # 优化内核参数
    cat >> /etc/sysctl.conf << EOF

# 宝塔面板优化
net.ipv4.tcp_max_tw_buckets = 600
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_fin_timeout = 1
net.ipv4.tcp_keepalive_time = 30
net.ipv4.ip_local_port_range = 1024 65000
EOF
    
    sysctl -p >/dev/null 2>&1
    
    log SUCCESS "系统优化完成"
}

# 下载安装脚本
download_install_script() {
    log INFO "下载宝塔安装脚本..."
    
    local temp_script="/tmp/bt_install.sh"
    
    # 下载脚本
    wget -O "$temp_script" "$BT_DOWNLOAD_URL" || error_exit "下载安装脚本失败"
    
    # 修改脚本以支持自定义参数
    if [[ -n "$BT_PORT" ]] && [[ "$BT_PORT" != "8888" ]]; then
        sed -i "s/panelPort=8888/panelPort=$BT_PORT/g" "$temp_script"
    fi
    
    chmod +x "$temp_script"
    BT_INSTALL_SCRIPT="$temp_script"
    
    log SUCCESS "安装脚本下载完成"
}

# 执行安装
install_bt_panel() {
    log INFO "开始安装宝塔面板..."
    
    # 设置环境变量
    export DEBIAN_FRONTEND=noninteractive
    
    # 执行安装脚本
    if [[ $USE_CN_MIRROR == true ]]; then
        # 国内版本
        echo y | bash "$BT_INSTALL_SCRIPT"
    else
        # 国际版本(aaPanel)
        echo y | bash "$BT_INSTALL_SCRIPT"
    fi
    
    # 检查安装结果
    if [[ ! -f "$BT_PANEL_PATH/BT-Panel" ]]; then
        error_exit "宝塔面板安装失败"
    fi
    
    log SUCCESS "宝塔面板安装完成"
}

# 配置面板
configure_panel() {
    log INFO "配置宝塔面板..."
    
    # 生成登录凭据
    if [[ -z "$BT_USERNAME" ]]; then
        BT_USERNAME="admin$(shuf -i 100-999 -n 1)"
    fi
    
    if [[ -z "$BT_PASSWORD" ]]; then
        BT_PASSWORD=$(generate_random_string 16)
    fi
    
    if [[ -z "$BT_PATH" ]]; then
        BT_PATH=$(generate_random_string 8)
    fi
    
    # 设置面板端口
    if [[ "$BT_PORT" != "8888" ]]; then
        python3 "$BT_PANEL_PATH/tools.py" panel "$BT_PORT"
    fi
    
    # 设置面板用户名
    python3 "$BT_PANEL_PATH/tools.py" username "$BT_USERNAME"
    
    # 设置面板密码
    python3 "$BT_PANEL_PATH/tools.py" password "$BT_PASSWORD"
    
    # 设置安全入口
    echo "/$BT_PATH" > "$BT_PANEL_PATH/data/admin_path.pl"
    
    log SUCCESS "面板配置完成"
}

# 配置SSL
configure_ssl() {
    if [[ $ENABLE_SSL == true ]]; then
        log INFO "配置面板SSL..."
        
        # 生成自签名证书
        mkdir -p "$BT_PANEL_PATH/ssl"
        cd "$BT_PANEL_PATH/ssl"
        
        # 生成私钥
        openssl genrsa -out privkey.pem 2048
        
        # 生成证书
        openssl req -new -x509 -key privkey.pem -out fullchain.pem -days 3650 \
            -subj "/C=CN/ST=State/L=City/O=Organization/CN=localhost"
        
        # 启用SSL
        echo "True" > "$BT_PANEL_PATH/data/ssl.pl"
        
        log SUCCESS "SSL配置完成"
    fi
}

# 安全加固
secure_panel() {
    if [[ $SAFE_MODE == true ]]; then
        log INFO "执行安全加固..."
        
        # 限制面板访问IP
        local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || echo "")
        if [[ -n "$server_ip" ]]; then
            echo "$server_ip" > "$BT_PANEL_PATH/data/limitip.conf"
            log INFO "限制面板访问IP: $server_ip"
        fi
        
        # 启用操作日志
        echo "True" > "$BT_PANEL_PATH/data/log_close.pl"
        
        # 启用登录告警
        echo "True" > "$BT_PANEL_PATH/data/login_send_mail.pl"
        
        # 设置session超时时间（30分钟）
        echo "1800" > "$BT_PANEL_PATH/data/session_timeout.pl"
        
        # 禁用开发者模式
        rm -f "$BT_PANEL_PATH/data/dev.pl"
        
        log SUCCESS "安全加固完成"
    fi
}

# 安装插件
install_plugins() {
    if [[ -n "$INSTALL_PLUGINS" ]]; then
        log INFO "安装预设插件..."
        
        # 启动面板服务
        service bt start
        sleep 5
        
        # 分割插件列表
        IFS=',' read -ra PLUGINS <<< "$INSTALL_PLUGINS"
        
        for plugin in "${PLUGINS[@]}"; do
            plugin=$(echo "$plugin" | tr -d ' ')
            log INFO "安装插件: $plugin"
            
            case $plugin in
                nginx)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install nginx 1.24
                    ;;
                mysql)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install mysql 5.7
                    ;;
                php)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install php 7.4
                    ;;
                redis)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install redis 7.0
                    ;;
                docker)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install docker 1.0
                    ;;
                firewall)
                    python3 "$BT_PANEL_PATH/script/install_soft.sh" 0 install firewall 1.0
                    ;;
                *)
                    log WARNING "未知插件: $plugin"
                    ;;
            esac
        done
        
        log SUCCESS "插件安装完成"
    fi
}

# 配置防火墙
configure_firewall() {
    log INFO "配置防火墙规则..."
    
    # 开放面板端口
    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=$BT_PORT/tcp
        firewall-cmd --reload
    elif command_exists ufw; then
        ufw allow $BT_PORT/tcp
    elif command_exists iptables; then
        iptables -I INPUT -p tcp --dport $BT_PORT -j ACCEPT
        service iptables save 2>/dev/null || true
    fi
    
    log SUCCESS "防火墙配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log INFO "创建管理脚本..."
    
    # 创建面板信息查看脚本
    cat > /usr/local/bin/bt-info << EOF
#!/bin/bash
echo "宝塔面板登录信息:"
echo "===================="
echo "面板地址: http://\$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print \$1}'):$BT_PORT/$BT_PATH"
echo "用户名: $BT_USERNAME"
echo "密码: $BT_PASSWORD"
echo "===================="
echo "面板命令: bt"
EOF
    chmod +x /usr/local/bin/bt-info
    
    # 创建备份脚本
    cat > /usr/local/bin/bt-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/www/backup/panel"
mkdir -p "$BACKUP_DIR"
tar -czf "$BACKUP_DIR/bt_panel_$(date +%Y%m%d_%H%M%S).tar.gz" -C /www/server panel
find "$BACKUP_DIR" -name "bt_panel_*.tar.gz" -mtime +7 -delete
echo "面板备份完成: $BACKUP_DIR"
EOF
    chmod +x /usr/local/bin/bt-backup
    
    log SUCCESS "管理脚本创建完成"
}

# 保存安装信息
save_install_info() {
    local info_file="/www/server/panel/install.info"
    cat > "$info_file" << EOF
# 宝塔面板安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')

面板版本: $BT_VERSION
面板端口: $BT_PORT
面板用户名: $BT_USERNAME
面板密码: $BT_PASSWORD
安全入口: /$BT_PATH
SSL状态: $ENABLE_SSL
安全模式: $SAFE_MODE

面板地址: http://$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}'):$BT_PORT/$BT_PATH

管理命令:
  bt         # 宝塔命令行工具
  bt-info    # 查看登录信息
  bt-backup  # 备份面板数据

服务管理:
  service bt start    # 启动面板
  service bt stop     # 停止面板
  service bt restart  # 重启面板
EOF
    
    chmod 600 "$info_file"
}

# 显示安装信息
show_installation_info() {
    local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}宝塔面板安装成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}面板登录信息:${NC}"
    echo -e "${YELLOW}外网地址:${NC} http://${server_ip}:${BT_PORT}/${BT_PATH}"
    echo -e "${YELLOW}内网地址:${NC} http://$(hostname -I | awk '{print $1}'):${BT_PORT}/${BT_PATH}"
    if [[ $ENABLE_SSL == true ]]; then
        echo -e "${YELLOW}SSL地址:${NC} https://${server_ip}:${BT_PORT}/${BT_PATH}"
    fi
    echo
    echo -e "${YELLOW}用户名:${NC} $BT_USERNAME"
    echo -e "${YELLOW}密码:${NC} $BT_PASSWORD"
    echo
    echo -e "${RED}重要提示:${NC}"
    echo "1. 请妥善保管以上登录信息"
    echo "2. 首次登录后建议修改默认设置"
    echo "3. 如果无法访问，请检查防火墙设置"
    echo
    echo -e "${BLUE}常用命令:${NC}"
    echo "  bt         # 宝塔命令行工具"
    echo "  bt-info    # 查看登录信息"
    echo "  bt-backup  # 备份面板数据"
    echo
    echo -e "${BLUE}服务管理:${NC}"
    echo "  service bt start/stop/restart"
    echo
    if [[ -n "$INSTALL_PLUGINS" ]]; then
        echo -e "${BLUE}已安装插件:${NC} $INSTALL_PLUGINS"
        echo
    fi
    echo -e "${BLUE}安装日志:${NC} $LOG_FILE"
    echo -e "${BLUE}配置信息:${NC} /www/server/panel/install.info"
    echo
}

# 显示面板信息
show_panel_info() {
    if [[ ! -f "$BT_PANEL_PATH/BT-Panel" ]]; then
        error_exit "宝塔面板未安装"
    fi
    
    echo -e "${BLUE}宝塔面板信息:${NC}"
    echo "========================================" 
    
    # 读取配置
    local port=$(cat "$BT_PANEL_PATH/data/port.pl" 2>/dev/null || echo "8888")
    local username=$(cat "$BT_PANEL_PATH/data/username.txt" 2>/dev/null || echo "未设置")
    local admin_path=$(cat "$BT_PANEL_PATH/data/admin_path.pl" 2>/dev/null || echo "/")
    local ssl_status="未启用"
    [[ -f "$BT_PANEL_PATH/data/ssl.pl" ]] && ssl_status="已启用"
    
    local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo "面板地址: http://${server_ip}:${port}${admin_path}"
    [[ "$ssl_status" == "已启用" ]] && echo "SSL地址: https://${server_ip}:${port}${admin_path}"
    echo "用户名: $username"
    echo "SSL状态: $ssl_status"
    echo
    echo "获取密码命令: bt default"
}

# 卸载宝塔面板
remove_bt_panel() {
    log WARNING "开始卸载宝塔面板..."
    
    echo -e "${YELLOW}此操作将完全删除宝塔面板及所有数据，是否继续？[y/N]:${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log INFO "用户取消卸载"
        exit 0
    fi
    
    # 停止服务
    service bt stop 2>/dev/null || true
    
    # 下载卸载脚本
    if [[ $USE_CN_MIRROR == true ]]; then
        wget -O /tmp/bt_uninstall.sh http://download.bt.cn/install/bt-uninstall.sh
    else
        wget -O /tmp/bt_uninstall.sh http://www.aapanel.com/script/bt-uninstall.sh
    fi
    
    # 执行卸载
    bash /tmp/bt_uninstall.sh
    
    # 清理残留
    rm -rf /www
    rm -f /usr/local/bin/bt-*
    rm -f /etc/init.d/bt
    
    log SUCCESS "宝塔面板卸载完成"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                BT_VERSION="$2"
                shift 2
                ;;
            --port)
                BT_PORT="$2"
                shift 2
                ;;
            --username)
                BT_USERNAME="$2"
                shift 2
                ;;
            --password)
                BT_PASSWORD="$2"
                shift 2
                ;;
            --path)
                BT_PATH="$2"
                shift 2
                ;;
            --ssl)
                ENABLE_SSL=true
                shift
                ;;
            --plugins)
                INSTALL_PLUGINS="$2"
                shift 2
                ;;
            --safe-mode)
                SAFE_MODE=true
                shift
                ;;
            --cn)
                USE_CN_MIRROR=true
                shift
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --info)
                ACTION="info"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log ERROR "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查权限
    check_root
    
    # 执行操作
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            # 检测系统
            detect_system
            check_compatibility
            check_existing_installation
            
            # 安装流程
            setup_download_source
            install_dependencies
            optimize_system
            download_install_script
            install_bt_panel
            configure_panel
            configure_ssl
            secure_panel
            install_plugins
            configure_firewall
            create_management_scripts
            save_install_info
            
            # 显示信息
            show_installation_info
            ;;
            
        remove)
            remove_bt_panel
            ;;
            
        info)
            show_panel_info
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"