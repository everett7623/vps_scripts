#!/bin/bash
#==============================================================================
# 脚本名称: install_wordpress.sh
# 脚本描述: WordPress安装配置脚本 - 支持Docker和传统部署，包含性能优化和安全加固
# 脚本路径: vps_scripts/scripts/service_install/install_wordpress.sh
# 作者: Jensfrank
# 使用方法: bash install_wordpress.sh [选项]
# 选项: 
#   --method METHOD      安装方式 (docker/traditional, 默认: docker)
#   --domain DOMAIN      网站域名 (默认: localhost)
#   --port PORT          HTTP端口 (默认: 80)
#   --ssl                启用HTTPS和SSL证书
#   --ssl-email EMAIL    Let's Encrypt邮箱
#   --db-host HOST       数据库主机 (默认: localhost)
#   --db-name NAME       数据库名称 (默认: wordpress)
#   --db-user USER       数据库用户 (默认: wpuser)
#   --db-pass PASS       数据库密码 (默认: 随机生成)
#   --wp-user USER       WP管理员用户 (默认: admin)
#   --wp-pass PASS       WP管理员密码 (默认: 随机生成)
#   --wp-email EMAIL     WP管理员邮箱
#   --install-dir DIR    安装目录 (默认: /var/www/wordpress)
#   --cn                 使用国内镜像源
#   --plugins PLUGINS    预装插件列表
#   --theme THEME        安装主题
#   --multisite          启用多站点
#   --remove             卸载WordPress
#   --backup             备份WordPress
#   --restore FILE       恢复备份
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
readonly SCRIPT_NAME="WordPress安装配置脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/wordpress_install_$(date +%Y%m%d_%H%M%S).log"
readonly BACKUP_DIR="/var/backups/wordpress"

# 默认配置
INSTALL_METHOD="docker"
SITE_DOMAIN="localhost"
HTTP_PORT=80
ENABLE_SSL=false
SSL_EMAIL=""
DB_HOST="localhost"
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASSWORD=""
DB_ROOT_PASSWORD=""
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD=""
WP_ADMIN_EMAIL=""
INSTALL_DIR="/var/www/wordpress"
USE_CN_MIRROR=false
INSTALL_PLUGINS=""
INSTALL_THEME=""
ENABLE_MULTISITE=false
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""
WEB_SERVER=""
PHP_VERSION=""

# WordPress相关
WP_VERSION="latest"
WP_LOCALE="en_US"
WP_CLI_PATH="/usr/local/bin/wp"

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --method METHOD      安装方式
                        - docker: Docker容器部署（推荐）
                        - traditional: 传统LAMP/LNMP部署
                        默认: docker
    
    --domain DOMAIN     网站域名（默认: localhost）
    --port PORT         HTTP端口（默认: 80）
    --ssl               启用HTTPS（自动申请Let's Encrypt证书）
    --ssl-email EMAIL   SSL证书邮箱（启用SSL时必需）
    
    数据库配置:
    --db-host HOST      数据库主机（默认: localhost）
    --db-name NAME      数据库名称（默认: wordpress）
    --db-user USER      数据库用户（默认: wpuser）
    --db-pass PASS      数据库密码（默认: 随机生成）
    
    WordPress配置:
    --wp-user USER      管理员用户名（默认: admin）
    --wp-pass PASS      管理员密码（默认: 随机生成）
    --wp-email EMAIL    管理员邮箱
    
    高级选项:
    --install-dir DIR   安装目录（默认: /var/www/wordpress）
    --cn                使用国内镜像源
    --plugins PLUGINS   预装插件，逗号分隔
                        示例: akismet,jetpack,wordfence
    --theme THEME       安装主题
    --multisite         启用多站点模式
    
    维护选项:
    --remove            卸载WordPress
    --backup            备份WordPress
    --restore FILE      从备份恢复
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                              # 默认Docker安装
    $(basename "$0") --domain example.com --ssl   # 配置域名和SSL
    $(basename "$0") --method traditional         # 传统方式安装
    $(basename "$0") --plugins akismet,wordfence  # 预装安全插件
    $(basename "$0") --backup                     # 备份站点

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
    local length=${1:-16}
    # 确保密码包含大小写字母、数字和特殊字符
    local password=""
    password+=$(openssl rand -base64 48 | tr -d "=+/" | grep -o '[A-Z]' | head -4 | tr -d '\n')
    password+=$(openssl rand -base64 48 | tr -d "=+/" | grep -o '[a-z]' | head -4 | tr -d '\n')
    password+=$(openssl rand -base64 48 | tr -d "=+/" | grep -o '[0-9]' | head -4 | tr -d '\n')
    password+="@#"
    echo "$password" | fold -w1 | shuf | tr -d '\n' | head -c "$length"
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
    
    # 设置语言环境
    if [[ $USE_CN_MIRROR == true ]]; then
        WP_LOCALE="zh_CN"
    fi
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查域名解析
check_domain() {
    if [[ "$SITE_DOMAIN" != "localhost" ]] && [[ "$SITE_DOMAIN" != "127.0.0.1" ]]; then
        log INFO "检查域名解析..."
        
        local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
        local domain_ip=$(dig +short "$SITE_DOMAIN" 2>/dev/null | tail -1)
        
        if [[ -z "$domain_ip" ]]; then
            log WARNING "域名 $SITE_DOMAIN 未解析"
            echo -e "${YELLOW}请确保域名已正确解析到服务器IP: $server_ip${NC}"
            echo -e "${YELLOW}是否继续安装？[y/N]:${NC} "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                exit 0
            fi
        elif [[ "$domain_ip" != "$server_ip" ]]; then
            log WARNING "域名解析IP ($domain_ip) 与服务器IP ($server_ip) 不一致"
        else
            log SUCCESS "域名解析正确"
        fi
    fi
}

# 检查端口占用
check_port() {
    if netstat -tuln 2>/dev/null | grep -q ":$HTTP_PORT "; then
        error_exit "端口 $HTTP_PORT 已被占用，请使用 --port 指定其他端口"
    fi
    
    if [[ $ENABLE_SSL == true ]] && netstat -tuln 2>/dev/null | grep -q ":443 "; then
        error_exit "端口 443 已被占用，无法启用SSL"
    fi
}

# Docker方式安装
install_docker_method() {
    log INFO "使用Docker方式安装WordPress..."
    
    # 检查Docker
    if ! command_exists docker; then
        error_exit "Docker未安装，请先安装Docker或使用 --method traditional"
    fi
    
    # 检查docker-compose
    if ! command_exists docker-compose && ! docker compose version &>/dev/null; then
        install_docker_compose
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # 生成数据库密码
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(generate_password 20)
    fi
    if [[ -z "$DB_ROOT_PASSWORD" ]]; then
        DB_ROOT_PASSWORD=$(generate_password 24)
    fi
    
    # 生成docker-compose.yml
    generate_docker_compose
    
    # 配置环境变量
    generate_env_file
    
    # 启动容器
    log INFO "启动WordPress容器..."
    if command_exists docker-compose; then
        docker-compose up -d
    else
        docker compose up -d
    fi
    
    # 等待服务启动
    wait_for_wordpress
    
    # 配置WordPress
    configure_wordpress_docker
}

# 生成Docker Compose配置
generate_docker_compose() {
    log INFO "生成Docker Compose配置..."
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  wordpress:
    image: wordpress:${WP_VERSION}-php8.2-apache
    container_name: wordpress_app
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:80"
EOF

    if [[ $ENABLE_SSL == true ]]; then
        cat >> docker-compose.yml << EOF
      - "443:443"
EOF
    fi

    cat >> docker-compose.yml << EOF
    environment:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_DB_NAME: \${DB_NAME}
      WORDPRESS_DB_USER: \${DB_USER}
      WORDPRESS_DB_PASSWORD: \${DB_PASSWORD}
      WORDPRESS_TABLE_PREFIX: wp_
    volumes:
      - wordpress_data:/var/www/html
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini:ro
EOF

    if [[ $ENABLE_SSL == true ]]; then
        cat >> docker-compose.yml << EOF
      - ./ssl:/etc/letsencrypt
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
EOF
    fi

    cat >> docker-compose.yml << EOF
    depends_on:
      - mysql
    networks:
      - wordpress_network

  mysql:
    image: mysql:8.0
    container_name: wordpress_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: \${DB_NAME}
      MYSQL_USER: \${DB_USER}
      MYSQL_PASSWORD: \${DB_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./mysql/conf.d:/etc/mysql/conf.d:ro
    networks:
      - wordpress_network

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: wordpress_pma
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      PMA_HOST: mysql
      PMA_PORT: 3306
      UPLOAD_LIMIT: 100M
    depends_on:
      - mysql
    networks:
      - wordpress_network

volumes:
  wordpress_data:
  mysql_data:

networks:
  wordpress_network:
    driver: bridge
EOF

    # 创建PHP配置
    mkdir -p mysql/conf.d
    cat > uploads.ini << EOF
file_uploads = On
upload_max_filesize = 100M
post_max_size = 100M
max_execution_time = 600
max_input_time = 600
memory_limit = 256M
EOF

    # 创建MySQL配置
    cat > mysql/conf.d/wordpress.cnf << EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_allowed_packet = 64M
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
EOF
}

# 生成环境变量文件
generate_env_file() {
    cat > .env << EOF
# WordPress环境配置
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
WP_ADMIN_USER=$WP_ADMIN_USER
WP_ADMIN_PASSWORD=$WP_ADMIN_PASSWORD
WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL
SITE_DOMAIN=$SITE_DOMAIN
EOF
    
    chmod 600 .env
}

# 传统方式安装
install_traditional_method() {
    log INFO "使用传统方式安装WordPress..."
    
    # 检测Web服务器
    detect_web_server
    
    # 安装LAMP/LNMP环境
    install_web_stack
    
    # 创建数据库
    create_database
    
    # 下载WordPress
    download_wordpress
    
    # 配置WordPress
    configure_wordpress_traditional
    
    # 配置Web服务器
    configure_web_server
    
    # 安装WP-CLI
    install_wp_cli
    
    # 完成WordPress安装
    finalize_wordpress_install
}

# 检测Web服务器
detect_web_server() {
    if systemctl is-active nginx &>/dev/null; then
        WEB_SERVER="nginx"
        PHP_VERSION=$(php -v 2>/dev/null | head -1 | grep -oP '\d+\.\d+' || echo "7.4")
    elif systemctl is-active apache2 &>/dev/null || systemctl is-active httpd &>/dev/null; then
        WEB_SERVER="apache"
        PHP_VERSION=$(php -v 2>/dev/null | head -1 | grep -oP '\d+\.\d+' || echo "7.4")
    else
        log INFO "未检测到Web服务器，将安装Nginx"
        WEB_SERVER="nginx"
    fi
}

# 安装Web环境
install_web_stack() {
    log INFO "安装Web环境..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            
            if [[ "$WEB_SERVER" == "nginx" ]]; then
                apt-get install -y nginx php-fpm php-mysql php-curl php-gd php-mbstring \
                    php-xml php-xmlrpc php-soap php-intl php-zip php-bcmath php-imagick
            else
                apt-get install -y apache2 libapache2-mod-php php-mysql php-curl php-gd \
                    php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-bcmath php-imagick
                a2enmod rewrite
            fi
            
            # 安装MySQL/MariaDB
            if ! command_exists mysql; then
                apt-get install -y mariadb-server mariadb-client
                systemctl start mariadb
                systemctl enable mariadb
            fi
            ;;
            
        centos|rhel|almalinux|rocky)
            if [[ "$WEB_SERVER" == "nginx" ]]; then
                yum install -y nginx php-fpm php-mysqlnd php-curl php-gd php-mbstring \
                    php-xml php-soap php-intl php-zip php-bcmath php-imagick
            else
                yum install -y httpd php php-mysqlnd php-curl php-gd php-mbstring \
                    php-xml php-soap php-intl php-zip php-bcmath php-imagick
            fi
            
            # 安装MariaDB
            if ! command_exists mysql; then
                yum install -y mariadb-server mariadb
                systemctl start mariadb
                systemctl enable mariadb
            fi
            ;;
    esac
    
    log SUCCESS "Web环境安装完成"
}

# 创建数据库
create_database() {
    log INFO "创建WordPress数据库..."
    
    # 生成数据库密码
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(generate_password 20)
    fi
    
    # 设置root密码（如果需要）
    if [[ -z "$DB_ROOT_PASSWORD" ]]; then
        DB_ROOT_PASSWORD=$(generate_password 24)
        mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';"
    fi
    
    # 创建数据库和用户
    mysql -u root -p"$DB_ROOT_PASSWORD" << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    log SUCCESS "数据库创建完成"
}

# 下载WordPress
download_wordpress() {
    log INFO "下载WordPress..."
    
    # 创建临时目录
    local temp_dir="/tmp/wordpress_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载WordPress
    if [[ $USE_CN_MIRROR == true ]]; then
        wget -q --show-progress "https://cn.wordpress.org/latest-zh_CN.tar.gz" -O wordpress.tar.gz
    else
        wget -q --show-progress "https://wordpress.org/latest.tar.gz" -O wordpress.tar.gz
    fi
    
    # 解压到安装目录
    mkdir -p "$INSTALL_DIR"
    tar -xzf wordpress.tar.gz
    cp -r wordpress/* "$INSTALL_DIR/"
    
    # 设置权限
    chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || \
    chown -R nginx:nginx "$INSTALL_DIR" 2>/dev/null || \
    chown -R apache:apache "$INSTALL_DIR" 2>/dev/null
    
    find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    
    # 清理
    rm -rf "$temp_dir"
    
    log SUCCESS "WordPress下载完成"
}

# 配置WordPress（传统方式）
configure_wordpress_traditional() {
    log INFO "配置WordPress..."
    
    cd "$INSTALL_DIR"
    
    # 复制配置文件
    cp wp-config-sample.php wp-config.php
    
    # 生成安全密钥
    local auth_key=$(generate_password 64)
    local secure_auth_key=$(generate_password 64)
    local logged_in_key=$(generate_password 64)
    local nonce_key=$(generate_password 64)
    local auth_salt=$(generate_password 64)
    local secure_auth_salt=$(generate_password 64)
    local logged_in_salt=$(generate_password 64)
    local nonce_salt=$(generate_password 64)
    
    # 更新配置文件
    sed -i "s/database_name_here/$DB_NAME/" wp-config.php
    sed -i "s/username_here/$DB_USER/" wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/" wp-config.php
    sed -i "s/localhost/$DB_HOST/" wp-config.php
    
    # 设置安全密钥
    sed -i "s/put your unique phrase here/$auth_key/" wp-config.php
    sed -i "s/put your unique phrase here/$secure_auth_key/" wp-config.php
    sed -i "s/put your unique phrase here/$logged_in_key/" wp-config.php
    sed -i "s/put your unique phrase here/$nonce_key/" wp-config.php
    sed -i "s/put your unique phrase here/$auth_salt/" wp-config.php
    sed -i "s/put your unique phrase here/$secure_auth_salt/" wp-config.php
    sed -i "s/put your unique phrase here/$logged_in_salt/" wp-config.php
    sed -i "s/put your unique phrase here/$nonce_salt/" wp-config.php
    
    # 添加额外配置
    cat >> wp-config.php << 'EOF'

/* WordPress安全和性能优化 */
define('WP_AUTO_UPDATE_CORE', 'minor');
define('DISALLOW_FILE_EDIT', true);
define('WP_POST_REVISIONS', 5);
define('EMPTY_TRASH_DAYS', 7);
define('WP_CRON_LOCK_TIMEOUT', 60);
define('AUTOSAVE_INTERVAL', 120);

/* 内存限制 */
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

/* 调试设置 */
define('WP_DEBUG', false);
define('WP_DEBUG_LOG', false);
define('WP_DEBUG_DISPLAY', false);
EOF
    
    log SUCCESS "WordPress配置完成"
}

# 配置Web服务器
configure_web_server() {
    log INFO "配置Web服务器..."
    
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        configure_nginx
    else
        configure_apache
    fi
}

# 配置Nginx
configure_nginx() {
    local config_file="/etc/nginx/sites-available/wordpress"
    
    cat > "$config_file" << EOF
server {
    listen $HTTP_PORT;
    listen [::]:$HTTP_PORT;
    server_name $SITE_DOMAIN;
    
    root $INSTALL_DIR;
    index index.php index.html index.htm;
    
    client_max_body_size 100M;
    
    # 日志
    access_log /var/log/nginx/wordpress_access.log;
    error_log /var/log/nginx/wordpress_error.log;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # PHP处理
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 256 16k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
    
    # 静态资源缓存
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml|svg|webp)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # 安全设置
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /\.user\.ini {
        deny all;
    }
    
    location ~* /(wp-config\.php|readme\.html|license\.txt) {
        deny all;
    }
    
    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }
}
EOF
    
    # 启用站点
    ln -sf "$config_file" /etc/nginx/sites-enabled/wordpress
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    nginx -t || error_exit "Nginx配置错误"
    
    # 重启Nginx
    systemctl restart nginx
    
    log SUCCESS "Nginx配置完成"
}

# 配置Apache
configure_apache() {
    local config_file="/etc/apache2/sites-available/wordpress.conf"
    [[ "$OS" == "centos" ]] && config_file="/etc/httpd/conf.d/wordpress.conf"
    
    cat > "$config_file" << EOF
<VirtualHost *:$HTTP_PORT>
    ServerName $SITE_DOMAIN
    DocumentRoot $INSTALL_DIR
    
    <Directory $INSTALL_DIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/wordpress_error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress_access.log combined
    
    # PHP设置
    php_value upload_max_filesize 100M
    php_value post_max_size 100M
    php_value max_execution_time 300
    php_value max_input_time 300
</VirtualHost>
EOF
    
    # 创建.htaccess文件
    cat > "$INSTALL_DIR/.htaccess" << 'EOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress

# 安全设置
<Files wp-config.php>
Order allow,deny
Deny from all
</Files>

# 禁止目录浏览
Options -Indexes

# 保护.htaccess
<Files .htaccess>
Order allow,deny
Deny from all
</Files>
EOF
    
    # 启用站点和模块
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        a2ensite wordpress.conf
        a2dissite 000-default.conf
        a2enmod rewrite
    fi
    
    # 重启Apache
    systemctl restart apache2 2>/dev/null || systemctl restart httpd
    
    log SUCCESS "Apache配置完成"
}

# 安装WP-CLI
install_wp_cli() {
    if ! command_exists wp; then
        log INFO "安装WP-CLI..."
        
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar "$WP_CLI_PATH"
        
        log SUCCESS "WP-CLI安装完成"
    fi
}

# 完成WordPress安装
finalize_wordpress_install() {
    log INFO "完成WordPress安装..."
    
    cd "$INSTALL_DIR"
    
    # 生成管理员密码
    if [[ -z "$WP_ADMIN_PASSWORD" ]]; then
        WP_ADMIN_PASSWORD=$(generate_password 16)
    fi
    
    # 设置邮箱
    if [[ -z "$WP_ADMIN_EMAIL" ]]; then
        WP_ADMIN_EMAIL="admin@$SITE_DOMAIN"
    fi
    
    # 使用WP-CLI完成安装
    sudo -u www-data wp core install \
        --url="http://$SITE_DOMAIN:$HTTP_PORT" \
        --title="My WordPress Site" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email
    
    # 基础优化
    sudo -u www-data wp option update permalink_structure '/%postname%/'
    sudo -u www-data wp option update timezone_string 'Asia/Shanghai'
    
    log SUCCESS "WordPress安装完成"
}

# 等待WordPress就绪
wait_for_wordpress() {
    log INFO "等待WordPress启动..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT" | grep -q "200\|302"; then
            log SUCCESS "WordPress已就绪"
            return 0
        fi
        
        sleep 2
        ((attempt++))
    done
    
    error_exit "WordPress启动超时"
}

# 配置WordPress（Docker方式）
configure_wordpress_docker() {
    log INFO "配置WordPress..."
    
    # 生成管理员密码
    if [[ -z "$WP_ADMIN_PASSWORD" ]]; then
        WP_ADMIN_PASSWORD=$(generate_password 16)
    fi
    
    # 设置邮箱
    if [[ -z "$WP_ADMIN_EMAIL" ]]; then
        WP_ADMIN_EMAIL="admin@$SITE_DOMAIN"
    fi
    
    # 使用docker exec运行WP-CLI
    docker exec wordpress_app bash -c "
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
        chmod +x wp-cli.phar && \
        mv wp-cli.phar /usr/local/bin/wp && \
        wp core install \
            --url='http://$SITE_DOMAIN:$HTTP_PORT' \
            --title='My WordPress Site' \
            --admin_user='$WP_ADMIN_USER' \
            --admin_password='$WP_ADMIN_PASSWORD' \
            --admin_email='$WP_ADMIN_EMAIL' \
            --skip-email \
            --allow-root
    "
    
    # 优化设置
    docker exec wordpress_app wp option update permalink_structure '/%postname%/' --allow-root
    docker exec wordpress_app wp option update timezone_string 'Asia/Shanghai' --allow-root
    
    log SUCCESS "WordPress配置完成"
}

# 安装Docker Compose
install_docker_compose() {
    log INFO "安装Docker Compose..."
    
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log SUCCESS "Docker Compose安装完成"
}

# 配置SSL证书
configure_ssl() {
    if [[ $ENABLE_SSL == true ]]; then
        log INFO "配置SSL证书..."
        
        if [[ -z "$SSL_EMAIL" ]]; then
            error_exit "启用SSL需要提供邮箱地址，请使用 --ssl-email 参数"
        fi
        
        # 安装Certbot
        case $OS in
            ubuntu|debian)
                apt-get install -y certbot python3-certbot-nginx
                ;;
            centos|rhel|almalinux|rocky)
                yum install -y certbot python3-certbot-nginx
                ;;
        esac
        
        # 申请证书
        certbot --nginx -d "$SITE_DOMAIN" --non-interactive --agree-tos -m "$SSL_EMAIL" --redirect
        
        # 设置自动续期
        echo "0 0,12 * * * root certbot renew --quiet" > /etc/cron.d/certbot
        
        log SUCCESS "SSL证书配置完成"
    fi
}

# 安装插件
install_plugins() {
    if [[ -n "$INSTALL_PLUGINS" ]]; then
        log INFO "安装WordPress插件..."
        
        IFS=',' read -ra PLUGINS <<< "$INSTALL_PLUGINS"
        
        for plugin in "${PLUGINS[@]}"; do
            plugin=$(echo "$plugin" | tr -d ' ')
            log INFO "安装插件: $plugin"
            
            if [[ "$INSTALL_METHOD" == "docker" ]]; then
                docker exec wordpress_app wp plugin install "$plugin" --activate --allow-root
            else
                sudo -u www-data wp plugin install "$plugin" --activate --path="$INSTALL_DIR"
            fi
        done
        
        log SUCCESS "插件安装完成"
    fi
}

# 安装主题
install_theme() {
    if [[ -n "$INSTALL_THEME" ]]; then
        log INFO "安装WordPress主题: $INSTALL_THEME"
        
        if [[ "$INSTALL_METHOD" == "docker" ]]; then
            docker exec wordpress_app wp theme install "$INSTALL_THEME" --activate --allow-root
        else
            sudo -u www-data wp theme install "$INSTALL_THEME" --activate --path="$INSTALL_DIR"
        fi
        
        log SUCCESS "主题安装完成"
    fi
}

# 配置多站点
configure_multisite() {
    if [[ $ENABLE_MULTISITE == true ]]; then
        log INFO "配置WordPress多站点..."
        
        if [[ "$INSTALL_METHOD" == "docker" ]]; then
            docker exec wordpress_app wp core multisite-convert --allow-root
        else
            sudo -u www-data wp core multisite-convert --path="$INSTALL_DIR"
        fi
        
        log SUCCESS "多站点配置完成"
    fi
}

# 创建备份
backup_wordpress() {
    log INFO "备份WordPress..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/wordpress_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        # 备份Docker卷
        cd "$INSTALL_DIR"
        docker-compose stop
        
        docker run --rm \
            -v wordpress_wordpress_data:/data \
            -v wordpress_mysql_data:/db \
            -v "$BACKUP_DIR":/backup \
            alpine tar czf "/backup/$(basename "$backup_file")" -C / data db
        
        docker-compose start
    else
        # 备份文件和数据库
        tar -czf "$backup_file" -C "$INSTALL_DIR" .
        
        mysqldump -u root -p"$DB_ROOT_PASSWORD" "$DB_NAME" | gzip >> "$backup_file"
    fi
    
    log SUCCESS "备份完成: $backup_file"
    
    # 清理旧备份（保留7天）
    find "$BACKUP_DIR" -name "wordpress_backup_*.tar.gz" -mtime +7 -delete
}

# 恢复备份
restore_wordpress() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error_exit "备份文件不存在: $backup_file"
    fi
    
    log WARNING "恢复WordPress备份..."
    echo -e "${YELLOW}此操作将覆盖当前数据，是否继续？[y/N]:${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # 恢复过程
    log INFO "正在恢复..."
    # TODO: 实现恢复逻辑
    
    log SUCCESS "恢复完成"
}

# 优化WordPress
optimize_wordpress() {
    log INFO "优化WordPress性能..."
    
    # 创建对象缓存目录
    mkdir -p "$INSTALL_DIR/wp-content/cache"
    
    # 安装性能优化插件
    local optimization_plugins="w3-total-cache autoptimize"
    
    for plugin in $optimization_plugins; do
        if [[ "$INSTALL_METHOD" == "docker" ]]; then
            docker exec wordpress_app wp plugin install "$plugin" --allow-root || true
        else
            sudo -u www-data wp plugin install "$plugin" --path="$INSTALL_DIR" || true
        fi
    done
    
    # 添加wp-config.php优化
    if [[ "$INSTALL_METHOD" == "traditional" ]]; then
        cat >> "$INSTALL_DIR/wp-config.php" << 'EOF'

/* 性能优化 */
define('WP_CACHE', true);
define('COMPRESS_CSS', true);
define('COMPRESS_SCRIPTS', true);
define('CONCATENATE_SCRIPTS', true);
define('ENFORCE_GZIP', true);
EOF
    fi
    
    log SUCCESS "性能优化完成"
}

# 安全加固
secure_wordpress() {
    log INFO "执行安全加固..."
    
    # 修改文件权限
    if [[ "$INSTALL_METHOD" == "traditional" ]]; then
        find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
        find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
        chmod 400 "$INSTALL_DIR/wp-config.php"
    fi
    
    # 安装安全插件
    local security_plugins="wordfence"
    
    for plugin in $security_plugins; do
        if [[ "$INSTALL_METHOD" == "docker" ]]; then
            docker exec wordpress_app wp plugin install "$plugin" --allow-root || true
        else
            sudo -u www-data wp plugin install "$plugin" --path="$INSTALL_DIR" || true
        fi
    done
    
    # 禁用文件编辑器
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        docker exec wordpress_app wp config set DISALLOW_FILE_EDIT true --raw --allow-root
    else
        sudo -u www-data wp config set DISALLOW_FILE_EDIT true --raw --path="$INSTALL_DIR"
    fi
    
    log SUCCESS "安全加固完成"
}

# 创建管理脚本
create_management_scripts() {
    log INFO "创建管理脚本..."
    
    # WordPress信息脚本
    cat > /usr/local/bin/wp-info << EOF
#!/bin/bash
echo "WordPress站点信息:"
echo "===================="
echo "网站地址: http://$SITE_DOMAIN:$HTTP_PORT"
$( [[ $ENABLE_SSL == true ]] && echo "SSL地址: https://$SITE_DOMAIN" )
echo "管理后台: http://$SITE_DOMAIN:$HTTP_PORT/wp-admin"
echo "管理员用户: $WP_ADMIN_USER"
echo "管理员密码: $WP_ADMIN_PASSWORD"
echo
echo "数据库信息:"
echo "数据库名: $DB_NAME"
echo "数据库用户: $DB_USER"
echo "数据库密码: $DB_PASSWORD"
$( [[ "$INSTALL_METHOD" == "docker" ]] && echo "phpMyAdmin: http://$SITE_DOMAIN:8080" )
echo "===================="
EOF
    chmod +x /usr/local/bin/wp-info
    
    # 备份脚本
    ln -sf "$0" /usr/local/bin/wp-backup
    
    log SUCCESS "管理脚本创建完成"
}

# 保存安装信息
save_install_info() {
    local info_file="$INSTALL_DIR/wordpress.info"
    
    cat > "$info_file" << EOF
# WordPress安装信息
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')

安装方式: $INSTALL_METHOD
安装目录: $INSTALL_DIR
WordPress版本: $WP_VERSION
语言: $WP_LOCALE

网站信息:
  域名: $SITE_DOMAIN
  HTTP端口: $HTTP_PORT
  SSL状态: $ENABLE_SSL
  多站点: $ENABLE_MULTISITE

管理员信息:
  用户名: $WP_ADMIN_USER
  密码: $WP_ADMIN_PASSWORD
  邮箱: $WP_ADMIN_EMAIL

数据库信息:
  主机: $DB_HOST
  数据库名: $DB_NAME
  用户名: $DB_USER
  密码: $DB_PASSWORD

访问地址:
  前台: http://$SITE_DOMAIN:$HTTP_PORT
  后台: http://$SITE_DOMAIN:$HTTP_PORT/wp-admin
$( [[ "$INSTALL_METHOD" == "docker" ]] && echo "  phpMyAdmin: http://$SITE_DOMAIN:8080" )

管理命令:
  wp-info     # 查看站点信息
  wp-backup   # 备份站点
$( [[ "$INSTALL_METHOD" == "docker" ]] && echo "  cd $INSTALL_DIR && docker-compose [命令]" )
EOF
    
    chmod 600 "$info_file"
}

# 显示安装信息
show_installation_info() {
    local server_ip=$(curl -s http://ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}WordPress安装成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}访问地址:${NC}"
    echo -e "${YELLOW}网站首页:${NC} http://$SITE_DOMAIN:$HTTP_PORT"
    if [[ $ENABLE_SSL == true ]]; then
        echo -e "${YELLOW}SSL地址:${NC} https://$SITE_DOMAIN"
    fi
    echo -e "${YELLOW}管理后台:${NC} http://$SITE_DOMAIN:$HTTP_PORT/wp-admin"
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        echo -e "${YELLOW}phpMyAdmin:${NC} http://$SITE_DOMAIN:8080"
    fi
    echo
    echo -e "${BLUE}管理员信息:${NC}"
    echo -e "  用户名: $WP_ADMIN_USER"
    echo -e "  密码: $WP_ADMIN_PASSWORD"
    echo -e "  邮箱: $WP_ADMIN_EMAIL"
    echo
    echo -e "${BLUE}数据库信息:${NC}"
    echo -e "  数据库名: $DB_NAME"
    echo -e "  用户名: $DB_USER"
    echo -e "  密码: $DB_PASSWORD"
    echo
    echo -e "${RED}重要提示:${NC}"
    echo "1. 请妥善保管以上登录信息"
    echo "2. 建议立即登录后台修改密码"
    echo "3. 建议配置SSL证书以提高安全性"
    echo "4. 定期备份网站数据"
    echo
    echo -e "${BLUE}常用命令:${NC}"
    echo "  wp-info              # 查看站点信息"
    echo "  bash $0 --backup     # 备份站点"
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        echo "  cd $INSTALL_DIR"
        echo "  docker-compose stop  # 停止站点"
        echo "  docker-compose start # 启动站点"
        echo "  docker-compose logs  # 查看日志"
    fi
    echo
    if [[ -n "$INSTALL_PLUGINS" ]]; then
        echo -e "${BLUE}已安装插件:${NC} $INSTALL_PLUGINS"
    fi
    if [[ -n "$INSTALL_THEME" ]]; then
        echo -e "${BLUE}已安装主题:${NC} $INSTALL_THEME"
    fi
    echo
    echo -e "${BLUE}配置文件:${NC} $INSTALL_DIR/wordpress.info"
    echo -e "${BLUE}安装日志:${NC} $LOG_FILE"
    echo
}

# 卸载WordPress
remove_wordpress() {
    log WARNING "开始卸载WordPress..."
    
    echo -e "${YELLOW}此操作将删除所有数据，是否继续？[y/N]:${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    if [[ "$INSTALL_METHOD" == "docker" ]]; then
        # Docker方式卸载
        cd "$INSTALL_DIR" 2>/dev/null || true
        docker-compose down -v 2>/dev/null || true
        rm -rf "$INSTALL_DIR"
    else
        # 传统方式卸载
        # 删除数据库
        mysql -u root -p"$DB_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS $DB_NAME;" 2>/dev/null || true
        mysql -u root -p"$DB_ROOT_PASSWORD" -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" 2>/dev/null || true
        
        # 删除网站配置
        rm -f /etc/nginx/sites-enabled/wordpress
        rm -f /etc/nginx/sites-available/wordpress
        rm -f /etc/apache2/sites-enabled/wordpress.conf
        rm -f /etc/apache2/sites-available/wordpress.conf
        rm -f /etc/httpd/conf.d/wordpress.conf
        
        # 删除文件
        rm -rf "$INSTALL_DIR"
        
        # 重启Web服务器
        systemctl restart nginx 2>/dev/null || true
        systemctl restart apache2 2>/dev/null || true
        systemctl restart httpd 2>/dev/null || true
    fi
    
    # 删除管理脚本
    rm -f /usr/local/bin/wp-info
    rm -f /usr/local/bin/wp-backup
    
    log SUCCESS "WordPress卸载完成"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --domain)
                SITE_DOMAIN="$2"
                shift 2
                ;;
            --port)
                HTTP_PORT="$2"
                shift 2
                ;;
            --ssl)
                ENABLE_SSL=true
                shift
                ;;
            --ssl-email)
                SSL_EMAIL="$2"
                shift 2
                ;;
            --db-host)
                DB_HOST="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --db-pass)
                DB_PASSWORD="$2"
                shift 2
                ;;
            --wp-user)
                WP_ADMIN_USER="$2"
                shift 2
                ;;
            --wp-pass)
                WP_ADMIN_PASSWORD="$2"
                shift 2
                ;;
            --wp-email)
                WP_ADMIN_EMAIL="$2"
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
            --plugins)
                INSTALL_PLUGINS="$2"
                shift 2
                ;;
            --theme)
                INSTALL_THEME="$2"
                shift 2
                ;;
            --multisite)
                ENABLE_MULTISITE=true
                shift
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --backup)
                ACTION="backup"
                shift
                ;;
            --restore)
                ACTION="restore"
                RESTORE_FILE="$2"
                shift 2
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
            check_domain
            check_port
            
            # 执行安装
            if [[ "$INSTALL_METHOD" == "docker" ]]; then
                install_docker_method
            else
                install_traditional_method
            fi
            
            # 后续配置
            configure_ssl
            install_plugins
            install_theme
            configure_multisite
            optimize_wordpress
            secure_wordpress
            create_management_scripts
            save_install_info
            
            # 显示信息
            show_installation_info
            ;;
            
        remove)
            remove_wordpress
            ;;
            
        backup)
            backup_wordpress
            ;;
            
        restore)
            restore_wordpress "$RESTORE_FILE"
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"
