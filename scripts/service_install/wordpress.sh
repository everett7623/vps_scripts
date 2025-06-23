#!/bin/bash
#==============================================================================
# 脚本名称: wordpress.sh
# 脚本描述: WordPress自动安装脚本 - 一键部署WordPress网站
# 脚本路径: vps_scripts/scripts/service_install/wordpress.sh
# 作者: Jensfrank
# 使用方法: bash wordpress.sh [选项]
# 选项: --domain [域名] (必须，网站域名)
#       --path [路径] (安装路径，默认/var/www/域名)
#       --title [标题] (网站标题)
#       --admin [用户名] (管理员用户名，默认admin)
#       --email [邮箱] (管理员邮箱)
#       --ssl (启用Let's Encrypt SSL)
#       --cache (安装缓存插件)
#       --security (安装安全插件)
#       --uninstall [域名] (卸载指定网站)
# 更新日期: 2025-01-23
#==============================================================================

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
DOMAIN=""
SITE_PATH=""
SITE_TITLE="My WordPress Site"
ADMIN_USER="admin"
ADMIN_EMAIL=""
ADMIN_PASS=""
DB_NAME=""
DB_USER=""
DB_PASS=""
ENABLE_SSL=false
INSTALL_CACHE=false
INSTALL_SECURITY=false
ACTION="install"
WP_VERSION="latest"
WP_LOCALE="zh_CN"

# 检测的Web服务器
WEB_SERVER=""
PHP_VERSION=""

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${CYAN}[SUCCESS]${NC} $1"
}

# 显示标题
show_banner() {
    clear
    echo "=================================================="
    echo -e "${PURPLE}    WordPress 安装脚本${NC}"
    echo "=================================================="
    echo "    作者: Jensfrank"
    echo "    版本: 1.0"
    echo "    更新: 2025-01-23"
    echo "=================================================="
    echo ""
}

# 帮助信息
show_help() {
    show_banner
    echo "使用方法: bash wordpress.sh [选项]"
    echo ""
    echo "必需参数:"
    echo "  --domain [域名]      网站域名 (如: example.com)"
    echo ""
    echo "可选参数:"
    echo "  --path [路径]        安装路径 (默认: /var/www/域名)"
    echo "  --title [标题]       网站标题 (默认: My WordPress Site)"
    echo "  --admin [用户名]     管理员用户名 (默认: admin)"
    echo "  --email [邮箱]       管理员邮箱"
    echo "  --ssl               自动配置Let's Encrypt SSL证书"
    echo "  --cache             安装缓存插件 (WP Super Cache)"
    echo "  --security          安装安全插件 (Wordfence)"
    echo "  --uninstall [域名]   卸载指定域名的WordPress"
    echo ""
    echo "示例:"
    echo "  # 基本安装"
    echo "  bash wordpress.sh --domain example.com --email admin@example.com"
    echo ""
    echo "  # 完整安装 (含SSL和插件)"
    echo "  bash wordpress.sh --domain example.com --email admin@example.com \\"
    echo "    --title \"我的博客\" --ssl --cache --security"
    echo ""
    echo "  # 卸载网站"
    echo "  bash wordpress.sh --uninstall example.com"
    echo "=================================================="
}

# 解析命令行参数
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --path)
                SITE_PATH="$2"
                shift 2
                ;;
            --title)
                SITE_TITLE="$2"
                shift 2
                ;;
            --admin)
                ADMIN_USER="$2"
                shift 2
                ;;
            --email)
                ADMIN_EMAIL="$2"
                shift 2
                ;;
            --ssl)
                ENABLE_SSL=true
                shift
                ;;
            --cache)
                INSTALL_CACHE=true
                shift
                ;;
            --security)
                INSTALL_SECURITY=true
                shift
                ;;
            --uninstall)
                ACTION="uninstall"
                DOMAIN="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 验证必需参数
    if [[ -z "$DOMAIN" ]]; then
        log_error "缺少必需参数: --domain"
        show_help
        exit 1
    fi
    
    # 设置默认值
    if [[ -z "$SITE_PATH" ]]; then
        SITE_PATH="/var/www/$DOMAIN"
    fi
    
    if [[ -z "$ADMIN_EMAIL" && "$ACTION" == "install" ]]; then
        ADMIN_EMAIL="admin@$DOMAIN"
    fi
    
    # 生成数据库信息
    DB_NAME="wp_$(echo $DOMAIN | tr '.' '_' | tr '-' '_')"
    DB_USER="wp_$(echo $DOMAIN | tr '.' '_' | tr '-' '_' | cut -c1-16)"
    DB_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
    ADMIN_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
}

# 检查系统环境
check_system() {
    log_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        exit 1
    fi
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测系统版本"
        exit 1
    fi
    
    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    log_success "系统检查通过: $OS $VER"
}

# 检测Web服务器
detect_web_server() {
    log_info "检测Web服务器..."
    
    if systemctl is-active nginx &>/dev/null || command -v nginx &>/dev/null; then
        WEB_SERVER="nginx"
        log_success "检测到 Nginx"
    elif systemctl is-active apache2 &>/dev/null || systemctl is-active httpd &>/dev/null; then
        WEB_SERVER="apache"
        log_success "检测到 Apache"
    elif systemctl is-active lsws &>/dev/null || [[ -d /usr/local/lsws ]]; then
        WEB_SERVER="openlitespeed"
        log_success "检测到 OpenLiteSpeed"
    else
        log_warning "未检测到Web服务器，将安装Nginx"
        install_nginx
        WEB_SERVER="nginx"
    fi
}

# 安装Nginx
install_nginx() {
    log_info "安装Nginx..."
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt update -y
        apt install -y nginx
    else
        $PKG_MANAGER install -y nginx
    fi
    
    systemctl enable nginx
    systemctl start nginx
    
    log_success "Nginx安装完成"
}

# 检测PHP版本
detect_php() {
    log_info "检测PHP环境..."
    
    # 检查已安装的PHP版本
    if command -v php &>/dev/null; then
        PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d'.' -f1,2)
        local PHP_MAJOR=$(echo $PHP_VERSION | cut -d'.' -f1)
        local PHP_MINOR=$(echo $PHP_VERSION | cut -d'.' -f2)
        
        # WordPress 6.x 需要 PHP 7.4+
        if [[ $PHP_MAJOR -gt 7 ]] || [[ $PHP_MAJOR -eq 7 && $PHP_MINOR -ge 4 ]]; then
            log_success "PHP版本符合要求: $PHP_VERSION"
        else
            log_warning "PHP版本过低: $PHP_VERSION，需要升级"
            install_php
        fi
    else
        log_warning "未检测到PHP，开始安装"
        install_php
    fi
}

# 安装PHP
install_php() {
    log_info "安装PHP及相关扩展..."
    
    # 推荐的PHP版本
    PHP_VERSION="8.1"
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        # 添加PHP仓库
        apt install -y software-properties-common
        add-apt-repository -y ppa:ondrej/php
        apt update -y
        
        # 安装PHP和必需扩展
        apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm \
            php${PHP_VERSION}-mysql php${PHP_VERSION}-xml \
            php${PHP_VERSION}-curl php${PHP_VERSION}-gd \
            php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip \
            php${PHP_VERSION}-bcmath php${PHP_VERSION}-intl \
            php${PHP_VERSION}-soap php${PHP_VERSION}-imagick
    else
        # CentOS/RHEL
        $PKG_MANAGER install -y epel-release
        $PKG_MANAGER install -y https://rpms.remirepo.net/enterprise/remi-release-${VER%%.*}.rpm
        $PKG_MANAGER module enable php:remi-${PHP_VERSION} -y
        
        $PKG_MANAGER install -y php php-fpm php-mysql php-xml \
            php-curl php-gd php-mbstring php-zip php-bcmath \
            php-intl php-soap php-imagick
    fi
    
    # 启动PHP-FPM
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        systemctl enable php${PHP_VERSION}-fpm
        systemctl start php${PHP_VERSION}-fpm
    else
        systemctl enable php-fpm
        systemctl start php-fpm
    fi
    
    log_success "PHP ${PHP_VERSION} 安装完成"
}

# 检测MySQL/MariaDB
detect_mysql() {
    log_info "检测数据库服务..."
    
    if command -v mysql &>/dev/null; then
        if systemctl is-active mysql &>/dev/null || systemctl is-active mariadb &>/dev/null; then
            log_success "检测到MySQL/MariaDB"
        else
            log_warning "数据库服务未运行，尝试启动"
            systemctl start mysql 2>/dev/null || systemctl start mariadb 2>/dev/null
        fi
    else
        log_warning "未检测到数据库，开始安装MariaDB"
        install_mysql
    fi
}

# 安装MariaDB
install_mysql() {
    log_info "安装MariaDB..."
    
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        apt install -y mariadb-server mariadb-client
    else
        $PKG_MANAGER install -y mariadb-server mariadb
    fi
    
    systemctl enable mariadb
    systemctl start mariadb
    
    # 基本安全设置
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('root_temp_pass_2024') WHERE User='root';"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DROP DATABASE IF EXISTS test;"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    log_success "MariaDB安装完成"
}

# 安装WP-CLI
install_wp_cli() {
    if ! command -v wp &>/dev/null; then
        log_info "安装WP-CLI..."
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        chmod +x wp-cli.phar
        mv wp-cli.phar /usr/local/bin/wp
        log_success "WP-CLI安装完成"
    fi
}

# 创建数据库
create_database() {
    log_info "创建WordPress数据库..."
    
    # 创建数据库和用户
    mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    log_success "数据库创建成功"
}

# 下载和配置WordPress
install_wordpress() {
    log_info "下载WordPress..."
    
    # 创建网站目录
    mkdir -p $SITE_PATH
    cd $SITE_PATH
    
    # 下载WordPress
    wp core download --locale=$WP_LOCALE --allow-root
    
    # 创建wp-config.php
    wp config create \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASS \
        --dbhost=localhost \
        --allow-root
    
    # 安装WordPress
    wp core install \
        --url="http://$DOMAIN" \
        --title="$SITE_TITLE" \
        --admin_user=$ADMIN_USER \
        --admin_password=$ADMIN_PASS \
        --admin_email=$ADMIN_EMAIL \
        --skip-email \
        --allow-root
    
    # 设置中文
    wp language core install zh_CN --allow-root
    wp site switch-language zh_CN --allow-root
    
    # 更新固定链接
    wp rewrite structure '/%postname%/' --allow-root
    
    # 删除默认插件和主题
    wp plugin delete hello akismet --allow-root
    wp theme delete twentytwentytwo twentytwentythree --allow-root
    
    log_success "WordPress安装完成"
}

# 配置Web服务器
configure_web_server() {
    log_info "配置Web服务器..."
    
    case $WEB_SERVER in
        nginx)
            configure_nginx
            ;;
        apache)
            configure_apache
            ;;
        openlitespeed)
            configure_openlitespeed
            ;;
    esac
}

# 配置Nginx
configure_nginx() {
    local CONF_FILE="/etc/nginx/sites-available/$DOMAIN"
    
    cat > $CONF_FILE << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_PATH;
    index index.php index.html index.htm;

    # 日志
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    # PHP配置
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # WordPress规则
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # 安全设置
    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    # 缓存静态文件
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 365d;
        add_header Cache-Control "public, immutable";
    }

    # 上传大小限制
    client_max_body_size 64M;
}
EOF

    # 启用站点
    ln -sf $CONF_FILE /etc/nginx/sites-enabled/
    
    # 测试配置
    nginx -t
    systemctl reload nginx
    
    log_success "Nginx配置完成"
}

# 配置Apache
configure_apache() {
    local CONF_FILE="/etc/apache2/sites-available/${DOMAIN}.conf"
    
    cat > $CONF_FILE << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $SITE_PATH
    
    <Directory $SITE_PATH>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF

    # 启用站点和模块
    a2ensite ${DOMAIN}.conf
    a2enmod rewrite
    systemctl reload apache2
    
    log_success "Apache配置完成"
}

# 配置OpenLiteSpeed
configure_openlitespeed() {
    log_info "配置OpenLiteSpeed..."
    
    # OpenLiteSpeed配置比较复杂，通常通过Web管理界面
    # 这里创建基本的虚拟主机配置
    
    local VHOST_CONF="/usr/local/lsws/conf/vhosts/$DOMAIN/vhconf.conf"
    local VHOST_ROOT="/usr/local/lsws/conf/vhosts/$DOMAIN"
    
    mkdir -p $VHOST_ROOT
    
    cat > $VHOST_CONF << EOF
docRoot                   $SITE_PATH
enableGzip                1
index  {
  useServer               0
  indexFiles              index.php index.html
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
}

context / {
  type                    NULL
  location                $SITE_PATH
  allowBrowse             1
  extraHeaders            <<<END_extraHeaders
X-Forwarded-Proto \$scheme
END_extraHeaders

  rewrite  {
    RewriteFile           $SITE_PATH/.htaccess
  }
}
EOF

    # 重启OpenLiteSpeed
    /usr/local/lsws/bin/lshttpd -s reload
    
    log_success "OpenLiteSpeed配置完成"
}

# 设置权限
set_permissions() {
    log_info "设置文件权限..."
    
    # 设置所有者
    if [[ "$WEB_SERVER" == "nginx" || "$WEB_SERVER" == "openlitespeed" ]]; then
        chown -R www-data:www-data $SITE_PATH
    elif [[ "$WEB_SERVER" == "apache" ]]; then
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            chown -R www-data:www-data $SITE_PATH
        else
            chown -R apache:apache $SITE_PATH
        fi
    fi
    
    # 设置权限
    find $SITE_PATH -type d -exec chmod 755 {} \;
    find $SITE_PATH -type f -exec chmod 644 {} \;
    
    # WordPress上传目录需要写权限
    chmod -R 775 $SITE_PATH/wp-content/uploads
    
    log_success "权限设置完成"
}

# 配置SSL
configure_ssl() {
    if [[ "$ENABLE_SSL" != true ]]; then
        return
    fi
    
    log_info "配置Let's Encrypt SSL证书..."
    
    # 安装Certbot
    if ! command -v certbot &>/dev/null; then
        if [[ "$PKG_MANAGER" == "apt" ]]; then
            apt install -y certbot python3-certbot-nginx
        else
            $PKG_MANAGER install -y certbot python3-certbot-nginx
        fi
    fi
    
    # 获取SSL证书
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $ADMIN_EMAIL
    elif [[ "$WEB_SERVER" == "apache" ]]; then
        certbot --apache -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $ADMIN_EMAIL
    fi
    
    # 更新WordPress URL为HTTPS
    cd $SITE_PATH
    wp option update home "https://$DOMAIN" --allow-root
    wp option update siteurl "https://$DOMAIN" --allow-root
    
    log_success "SSL证书配置完成"
}

# 安装插件
install_plugins() {
    cd $SITE_PATH
    
    # 安装缓存插件
    if [[ "$INSTALL_CACHE" == true ]]; then
        log_info "安装缓存插件..."
        wp plugin install wp-super-cache --activate --allow-root
        
        # 启用缓存
        wp super-cache enable --allow-root
    fi
    
    # 安装安全插件
    if [[ "$INSTALL_SECURITY" == true ]]; then
        log_info "安装安全插件..."
        wp plugin install wordfence --activate --allow-root
    fi
    
    # 安装其他推荐插件
    log_info "安装推荐插件..."
    wp plugin install classic-editor --allow-root  # 经典编辑器
    wp plugin install duplicate-post --allow-root  # 复制文章
    wp plugin install wp-mail-smtp --allow-root    # SMTP邮件
    
    log_success "插件安装完成"
}

# 创建基本安全配置
configure_security() {
    log_info "配置安全设置..."
    
    cd $SITE_PATH
    
    # 禁用文件编辑
    wp config set DISALLOW_FILE_EDIT true --raw --allow-root
    
    # 限制登录尝试
    cat >> wp-config.php << 'EOF'

// 安全设置
define('WP_AUTO_UPDATE_CORE', 'minor'); // 自动更新小版本
define('FORCE_SSL_ADMIN', true); // 后台强制SSL
EOF

    # 创建.htaccess安全规则（如果是Apache）
    if [[ "$WEB_SERVER" == "apache" ]]; then
        cat > $SITE_PATH/.htaccess << 'EOF'
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

# 保护wp-config.php
<files wp-config.php>
order allow,deny
deny from all
</files>

# 禁止目录浏览
Options -Indexes

# 保护.htaccess
<files ~ "^.*\.([Hh][Tt][Aa])">
order allow,deny
deny from all
</files>
EOF
    fi
    
    log_success "安全配置完成"
}

# 显示安装信息
show_install_info() {
    clear
    echo "=================================================="
    echo -e "${GREEN}    WordPress 安装成功！${NC}"
    echo "=================================================="
    echo ""
    echo -e "${CYAN}网站信息：${NC}"
    echo "网站地址: http://$DOMAIN"
    if [[ "$ENABLE_SSL" == true ]]; then
        echo "安全地址: https://$DOMAIN"
    fi
    echo "管理后台: http://$DOMAIN/wp-admin"
    echo ""
    echo -e "${CYAN}管理员信息：${NC}"
    echo "用户名: $ADMIN_USER"
    echo "密码: $ADMIN_PASS"
    echo "邮箱: $ADMIN_EMAIL"
    echo ""
    echo -e "${CYAN}数据库信息：${NC}"
    echo "数据库名: $DB_NAME"
    echo "数据库用户: $DB_USER"
    echo "数据库密码: $DB_PASS"
    echo ""
    echo -e "${CYAN}文件路径：${NC}"
    echo "网站目录: $SITE_PATH"
    echo "配置文件: $SITE_PATH/wp-config.php"
    echo ""
    
    if [[ "$INSTALL_CACHE" == true || "$INSTALL_SECURITY" == true ]]; then
        echo -e "${CYAN}已安装插件：${NC}"
        [[ "$INSTALL_CACHE" == true ]] && echo "✓ WP Super Cache (缓存插件)"
        [[ "$INSTALL_SECURITY" == true ]] && echo "✓ Wordfence (安全插件)"
        echo ""
    fi
    
    echo -e "${YELLOW}重要提示：${NC}"
    echo "1. 请立即登录后台修改密码"
    echo "2. 建议配置SMTP邮件发送"
    echo "3. 定期备份网站和数据库"
    echo "4. 保持WordPress和插件更新"
    echo ""
    echo "=================================================="
    
    # 保存安装信息
    save_install_info
}

# 保存安装信息
save_install_info() {
    local INFO_FILE="/root/wordpress_${DOMAIN}_info.txt"
    
    cat > "$INFO_FILE" << EOF
WordPress Installation Information
===================================
Installation Date: $(date)
Domain: $DOMAIN
Site Path: $SITE_PATH
Web Server: $WEB_SERVER
PHP Version: $PHP_VERSION

Admin Access:
- URL: http://$DOMAIN/wp-admin
- Username: $ADMIN_USER
- Password: $ADMIN_PASS
- Email: $ADMIN_EMAIL

Database Info:
- Database: $DB_NAME
- User: $DB_USER
- Password: $DB_PASS

Commands:
- Enter site directory: cd $SITE_PATH
- WP-CLI: wp --allow-root [command]
===================================
EOF
    
    chmod 600 "$INFO_FILE"
    log_info "安装信息已保存到: $INFO_FILE"
}

# 卸载WordPress
uninstall_wordpress() {
    show_banner
    
    if [[ ! -d "/var/www/$DOMAIN" ]] && [[ ! -d "$SITE_PATH" ]]; then
        log_error "未找到域名 $DOMAIN 的WordPress安装"
        exit 1
    fi
    
    # 确定网站路径
    if [[ -z "$SITE_PATH" ]]; then
        SITE_PATH="/var/www/$DOMAIN"
    fi
    
    echo -e "${RED}警告：卸载操作${NC}"
    echo "=================================================="
    echo "将要删除："
    echo "- 网站目录: $SITE_PATH"
    echo "- 数据库: wp_$(echo $DOMAIN | tr '.' '_' | tr '-' '_')"
    echo "- Web服务器配置"
    echo ""
    echo -e "${RED}此操作不可恢复！${NC}"
    echo ""
    
    read -p "请输入 'YES' 确认卸载: " confirm
    
    if [[ "$confirm" != "YES" ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "开始卸载WordPress..."
    
    # 删除网站文件
    rm -rf $SITE_PATH
    
    # 删除数据库
    DB_NAME="wp_$(echo $DOMAIN | tr '.' '_' | tr '-' '_')"
    DB_USER="wp_$(echo $DOMAIN | tr '.' '_' | tr '-' '_' | cut -c1-16)"
    
    mysql -e "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null
    mysql -e "DROP USER IF EXISTS '${DB_USER}'@'localhost';" 2>/dev/null
    
    # 删除Web服务器配置
    if [[ "$WEB_SERVER" == "nginx" ]]; then
        rm -f /etc/nginx/sites-available/$DOMAIN
        rm -f /etc/nginx/sites-enabled/$DOMAIN
        systemctl reload nginx
    elif [[ "$WEB_SERVER" == "apache" ]]; then
        a2dissite ${DOMAIN}.conf
        rm -f /etc/apache2/sites-available/${DOMAIN}.conf
        systemctl reload apache2
    fi
    
    # 删除SSL证书
    if command -v certbot &>/dev/null; then
        certbot delete --cert-name $DOMAIN 2>/dev/null
    fi
    
    # 删除日志文件
    rm -f /var/log/nginx/${DOMAIN}_*.log
    rm -f /var/log/apache2/${DOMAIN}_*.log
    
    log_success "WordPress卸载完成"
}

# 主函数
main() {
    # 解析参数
    parse_arguments "$@"
    
    # 显示标题
    show_banner
    
    # 根据操作执行
    if [[ "$ACTION" == "uninstall" ]]; then
        detect_web_server
        uninstall_wordpress
    else
        # 执行安装流程
        check_system
        detect_web_server
        detect_php
        detect_mysql
        install_wp_cli
        create_database
        install_wordpress
        configure_web_server
        set_permissions
        configure_ssl
        install_plugins
        configure_security
        show_install_info
    fi
}

# 执行主函数
main "$@"