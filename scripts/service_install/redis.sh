#!/bin/bash
#==============================================================================
# 脚本名称: install_redis.sh
# 脚本描述: Redis安装配置脚本 - 支持单机、主从、哨兵和集群模式
# 脚本路径: vps_scripts/scripts/service_install/install_redis.sh
# 作者: Jensfrank
# 使用方法: bash install_redis.sh [选项]
# 选项: 
#   --version VERSION    指定Redis版本 (如: 6.2, 7.0, 7.2, latest)
#   --method METHOD      安装方式 (system/source/docker, 默认: source)
#   --port PORT          Redis端口 (默认: 6379)
#   --password PASSWORD  设置密码 (默认: 随机生成)
#   --mode MODE          运行模式 (standalone/master/slave/sentinel)
#   --data-dir DIR       数据目录 (默认: /var/lib/redis)
#   --memory-limit SIZE  内存限制 (如: 1gb, 512mb)
#   --persistence TYPE   持久化方式 (rdb/aof/both/none)
#   --cn                 使用国内镜像源
#   --with-tools         安装管理工具
#   --remove             卸载Redis
#   --status             查看服务状态
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
readonly SCRIPT_NAME="Redis安装配置脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/redis_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
REDIS_VERSION="7.2"
INSTALL_METHOD="source"
REDIS_PORT=6379
REDIS_PASSWORD=""
REDIS_MODE="standalone"
DATA_DIR="/var/lib/redis"
MEMORY_LIMIT=""
PERSISTENCE_TYPE="both"
USE_CN_MIRROR=false
INSTALL_TOOLS=false
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""

# Redis相关路径
REDIS_PREFIX="/usr/local"
REDIS_CONFIG_DIR="/etc/redis"
REDIS_LOG_DIR="/var/log/redis"
REDIS_PID_FILE="/var/run/redis_${REDIS_PORT}.pid"

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --version VERSION    指定Redis版本
                        - 6.2: 稳定版本
                        - 7.0: 较新版本
                        - 7.2: 最新稳定版（推荐）
                        - latest: 最新版本
                        默认: 7.2
    
    --method METHOD      安装方式
                        - system: 使用系统包管理器
                        - source: 从源码编译（推荐）
                        - docker: 使用Docker容器
                        默认: source
    
    --port PORT         Redis监听端口（默认: 6379）
    --password PASSWORD 设置访问密码（默认: 随机生成）
    
    --mode MODE         运行模式
                        - standalone: 单机模式（默认）
                        - master: 主节点模式
                        - slave: 从节点模式
                        - sentinel: 哨兵模式
    
    --data-dir DIR      数据存储目录（默认: /var/lib/redis）
    --memory-limit SIZE 内存限制（如: 1gb, 512mb）
    
    --persistence TYPE  持久化方式
                        - rdb: 快照持久化
                        - aof: 追加日志持久化
                        - both: 同时启用（默认）
                        - none: 不持久化
    
    --cn                使用国内镜像源
    --with-tools        安装Redis管理工具
    --remove            卸载Redis
    --status            查看服务状态
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                              # 默认安装
    $(basename "$0") --version 7.2 --cn           # 使用国内源安装7.2版本
    $(basename "$0") --password mypass123         # 设置自定义密码
    $(basename "$0") --mode master --port 6380    # 主节点模式，自定义端口
    $(basename "$0") --memory-limit 2gb           # 限制内存使用

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

# 生成随机密码
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
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
    
    ARCH=$(uname -m)
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查端口占用
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$REDIS_PORT "; then
        error_exit "端口 $REDIS_PORT 已被占用，请使用 --port 指定其他端口"
    fi
}

# 安装编译依赖
install_dependencies() {
    log INFO "安装编译依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq \
                build-essential \
                tcl \
                wget \
                make \
                gcc \
                libc6-dev \
                libssl-dev \
                pkg-config
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y -q \
                gcc \
                gcc-c++ \
                make \
                tcl \
                wget \
                openssl-devel
            ;;
        fedora)
            dnf install -y -q \
                gcc \
                gcc-c++ \
                make \
                tcl \
                wget \
                openssl-devel
            ;;
    esac
    
    log SUCCESS "依赖安装完成"
}

# 创建Redis用户
create_redis_user() {
    if ! id -u redis &>/dev/null; then
        log INFO "创建redis用户..."
        useradd -r -s /sbin/nologin redis
    fi
}

# 获取Redis版本
get_redis_version() {
    local version=$1
    
    if [[ "$version" == "latest" ]]; then
        # 获取最新稳定版本
        version=$(curl -s http://download.redis.io/redis-stable/VERSION | head -1)
        if [[ -z "$version" ]]; then
            version="7.2.3"  # 默认版本
        fi
    else
        # 获取指定大版本的最新小版本
        case $version in
            6.2) version="6.2.14" ;;
            7.0) version="7.0.15" ;;
            7.2) version="7.2.3" ;;
            *) ;;  # 保持原样
        esac
    fi
    
    echo "$version"
}

# 通过系统包管理器安装
install_via_system() {
    log INFO "使用系统包管理器安装Redis..."
    
    case $OS in
        ubuntu|debian)
            # 添加Redis官方仓库
            curl -fsSL https://packages.redis.io/gpg | apt-key add -
            echo "deb https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
            apt-get update -qq
            apt-get install -y redis
            ;;
        centos|rhel|almalinux|rocky)
            # 添加EPEL和Remi仓库
            yum install -y epel-release
            if [[ "$VERSION" == "7" ]]; then
                yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
            else
                dnf install -y https://rpms.remirepo.net/enterprise/remi-release-${VERSION}.rpm
            fi
            yum install -y redis
            ;;
        fedora)
            dnf install -y redis
            ;;
    esac
    
    log SUCCESS "Redis系统包安装完成"
}

# 从源码编译安装
install_from_source() {
    log INFO "从源码编译安装Redis..."
    
    install_dependencies
    
    local version=$(get_redis_version "$REDIS_VERSION")
    local download_url="http://download.redis.io/releases/redis-${version}.tar.gz"
    
    if [[ $USE_CN_MIRROR == true ]]; then
        download_url="https://mirrors.huaweicloud.com/redis/redis-${version}.tar.gz"
    fi
    
    local temp_dir="/tmp/redis_build"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log INFO "下载Redis ${version}..."
    wget -q --show-progress "$download_url" -O redis-${version}.tar.gz || error_exit "下载失败"
    
    log INFO "解压源码..."
    tar -xzf redis-${version}.tar.gz
    cd redis-${version}
    
    log INFO "编译安装..."
    make BUILD_TLS=yes
    make test || log WARNING "测试未通过，继续安装"
    make PREFIX=$REDIS_PREFIX install
    
    # 复制配置文件
    mkdir -p "$REDIS_CONFIG_DIR"
    cp redis.conf "$REDIS_CONFIG_DIR/redis.conf.default"
    cp sentinel.conf "$REDIS_CONFIG_DIR/sentinel.conf.default" 2>/dev/null || true
    
    # 复制工具脚本
    cp src/redis-trib.rb $REDIS_PREFIX/bin/ 2>/dev/null || true
    
    # 创建符号链接
    for cmd in redis-server redis-cli redis-sentinel redis-check-aof redis-check-rdb redis-benchmark; do
        ln -sf $REDIS_PREFIX/bin/$cmd /usr/local/bin/$cmd
    done
    
    # 清理
    cd /
    rm -rf "$temp_dir"
    
    log SUCCESS "Redis ${version} 源码编译安装完成"
}

# 通过Docker安装
install_via_docker() {
    log INFO "使用Docker安装Redis..."
    
    if ! command_exists docker; then
        error_exit "Docker未安装，请先安装Docker"
    fi
    
    local version=$(get_redis_version "$REDIS_VERSION")
    local image="redis:${version}-alpine"
    
    # 创建数据目录
    mkdir -p "$DATA_DIR"
    mkdir -p "$REDIS_CONFIG_DIR"
    
    # 生成Docker配置
    generate_redis_config
    
    # 创建Docker Compose文件
    cat > "$REDIS_CONFIG_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  redis:
    image: ${image}
    container_name: redis_${REDIS_PORT}
    restart: unless-stopped
    ports:
      - "${REDIS_PORT}:6379"
    volumes:
      - ${REDIS_CONFIG_DIR}/redis.conf:/usr/local/etc/redis/redis.conf:ro
      - ${DATA_DIR}:/data
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - redis_network

networks:
  redis_network:
    driver: bridge
EOF
    
    # 启动容器
    cd "$REDIS_CONFIG_DIR"
    docker-compose up -d
    
    log SUCCESS "Redis Docker容器启动成功"
}

# 生成Redis配置文件
generate_redis_config() {
    log INFO "生成Redis配置文件..."
    
    # 设置密码
    if [[ -z "$REDIS_PASSWORD" ]]; then
        REDIS_PASSWORD=$(generate_password)
        log INFO "生成Redis密码: $REDIS_PASSWORD"
    fi
    
    # 基础配置
    cat > "$REDIS_CONFIG_DIR/redis.conf" << EOF
# Redis配置文件
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 网络配置
bind 0.0.0.0
protected-mode yes
port $REDIS_PORT
tcp-backlog 511
timeout 0
tcp-keepalive 300

# 通用配置
daemonize yes
supervised no
pidfile $REDIS_PID_FILE
loglevel notice
logfile $REDIS_LOG_DIR/redis.log
databases 16
always-show-logo no

# 安全配置
requirepass $REDIS_PASSWORD

# 持久化配置
dir $DATA_DIR
EOF

    # RDB持久化配置
    if [[ "$PERSISTENCE_TYPE" == "rdb" ]] || [[ "$PERSISTENCE_TYPE" == "both" ]]; then
        cat >> "$REDIS_CONFIG_DIR/redis.conf" << EOF

# RDB持久化
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
EOF
    else
        echo "save \"\"" >> "$REDIS_CONFIG_DIR/redis.conf"
    fi
    
    # AOF持久化配置
    if [[ "$PERSISTENCE_TYPE" == "aof" ]] || [[ "$PERSISTENCE_TYPE" == "both" ]]; then
        cat >> "$REDIS_CONFIG_DIR/redis.conf" << EOF

# AOF持久化
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
EOF
    fi
    
    # 内存配置
    if [[ -n "$MEMORY_LIMIT" ]]; then
        cat >> "$REDIS_CONFIG_DIR/redis.conf" << EOF

# 内存配置
maxmemory $MEMORY_LIMIT
maxmemory-policy allkeys-lru
EOF
    fi
    
    # 慢查询配置
    cat >> "$REDIS_CONFIG_DIR/redis.conf" << EOF

# 慢查询配置
slowlog-log-slower-than 10000
slowlog-max-len 128

# 延迟监控
latency-monitor-threshold 0

# 事件通知
notify-keyspace-events ""

# 高级配置
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes

# LFU设置
lfu-log-factor 10
lfu-decay-time 1
EOF

    # 主从配置
    if [[ "$REDIS_MODE" == "slave" ]]; then
        cat >> "$REDIS_CONFIG_DIR/redis.conf" << EOF

# 主从复制配置
# replicaof <masterip> <masterport>
# masterauth <master-password>
replica-read-only yes
replica-serve-stale-data yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-ping-replica-period 10
repl-timeout 60
repl-disable-tcp-nodelay no
repl-backlog-size 1mb
repl-backlog-ttl 3600
EOF
    fi
    
    # 设置权限
    chmod 640 "$REDIS_CONFIG_DIR/redis.conf"
    chown redis:redis "$REDIS_CONFIG_DIR/redis.conf"
    
    log SUCCESS "Redis配置文件生成完成"
}

# 创建systemd服务
create_systemd_service() {
    log INFO "创建systemd服务..."
    
    cat > /etc/systemd/system/redis.service << EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
ExecStart=$REDIS_PREFIX/bin/redis-server $REDIS_CONFIG_DIR/redis.conf
ExecStop=$REDIS_PREFIX/bin/redis-cli -p $REDIS_PORT shutdown
Restart=always
RestartSec=3
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755
PIDFile=$REDIS_PID_FILE

# 限制
LimitNOFILE=65535

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $REDIS_LOG_DIR /var/run/redis

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable redis
    
    log SUCCESS "systemd服务创建完成"
}

# 配置系统优化
configure_system() {
    log INFO "优化系统配置..."
    
    # 内核参数优化
    cat >> /etc/sysctl.conf << EOF

# Redis优化
vm.overcommit_memory = 1
net.core.somaxconn = 511
net.ipv4.tcp_max_syn_backlog = 511
EOF
    
    sysctl -p
    
    # 禁用透明大页
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.local
    fi
    
    # 创建日志轮转配置
    cat > /etc/logrotate.d/redis << EOF
$REDIS_LOG_DIR/*.log {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        systemctl reload redis > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log SUCCESS "系统优化完成"
}

# 启动Redis服务
start_redis() {
    log INFO "启动Redis服务..."
    
    # 创建必要的目录
    mkdir -p "$DATA_DIR" "$REDIS_LOG_DIR" /var/run/redis
    chown -R redis:redis "$DATA_DIR" "$REDIS_LOG_DIR" /var/run/redis
    
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        cd "$REDIS_CONFIG_DIR"
        docker-compose up -d
    else
        systemctl start redis
    fi
    
    # 等待服务启动
    sleep 2
    
    # 检查服务状态
    if redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
        log SUCCESS "Redis服务启动成功"
    else
        error_exit "Redis服务启动失败"
    fi
}

# 安装Redis工具
install_redis_tools() {
    if [[ $INSTALL_TOOLS == true ]]; then
        log INFO "安装Redis管理工具..."
        
        # 安装redis-tools
        case $OS in
            ubuntu|debian)
                apt-get install -y redis-tools
                ;;
            centos|rhel|almalinux|rocky|fedora)
                # 工具已包含在redis包中
                ;;
        esac
        
        # 创建便捷脚本
        cat > /usr/local/bin/redis-stats << 'EOF'
#!/bin/bash
# Redis状态监控脚本
redis-cli -p ${REDIS_PORT:-6379} ${REDIS_PASSWORD:+-a $REDIS_PASSWORD} info
EOF
        chmod +x /usr/local/bin/redis-stats
        
        # 创建备份脚本
        cat > /usr/local/bin/redis-backup << 'EOF'
#!/bin/bash
# Redis备份脚本
BACKUP_DIR="/var/backups/redis"
mkdir -p "$BACKUP_DIR"
redis-cli -p ${REDIS_PORT:-6379} ${REDIS_PASSWORD:+-a $REDIS_PASSWORD} BGSAVE
sleep 5
cp ${DATA_DIR:-/var/lib/redis}/dump.rdb "$BACKUP_DIR/dump_$(date +%Y%m%d_%H%M%S).rdb"
find "$BACKUP_DIR" -name "dump_*.rdb" -mtime +7 -delete
EOF
        chmod +x /usr/local/bin/redis-backup
        
        # 添加定时备份
        echo "0 2 * * * /usr/local/bin/redis-backup" | crontab -u redis -
        
        log SUCCESS "Redis工具安装完成"
    fi
}

# 验证安装
verify_installation() {
    log INFO "验证Redis安装..."
    
    # 检查Redis版本
    if command_exists redis-server; then
        local version=$(redis-server --version | grep -oP 'v=\K[\d.]+')
        log SUCCESS "Redis已安装: v$version"
    else
        error_exit "Redis安装失败"
    fi
    
    # 测试连接
    if redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" ping 2>/dev/null | grep -q PONG; then
        log SUCCESS "Redis连接测试成功"
    else
        log WARNING "Redis连接测试失败"
    fi
    
    # 显示信息
    redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" INFO server 2>/dev/null | grep -E "redis_version|redis_mode|os"
}

# 查看服务状态
show_status() {
    echo -e "${BLUE}Redis服务状态:${NC}"
    echo "----------------------------------------"
    
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        docker ps -a | grep redis || echo "Redis容器未运行"
    else
        systemctl status redis --no-pager || echo "Redis服务未运行"
    fi
    
    echo
    echo -e "${BLUE}Redis信息:${NC}"
    redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" INFO server 2>/dev/null | head -20 || echo "无法连接到Redis"
}

# 卸载Redis
remove_redis() {
    log WARNING "开始卸载Redis..."
    
    # 停止服务
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        cd "$REDIS_CONFIG_DIR" 2>/dev/null && docker-compose down -v
    else
        systemctl stop redis 2>/dev/null || true
        systemctl disable redis 2>/dev/null || true
    fi
    
    # 卸载软件包
    case $OS in
        ubuntu|debian)
            apt-get purge -y redis* || true
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ $OS == "fedora" ]] || [[ $VERSION -ge 8 ]]; then
                dnf remove -y redis* || true
            else
                yum remove -y redis* || true
            fi
            ;;
    esac
    
    # 删除文件
    rm -rf $REDIS_CONFIG_DIR
    rm -rf $DATA_DIR
    rm -rf $REDIS_LOG_DIR
    rm -f /etc/systemd/system/redis.service
    rm -f $REDIS_PREFIX/bin/redis-*
    rm -f /usr/local/bin/redis-*
    
    # 删除用户
    userdel -r redis 2>/dev/null || true
    
    log SUCCESS "Redis卸载完成"
}

# 显示安装信息
show_installation_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Redis安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}连接信息:${NC}"
    echo -e "  主机: 127.0.0.1"
    echo -e "  端口: $REDIS_PORT"
    echo -e "  密码: $REDIS_PASSWORD"
    echo
    echo -e "${BLUE}配置文件:${NC}"
    echo -e "  $REDIS_CONFIG_DIR/redis.conf"
    echo
    echo -e "${BLUE}数据目录:${NC}"
    echo -e "  $DATA_DIR"
    echo
    echo -e "${BLUE}日志文件:${NC}"
    echo -e "  $REDIS_LOG_DIR/redis.log"
    echo
    echo -e "${BLUE}服务管理:${NC}"
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        echo "  启动: cd $REDIS_CONFIG_DIR && docker-compose up -d"
        echo "  停止: cd $REDIS_CONFIG_DIR && docker-compose down"
        echo "  重启: cd $REDIS_CONFIG_DIR && docker-compose restart"
    else
        echo "  启动: systemctl start redis"
        echo "  停止: systemctl stop redis"
        echo "  重启: systemctl restart redis"
        echo "  状态: systemctl status redis"
    fi
    echo
    echo -e "${BLUE}客户端连接:${NC}"
    echo "  redis-cli -p $REDIS_PORT -a $REDIS_PASSWORD"
    echo
    if [[ $INSTALL_TOOLS == true ]]; then
        echo -e "${BLUE}管理工具:${NC}"
        echo "  redis-stats    # 查看Redis状态"
        echo "  redis-backup   # 备份Redis数据"
        echo
    fi
    echo -e "${BLUE}配置信息已保存到:${NC}"
    echo "  $REDIS_CONFIG_DIR/redis.info"
    echo
    echo -e "${BLUE}安装日志:${NC}"
    echo "  $LOG_FILE"
    echo
}

# 保存配置信息
save_config_info() {
    cat > "$REDIS_CONFIG_DIR/redis.info" << EOF
# Redis安装信息
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

安装方式: $INSTALL_METHOD
Redis版本: $(redis-server --version | grep -oP 'v=\K[\d.]+' || echo "未知")
监听端口: $REDIS_PORT
访问密码: $REDIS_PASSWORD
运行模式: $REDIS_MODE
数据目录: $DATA_DIR
持久化方式: $PERSISTENCE_TYPE
内存限制: ${MEMORY_LIMIT:-无限制}

连接命令:
redis-cli -p $REDIS_PORT -a $REDIS_PASSWORD

配置文件: $REDIS_CONFIG_DIR/redis.conf
日志文件: $REDIS_LOG_DIR/redis.log
PID文件: $REDIS_PID_FILE
EOF
    
    chmod 600 "$REDIS_CONFIG_DIR/redis.info"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                REDIS_VERSION="$2"
                shift 2
                ;;
            --method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --port)
                REDIS_PORT="$2"
                shift 2
                ;;
            --password)
                REDIS_PASSWORD="$2"
                shift 2
                ;;
            --mode)
                REDIS_MODE="$2"
                shift 2
                ;;
            --data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            --memory-limit)
                MEMORY_LIMIT="$2"
                shift 2
                ;;
            --persistence)
                PERSISTENCE_TYPE="$2"
                shift 2
                ;;
            --cn)
                USE_CN_MIRROR=true
                shift
                ;;
            --with-tools)
                INSTALL_TOOLS=true
                shift
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --status)
                ACTION="status"
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
    
    # 检测系统
    detect_system
    
    # 执行操作
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            # 检查端口
            check_port
            
            # 创建用户
            create_redis_user
            
            # 根据方法安装Redis
            case $INSTALL_METHOD in
                system)
                    install_via_system
                    ;;
                source)
                    install_from_source
                    ;;
                docker)
                    install_via_docker
                    ;;
                *)
                    error_exit "不支持的安装方法: $INSTALL_METHOD"
                    ;;
            esac
            
            # 配置Redis
            if [[ "$INSTALL_METHOD" != "docker" ]]; then
                generate_redis_config
                create_systemd_service
                configure_system
                start_redis
            fi
            
            # 安装工具
            install_redis_tools
            
            # 验证安装
            verify_installation
            
            # 保存配置信息
            save_config_info
            
            # 显示安装信息
            show_installation_info
            ;;
            
        remove)
            remove_redis
            ;;
            
        status)
            show_status
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"
