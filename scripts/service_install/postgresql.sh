#!/bin/bash
#==============================================================================
# 脚本名称: postgresql.sh
# 脚本描述: PostgreSQL 数据库安装配置脚本 - 支持主从复制、性能优化和扩展管理
# 脚本路径: vps_scripts/scripts/service_install/postgresql.sh
# 作者: Jensfrank
# 使用方法: bash postgresql.sh [选项]
# 选项说明:
#   --version <版本>     PostgreSQL版本 (12/13/14/15/16)
#   --port <端口>        数据库端口 (默认: 5432)
#   --data-dir <路径>    数据目录 (默认: /var/lib/postgresql/版本/main)
#   --locale <语言>      数据库字符集 (默认: en_US.UTF-8)
#   --password <密码>    postgres用户密码
#   --mode <模式>        部署模式 (standalone/primary/standby)
#   --primary-host <IP>  主服务器地址 (standby模式必需)
#   --replication-user   复制用户名 (默认: replicator)
#   --max-connections    最大连接数 (默认: 200)
#   --shared-buffers     共享缓冲区大小 (如: 256MB)
#   --extensions <扩展>  安装扩展 (如: postgis,pg_stat_statements)
#   --enable-ssl        启用SSL加密
#   --backup-schedule   配置自动备份
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
PG_VERSION=""
PG_PORT="5432"
DATA_DIR=""
DB_LOCALE="en_US.UTF-8"
PG_PASSWORD=""
DEPLOY_MODE="standalone"
PRIMARY_HOST=""
REPL_USER="replicator"
REPL_PASSWORD=""
MAX_CONNECTIONS="200"
SHARED_BUFFERS=""
EXTENSIONS=""
ENABLE_SSL=false
BACKUP_SCHEDULE=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/postgresql_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DEFAULT_PG_VERSION="15"
CONFIG_DIR="/etc/postgresql"
LOG_DIR="/var/log/postgresql"
BACKUP_DIR="/var/backups/postgresql"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}  PostgreSQL 数据库安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash postgresql.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --version <版本>     PostgreSQL版本 (12/13/14/15/16)"
    echo "  --port <端口>        数据库端口 (默认: 5432)"
    echo "  --data-dir <路径>    数据目录"
    echo "  --locale <语言>      数据库字符集 (默认: en_US.UTF-8)"
    echo "  --password <密码>    postgres用户密码"
    echo "  --mode <模式>        部署模式:"
    echo "                       standalone - 单机模式 (默认)"
    echo "                       primary    - 主服务器"
    echo "                       standby    - 备用服务器"
    echo "  --primary-host <IP>  主服务器地址 (standby模式必需)"
    echo "  --replication-user   复制用户名 (默认: replicator)"
    echo "  --max-connections    最大连接数"
    echo "  --shared-buffers     共享缓冲区大小 (建议为系统内存的25%)"
    echo "  --extensions <扩展>  安装扩展 (逗号分隔):"
    echo "                       postgis         - 地理空间扩展"
    echo "                       pg_stat_statements - 查询统计"
    echo "                       pg_trgm         - 相似度匹配"
    echo "                       uuid-ossp       - UUID生成"
    echo "                       hstore          - 键值存储"
    echo "  --enable-ssl        启用SSL加密连接"
    echo "  --backup-schedule   配置自动备份 (每天凌晨2点)"
    echo "  --force             强制重新安装"
    echo "  --help              显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash postgresql.sh --version 15 --password MySecurePass"
    echo "  bash postgresql.sh --mode primary --shared-buffers 1GB"
    echo "  bash postgresql.sh --mode standby --primary-host 192.168.1.100"
    echo "  bash postgresql.sh --extensions postgis,pg_stat_statements --enable-ssl"
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
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
        VER_MAJOR=$(echo $VER | cut -d. -f1)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
}

# 检查PostgreSQL是否已安装
check_postgresql_installed() {
    if command -v psql &> /dev/null || systemctl list-units --type=service | grep -q postgresql; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到PostgreSQL已安装${NC}"
            psql --version
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop postgresql* 2>/dev/null || true
    fi
}

# 添加PostgreSQL官方仓库
add_postgresql_repo() {
    log "${CYAN}添加PostgreSQL官方仓库...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 安装依赖
            apt-get update
            apt-get install -y wget ca-certificates
            
            # 添加PostgreSQL APT仓库
            wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
            echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
            apt-get update
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 安装PostgreSQL YUM仓库
            if [[ "$VER_MAJOR" == "7" ]]; then
                yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
            elif [[ "$VER_MAJOR" == "8" ]] || [[ "$VER_MAJOR" == "9" ]]; then
                dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
            fi
            ;;
    esac
}

# 安装PostgreSQL
install_postgresql() {
    # 确定版本
    if [[ -z "$PG_VERSION" ]]; then
        PG_VERSION="$DEFAULT_PG_VERSION"
    fi
    
    log "${CYAN}安装 PostgreSQL ${PG_VERSION}...${NC}"
    
    # 添加官方仓库
    add_postgresql_repo
    
    case $OS in
        ubuntu|debian)
            apt-get install -y \
                postgresql-${PG_VERSION} \
                postgresql-client-${PG_VERSION} \
                postgresql-contrib-${PG_VERSION} \
                postgresql-server-dev-${PG_VERSION}
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 禁用内置的postgresql模块
            dnf -qy module disable postgresql 2>/dev/null || true
            
            yum install -y \
                postgresql${PG_VERSION}-server \
                postgresql${PG_VERSION}-contrib \
                postgresql${PG_VERSION}-devel
            ;;
    esac
    
    log "${GREEN}PostgreSQL ${PG_VERSION} 安装完成${NC}"
}

# 初始化数据库
initialize_database() {
    log "${CYAN}初始化数据库...${NC}"
    
    # 确定数据目录
    if [[ -z "$DATA_DIR" ]]; then
        case $OS in
            ubuntu|debian)
                DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"
                ;;
            centos|rhel|fedora|rocky|almalinux)
                DATA_DIR="/var/lib/pgsql/${PG_VERSION}/data"
                ;;
        esac
    fi
    
    # 创建数据目录
    mkdir -p "$DATA_DIR"
    chown postgres:postgres "$DATA_DIR"
    chmod 700 "$DATA_DIR"
    
    # 初始化数据库集群
    case $OS in
        ubuntu|debian)
            # Ubuntu/Debian自动初始化
            if [[ ! -f "$DATA_DIR/PG_VERSION" ]]; then
                sudo -u postgres /usr/lib/postgresql/${PG_VERSION}/bin/initdb -D "$DATA_DIR" --locale="$DB_LOCALE"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # CentOS/RHEL需要手动初始化
            /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb
            ;;
    esac
    
    log "${GREEN}数据库初始化完成${NC}"
}

# 配置PostgreSQL
configure_postgresql() {
    log "${CYAN}配置PostgreSQL...${NC}"
    
    # 确定配置文件路径
    case $OS in
        ubuntu|debian)
            PG_CONFIG_DIR="/etc/postgresql/${PG_VERSION}/main"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            PG_CONFIG_DIR="/var/lib/pgsql/${PG_VERSION}/data"
            ;;
    esac
    
    # 备份原配置文件
    cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 计算内存参数
    if [[ -z "$SHARED_BUFFERS" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        SHARED_BUFFERS=$(( TOTAL_MEM * 25 / 100 ))MB
    fi
    
    # 生成优化配置
    cat >> "$PG_CONFIG_DIR/postgresql.conf" << EOF

# ===== 自定义配置 =====
# 基础设置
listen_addresses = '*'
port = $PG_PORT
max_connections = $MAX_CONNECTIONS

# 内存设置
shared_buffers = $SHARED_BUFFERS
effective_cache_size = $(( TOTAL_MEM * 50 / 100 ))MB
maintenance_work_mem = $(( TOTAL_MEM * 5 / 100 ))MB
work_mem = $(( TOTAL_MEM * 1 / 100 ))MB

# 检查点设置
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1

# 日志设置
logging_collector = on
log_directory = '$LOG_DIR'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
log_statement = 'ddl'
log_temp_files = 0

# 查询优化
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all

# 并行查询 (PG 9.6+)
max_worker_processes = $(nproc)
max_parallel_workers_per_gather = $(( $(nproc) / 2 ))
max_parallel_workers = $(nproc)
EOF

    # SSL配置
    if [[ "$ENABLE_SSL" = true ]]; then
        cat >> "$PG_CONFIG_DIR/postgresql.conf" << EOF

# SSL设置
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_ca_file = 'root.crt'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on
EOF
        # 生成SSL证书
        generate_ssl_certificates
    fi
    
    # 复制配置
    if [[ "$DEPLOY_MODE" == "primary" ]] || [[ "$DEPLOY_MODE" == "standby" ]]; then
        cat >> "$PG_CONFIG_DIR/postgresql.conf" << EOF

# 复制设置
wal_level = replica
max_wal_senders = 10
wal_keep_segments = 64
hot_standby = on
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/archive/%f && cp %p /var/lib/postgresql/archive/%f'
EOF
        
        # 创建归档目录
        mkdir -p /var/lib/postgresql/archive
        chown postgres:postgres /var/lib/postgresql/archive
    fi
    
    # 配置pg_hba.conf
    cat > "$PG_CONFIG_DIR/pg_hba.conf" << EOF
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

# Allow connections from local network
host    all             all             0.0.0.0/0               md5

EOF

    # 复制用户配置
    if [[ "$DEPLOY_MODE" == "primary" ]]; then
        echo "# Replication connections" >> "$PG_CONFIG_DIR/pg_hba.conf"
        echo "host    replication     $REPL_USER      0.0.0.0/0               md5" >> "$PG_CONFIG_DIR/pg_hba.conf"
    fi
}

# 生成SSL证书
generate_ssl_certificates() {
    log "${CYAN}生成SSL证书...${NC}"
    
    cd "$PG_CONFIG_DIR"
    
    # 生成CA证书
    openssl genrsa -out root.key 2048
    openssl req -new -key root.key -out root.csr -subj "/C=CN/ST=State/L=City/O=Organization/CN=PostgreSQL CA"
    openssl x509 -req -days 3650 -in root.csr -signkey root.key -out root.crt
    
    # 生成服务器证书
    openssl genrsa -out server.key 2048
    openssl req -new -key server.key -out server.csr -subj "/C=CN/ST=State/L=City/O=Organization/CN=$(hostname)"
    openssl x509 -req -days 365 -in server.csr -CA root.crt -CAkey root.key -CAcreateserial -out server.crt
    
    # 设置权限
    chmod 600 server.key root.key
    chown postgres:postgres *.key *.crt
    
    log "${GREEN}SSL证书生成完成${NC}"
}

# 启动PostgreSQL服务
start_postgresql_service() {
    log "${CYAN}启动PostgreSQL服务...${NC}"
    
    case $OS in
        ubuntu|debian)
            systemctl enable postgresql
            systemctl start postgresql
            ;;
        centos|rhel|fedora|rocky|almalinux)
            systemctl enable postgresql-${PG_VERSION}
            systemctl start postgresql-${PG_VERSION}
            ;;
    esac
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet postgresql 2>/dev/null || systemctl is-active --quiet postgresql-${PG_VERSION} 2>/dev/null; then
        log "${GREEN}PostgreSQL服务启动成功${NC}"
    else
        log "${RED}PostgreSQL服务启动失败${NC}"
        systemctl status postgresql* | head -20
        exit 1
    fi
}

# 设置postgres用户密码
set_postgres_password() {
    log "${CYAN}设置postgres用户密码...${NC}"
    
    if [[ -z "$PG_PASSWORD" ]]; then
        PG_PASSWORD=$(generate_password)
        log "${YELLOW}生成的postgres密码: $PG_PASSWORD${NC}"
    fi
    
    # 设置密码
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_PASSWORD';"
    
    # 保存密码到文件
    echo "localhost:$PG_PORT:*:postgres:$PG_PASSWORD" > /root/.pgpass
    chmod 600 /root/.pgpass
}

# 配置主服务器
configure_primary() {
    log "${CYAN}配置主服务器...${NC}"
    
    # 生成复制用户密码
    if [[ -z "$REPL_PASSWORD" ]]; then
        REPL_PASSWORD=$(generate_password)
    fi
    
    # 创建复制用户
    sudo -u postgres psql -c "CREATE USER $REPL_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPL_PASSWORD';"
    
    # 创建复制槽 (PG 9.4+)
    sudo -u postgres psql -c "SELECT pg_create_physical_replication_slot('standby_slot');"
    
    log "${GREEN}主服务器配置完成${NC}"
    log "${YELLOW}复制用户: $REPL_USER / $REPL_PASSWORD${NC}"
    
    # 保存复制信息
    cat > /root/.pg_replication_info << EOF
PRIMARY_HOST=$(hostname -I | awk '{print $1}')
PRIMARY_PORT=$PG_PORT
REPLICATION_USER=$REPL_USER
REPLICATION_PASSWORD=$REPL_PASSWORD
REPLICATION_SLOT=standby_slot
EOF
    chmod 600 /root/.pg_replication_info
}

# 配置备用服务器
configure_standby() {
    log "${CYAN}配置备用服务器...${NC}"
    
    if [[ -z "$PRIMARY_HOST" ]]; then
        log "${RED}错误: 未指定主服务器地址${NC}"
        return 1
    fi
    
    # 停止PostgreSQL
    systemctl stop postgresql* 2>/dev/null || true
    
    # 清空数据目录
    rm -rf "$DATA_DIR"/*
    
    # 获取复制凭据
    read -p "请输入主服务器的复制用户名 [replicator]: " REPL_USER
    REPL_USER=${REPL_USER:-replicator}
    read -s -p "请输入主服务器的复制密码: " REPL_PASSWORD
    echo
    
    # 创建.pgpass文件
    echo "$PRIMARY_HOST:$PG_PORT:*:$REPL_USER:$REPL_PASSWORD" >> /var/lib/postgresql/.pgpass
    chown postgres:postgres /var/lib/postgresql/.pgpass
    chmod 600 /var/lib/postgresql/.pgpass
    
    # 使用pg_basebackup进行基础备份
    log "${YELLOW}从主服务器同步数据...${NC}"
    sudo -u postgres pg_basebackup -h "$PRIMARY_HOST" -p "$PG_PORT" -U "$REPL_USER" -D "$DATA_DIR" -Fp -Xs -P -R
    
    # 配置recovery (PG 12+使用standby.signal)
    if [[ "${PG_VERSION}" -ge 12 ]]; then
        touch "$DATA_DIR/standby.signal"
        cat >> "$DATA_DIR/postgresql.auto.conf" << EOF
primary_conninfo = 'host=$PRIMARY_HOST port=$PG_PORT user=$REPL_USER'
primary_slot_name = 'standby_slot'
EOF
    else
        cat > "$DATA_DIR/recovery.conf" << EOF
standby_mode = 'on'
primary_conninfo = 'host=$PRIMARY_HOST port=$PG_PORT user=$REPL_USER'
primary_slot_name = 'standby_slot'
trigger_file = '/tmp/postgresql.trigger'
EOF
        chown postgres:postgres "$DATA_DIR/recovery.conf"
    fi
    
    # 启动备用服务器
    start_postgresql_service
    
    # 检查复制状态
    sleep 5
    if sudo -u postgres psql -c "SELECT pg_is_in_recovery();" | grep -q "t"; then
        log "${GREEN}备用服务器配置成功，正在接收复制流${NC}"
    else
        log "${RED}备用服务器配置失败${NC}"
    fi
}

# 安装扩展
install_extensions() {
    if [[ -z "$EXTENSIONS" ]]; then
        return
    fi
    
    log "${CYAN}安装PostgreSQL扩展...${NC}"
    
    # 安装扩展包
    case $OS in
        ubuntu|debian)
            # PostGIS
            if [[ "$EXTENSIONS" == *"postgis"* ]]; then
                apt-get install -y postgresql-${PG_VERSION}-postgis-3
            fi
            # 其他扩展
            apt-get install -y postgresql-${PG_VERSION}-pgrouting postgresql-${PG_VERSION}-pgtap
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ "$EXTENSIONS" == *"postgis"* ]]; then
                yum install -y postgis33_${PG_VERSION}
            fi
            ;;
    esac
    
    # 在数据库中创建扩展
    IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
    for ext in "${EXT_ARRAY[@]}"; do
        ext=$(echo $ext | tr -d ' ')
        log "${YELLOW}创建扩展: $ext${NC}"
        sudo -u postgres psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS $ext;" || true
    done
    
    log "${GREEN}扩展安装完成${NC}"
}

# 配置自动备份
configure_backup() {
    if [[ "$BACKUP_SCHEDULE" != true ]]; then
        return
    fi
    
    log "${CYAN}配置自动备份...${NC}"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    chown postgres:postgres "$BACKUP_DIR"
    
    # 创建备份脚本
    cat > /usr/local/bin/pg_backup.sh << 'EOF'
#!/bin/bash
# PostgreSQL自动备份脚本

BACKUP_DIR="/var/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PG_VERSION="__PG_VERSION__"

# 备份所有数据库
sudo -u postgres pg_dumpall | gzip > "$BACKUP_DIR/all_databases_$TIMESTAMP.sql.gz"

# 备份单个数据库
for db in $(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;"); do
    sudo -u postgres pg_dump "$db" | gzip > "$BACKUP_DIR/${db}_$TIMESTAMP.sql.gz"
done

# 清理30天前的备份
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +30 -delete

# 记录日志
echo "$(date): Backup completed" >> "$BACKUP_DIR/backup.log"
EOF
    
    # 替换版本号
    sed -i "s/__PG_VERSION__/$PG_VERSION/g" /usr/local/bin/pg_backup.sh
    chmod +x /usr/local/bin/pg_backup.sh
    
    # 添加cron任务
    echo "0 2 * * * /usr/local/bin/pg_backup.sh" | crontab -
    
    log "${GREEN}自动备份配置完成 (每天凌晨2点执行)${NC}"
}

# 创建示例数据库
create_sample_database() {
    log "${CYAN}创建示例数据库...${NC}"
    
    sudo -u postgres createdb sampledb
    sudo -u postgres psql -d sampledb << EOF
-- 创建示例表
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(200) NOT NULL,
    content TEXT,
    published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_published_at ON posts(published_at);

-- 插入示例数据
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com'),
    ('user2', 'user2@example.com');

INSERT INTO posts (user_id, title, content) VALUES
    (1, 'Welcome to PostgreSQL', 'PostgreSQL is a powerful database system.'),
    (2, 'First Post', 'This is my first post.'),
    (3, 'Hello World', 'Hello from PostgreSQL!');

-- 创建视图
CREATE VIEW user_posts AS
SELECT u.username, p.title, p.content, p.published_at
FROM users u
JOIN posts p ON u.id = p.user_id;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE sampledb TO postgres;
EOF
    
    log "${GREEN}示例数据库创建完成${NC}"
}

# 配置监控
configure_monitoring() {
    log "${CYAN}配置PostgreSQL监控...${NC}"
    
    # 创建监控用户
    sudo -u postgres psql << EOF
CREATE USER monitor WITH PASSWORD 'monitor123';
GRANT pg_monitor TO monitor;
GRANT CONNECT ON DATABASE postgres TO monitor;
EOF
    
    # 创建监控视图
    sudo -u postgres psql << 'EOF'
-- 数据库大小视图
CREATE VIEW database_sizes AS
SELECT 
    datname AS database_name,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

-- 表大小视图
CREATE VIEW table_sizes AS
SELECT 
    schemaname AS schema_name,
    tablename AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- 活动连接视图
CREATE VIEW active_connections AS
SELECT 
    pid,
    usename AS username,
    application_name,
    client_addr,
    state,
    query_start,
    state_change,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start DESC;

-- 授权给监控用户
GRANT SELECT ON database_sizes TO monitor;
GRANT SELECT ON table_sizes TO monitor;
GRANT SELECT ON active_connections TO monitor;
EOF
    
    log "${GREEN}监控配置完成${NC}"
}

# 显示连接信息
show_connection_info() {
    log "${CYAN}获取连接信息...${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # 创建连接信息文件
    cat > /root/postgresql_connection_info.txt << EOF
PostgreSQL 连接信息
==================

版本: PostgreSQL ${PG_VERSION}
主机: ${SERVER_IP}
端口: ${PG_PORT}
管理员用户: postgres
管理员密码: ${PG_PASSWORD}

连接字符串:
- psql: psql -h ${SERVER_IP} -p ${PG_PORT} -U postgres -d postgres
- JDBC: jdbc:postgresql://${SERVER_IP}:${PG_PORT}/postgres
- Python: postgresql://postgres:${PG_PASSWORD}@${SERVER_IP}:${PG_PORT}/postgres

示例数据库: sampledb
监控用户: monitor / monitor123

配置文件位置: ${PG_CONFIG_DIR}
数据目录: ${DATA_DIR}
日志目录: ${LOG_DIR}
备份目录: ${BACKUP_DIR}
EOF
    
    chmod 600 /root/postgresql_connection_info.txt
}

# 验证安装
verify_installation() {
    log "${CYAN}验证PostgreSQL安装...${NC}"
    
    # 检查版本
    pg_version=$(sudo -u postgres psql -t -c "SELECT version();")
    log "${GREEN}PostgreSQL版本: ${pg_version}${NC}"
    
    # 检查数据库列表
    log "${CYAN}数据库列表:${NC}"
    sudo -u postgres psql -l
    
    # 检查扩展
    log "${CYAN}已安装的扩展:${NC}"
    sudo -u postgres psql -d postgres -c "\dx"
    
    # 检查连接数
    log "${CYAN}当前连接数:${NC}"
    sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;"
    
    # 检查复制状态（如果配置了复制）
    if [[ "$DEPLOY_MODE" == "primary" ]]; then
        log "${CYAN}复制状态:${NC}"
        sudo -u postgres psql -c "SELECT * FROM pg_replication_slots;"
    elif [[ "$DEPLOY_MODE" == "standby" ]]; then
        log "${CYAN}复制延迟:${NC}"
        sudo -u postgres psql -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}PostgreSQL安装配置完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- PostgreSQL版本: ${PG_VERSION}"
    echo "- 部署模式: ${DEPLOY_MODE}"
    echo "- 监听端口: ${PG_PORT}"
    echo "- 数据目录: ${DATA_DIR}"
    echo "- 配置目录: ${PG_CONFIG_DIR}"
    echo "- 日志目录: ${LOG_DIR}"
    
    if [[ "$BACKUP_SCHEDULE" = true ]]; then
        echo "- 自动备份: 已配置 (每天凌晨2点)"
    fi
    
    if [[ "$ENABLE_SSL" = true ]]; then
        echo "- SSL加密: 已启用"
    fi
    
    echo
    echo -e "${CYAN}连接信息:${NC}"
    echo "- 管理员用户: postgres"
    echo "- 管理员密码: ${PG_PASSWORD}"
    echo "- 连接命令: psql -h localhost -p ${PG_PORT} -U postgres"
    echo "- 连接信息文件: /root/postgresql_connection_info.txt"
    
    echo
    echo -e "${CYAN}服务管理:${NC}"
    case $OS in
        ubuntu|debian)
            echo "- 启动服务: systemctl start postgresql"
            echo "- 停止服务: systemctl stop postgresql"
            echo "- 重启服务: systemctl restart postgresql"
            echo "- 查看状态: systemctl status postgresql"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            echo "- 启动服务: systemctl start postgresql-${PG_VERSION}"
            echo "- 停止服务: systemctl stop postgresql-${PG_VERSION}"
            echo "- 重启服务: systemctl restart postgresql-${PG_VERSION}"
            echo "- 查看状态: systemctl status postgresql-${PG_VERSION}"
            ;;
    esac
    
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "- 创建数据库: createdb dbname"
    echo "- 删除数据库: dropdb dbname"
    echo "- 创建用户: createuser username"
    echo "- 备份数据库: pg_dump dbname > backup.sql"
    echo "- 恢复数据库: psql dbname < backup.sql"
    echo "- 查看活动连接: SELECT * FROM pg_stat_activity;"
    echo "- 查看数据库大小: SELECT pg_size_pretty(pg_database_size('dbname'));"
    
    if [[ "$DEPLOY_MODE" == "primary" ]]; then
        echo
        echo -e "${YELLOW}主服务器复制信息已保存到: /root/.pg_replication_info${NC}"
    elif [[ "$DEPLOY_MODE" == "standby" ]]; then
        echo
        echo -e "${CYAN}查看复制状态:${NC}"
        echo "sudo -u postgres psql -c \"SELECT * FROM pg_stat_wal_receiver;\""
    fi
    
    echo
    echo -e "${YELLOW}安全建议:${NC}"
    echo "1. 修改pg_hba.conf限制访问来源"
    echo "2. 使用SSL加密连接"
    echo "3. 定期备份数据"
    echo "4. 监控慢查询"
    echo "5. 定期运行VACUUM和ANALYZE"
    
    echo
    echo -e "${YELLOW}性能优化提示:${NC}"
    echo "1. 根据工作负载调整shared_buffers"
    echo "2. 为频繁查询的列创建索引"
    echo "3. 使用EXPLAIN ANALYZE分析查询"
    echo "4. 定期更新表统计信息"
    
    echo
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                PG_VERSION="$2"
                shift 2
                ;;
            --port)
                PG_PORT="$2"
                shift 2
                ;;
            --data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            --locale)
                DB_LOCALE="$2"
                shift 2
                ;;
            --password)
                PG_PASSWORD="$2"
                shift 2
                ;;
            --mode)
                DEPLOY_MODE="$2"
                shift 2
                ;;
            --primary-host)
                PRIMARY_HOST="$2"
                shift 2
                ;;
            --replication-user)
                REPL_USER="$2"
                shift 2
                ;;
            --max-connections)
                MAX_CONNECTIONS="$2"
                shift 2
                ;;
            --shared-buffers)
                SHARED_BUFFERS="$2"
                shift 2
                ;;
            --extensions)
                EXTENSIONS="$2"
                shift 2
                ;;
            --enable-ssl)
                ENABLE_SSL=true
                shift
                ;;
            --backup-schedule)
                BACKUP_SCHEDULE=true
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
    if [[ "$DEPLOY_MODE" == "standby" ]] && [[ -z "$PRIMARY_HOST" ]]; then
        log "${RED}错误: standby模式需要指定 --primary-host${NC}"
        exit 1
    fi
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_postgresql_installed
    
    # 安装PostgreSQL
    install_postgresql
    
    # 初始化数据库
    initialize_database
    
    # 配置PostgreSQL
    configure_postgresql
    
    # 启动服务
    start_postgresql_service
    
    # 设置密码
    set_postgres_password
    
    # 配置复制
    if [[ "$DEPLOY_MODE" == "primary" ]]; then
        configure_primary
    elif [[ "$DEPLOY_MODE" == "standby" ]]; then
        configure_standby
    fi
    
    # 安装扩展
    install_extensions
    
    # 配置备份
    configure_backup
    
    # 创建示例数据库
    create_sample_database
    
    # 配置监控
    configure_monitoring
    
    # 显示连接信息
    show_connection_info
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"