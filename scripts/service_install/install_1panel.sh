#!/bin/bash
#==============================================================================
# 脚本名称: install_1panel.sh
# 脚本描述: 1Panel运维面板安装配置脚本 - 现代化的Linux服务器管理面板
# 脚本路径: vps_scripts/scripts/service_install/install_1panel.sh
# 作者: Jensfrank
# 使用方法: bash install_1panel.sh [选项]
# 选项: 
#   --version VERSION    指定版本 (如: v1.8.0, latest)
#   --port PORT          面板端口 (默认: 9999)
#   --entrance PATH      安全入口 (默认: 随机生成)
#   --username USERNAME  用户名 (默认: admin)
#   --password PASSWORD  密码 (默认: 随机生成)
#   --install-dir DIR    安装目录 (默认: /opt)
#   --cn                 使用国内加速源
#   --apps APPS          预装应用列表
#   --ssl                启用HTTPS
#   --remove             卸载1Panel
#   --update             更新到最新版本
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
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 全局变量
readonly SCRIPT_NAME="1Panel运维面板安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/1panel_install_$(date +%Y%m%d_%H%M%S).log"
readonly CONFIG_DIR="/opt/1panel/conf"
readonly DATA_DIR="/opt/1panel/data"
readonly APP_DIR="/opt/1panel/apps"
readonly BACKUP_DIR="/opt/1panel/backup"

# 默认配置
PANEL_VERSION="latest"
PANEL_PORT=9999
PANEL_ENTRANCE=""
PANEL_USERNAME="admin"
PANEL_PASSWORD=""
INSTALL_DIR="/opt"
USE_CN_MIRROR=false
INSTALL_APPS=""
ENABLE_SSL=false
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""

# 下载地址
GITHUB_URL="https://github.com/1Panel-dev/1Panel"
GITEE_URL="https://gitee.com/fit2cloud-feizhiyun/1Panel"
DOWNLOAD_URL=""

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --version VERSION    指定安装版本
                        - latest: 最新版本（默认）
                        - v1.8.0: 指定版本号
    
    --port PORT         面板访问端口（默认: 9999）
    --entrance PATH     安全入口路径（默认: 随机生成）
    --username USERNAME 管理员用户名（默认: admin）
    --password PASSWORD 管理员密码（默认: 随机生成）
    --install-dir DIR   安装目录（默认: /opt）
    
    --cn                使用国内加速源（推荐国内用户使用）
    --ssl               启用HTTPS访问
    
    --apps APPS         预装应用，用逗号分隔
                        可选: nginx,mysql,redis,postgresql,mongodb
                        示例: --apps nginx,mysql,redis
    
    --remove            卸载1Panel面板
    --update            更新到最新版本
    --info              显示面板登录信息
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                          # 默认安装最新版本
    $(basename "$0") --cn --port 8999         # 使用国内源，自定义端口
    $(basename "$0") --apps nginx,mysql       # 预装应用
    $(basename "$0") --ssl --entrance admin   # 启用SSL，自定义入口
    $(basename "$0") --update                 # 更新到最新版本

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
        DEBUG) [[ "${DEBUG:-false}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $message" ;;
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
    local chars=${2:-'A-Za-z0-9'}
    tr -dc "$chars" < /dev/urandom | head -c "$length"
}

# 生成安全密码
generate_secure_password() {
    local password=""
    # 确保包含大写字母、小写字母、数字和特殊字符
    password+=$(generate_random_string 4 'A-Z')
    password+=$(generate_random_string 4 'a-z')
    password+=$(generate_random_string 4 '0-9')
    password+=$(generate_random_string 4 '!@#$%^&*')
    # 打乱顺序
    echo "$password" | fold -w1 | shuf | tr -d '\n'
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
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armv7" ;;
        *) error_exit "不支持的系统架构: $ARCH" ;;
    esac
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查系统兼容性
check_compatibility() {
    log INFO "检查系统兼容性..."
    
    # 检查操作系统
    local supported=false
    case $OS in
        ubuntu)
            case $VERSION in
                18.04|20.04|22.04|24.04) supported=true ;;
            esac
            ;;
        debian)
            case $VERSION in
                10|11|12) supported=true ;;
            esac
            ;;
        centos)
            case $VERSION in
                7|8|9) supported=true ;;
            esac
            ;;
        rhel|almalinux|rocky)
            case $VERSION in
                8|9) supported=true ;;
            esac
            ;;
        fedora)
            if [[ $VERSION -ge 35 ]]; then
                supported=true
            fi
            ;;
    esac
    
    if [[ $supported == false ]]; then
        error_exit "1Panel不支持当前系统: $OS $VERSION"
    fi
    
    # 检查内存（最低512MB）
    local mem_total=$(free -m | grep "^Mem:" | awk '{print $2}')
    if [[ $mem_total -lt 512 ]]; then
        error_exit "系统内存不足，至少需要512MB内存"
    fi
    
    # 检查磁盘空间（最低1GB）
    local disk_free=$(df -BG "$INSTALL_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $disk_free -lt 1 ]]; then
        error_exit "磁盘空间不足，至少需要1GB可用空间"
    fi
    
    log SUCCESS "系统兼容性检查通过"
}

# 检查是否已安装
check_existing_installation() {
    if [[ -f "$INSTALL_DIR/1panel/1panel" ]]; then
        log WARNING "检测到1Panel已安装"
        echo -e "${YELLOW}是否重新安装？这将保留数据但更新程序 [y/N]:${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log INFO "用户取消安装"
            exit 0
        fi
    fi
}

# 检查端口占用
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$PANEL_PORT "; then
        error_exit "端口 $PANEL_PORT 已被占用，请使用 --port 指定其他端口"
    fi
}

# 检查Docker
check_docker() {
    if ! command_exists docker; then
        log WARNING "Docker未安装，1Panel需要Docker支持"
        echo -e "${YELLOW}是否自动安装Docker？[Y/n]:${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            install_docker
        else
            error_exit "1Panel需要Docker环境，请先安装Docker"
        fi
    fi
    
    # 检查Docker服务状态
    if ! systemctl is-active docker &>/dev/null; then
        log INFO "启动Docker服务..."
        systemctl start docker
        systemctl enable docker
    fi
}

# 安装Docker
install_docker() {
    log INFO "安装Docker..."
    
    # 使用官方脚本安装
    if [[ $USE_CN_MIRROR == true ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh --mirror Aliyun
    else
        curl -fsSL https://get.docker.com | sh
    fi
    
    # 启动Docker
    systemctl start docker
    systemctl enable docker
    
    # 配置Docker镜像加速（如果使用国内源）
    if [[ $USE_CN_MIRROR == true ]]; then
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com",
        "https://mirror.ccs.tencentyun.com"
    ]
}
EOF
        systemctl daemon-reload
        systemctl restart docker
    fi
    
    log SUCCESS "Docker安装完成"
}

# 安装依赖
install_dependencies() {
    log INFO "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq \
                curl \
                wget \
                tar \
                gzip \
                ca-certificates \
                lsb-release
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y -q \
                curl \
                wget \
                tar \
                gzip \
                ca-certificates
            ;;
        fedora)
            dnf install -y -q \
                curl \
                wget \
                tar \
                gzip \
                ca-certificates
            ;;
    esac
    
    log SUCCESS "依赖安装完成"
}

# 获取最新版本
get_latest_version() {
    local api_url
    if [[ $USE_CN_MIRROR == true ]]; then
        api_url="https://gitee.com/api/v5/repos/fit2cloud-feizhiyun/1Panel/releases/latest"
    else
        api_url="https://api.github.com/repos/1Panel-dev/1Panel/releases/latest"
    fi
    
    local version=$(curl -s "$api_url" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "$version" ]]; then
        version="v1.8.0"  # 默认版本
        log WARNING "无法获取最新版本，使用默认版本 $version"
    fi
    
    echo "$version"
}

# 下载1Panel
download_1panel() {
    log INFO "下载1Panel..."
    
    # 确定版本
    if [[ "$PANEL_VERSION" == "latest" ]]; then
        PANEL_VERSION=$(get_latest_version)
    fi
    
    log INFO "安装版本: $PANEL_VERSION"
    
    # 构建下载URL
    local filename="1panel-${PANEL_VERSION}-linux-${ARCH}.tar.gz"
    if [[ $USE_CN_MIRROR == true ]]; then
        DOWNLOAD_URL="${GITEE_URL}/releases/download/${PANEL_VERSION}/${filename}"
    else
        DOWNLOAD_URL="${GITHUB_URL}/releases/download/${PANEL_VERSION}/${filename}"
    fi
    
    # 创建临时目录
    local temp_dir="/tmp/1panel_install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载安装包
    log INFO "下载地址: $DOWNLOAD_URL"
    wget -q --show-progress "$DOWNLOAD_URL" -O "$filename" || {
        # 如果下载失败，尝试备用地址
        log WARNING "主下载源失败，尝试备用地址..."
        if [[ $USE_CN_MIRROR == true ]]; then
            DOWNLOAD_URL="${GITHUB_URL}/releases/download/${PANEL_VERSION}/${filename}"
        else
            DOWNLOAD_URL="${GITEE_URL}/releases/download/${PANEL_VERSION}/${filename}"
        fi
        wget -q --show-progress "$DOWNLOAD_URL" -O "$filename" || error_exit "下载失败"
    }
    
    # 解压文件
    log INFO "解压安装包..."
    tar -xzf "$filename"
    
    log SUCCESS "下载完成"
}

# 安装1Panel
install_1panel() {
    log INFO "安装1Panel..."
    
    # 复制文件到安装目录
    mkdir -p "$INSTALL_DIR/1panel"
    cp -r /tmp/1panel_install/1panel/* "$INSTALL_DIR/1panel/"
    
    # 设置执行权限
    chmod +x "$INSTALL_DIR/1panel/1panel"
    chmod +x "$INSTALL_DIR/1panel/1pctl"
    
    # 创建必要的目录
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$INSTALL_DIR/1panel/logs"
    
    # 创建符号链接
    ln -sf "$INSTALL_DIR/1panel/1pctl" /usr/local/bin/1pctl
    
    log SUCCESS "1Panel安装完成"
}

# 生成配置文件
generate_config() {
    log INFO "生成配置文件..."
    
    # 生成随机入口
    if [[ -z "$PANEL_ENTRANCE" ]]; then
        PANEL_ENTRANCE=$(generate_random_string 8 'a-z0-9')
    fi
    
    # 生成密码
    if [[ -z "$PANEL_PASSWORD" ]]; then
        PANEL_PASSWORD=$(generate_secure_password)
    fi
    
    # 生成主配置文件
    cat > "$CONFIG_DIR/app.yaml" << EOF
system:
  port: $PANEL_PORT
  entrance: $PANEL_ENTRANCE
  username: $PANEL_USERNAME
  password: $(echo -n "$PANEL_PASSWORD" | md5sum | awk '{print $1}')
  ssl: $ENABLE_SSL
  mode: production
  
database:
  type: sqlite
  path: $DATA_DIR/1panel.db
  
log:
  level: info
  path: $INSTALL_DIR/1panel/logs
  max_size: 10
  max_backups: 3
  max_age: 7
  
app:
  repo: https://resource.fit2cloud.com/1panel/appstore
  path: $APP_DIR
  
backup:
  path: $BACKUP_DIR
  
docker:
  compose_path: /usr/local/bin/docker-compose
EOF
    
    # 生成SSL配置（如果启用）
    if [[ $ENABLE_SSL == true ]]; then
        generate_ssl_cert
    fi
    
    log SUCCESS "配置文件生成完成"
}

# 生成SSL证书
generate_ssl_cert() {
    log INFO "生成自签名SSL证书..."
    
    mkdir -p "$CONFIG_DIR/ssl"
    cd "$CONFIG_DIR/ssl"
    
    # 生成私钥
    openssl genrsa -out server.key 2048
    
    # 生成证书请求
    openssl req -new -key server.key -out server.csr -subj \
        "/C=CN/ST=State/L=City/O=Organization/CN=1panel.local"
    
    # 生成自签名证书
    openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
    
    # 清理证书请求文件
    rm -f server.csr
    
    log SUCCESS "SSL证书生成完成"
}

# 创建systemd服务
create_systemd_service() {
    log INFO "创建系统服务..."
    
    cat > /etc/systemd/system/1panel.service << EOF
[Unit]
Description=1Panel Linux Server Management Panel
Documentation=https://github.com/1Panel-dev/1Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR/1panel
ExecStart=$INSTALL_DIR/1panel/1panel server
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM

# 安全限制
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR/1panel $DATA_DIR $APP_DIR $BACKUP_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    systemctl enable 1panel
    
    log SUCCESS "系统服务创建完成"
}

# 初始化数据库
init_database() {
    log INFO "初始化数据库..."
    
    # 首次启动会自动初始化数据库
    systemctl start 1panel
    sleep 5
    
    # 检查服务状态
    if ! systemctl is-active 1panel &>/dev/null; then
        error_exit "1Panel服务启动失败"
    fi
    
    log SUCCESS "数据库初始化完成"
}

# 配置防火墙
configure_firewall() {
    log INFO "配置防火墙规则..."
    
    # 开放面板端口
    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=$PANEL_PORT/tcp
        firewall-cmd --reload
    elif command_exists ufw; then
        ufw allow $PANEL_PORT/tcp
    elif command_exists iptables; then
        iptables -I INPUT -p tcp --dport $PANEL_PORT -j ACCEPT
        
        # 保存规则
        if [[ "$OS" == "centos" ]] || [[ "$OS" == "rhel" ]]; then
            service iptables save
        elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
            iptables-save > /etc/iptables/rules.v4
        fi
    fi
    
    log SUCCESS "防火墙配置完成"
}

# 安装预设应用
install_preset_apps() {
    if [[ -n "$INSTALL_APPS" ]]; then
        log INFO "安装预设应用..."
        
        # 等待面板完全启动
        sleep 10
        
        # 分割应用列表
        IFS=',' read -ra APPS <<< "$INSTALL_APPS"
        
        for app in "${APPS[@]}"; do
            app=$(echo "$app" | tr -d ' ')
            log INFO "安装应用: $app"
            
            # 使用1pctl安装应用
            1pctl app install "$app" || log WARNING "$app 安装失败"
        done
        
        log SUCCESS "应用安装完成"
    fi
}

# 创建管理脚本
create_management_scripts() {
    log INFO "创建管理脚本..."
    
    # 创建面板信息查看脚本
    cat > /usr/local/bin/1panel-info << EOF
#!/bin/bash
echo "1Panel面板登录信息:"
echo "===================="
echo "面板地址: http://\$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print \$1}'):$PANEL_PORT/$PANEL_ENTRANCE"
if [[ "$ENABLE_SSL" == "true" ]]; then
    echo "SSL地址: https://\$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print \$1}'):$PANEL_PORT/$PANEL_ENTRANCE"
fi
echo "用户名: $PANEL_USERNAME"
echo "密码: $PANEL_PASSWORD"
echo "===================="
echo "管理命令: 1pctl"
EOF
    chmod +x /usr/local/bin/1panel-info
    
    # 创建备份脚本
    cat > /usr/local/bin/1panel-backup << 'EOF'
#!/bin/bash
BACKUP_FILE="$BACKUP_DIR/1panel_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$BACKUP_FILE" -C "$INSTALL_DIR" 1panel
echo "备份完成: $BACKUP_FILE"
# 清理7天前的备份
find "$BACKUP_DIR" -name "1panel_backup_*.tar.gz" -mtime +7 -delete
EOF
    chmod +x /usr/local/bin/1panel-backup
    
    # 添加定时备份任务
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/1panel-backup") | crontab -
    
    log SUCCESS "管理脚本创建完成"
}

# 保存安装信息
save_install_info() {
    local info_file="$CONFIG_DIR/install.info"
    local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    cat > "$info_file" << EOF
# 1Panel安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')

面板版本: $PANEL_VERSION
安装目录: $INSTALL_DIR/1panel
面板端口: $PANEL_PORT
安全入口: /$PANEL_ENTRANCE
管理员用户: $PANEL_USERNAME
管理员密码: $PANEL_PASSWORD
SSL状态: $ENABLE_SSL

面板地址: http://${server_ip}:${PANEL_PORT}/${PANEL_ENTRANCE}
$([ "$ENABLE_SSL" == "true" ] && echo "SSL地址: https://${server_ip}:${PANEL_PORT}/${PANEL_ENTRANCE}")

管理命令:
  1pctl              # 命令行管理工具
  1panel-info        # 查看登录信息  
  1panel-backup      # 备份面板数据

服务管理:
  systemctl start 1panel    # 启动服务
  systemctl stop 1panel     # 停止服务
  systemctl restart 1panel  # 重启服务
  systemctl status 1panel   # 查看状态

日志文件:
  $INSTALL_DIR/1panel/logs/

配置文件:
  $CONFIG_DIR/app.yaml
EOF
    
    chmod 600 "$info_file"
}

# 显示安装信息
show_installation_info() {
    local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}1Panel安装成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}面板访问信息:${NC}"
    echo -e "${YELLOW}外网地址:${NC} http://${server_ip}:${PANEL_PORT}/${PANEL_ENTRANCE}"
    echo -e "${YELLOW}内网地址:${NC} http://$(hostname -I | awk '{print $1}'):${PANEL_PORT}/${PANEL_ENTRANCE}"
    if [[ $ENABLE_SSL == true ]]; then
        echo -e "${YELLOW}SSL地址:${NC} https://${server_ip}:${PANEL_PORT}/${PANEL_ENTRANCE}"
    fi
    echo
    echo -e "${YELLOW}登录用户:${NC} $PANEL_USERNAME"
    echo -e "${YELLOW}登录密码:${NC} $PANEL_PASSWORD"
    echo
    echo -e "${RED}安全提示:${NC}"
    echo "1. 请妥善保管登录信息，首次登录后建议修改密码"
    echo "2. 安全入口地址请勿泄露，可有效防止未授权访问"
    echo "3. 建议配置SSL证书以加密数据传输"
    echo
    echo -e "${BLUE}常用命令:${NC}"
    echo "  1pctl              # 命令行管理工具"
    echo "  1pctl status       # 查看服务状态"
    echo "  1pctl restart      # 重启面板服务"
    echo "  1pctl app list     # 查看已安装应用"
    echo "  1panel-info        # 查看登录信息"
    echo
    if [[ -n "$INSTALL_APPS" ]]; then
        echo -e "${BLUE}已安装应用:${NC} $INSTALL_APPS"
        echo
    fi
    echo -e "${BLUE}官方文档:${NC} https://1panel.cn/docs/"
    echo -e "${BLUE}安装日志:${NC} $LOG_FILE"
    echo -e "${BLUE}配置信息:${NC} $CONFIG_DIR/install.info"
    echo
}

# 显示面板信息
show_panel_info() {
    if [[ ! -f "$CONFIG_DIR/install.info" ]]; then
        error_exit "1Panel未安装或配置文件不存在"
    fi
    
    echo -e "${BLUE}1Panel面板信息:${NC}"
    echo "========================================"
    cat "$CONFIG_DIR/install.info"
}

# 更新1Panel
update_1panel() {
    log INFO "检查更新..."
    
    # 获取当前版本
    local current_version=$($INSTALL_DIR/1panel/1panel version 2>/dev/null | grep -oP 'v[\d.]+' || echo "未知")
    local latest_version=$(get_latest_version)
    
    log INFO "当前版本: $current_version"
    log INFO "最新版本: $latest_version"
    
    if [[ "$current_version" == "$latest_version" ]]; then
        log SUCCESS "已是最新版本"
        return
    fi
    
    # 备份当前版本
    log INFO "备份当前版本..."
    /usr/local/bin/1panel-backup
    
    # 停止服务
    systemctl stop 1panel
    
    # 下载新版本
    PANEL_VERSION="$latest_version"
    download_1panel
    
    # 更新文件
    cp -f /tmp/1panel_install/1panel/1panel "$INSTALL_DIR/1panel/"
    cp -f /tmp/1panel_install/1panel/1pctl "$INSTALL_DIR/1panel/"
    chmod +x "$INSTALL_DIR/1panel/1panel"
    chmod +x "$INSTALL_DIR/1panel/1pctl"
    
    # 重启服务
    systemctl start 1panel
    
    # 清理临时文件
    rm -rf /tmp/1panel_install
    
    log SUCCESS "更新完成: $current_version -> $latest_version"
}

# 卸载1Panel
remove_1panel() {
    log WARNING "开始卸载1Panel..."
    
    echo -e "${YELLOW}此操作将删除1Panel及相关数据，是否继续？[y/N]:${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log INFO "用户取消卸载"
        exit 0
    fi
    
    echo -e "${YELLOW}是否保留应用数据？[y/N]:${NC} "
    read -r keep_data
    
    # 停止服务
    systemctl stop 1panel 2>/dev/null || true
    systemctl disable 1panel 2>/dev/null || true
    
    # 删除服务文件
    rm -f /etc/systemd/system/1panel.service
    systemctl daemon-reload
    
    # 删除程序文件
    rm -rf "$INSTALL_DIR/1panel"
    rm -f /usr/local/bin/1pctl
    rm -f /usr/local/bin/1panel-info
    rm -f /usr/local/bin/1panel-backup
    
    # 删除数据（如果用户选择）
    if [[ ! "$keep_data" =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        rm -rf "$APP_DIR"
        rm -rf "$BACKUP_DIR"
        rm -rf "$CONFIG_DIR"
    else
        log INFO "应用数据已保留在: $DATA_DIR"
    fi
    
    # 删除定时任务
    crontab -l 2>/dev/null | grep -v "1panel-backup" | crontab - || true
    
    log SUCCESS "1Panel卸载完成"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                PANEL_VERSION="$2"
                shift 2
                ;;
            --port)
                PANEL_PORT="$2"
                shift 2
                ;;
            --entrance)
                PANEL_ENTRANCE="$2"
                shift 2
                ;;
            --username)
                PANEL_USERNAME="$2"
                shift 2
                ;;
            --password)
                PANEL_PASSWORD="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --cn)
                USE_CN_MIRROR=true
                shift
                ;;
            --apps)
                INSTALL_APPS="$2"
                shift 2
                ;;
            --ssl)
                ENABLE_SSL=true
                shift
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --update)
                ACTION="update"
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
    
    # 更新路径变量
    CONFIG_DIR="$INSTALL_DIR/1panel/conf"
    DATA_DIR="$INSTALL_DIR/1panel/data"
    APP_DIR="$INSTALL_DIR/1panel/apps"
    BACKUP_DIR="$INSTALL_DIR/1panel/backup"
    
    # 执行操作
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            # 检测系统
            detect_system
            check_compatibility
            check_existing_installation
            check_port
            
            # 安装流程
            install_dependencies
            check_docker
            download_1panel
            install_1panel
            generate_config
            create_systemd_service
            init_database
            configure_firewall
            install_preset_apps
            create_management_scripts
            save_install_info
            
            # 清理
            rm -rf /tmp/1panel_install
            
            # 显示信息
            show_installation_info
            ;;
            
        remove)
            remove_1panel
            ;;
            
        update)
            update_1panel
            ;;
            
        info)
            show_panel_info
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"