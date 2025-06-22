#!/bin/bash
#==============================================================================
# 脚本名称: mysql.sh
# 脚本描述: MySQL/MariaDB 数据库安装配置脚本 - 支持主从复制和安全加固
# 脚本路径: vps_scripts/scripts/service_install/mysql.sh
# 作者: Jensfrank
# 使用方法: bash mysql.sh [选项]
# 选项说明:
#   --type <类型>        数据库类型 (mysql/mariadb)
#   --version <版本>     数据库版本 (如: 8.0, 10.11)
#   --root-password      root密码
#   --port <端口>        数据库端口 (默认: 3306)
#   --charset <字符集>   默认字符集 (默认: utf8mb4)
#   --mode <模式>        部署模式 (standalone/master/slave)
#   --master-host <IP>   主服务器地址 (slave模式必需)
#   --server-id <ID>     服务器ID (复制模式必需)
#   --max-connections    最大连接数 (默认: 1000)
#   --innodb-buffer      InnoDB缓冲池大小 (如: 1G)
#   --secure-install     执行安全加固
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
DB_TYPE="mariadb"
DB_VERSION=""
ROOT_PASSWORD=""
DB_PORT="3306"
CHARSET="utf8mb4"
DEPLOY_MODE="standalone"
MASTER_HOST=""
SERVER_ID=""
MAX_CONNECTIONS="1000"
INNODB_BUFFER_SIZE=""
SECURE_INSTALL=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/mysql_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DATA_DIR="/var/lib/mysql"
CONFIG_DIR="/etc/mysql"
LOG_DIR="/var/log/mysql"
MYSQL_USER="mysql"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}  MySQL/MariaDB 安装配置脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash mysql.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --type <类型>        数据库类型:"
    echo "                       mysql    - MySQL数据库"
    echo "                       mariadb  - MariaDB数据库 (默认)"
    echo "  --version <版本>     数据库版本:"
    echo "                       MySQL: 5.7, 8.0"
    echo "                       MariaDB: 10.6, 10.11, 11.0"
    echo "  --root-password      设置root密码"
    echo "  --port <端口>        数据库端口 (默认: 3306)"
    echo "  --charset <字符集>   默认字符集 (默认: utf8mb4)"
    echo "  --mode <模式>        部署模式:"
    echo "                       standalone - 单机模式 (默认)"
    echo "                       master     - 主服务器"
    echo "                       slave      - 从服务器"
    echo "  --master-host <IP>   主服务器地址 (slave模式必需)"
    echo "  --server-id <ID>     服务器ID (复制模式必需)"
    echo "  --max-connections    最大连接数"
    echo "  --innodb-buffer      InnoDB缓冲池大小"
    echo "  --secure-install     执行安全加固"
    echo "  --force             强制重新安装"
    echo "  --help              显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash mysql.sh --type mariadb --root-password MyPass123!"
    echo "  bash mysql.sh --type mysql --version 8.0 --secure-install"
    echo "  bash mysql.sh --mode master --server-id 1 --innodb-buffer 2G"
    echo "  bash mysql.sh --mode slave --master-host 192.168.1.100 --server-id 2"
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

# 检查是否已安装
check_mysql_installed() {
    if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到MySQL/MariaDB已安装${NC}"
            mysql --version 2>/dev/null || mariadb --version
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
        
        # 停止现有服务
        systemctl stop mysql 2>/dev/null || true
        systemctl stop mariadb 2>/dev/null || true
    fi
}

# 添加MySQL官方仓库
add_mysql_repo() {
    log "${CYAN}添加MySQL官方仓库...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 安装依赖
            apt-get update
            apt-get install -y software-properties-common gnupg
            
            # 添加MySQL APT仓库
            cd /tmp
            wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb
            DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.29-1_all.deb
            apt-get update
            rm -f mysql-apt-config_0.8.29-1_all.deb
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 添加MySQL YUM仓库
            if [[ "$VER_MAJOR" == "7" ]]; then
                rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
            elif [[ "$VER_MAJOR" == "8" ]] || [[ "$VER_MAJOR" == "9" ]]; then
                rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm
            fi
            ;;
    esac
}

# 添加MariaDB仓库
add_mariadb_repo() {
    log "${CYAN}添加MariaDB官方仓库...${NC}"
    
    # 确定MariaDB版本
    if [[ -z "$DB_VERSION" ]]; then
        DB_VERSION="10.11"
    fi
    
    case $OS in
        ubuntu|debian)
            # 添加MariaDB APT仓库
            apt-get install -y software-properties-common gnupg
            curl -fsSL https://mariadb.org/mariadb_release_signing_key.asc | apt-key add -
            
            if [[ "$OS" == "ubuntu" ]]; then
                add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/mariadb/repo/${DB_VERSION}/ubuntu $(lsb_release -cs) main"
            else
                add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/mariadb/repo/${DB_VERSION}/debian $(lsb_release -cs) main"
            fi
            apt-get update
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 创建MariaDB YUM仓库
            cat > /etc/yum.repos.d/MariaDB.repo << EOF
[mariadb]
name = MariaDB
baseurl = https://mirrors.aliyun.com/mariadb/yum/${DB_VERSION}/centos${VER_MAJOR}-amd64
gpgkey = https://mirrors.aliyun.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF
            yum clean all
            yum makecache
            ;;
    esac
}

# 安装MySQL
install_mysql() {
    log "${CYAN}安装MySQL ${DB_VERSION}...${NC}"
    
    # 添加仓库
    add_mysql_repo
    
    # 设置root密码（避免交互式安装）
    if [[ -n "$ROOT_PASSWORD" ]]; then
        debconf-set-selections <<< "mysql-server mysql-server/root_password password $ROOT_PASSWORD"
        debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $ROOT_PASSWORD"
    fi
    
    case $OS in
        ubuntu|debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y mysql-server mysql
            ;;
    esac
}

# 安装MariaDB
install_mariadb() {
    log "${CYAN}安装MariaDB ${DB_VERSION}...${NC}"
    
    # 添加仓库
    add_mariadb_repo
    
    case $OS in
        ubuntu|debian)
            DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server mariadb-client
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y MariaDB-server MariaDB-client
            ;;
    esac
}

# 创建配置文件
create_config_file() {
    log "${CYAN}创建优化配置文件...${NC}"
    
    # 确定配置文件路径
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        CONFIG_FILE="/etc/mysql/mysql.conf.d/optimization.cnf"
        mkdir -p /etc/mysql/mysql.conf.d
    else
        CONFIG_FILE="/etc/my.cnf.d/optimization.cnf"
        mkdir -p /etc/my.cnf.d
    fi
    
    # 计算InnoDB缓冲池大小（如果未指定）
    if [[ -z "$INNODB_BUFFER_SIZE" ]]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        BUFFER_SIZE=$(( TOTAL_MEM * 50 / 100 ))M
        INNODB_BUFFER_SIZE=$BUFFER_SIZE
    fi
    
    cat > "$CONFIG_FILE" << EOF
[mysqld]
# 基础设置
port = $DB_PORT
bind-address = 0.0.0.0
max_connections = $MAX_CONNECTIONS
max_allowed_packet = 64M

# 字符集设置
character-set-server = $CHARSET
collation-server = ${CHARSET}_general_ci
init_connect = 'SET NAMES $CHARSET'

# InnoDB设置
innodb_buffer_pool_size = $INNODB_BUFFER_SIZE
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000

# 查询缓存（MySQL 5.7）
query_cache_type = 0
query_cache_size = 0

# 日志设置
slow_query_log = 1
slow_query_log_file = $LOG_DIR/slow-query.log
long_query_time = 2
log_error = $LOG_DIR/error.log

# 复制设置
server-id = ${SERVER_ID:-1}
log_bin = $LOG_DIR/mysql-bin
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 1G
sync_binlog = 1

# 线程和缓存
thread_cache_size = 50
table_open_cache = 4000
table_definition_cache = 2000

# 临时表
tmp_table_size = 64M
max_heap_table_size = 64M

# 其他优化
skip-name-resolve
performance_schema = ON

[client]
default-character-set = $CHARSET
port = $DB_PORT

[mysql]
default-character-set = $CHARSET
prompt = "\\u@\\h [\\d]> "
EOF

    # 主从复制特定配置
    if [[ "$DEPLOY_MODE" == "master" ]]; then
        cat >> "$CONFIG_FILE" << EOF

# 主服务器配置
binlog_do_db = # 指定要复制的数据库，留空表示所有
# binlog_ignore_db = mysql,information_schema
EOF
    elif [[ "$DEPLOY_MODE" == "slave" ]]; then
        cat >> "$CONFIG_FILE" << EOF

# 从服务器配置
relay_log = $LOG_DIR/relay-bin
log_slave_updates = 1
read_only = 1
EOF
    fi
}

# 初始化数据库
initialize_database() {
    log "${CYAN}初始化数据库...${NC}"
    
    # 创建必要的目录
    mkdir -p $DATA_DIR $LOG_DIR
    chown -R $MYSQL_USER:$MYSQL_USER $DATA_DIR $LOG_DIR
    
    # 启动服务
    systemctl enable --now mysql 2>/dev/null || systemctl enable --now mariadb
    
    # 等待服务启动
    sleep 5
    
    # 设置root密码（如果提供）
    if [[ -n "$ROOT_PASSWORD" ]]; then
        if [[ "$DB_TYPE" == "mysql" ]]; then
            mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
        else
            mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$ROOT_PASSWORD');"
        fi
    else
        # 生成随机密码
        ROOT_PASSWORD=$(generate_password)
        log "${YELLOW}生成的root密码: $ROOT_PASSWORD${NC}"
        
        if [[ "$DB_TYPE" == "mysql" ]]; then
            mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';"
        else
            mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$ROOT_PASSWORD');"
        fi
    fi
    
    # 保存密码到文件
    echo "[client]" > ~/.my.cnf
    echo "user=root" >> ~/.my.cnf
    echo "password=$ROOT_PASSWORD" >> ~/.my.cnf
    chmod 600 ~/.my.cnf
}

# 安全加固
secure_installation() {
    log "${CYAN}执行安全加固...${NC}"
    
    # 删除匿名用户
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    
    # 禁止root远程登录（可选）
    # mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    
    # 删除test数据库
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    
    # 创建管理员用户（允许远程连接）
    ADMIN_USER="admin"
    ADMIN_PASS=$(generate_password)
    mysql -e "CREATE USER '$ADMIN_USER'@'%' IDENTIFIED BY '$ADMIN_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$ADMIN_USER'@'%' WITH GRANT OPTION;"
    
    log "${GREEN}创建管理员用户: $ADMIN_USER / $ADMIN_PASS${NC}"
    
    # 刷新权限
    mysql -e "FLUSH PRIVILEGES;"
}

# 配置主服务器
configure_master() {
    log "${CYAN}配置主服务器...${NC}"
    
    # 创建复制用户
    REPL_USER="replication"
    REPL_PASS=$(generate_password)
    
    mysql -e "CREATE USER '$REPL_USER'@'%' IDENTIFIED BY '$REPL_PASS';"
    mysql -e "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # 获取主服务器状态
    MASTER_STATUS=$(mysql -e "SHOW MASTER STATUS\G")
    MASTER_FILE=$(echo "$MASTER_STATUS" | grep File | awk '{print $2}')
    MASTER_POS=$(echo "$MASTER_STATUS" | grep Position | awk '{print $2}')
    
    log "${GREEN}主服务器配置完成${NC}"
    log "${YELLOW}复制用户: $REPL_USER / $REPL_PASS${NC}"
    log "${YELLOW}Master File: $MASTER_FILE${NC}"
    log "${YELLOW}Master Position: $MASTER_POS${NC}"
    
    # 保存信息到文件
    cat > /root/.mysql_master_info << EOF
MASTER_HOST=$(hostname -I | awk '{print $1}')
MASTER_USER=$REPL_USER
MASTER_PASSWORD=$REPL_PASS
MASTER_LOG_FILE=$MASTER_FILE
MASTER_LOG_POS=$MASTER_POS
EOF
    chmod 600 /root/.mysql_master_info
}

# 配置从服务器
configure_slave() {
    log "${CYAN}配置从服务器...${NC}"
    
    if [[ -z "$MASTER_HOST" ]]; then
        log "${RED}错误: 未指定主服务器地址${NC}"
        return 1
    fi
    
    # 获取复制信息
    read -p "请输入主服务器的复制用户名: " REPL_USER
    read -s -p "请输入主服务器的复制密码: " REPL_PASS
    echo
    read -p "请输入主服务器的binlog文件名: " MASTER_FILE
    read -p "请输入主服务器的binlog位置: " MASTER_POS
    
    # 停止从服务器
    mysql -e "STOP SLAVE;"
    
    # 配置主服务器信息
    mysql -e "CHANGE MASTER TO
        MASTER_HOST='$MASTER_HOST',
        MASTER_USER='$REPL_USER',
        MASTER_PASSWORD='$REPL_PASS',
        MASTER_LOG_FILE='$MASTER_FILE',
        MASTER_LOG_POS=$MASTER_POS;"
    
    # 启动从服务器
    mysql -e "START SLAVE;"
    
    # 检查复制状态
    sleep 2
    SLAVE_STATUS=$(mysql -e "SHOW SLAVE STATUS\G")
    IO_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_IO_Running" | awk '{print $2}')
    SQL_RUNNING=$(echo "$SLAVE_STATUS" | grep "Slave_SQL_Running" | awk '{print $2}')
    
    if [[ "$IO_RUNNING" == "Yes" ]] && [[ "$SQL_RUNNING" == "Yes" ]]; then
        log "${GREEN}从服务器配置成功，复制正在运行${NC}"
    else
        log "${RED}从服务器配置失败，请检查错误日志${NC}"
        echo "$SLAVE_STATUS"
    fi
}

# 创建示例数据库
create_sample_database() {
    log "${CYAN}创建示例数据库...${NC}"
    
    mysql << EOF
CREATE DATABASE IF NOT EXISTS testdb CHARACTER SET $CHARSET COLLATE ${CHARSET}_general_ci;
USE testdb;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=$CHARSET;

INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com'),
    ('user2', 'user2@example.com');
EOF
    
    log "${GREEN}示例数据库创建完成${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证数据库安装...${NC}"
    
    # 检查服务状态
    if systemctl is-active --quiet mysql 2>/dev/null || systemctl is-active --quiet mariadb 2>/dev/null; then
        log "${GREEN}数据库服务运行正常${NC}"
    else
        log "${RED}数据库服务未运行${NC}"
        return 1
    fi
    
    # 显示版本信息
    mysql -e "SELECT VERSION();"
    
    # 显示数据库列表
    mysql -e "SHOW DATABASES;"
    
    # 显示当前连接数
    mysql -e "SHOW STATUS LIKE 'Threads_connected';"
    
    # 检查字符集
    mysql -e "SHOW VARIABLES LIKE 'character_set_%';"
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}数据库安装配置完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- 数据库类型: ${DB_TYPE} ${DB_VERSION}"
    echo "- 监听端口: ${DB_PORT}"
    echo "- 字符集: ${CHARSET}"
    echo "- 部署模式: ${DEPLOY_MODE}"
    echo "- 数据目录: ${DATA_DIR}"
    echo "- 配置文件: ${CONFIG_FILE}"
    echo "- 错误日志: ${LOG_DIR}/error.log"
    echo "- 慢查询日志: ${LOG_DIR}/slow-query.log"
    echo
    echo -e "${CYAN}访问信息:${NC}"
    echo "- Root密码: ${ROOT_PASSWORD}"
    if [[ "$SECURE_INSTALL" == true ]]; then
        echo "- 管理员用户: 见上方输出"
    fi
    echo "- 本地连接: mysql -u root -p"
    echo "- 远程连接: mysql -h <服务器IP> -P ${DB_PORT} -u <用户名> -p"
    echo
    echo -e "${CYAN}服务管理:${NC}"
    if [[ "$DB_TYPE" == "mysql" ]]; then
        echo "- 启动服务: systemctl start mysql"
        echo "- 停止服务: systemctl stop mysql"
        echo "- 重启服务: systemctl restart mysql"
        echo "- 查看状态: systemctl status mysql"
    else
        echo "- 启动服务: systemctl start mariadb"
        echo "- 停止服务: systemctl stop mariadb"
        echo "- 重启服务: systemctl restart mariadb"
        echo "- 查看状态: systemctl status mariadb"
    fi
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "- 创建数据库: CREATE DATABASE dbname;"
    echo "- 创建用户: CREATE USER 'username'@'%' IDENTIFIED BY 'password';"
    echo "- 授权: GRANT ALL ON dbname.* TO 'username'@'%';"
    echo "- 查看进程: SHOW PROCESSLIST;"
    echo "- 查看变量: SHOW VARIABLES LIKE '%max%';"
    echo "- 查看状态: SHOW STATUS;"
    
    if [[ "$DEPLOY_MODE" == "master" ]]; then
        echo
        echo -e "${YELLOW}主服务器信息已保存到: /root/.mysql_master_info${NC}"
    elif [[ "$DEPLOY_MODE" == "slave" ]]; then
        echo
        echo -e "${CYAN}检查复制状态: mysql -e 'SHOW SLAVE STATUS\\G'${NC}"
    fi
    
    echo
    echo -e "${YELLOW}安全建议:${NC}"
    echo "1. 定期备份数据库"
    echo "2. 限制远程访问权限"
    echo "3. 使用SSL加密连接"
    echo "4. 定期更新数据库版本"
    echo "5. 监控慢查询日志"
    echo
    echo -e "${YELLOW}密码已保存到: ~/.my.cnf${NC}"
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                DB_TYPE="$2"
                shift 2
                ;;
            --version)
                DB_VERSION="$2"
                shift 2
                ;;
            --root-password)
                ROOT_PASSWORD="$2"
                shift 2
                ;;
            --port)
                DB_PORT="$2"
                shift 2
                ;;
            --charset)
                CHARSET="$2"
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
            --server-id)
                SERVER_ID="$2"
                shift 2
                ;;
            --max-connections)
                MAX_CONNECTIONS="$2"
                shift 2
                ;;
            --innodb-buffer)
                INNODB_BUFFER_SIZE="$2"
                shift 2
                ;;
            --secure-install)
                SECURE_INSTALL=true
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
    if [[ "$DEPLOY_MODE" == "slave" ]] && [[ -z "$MASTER_HOST" ]]; then
        log "${RED}错误: slave模式需要指定 --master-host${NC}"
        exit 1
    fi
    
    if [[ "$DEPLOY_MODE" != "standalone" ]] && [[ -z "$SERVER_ID" ]]; then
        log "${RED}错误: 主从复制模式需要指定 --server-id${NC}"
        exit 1
    fi
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_mysql_installed
    
    # 安装数据库
    if [[ "$DB_TYPE" == "mysql" ]]; then
        install_mysql
    else
        install_mariadb
    fi
    
    # 创建配置文件
    create_config_file
    
    # 重启服务应用配置
    systemctl restart mysql 2>/dev/null || systemctl restart mariadb
    sleep 3
    
    # 初始化数据库
    initialize_database
    
    # 安全加固
    if [[ "$SECURE_INSTALL" == true ]]; then
        secure_installation
    fi
    
    # 配置主从复制
    if [[ "$DEPLOY_MODE" == "master" ]]; then
        configure_master
    elif [[ "$DEPLOY_MODE" == "slave" ]]; then
        configure_slave
    fi
    
    # 创建示例数据库
    create_sample_database
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"