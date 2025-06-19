#!/bin/bash
#==============================================================================
# 脚本名称: install_ldnmp.sh
# 脚本描述: LDNMP环境安装脚本 - 使用Docker Compose部署Nginx+MySQL+PHP环境
# 脚本路径: vps_scripts/scripts/service_install/install_ldnmp.sh
# 作者: Jensfrank
# 使用方法: bash install_ldnmp.sh [选项]
# 选项: 
#   --port-http PORT     设置HTTP端口 (默认: 80)
#   --port-https PORT    设置HTTPS端口 (默认: 443)
#   --port-mysql PORT    设置MySQL端口 (默认: 3306)
#   --mysql-root-pwd     设置MySQL root密码 (默认: 随机生成)
#   --php-version        PHP版本 (7.4/8.0/8.1/8.2/8.3, 默认: 8.2)
#   --install-dir        安装目录 (默认: /opt/ldnmp)
#   --remove             卸载LDNMP环境
#   --status             查看服务状态
#   --restart            重启所有服务
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
readonly SCRIPT_NAME="LDNMP环境安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/ldnmp_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
INSTALL_DIR="/opt/ldnmp"
HTTP_PORT=80
HTTPS_PORT=443
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=""
PHP_VERSION="8.2"
ACTION="install"

# 路径配置
COMPOSE_FILE=""
NGINX_CONF_DIR=""
PHP_CONF_DIR=""
MYSQL_CONF_DIR=""
WEB_ROOT_DIR=""
LOG_DIR=""
DATA_DIR=""

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --port-http PORT     设置HTTP端口 (默认: 80)
    --port-https PORT    设置HTTPS端口 (默认: 443)
    --port-mysql PORT    设置MySQL端口 (默认: 3306)
    --mysql-root-pwd PWD 设置MySQL root密码 (默认: 随机生成)
    --php-version VER    PHP版本 (7.4/8.0/8.1/8.2/8.3, 默认: 8.2)
    --install-dir DIR    安装目录 (默认: /opt/ldnmp)
    --remove             卸载LDNMP环境
    --status             查看服务状态
    --restart            重启所有服务
    --stop               停止所有服务
    --start              启动所有服务
    -h, --help           显示此帮助信息

示例:
    $(basename "$0")                              # 使用默认配置安装
    $(basename "$0") --port-http 8080            # 自定义HTTP端口
    $(basename "$0") --php-version 8.3           # 使用PHP 8.3
    $(basename "$0") --status                     # 查看服务状态

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
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本需要root权限运行，请使用 sudo bash $0"
    fi
}

# 检查Docker环境
check_docker() {
    log INFO "检查Docker环境..."
    
    if ! command_exists docker; then
        error_exit "未检测到Docker，请先运行 install_docker.sh 安装Docker"
    fi
    
    if ! command_exists docker-compose && ! docker compose version &>/dev/null; then
        error_exit "未检测到Docker Compose，请先安装Docker Compose"
    fi
    
    # 检查Docker服务状态
    if ! systemctl is-active docker &>/dev/null; then
        log WARNING "Docker服务未运行，尝试启动..."
        systemctl start docker || error_exit "Docker服务启动失败"
    fi
    
    log SUCCESS "Docker环境检查通过"
}

# 检查端口占用
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# 检查端口冲突
check_ports() {
    log INFO "检查端口占用情况..."
    
    local ports_in_use=()
    
    if check_port "$HTTP_PORT"; then
        ports_in_use+=("HTTP:$HTTP_PORT")
    fi
    
    if check_port "$HTTPS_PORT"; then
        ports_in_use+=("HTTPS:$HTTPS_PORT")
    fi
    
    if check_port "$MYSQL_PORT"; then
        ports_in_use+=("MySQL:$MYSQL_PORT")
    fi
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        log WARNING "以下端口已被占用: ${ports_in_use[*]}"
        echo -e "${YELLOW}是否继续安装？这将停止占用端口的服务 [y/N]:${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error_exit "用户取消安装"
        fi
    else
        log SUCCESS "端口检查通过"
    fi
}

# 初始化目录结构
init_directories() {
    log INFO "创建目录结构..."
    
    # 设置路径变量
    COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
    NGINX_CONF_DIR="${INSTALL_DIR}/nginx/conf"
    PHP_CONF_DIR="${INSTALL_DIR}/php/conf"
    MYSQL_CONF_DIR="${INSTALL_DIR}/mysql/conf"
    WEB_ROOT_DIR="${INSTALL_DIR}/www"
    LOG_DIR="${INSTALL_DIR}/logs"
    DATA_DIR="${INSTALL_DIR}/data"
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$NGINX_CONF_DIR"/{conf.d,ssl}
    mkdir -p "$PHP_CONF_DIR"
    mkdir -p "$MYSQL_CONF_DIR"
    mkdir -p "$WEB_ROOT_DIR"
    mkdir -p "$LOG_DIR"/{nginx,php,mysql}
    mkdir -p "$DATA_DIR"/{mysql,php}
    
    # 设置权限
    chmod -R 755 "$INSTALL_DIR"
    
    log SUCCESS "目录结构创建完成"
}

# 生成Nginx配置
generate_nginx_config() {
    log INFO "生成Nginx配置文件..."
    
    # 主配置文件
    cat > "$NGINX_CONF_DIR/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml application/atom+xml image/svg+xml;

    # 包含其他配置
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # 默认站点配置
    cat > "$NGINX_CONF_DIR/conf.d/default.conf" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    # 日志
    access_log /var/log/nginx/default_access.log;
    error_log /var/log/nginx/default_error.log;
    
    # PHP配置
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        
        # PHP-FPM优化
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
    
    # 静态资源缓存
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|webp|tiff|ttf|svg|eot|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # 安全配置
    location ~ /\. {
        deny all;
    }
    
    location ~ /\.ht {
        deny all;
    }
}

# HTTPS配置示例（需要SSL证书）
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name example.com;
#     
#     ssl_certificate /etc/nginx/ssl/cert.pem;
#     ssl_certificate_key /etc/nginx/ssl/key.pem;
#     
#     # SSL优化
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#     ssl_prefer_server_ciphers on;
#     
#     # 其他配置同上
# }
EOF

    log SUCCESS "Nginx配置生成完成"
}

# 生成PHP配置
generate_php_config() {
    log INFO "生成PHP配置文件..."
    
    # PHP配置文件
    cat > "$PHP_CONF_DIR/php.ini" << 'EOF'
[PHP]
; 基础设置
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
implicit_flush = Off
disable_functions = 
disable_classes = 
expose_php = Off
max_execution_time = 300
max_input_time = 60
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
log_errors = On
error_log = /var/log/php/error.log

; 文件上传
file_uploads = On
upload_max_filesize = 50M
max_file_uploads = 20
post_max_size = 50M

; 时区
date.timezone = Asia/Shanghai

; Session
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.use_strict_mode = 1
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_httponly = 1
session.gc_probability = 1
session.gc_divisor = 1000
session.gc_maxlifetime = 1440

; OPcache
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
opcache.fast_shutdown=1

; 扩展
extension=mysqli
extension=pdo_mysql
extension=gd
extension=curl
extension=mbstring
extension=zip
extension=xml
extension=json
extension=bcmath
EOF

    # PHP-FPM配置
    cat > "$PHP_CONF_DIR/www.conf" << 'EOF'
[www]
user = www-data
group = www-data
listen = 0.0.0.0:9000
listen.owner = www-data
listen.group = www-data

; 进程管理
pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

; 日志
access.log = /var/log/php/access.log
slowlog = /var/log/php/slow.log
request_slowlog_timeout = 5s

; 环境变量
env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; PHP设置
php_admin_value[error_log] = /var/log/php/error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = 256M
EOF

    log SUCCESS "PHP配置生成完成"
}

# 生成MySQL配置
generate_mysql_config() {
    log INFO "生成MySQL配置文件..."
    
    cat > "$MYSQL_CONF_DIR/my.cnf" << 'EOF'
[mysqld]
# 基础设置
user = mysql
default-storage-engine = InnoDB
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
init_connect = 'SET NAMES utf8mb4'
skip-character-set-client-handshake
skip-name-resolve

# 连接设置
max_connections = 200
max_connect_errors = 10
connect_timeout = 10

# 缓存设置
table_open_cache = 2000
table_definition_cache = 1400
query_cache_type = 1
query_cache_size = 64M
query_cache_limit = 2M

# InnoDB设置
innodb_buffer_pool_size = 512M
innodb_buffer_pool_instances = 1
innodb_log_file_size = 128M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1

# 日志设置
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# 其他优化
tmp_table_size = 64M
max_heap_table_size = 64M
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 8M
join_buffer_size = 2M

[mysql]
default-character-set = utf8mb4

[client]
default-character-set = utf8mb4
EOF

    log SUCCESS "MySQL配置生成完成"
}

# 生成Docker Compose文件
generate_docker_compose() {
    log INFO "生成Docker Compose配置文件..."
    
    # 生成MySQL root密码
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        MYSQL_ROOT_PASSWORD=$(generate_password)
        log INFO "生成MySQL root密码: $MYSQL_ROOT_PASSWORD"
    fi
    
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: ldnmp_nginx
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"
    volumes:
      - ${NGINX_CONF_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro
      - ${NGINX_CONF_DIR}/conf.d:/etc/nginx/conf.d:ro
      - ${NGINX_CONF_DIR}/ssl:/etc/nginx/ssl:ro
      - ${WEB_ROOT_DIR}:/var/www/html
      - ${LOG_DIR}/nginx:/var/log/nginx
    depends_on:
      - php
    networks:
      - ldnmp_network

  php:
    image: php:${PHP_VERSION}-fpm-alpine
    container_name: ldnmp_php
    restart: unless-stopped
    volumes:
      - ${PHP_CONF_DIR}/php.ini:/usr/local/etc/php/php.ini:ro
      - ${PHP_CONF_DIR}/www.conf:/usr/local/etc/php-fpm.d/www.conf:ro
      - ${WEB_ROOT_DIR}:/var/www/html
      - ${LOG_DIR}/php:/var/log/php
      - ${DATA_DIR}/php:/var/lib/php
    environment:
      - TZ=Asia/Shanghai
    depends_on:
      - mysql
    networks:
      - ldnmp_network

  mysql:
    image: mysql:8.0
    container_name: ldnmp_mysql
    restart: unless-stopped
    ports:
      - "${MYSQL_PORT}:3306"
    volumes:
      - ${MYSQL_CONF_DIR}/my.cnf:/etc/mysql/conf.d/my.cnf:ro
      - ${DATA_DIR}/mysql:/var/lib/mysql
      - ${LOG_DIR}/mysql:/var/log/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - TZ=Asia/Shanghai
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    networks:
      - ldnmp_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: ldnmp_phpmyadmin
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      - PMA_HOST=mysql
      - PMA_PORT=3306
      - UPLOAD_LIMIT=50M
    depends_on:
      - mysql
    networks:
      - ldnmp_network

networks:
  ldnmp_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    log SUCCESS "Docker Compose配置生成完成"
}

# 创建示例文件
create_sample_files() {
    log INFO "创建示例文件..."
    
    # PHP信息页面
    cat > "$WEB_ROOT_DIR/info.php" << 'EOF'
<?php
phpinfo();
EOF

    # 数据库连接测试
    cat > "$WEB_ROOT_DIR/test_db.php" << 'EOF'
<?php
$host = 'mysql';
$user = 'root';
$pass = getenv('MYSQL_ROOT_PASSWORD') ?: 'your_password';
$db = 'mysql';

try {
    $conn = new mysqli($host, $user, $pass, $db);
    if ($conn->connect_error) {
        die("连接失败: " . $conn->connect_error);
    }
    echo "MySQL连接成功！<br>";
    echo "服务器版本: " . $conn->server_info;
    $conn->close();
} catch (Exception $e) {
    echo "错误: " . $e->getMessage();
}
EOF

    # 首页
    cat > "$WEB_ROOT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LDNMP环境</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .info {
            margin: 20px 0;
            padding: 15px;
            background-color: #e8f5e9;
            border-radius: 5px;
        }
        .links {
            text-align: center;
            margin-top: 30px;
        }
        .links a {
            display: inline-block;
            margin: 10px;
            padding: 10px 20px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: background-color 0.3s;
        }
        .links a:hover {
            background-color: #45a049;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎉 LDNMP环境部署成功！</h1>
        <div class="info">
            <h2>环境信息</h2>
            <ul>
                <li>Nginx: Alpine最新版</li>
                <li>MySQL: 8.0</li>
                <li>PHP: <?php echo PHP_VERSION; ?></li>
                <li>Docker Compose: 3.8</li>
            </ul>
        </div>
        <div class="links">
            <a href="/info.php">PHP信息</a>
            <a href="/test_db.php">数据库测试</a>
            <a href="http://localhost:8080" target="_blank">phpMyAdmin</a>
        </div>
    </div>
</body>
</html>
EOF

    # 设置权限
    chmod -R 755 "$WEB_ROOT_DIR"
    
    log SUCCESS "示例文件创建完成"
}

# 构建PHP镜像（安装扩展）
build_php_image() {
    log INFO "构建PHP镜像（安装必要扩展）..."
    
    # 创建Dockerfile
    cat > "${INSTALL_DIR}/php/Dockerfile" << EOF
FROM php:${PHP_VERSION}-fpm-alpine

# 安装依赖
RUN apk add --no-cache \
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libzip-dev \
    libwebp-dev \
    icu-dev \
    oniguruma-dev \
    curl-dev \
    libxml2-dev

# 配置和安装PHP扩展
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    && docker-php-ext-install -j\$(nproc) \
    gd \
    mysqli \
    pdo_mysql \
    zip \
    intl \
    opcache \
    bcmath \
    curl \
    mbstring \
    xml \
    json

# 安装额外工具
RUN apk add --no-cache \
    bash \
    vim \
    git

# 创建日志目录
RUN mkdir -p /var/log/php && \
    chown -R www-data:www-data /var/log/php

WORKDIR /var/www/html
EOF

    # 更新docker-compose.yml使用自定义镜像
    sed -i "s|image: php:${PHP_VERSION}-fpm-alpine|build: ./php|g" "$COMPOSE_FILE"
    
    log SUCCESS "PHP镜像配置完成"
}

# 启动服务
start_services() {
    log INFO "启动LDNMP服务..."
    
    cd "$INSTALL_DIR"
    
    # 使用docker-compose或docker compose命令
    if command_exists docker-compose; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    # 等待服务启动
    log INFO "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    local all_running=true
    for service in nginx php mysql phpmyadmin; do
        if ! docker ps | grep -q "ldnmp_${service}"; then
            log ERROR "${service}服务启动失败"
            all_running=false
        fi
    done
    
    if [[ $all_running == true ]]; then
        log SUCCESS "所有服务启动成功"
    else
        error_exit "部分服务启动失败，请检查日志"
    fi
}

# 保存配置信息
save_config() {
    log INFO "保存配置信息..."
    
    cat > "${INSTALL_DIR}/config.info" << EOF
# LDNMP配置信息
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

安装目录: ${INSTALL_DIR}
HTTP端口: ${HTTP_PORT}
HTTPS端口: ${HTTPS_PORT}
MySQL端口: ${MYSQL_PORT}
phpMyAdmin端口: 8080
MySQL root密码: ${MYSQL_ROOT_PASSWORD}
PHP版本: ${PHP_VERSION}

Web根目录: ${WEB_ROOT_DIR}
日志目录: ${LOG_DIR}
数据目录: ${DATA_DIR}
EOF

    chmod 600 "${INSTALL_DIR}/config.info"
    log SUCCESS "配置信息已保存"
}

# 显示安装信息
show_installation_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}LDNMP环境安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}访问地址:${NC}"
    echo -e "  Web服务: http://your-server-ip:${HTTP_PORT}"
    echo -e "  phpMyAdmin: http://your-server-ip:8080"
    echo
    echo -e "${BLUE}数据库信息:${NC}"
    echo -e "  主机: localhost:${MYSQL_PORT}"
    echo -e "  用户名: root"
    echo -e "  密码: ${MYSQL_ROOT_PASSWORD}"
    echo
    echo -e "${BLUE}目录结构:${NC}"
    echo -e "  安装目录: ${INSTALL_DIR}"
    echo -e "  网站根目录: ${WEB_ROOT_DIR}"
    echo -e "  日志目录: ${LOG_DIR}"
    echo
    echo -e "${BLUE}管理命令:${NC}"
    echo -e "  查看状态: bash $0 --status"
    echo -e "  停止服务: bash $0 --stop"
    echo -e "  启动服务: bash $0 --start"
    echo -e "  重启服务: bash $0 --restart"
    echo
    echo -e "${YELLOW}配置信息已保存到: ${INSTALL_DIR}/config.info${NC}"
    echo -e "${YELLOW}安装日志: ${LOG_FILE}${NC}"
    echo
}

# 查看服务状态
show_status() {
    echo -e "${BLUE}LDNMP服务状态:${NC}"
    echo "----------------------------------------"
    
    cd "$INSTALL_DIR" 2>/dev/null || {
        error_exit "LDNMP未安装或安装目录不存在"
    }
    
    if command_exists docker-compose; then
        docker-compose ps
    else
        docker compose ps
    fi
}

# 停止服务
stop_services() {
    log INFO "停止LDNMP服务..."
    
    cd "$INSTALL_DIR" 2>/dev/null || {
        error_exit "LDNMP未安装或安装目录不存在"
    }
    
    if command_exists docker-compose; then
        docker-compose down
    else
        docker compose down
    fi
    
    log SUCCESS "服务已停止"
}

# 重启服务
restart_services() {
    log INFO "重启LDNMP服务..."
    stop_services
    sleep 2
    start_services
}

# 卸载LDNMP
remove_ldnmp() {
    log WARNING "开始卸载LDNMP环境..."
    
    echo -e "${YELLOW}此操作将删除所有数据，是否继续？[y/N]:${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log INFO "用户取消卸载"
        exit 0
    fi
    
    # 停止并删除容器
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"
        if command_exists docker-compose; then
            docker-compose down -v
        else
            docker compose down -v
        fi
    fi
    
    # 删除目录
    rm -rf "$INSTALL_DIR"
    
    log SUCCESS "LDNMP环境已完全卸载"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port-http)
                HTTP_PORT="$2"
                shift 2
                ;;
            --port-https)
                HTTPS_PORT="$2"
                shift 2
                ;;
            --port-mysql)
                MYSQL_PORT="$2"
                shift 2
                ;;
            --mysql-root-pwd)
                MYSQL_ROOT_PASSWORD="$2"
                shift 2
                ;;
            --php-version)
                PHP_VERSION="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --status)
                ACTION="status"
                shift
                ;;
            --stop)
                ACTION="stop"
                shift
                ;;
            --start)
                ACTION="start"
                shift
                ;;
            --restart)
                ACTION="restart"
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
    
    # 开始执行
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            check_docker
            check_ports
            init_directories
            generate_nginx_config
            generate_php_config
            generate_mysql_config
            generate_docker_compose
            create_sample_files
            build_php_image
            start_services
            save_config
            show_installation_info
            ;;
        remove)
            remove_ldnmp
            ;;
        status)
            show_status
            ;;
        stop)
            stop_services
            ;;
        start)
            cd "$INSTALL_DIR" && start_services
            ;;
        restart)
            restart_services
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"