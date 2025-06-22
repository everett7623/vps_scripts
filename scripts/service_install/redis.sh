#!/bin/bash
#==============================================================================
# 脚本名称: redis.sh
# 脚本描述: Redis 内存数据库安装配置脚本 - 支持单机、主从、哨兵模式
# 脚本路径: vps_scripts/scripts/service_install/redis.sh
# 作者: Jensfrank
# 使用方法: bash redis.sh [选项]
# 选项说明:
#   --version <版本>     Redis版本 (如: 7.2.3, 6.2.14)
#   --port <端口>        Redis端口 (默认: 6379)
#   --password <密码>    设置Redis密码
#   --mode <模式>        部署模式 (standalone/master/slave/sentinel)
#   --master-host <IP>   主节点地址 (slave模式必需)
#   --data-dir <路径>    数据存储路径 (默认: /var/lib/redis)
#   --max-memory <大小>  最大内存限制 (如: 1G, 512M)
#   --enable-aof        启用AOF持久化
#   --force             强制重新安装
#   --help              显示帮助信息
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
REDIS_VERSION=""
REDIS_PORT="6379"
REDIS_PASSWORD=""
DEPLOY_MODE="standalone"
MASTER_HOST=""
DATA_DIR="/var/lib/redis"
MAX_MEMORY=""
ENABLE_AOF=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/redis_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DEFAULT_REDIS_VERSION="7.2.3"
REDIS_USER="redis"
CONFIG_DIR="/etc/redis"
LOG_DIR="/var/log/redis"
PID_FILE="/var/run/redis/redis-server.pid"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Redis 安装配置脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash redis.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --version <版本>     Redis版本 (如: 7.2.3, 6.2.14)"
    echo "  --port <端口>        Redis端口 (默认: 6379)"
    echo "  --password <密码>    设置Redis密码"
    echo "  --mode <模式>        部署模式:"
    echo "                      standalone - 单机模式 (默认)"
    echo "                      master     - 主节点模式"
    echo "                      slave      - 从节点模式"
    echo "                      sentinel   - 哨兵模式"
    echo "  --master-host <IP>   主节点地址 (slave模式必需)"
    echo "  --data-dir <路径>    数据存储路径"
    echo "  --max-memory <大小>  最大内存限制 (如: 1G, 512M)"
    echo "  --enable-aof        启用AOF持久化"
    echo "  --force             强制重新安装"
    echo "  --help              显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash redis.sh                                           # 默认安装"
    echo "  bash redis.sh --version 7.2.3 --password mypass"
    echo "  bash redis.sh --mode slave --master-host 192.168.1.100"
    echo "  bash redis.sh --max-memory 2G --enable-aof"
    echo "  bash redis.sh --mode sentinel --port 26379"
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
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 安装基础依赖
install_dependencies() {
    log "${YELLOW}正在安装基础依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y build-essential tcl wget curl
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum groupinstall -y "Development Tools"
            yum install -y tcl wget curl
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}基础依赖安装完成${NC}"
}

# 检查Redis是否已安装
check_redis_installed() {
    if command -v redis-server &> /dev/null || systemctl list-units --type=service | grep -q redis; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到Redis已安装${NC}"
            redis-server --version
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop redis 2>/dev/null || true
        systemctl stop redis-server 2>/dev/null || true
    fi
}

# 创建Redis用户
create_redis_user() {
    if ! id "$REDIS_USER" &>/dev/null; then
        log "${CYAN}创建Redis用户...${NC}"
        useradd --system --home-dir /var/lib/redis --shell /bin/false $REDIS_USER
    fi
}

# 获取最新Redis版本
get_latest_redis_version() {
    log "${CYAN}获取最新Redis版本...${NC}"
    
    # 从Redis下载页面获取最新稳定版本
    local latest=$(curl -s http://download.redis.io/redis-stable/VERSION | head -1)
    
    if [[ -n "$latest" ]]; then
        REDIS_VERSION="$latest"
    else
        REDIS_VERSION="$DEFAULT_REDIS_VERSION"
    fi
    
    log "${GREEN}将安装Redis版本: ${REDIS_VERSION}${NC}"
}

# 编译安装Redis
install_redis() {
    # 如果没有指定版本，获取最新版本
    if [[ -z "$REDIS_VERSION" ]]; then
        get_latest_redis_version
    fi
    
    log "${CYAN}开始安装 Redis ${REDIS_VERSION}...${NC}"
    
    # 下载Redis源码
    cd /tmp
    wget "http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz"
    
    if [[ ! -f "redis-${REDIS_VERSION}.tar.gz" ]]; then
        log "${RED}错误: Redis下载失败${NC}"
        exit 1
    fi
    
    # 解压并编译
    tar -xzf "redis-${REDIS_VERSION}.tar.gz"
    cd "redis-${REDIS_VERSION}"
    
    log "${YELLOW}编译Redis...${NC}"
    make
    make test
    make install PREFIX=/usr/local
    
    # 创建软链接
    ln -sf /usr/local/bin/redis-server /usr/bin/redis-server
    ln -sf /usr/local/bin/redis-cli /usr/bin/redis-cli
    ln -sf /usr/local/bin/redis-sentinel /usr/bin/redis-sentinel
    ln -sf /usr/local/bin/redis-benchmark /usr/bin/redis-benchmark
    ln -sf /usr/local/bin/redis-check-aof /usr/bin/redis-check-aof
    ln -sf /usr/local/bin/redis-check-rdb /usr/bin/redis-check-rdb
    
    # 清理临时文件
    cd /
    rm -rf /tmp/redis-${REDIS_VERSION}*
    
    log "${GREEN}Redis ${REDIS_VERSION} 安装完成${NC}"
}

# 创建目录结构
create_directories() {
    log "${CYAN}创建Redis目录结构...${NC}"
    
    # 创建必要的目录
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "/var/run/redis"
    
    # 设置权限
    chown -R $REDIS_USER:$REDIS_USER "$DATA_DIR"
    chown -R $REDIS_USER:$REDIS_USER "$LOG_DIR"
    chown -R $REDIS_USER:$REDIS_USER "/var/run/redis"
    
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$DATA_DIR"
    chmod 755 "$LOG_DIR"
}

# 生成Redis配置文件
generate_redis_config() {
    log "${CYAN}生成Redis配置文件...${NC}"
    
    local config_file="$CONFIG_DIR/redis.conf"
    
    cat > "$config_file" << EOF
# Redis配置文件
# 生成时间: $(date)

# 基础配置
bind 0.0.0.0
protected-mode yes
port $REDIS_PORT
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised systemd
pidfile $PID_FILE
loglevel notice
logfile $LOG_DIR/redis-server.log

# 数据持久化
dir $DATA_DIR
dbfilename dump.rdb
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes

EOF

    # 密码配置
    if [[ -n "$REDIS_PASSWORD" ]]; then
        echo "requirepass $REDIS_PASSWORD" >> "$config_file"
        echo "masterauth $REDIS_PASSWORD" >> "$config_file"
    fi
    
    # 内存限制
    if [[ -n "$MAX_MEMORY" ]]; then
        cat >> "$config_file" << EOF

# 内存管理
maxmemory $MAX_MEMORY
maxmemory-policy allkeys-lru
EOF
    fi
    
    # AOF配置
    if [[ "$ENABLE_AOF" = true ]]; then
        cat >> "$config_file" << EOF

# AOF持久化
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
EOF
    else
        echo "appendonly no" >> "$config_file"
    fi
    
    # 主从配置
    if [[ "$DEPLOY_MODE" = "slave" ]] && [[ -n "$MASTER_HOST" ]]; then
        cat >> "$config_file" << EOF

# 主从复制
replicaof $MASTER_HOST $REDIS_PORT
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
EOF
    fi
    
    # 高级配置
    cat >> "$config_file" << EOF

# 慢查询日志
slowlog-log-slower-than 10000
slowlog-max-len 128

# 客户端输出缓冲限制
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# 其他设置
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
EOF
    
    # 设置配置文件权限
    chmod 640 "$config_file"
    chown root:$REDIS_USER "$config_file"
}

# 生成哨兵配置文件
generate_sentinel_config() {
    log "${CYAN}生成Redis Sentinel配置文件...${NC}"
    
    local sentinel_config="$CONFIG_DIR/sentinel.conf"
    local sentinel_port="${REDIS_PORT:-26379}"
    
    cat > "$sentinel_config" << EOF
# Redis Sentinel配置文件
# 生成时间: $(date)

port $sentinel_port
daemonize no
pidfile /var/run/redis/redis-sentinel.pid
logfile $LOG_DIR/redis-sentinel.log
dir $DATA_DIR

# 监控主节点
# sentinel monitor <master-name> <ip> <port> <quorum>
# 需要手动配置主节点信息
# sentinel monitor mymaster 127.0.0.1 6379 2

# Sentinel选项
sentinel down-after-milliseconds mymaster 30000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 180000

# 密码认证
# sentinel auth-pass mymaster yourpassword

# 通知脚本
# sentinel notification-script mymaster /var/redis/notify.sh
# sentinel client-reconfig-script mymaster /var/redis/reconfig.sh
EOF
    
    chmod 640 "$sentinel_config"
    chown root:$REDIS_USER "$sentinel_config"
}

# 创建systemd服务文件
create_systemd_service() {
    log "${CYAN}创建systemd服务文件...${NC}"
    
    # Redis服务文件
    cat > /etc/systemd/system/redis.service << EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/redis-server $CONFIG_DIR/redis.conf
ExecStop=/usr/bin/redis-cli shutdown
TimeoutStopSec=0
Restart=on-failure
User=$REDIS_USER
Group=$REDIS_USER
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $LOG_DIR /var/run/redis

[Install]
WantedBy=multi-user.target
EOF
    
    # 如果是哨兵模式，创建哨兵服务
    if [[ "$DEPLOY_MODE" = "sentinel" ]]; then
        cat > /etc/systemd/system/redis-sentinel.service << EOF
[Unit]
Description=Redis Sentinel
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/redis-sentinel $CONFIG_DIR/sentinel.conf
ExecStop=/usr/bin/redis-cli -p ${REDIS_PORT:-26379} shutdown
TimeoutStopSec=0
Restart=on-failure
User=$REDIS_USER
Group=$REDIS_USER
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # 重新加载systemd
    systemctl daemon-reload
}

# 配置内核参数
configure_kernel_params() {
    log "${CYAN}优化内核参数...${NC}"
    
    # 备份原有配置
    cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d_%H%M%S)
    
    # Redis推荐的内核参数
    cat >> /etc/sysctl.conf << EOF

# Redis优化参数
vm.overcommit_memory = 1
net.core.somaxconn = 1024
EOF
    
    # 应用参数
    sysctl -p
    
    # 禁用透明大页
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    
    # 持久化设置
    cat > /etc/rc.local << EOF
#!/bin/bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
exit 0
EOF
    chmod +x /etc/rc.local
}

# 启动Redis服务
start_redis_service() {
    log "${CYAN}启动Redis服务...${NC}"
    
    if [[ "$DEPLOY_MODE" = "sentinel" ]]; then
        systemctl enable redis-sentinel
        systemctl start redis-sentinel
        
        # 检查服务状态
        sleep 2
        if systemctl is-active --quiet redis-sentinel; then
            log "${GREEN}Redis Sentinel服务启动成功${NC}"
        else
            log "${RED}Redis Sentinel服务启动失败${NC}"
            systemctl status redis-sentinel
        fi
    else
        systemctl enable redis
        systemctl start redis
        
        # 检查服务状态
        sleep 2
        if systemctl is-active --quiet redis; then
            log "${GREEN}Redis服务启动成功${NC}"
        else
            log "${RED}Redis服务启动失败${NC}"
            systemctl status redis
        fi
    fi
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Redis安装...${NC}"
    
    # 检查Redis版本
    redis_version=$(redis-server --version)
    log "${GREEN}${redis_version}${NC}"
    
    # 测试Redis连接
    if [[ "$DEPLOY_MODE" != "sentinel" ]]; then
        log "${CYAN}测试Redis连接...${NC}"
        
        if [[ -n "$REDIS_PASSWORD" ]]; then
            echo "AUTH $REDIS_PASSWORD" | redis-cli -p $REDIS_PORT
        fi
        
        # 测试基本操作
        test_result=$(redis-cli -p $REDIS_PORT ping)
        if [[ "$test_result" == "PONG" ]]; then
            log "${GREEN}Redis连接测试成功${NC}"
            
            # 显示Redis信息
            if [[ -n "$REDIS_PASSWORD" ]]; then
                redis-cli -p $REDIS_PORT -a "$REDIS_PASSWORD" INFO server | grep -E "redis_version|tcp_port|config_file"
            else
                redis-cli -p $REDIS_PORT INFO server | grep -E "redis_version|tcp_port|config_file"
            fi
        else
            log "${RED}Redis连接测试失败${NC}"
        fi
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Redis安装配置完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- Redis版本: ${REDIS_VERSION}"
    echo "- 部署模式: ${DEPLOY_MODE}"
    echo "- 监听端口: ${REDIS_PORT}"
    echo "- 数据目录: ${DATA_DIR}"
    echo "- 配置文件: ${CONFIG_DIR}/redis.conf"
    echo "- 日志文件: ${LOG_DIR}/redis-server.log"
    
    if [[ -n "$REDIS_PASSWORD" ]]; then
        echo "- 访问密码: ${REDIS_PASSWORD}"
    fi
    
    echo
    echo -e "${CYAN}服务管理命令:${NC}"
    if [[ "$DEPLOY_MODE" = "sentinel" ]]; then
        echo "- 启动服务: systemctl start redis-sentinel"
        echo "- 停止服务: systemctl stop redis-sentinel"
        echo "- 重启服务: systemctl restart redis-sentinel"
        echo "- 查看状态: systemctl status redis-sentinel"
        echo "- 查看日志: tail -f ${LOG_DIR}/redis-sentinel.log"
    else
        echo "- 启动服务: systemctl start redis"
        echo "- 停止服务: systemctl stop redis"
        echo "- 重启服务: systemctl restart redis"
        echo "- 查看状态: systemctl status redis"
        echo "- 查看日志: tail -f ${LOG_DIR}/redis-server.log"
    fi
    
    echo
    echo -e "${CYAN}客户端连接:${NC}"
    if [[ -n "$REDIS_PASSWORD" ]]; then
        echo "- 本地连接: redis-cli -p ${REDIS_PORT} -a ${REDIS_PASSWORD}"
        echo "- 远程连接: redis-cli -h <服务器IP> -p ${REDIS_PORT} -a ${REDIS_PASSWORD}"
    else
        echo "- 本地连接: redis-cli -p ${REDIS_PORT}"
        echo "- 远程连接: redis-cli -h <服务器IP> -p ${REDIS_PORT}"
    fi
    
    echo
    echo -e "${CYAN}常用Redis命令:${NC}"
    echo "- PING              # 测试连接"
    echo "- INFO              # 查看服务器信息"
    echo "- CONFIG GET *      # 查看所有配置"
    echo "- DBSIZE            # 查看key数量"
    echo "- FLUSHDB           # 清空当前数据库"
    echo "- FLUSHALL          # 清空所有数据库"
    echo "- SAVE              # 同步保存数据"
    echo "- BGSAVE            # 异步保存数据"
    
    if [[ "$DEPLOY_MODE" = "slave" ]]; then
        echo
        echo -e "${YELLOW}注意: 从节点已配置，请确保主节点 ${MASTER_HOST}:${REDIS_PORT} 可访问${NC}"
    fi
    
    if [[ "$DEPLOY_MODE" = "sentinel" ]]; then
        echo
        echo -e "${YELLOW}注意: 哨兵模式需要手动编辑 ${CONFIG_DIR}/sentinel.conf 配置监控的主节点${NC}"
    fi
    
    echo
    echo -e "${YELLOW}安全提示:${NC}"
    echo "1. 建议设置密码保护 (--password 参数)"
    echo "2. 生产环境建议限制bind地址"
    echo "3. 定期备份数据文件"
    echo "4. 监控内存使用情况"
    echo
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                REDIS_VERSION="$2"
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
                DEPLOY_MODE="$2"
                shift 2
                ;;
            --master-host)
                MASTER_HOST="$2"
                shift 2
                ;;
            --data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            --max-memory)
                MAX_MEMORY="$2"
                shift 2
                ;;
            --enable-aof)
                ENABLE_AOF=true
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
    
    # 验证参数
    if [[ "$DEPLOY_MODE" = "slave" ]] && [[ -z "$MASTER_HOST" ]]; then
        log "${RED}错误: slave模式需要指定 --master-host${NC}"
        exit 1
    fi
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_redis_installed
    
    # 安装依赖
    install_dependencies
    
    # 创建Redis用户
    create_redis_user
    
    # 安装Redis
    install_redis
    
    # 创建目录结构
    create_directories
    
    # 生成配置文件
    generate_redis_config
    
    if [[ "$DEPLOY_MODE" = "sentinel" ]]; then
        generate_sentinel_config
    fi
    
    # 创建systemd服务
    create_systemd_service
    
    # 配置内核参数
    configure_kernel_params
    
    # 启动服务
    start_redis_service
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"