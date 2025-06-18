#!/bin/bash
################################################################################
# 脚本名称: install_lnmp.sh
# 脚本用途: 自动安装和配置LNMP(Linux+Nginx+MySQL+PHP)环境
# 脚本路径: vps_scripts/scripts/service_install/install_lnmp.sh
# 作者: Jensfrank
# 更新日期: $(date +%Y-%m-%d)
################################################################################

# 定义脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
GRAND_PARENT_DIR="$(dirname "$PARENT_DIR")"

# 加载通用函数库
source "$PARENT_DIR/system_tools/install_deps.sh" 2>/dev/null || {
    echo "错误: 无法加载依赖函数库"
    exit 1
}

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# 全局变量
NGINX_VERSION="stable"
MYSQL_VERSION="8.0"
PHP_VERSION="8.2"
INSTALL_MODE=""
WEB_ROOT="/var/www"
MYSQL_ROOT_PASSWORD=""
CHINA_MIRROR=false

# 函数: 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help                  显示此帮助信息"
    echo "  -n, --nginx VERSION         指定Nginx版本(默认:stable)"
    echo "  -m, --mysql VERSION         指定MySQL版本(默认:8.0)"
    echo "  -p, --php VERSION           指定PHP版本(默认:8.2)"
    echo "  -r, --root DIR              指定Web根目录(默认:/var/www)"
    echo "  -P, --password PASSWORD     设置MySQL root密码"
    echo "  -c, --china-mirror          使用中国镜像源"
    echo "  -u, --uninstall             卸载LNMP环境"
    echo ""
    echo "支持的版本:"
    echo "  Nginx: stable, mainline, 1.24, 1.25"
    echo "  MySQL: 5.7, 8.0"
    echo "  PHP: 7.4, 8.0, 8.1, 8.2, 8.3"
    echo ""
    echo "示例:"
    echo "  $0                          # 安装默认版本LNMP"
    echo "  $0 -p 8.1 -m 5.7           # 安装PHP 8.1和MySQL 5.7"
    echo "  $0 -c -P mypassword        # 使用中国镜像并设置MySQL密码"
}

# 函数: 检查系统要求
check_requirements() {
    echo -e "${BLUE}>>> 检查系统要求...${NC}"
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}错误: 无法确定操作系统类型${NC}"
        exit 1
    fi
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]] && [[ "$ARCH" != "aarch64" ]]; then
        echo -e "${YELLOW}警告: 某些软件包可能不支持 $ARCH 架构${NC}"
    fi
    
    # 检查可用内存
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [[ $TOTAL_MEM -lt 512 ]]; then
        echo -e "${YELLOW}警告: 系统内存少于512MB，可能影响性能${NC}"
        echo -e "${YELLOW}当前内存: ${TOTAL_MEM}MB${NC}"
    fi
    
    # 检查磁盘空间
    DISK_FREE=$(df -m / | awk 'NR==2{print $4}')
    if [[ $DISK_FREE -lt 2048 ]]; then
        echo -e "${YELLOW}警告: 磁盘剩余空间少于2GB${NC}"
        echo -e "${YELLOW}剩余空间: ${DISK_FREE}MB${NC}"
    fi
    
    # 检查是否已安装相关服务
    local services=("nginx" "mysql" "php-fpm")
    local installed=()
    for service in "${services[@]}"; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            installed+=($service)
        fi
    done
    
    if [[ ${#installed[@]} -gt 0 ]]; then
        echo -e "${YELLOW}警告: 检测到已安装的服务: ${installed[*]}${NC}"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo -e "${GREEN}✓ 系统要求检查通过${NC}"
    echo -e "  操作系统: $OS $VERSION"
    echo -e "  系统架构: $ARCH"
    echo -e "  总内存: ${TOTAL_MEM}MB"
    echo -e "  可用磁盘: ${DISK_FREE}MB"
}

# 函数: 配置中国镜像源
setup_china_mirrors() {
    echo -e "${BLUE}>>> 配置中国镜像源...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 备份原始源
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            
            # 使用阿里云镜像
            if [[ "$OS" == "ubuntu" ]]; then
                cat > /etc/apt/sources.list <<EOF
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
EOF
            elif [[ "$OS" == "debian" ]]; then
                cat > /etc/apt/sources.list <<EOF
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs) main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-updates main non-free contrib
deb https://mirrors.aliyun.com/debian/ $(lsb_release -cs)-backports main non-free contrib
deb https://mirrors.aliyun.com/debian-security $(lsb_release -cs)/updates main non-free contrib
EOF
            fi
            apt-get update
            ;;
        centos|rhel|fedora)
            # 备份原始源
            cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null
            
            # 使用阿里云镜像
            curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-vault-8.5.2111.repo
            yum clean all
            yum makecache
            ;;
    esac
    
    echo -e "${GREEN}✓ 中国镜像源配置完成${NC}"
}

# 函数: 安装Nginx
install_nginx() {
    echo -e "${BLUE}>>> 安装Nginx...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 添加Nginx官方仓库
            curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
            
            if [[ "$NGINX_VERSION" == "stable" ]]; then
                echo "deb https://nginx.org/packages/$OS $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
            else
                echo "deb https://nginx.org/packages/mainline/$OS $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
            fi
            
            apt-get update
            apt-get install -y nginx
            ;;
        centos|rhel|fedora)
            # 添加Nginx官方仓库
            cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            
            if [[ "$NGINX_VERSION" == "mainline" ]]; then
                yum-config-manager --enable nginx-mainline
            fi
            
            yum install -y nginx
            ;;
    esac
    
    # 启动Nginx
    systemctl enable nginx
    systemctl start nginx
    
    # 创建Web目录
    mkdir -p $WEB_ROOT/html
    chown -R nginx:nginx $WEB_ROOT
    
    # 配置默认站点
    configure_nginx_default
    
    echo -e "${GREEN}✓ Nginx安装完成${NC}"
}

# 函数: 配置Nginx默认站点
configure_nginx_default() {
    cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen       80 default_server;
    listen       [::]:80 default_server;
    server_name  _;
    root         $WEB_ROOT/html;
    index        index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    error_page 404 /404.html;
    location = /404.html {
    }

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }
}
EOF
    
    # 测试配置
    nginx -t
    systemctl reload nginx
}

# 函数: 安装MySQL
install_mysql() {
    echo -e "${BLUE}>>> 安装MySQL ${MYSQL_VERSION}...${NC}"
    
    # 生成随机密码（如果未指定）
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
        echo -e "${YELLOW}生成MySQL root密码: $MYSQL_ROOT_PASSWORD${NC}"
    fi
    
    case $OS in
        ubuntu|debian)
            # 添加MySQL APT仓库
            wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb
            DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.29-1_all.deb
            apt-get update
            
            # 预设置root密码
            debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
            debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
            
            # 安装MySQL
            DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
            rm -f mysql-apt-config_0.8.29-1_all.deb
            ;;
        centos|rhel|fedora)
            # 添加MySQL YUM仓库
            if [[ "$MYSQL_VERSION" == "8.0" ]]; then
                yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-7.noarch.rpm
            else
                yum install -y https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
            fi
            
            # 安装MySQL
            yum install -y mysql-server
            
            # 启动MySQL
            systemctl enable mysqld
            systemctl start mysqld
            
            # 获取临时密码
            TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
            
            # 修改root密码
            mysql --connect-expired-password -uroot -p"$TEMP_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF
            ;;
    esac
    
    # 安全配置
    configure_mysql_security
    
    # 启动MySQL
    systemctl enable mysql 2>/dev/null || systemctl enable mysqld 2>/dev/null
    systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null
    
    echo -e "${GREEN}✓ MySQL安装完成${NC}"
}

# 函数: MySQL安全配置
configure_mysql_security() {
    echo -e "${CYAN}配置MySQL安全设置...${NC}"
    
    mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOF
-- 删除匿名用户
DELETE FROM mysql.user WHERE User='';
-- 禁止root远程登录
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- 删除测试数据库
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- 刷新权限
FLUSH PRIVILEGES;
EOF
    
    # 创建MySQL配置文件
    cat > /etc/mysql/conf.d/custom.cnf <<EOF
[mysqld]
# 字符集
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# 性能优化
innodb_buffer_pool_size=256M
innodb_log_file_size=64M
max_connections=500
key_buffer_size=16M

# 慢查询日志
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

[client]
default-character-set=utf8mb4
EOF
    
    # 重启MySQL
    systemctl restart mysql 2>/dev/null || systemctl restart mysqld 2>/dev/null
}

# 函数: 安装PHP
install_php() {
    echo -e "${BLUE}>>> 安装PHP ${PHP_VERSION}...${NC}"
    
    case $OS in
        ubuntu|debian)
            # 添加PHP PPA仓库
            apt-get install -y software-properties-common
            add-apt-repository -y ppa:ondrej/php
            apt-get update
            
            # 安装PHP和常用扩展
            apt-get install -y \
                php${PHP_VERSION}-fpm \
                php${PHP_VERSION}-cli \
                php${PHP_VERSION}-common \
                php${PHP_VERSION}-mysql \
                php${PHP_VERSION}-xml \
                php${PHP_VERSION}-xmlrpc \
                php${PHP_VERSION}-curl \
                php${PHP_VERSION}-gd \
                php${PHP_VERSION}-imagick \
                php${PHP_VERSION}-mbstring \
                php${PHP_VERSION}-zip \
                php${PHP_VERSION}-bcmath \
                php${PHP_VERSION}-intl \
                php${PHP_VERSION}-soap \
                php${PHP_VERSION}-opcache \
                php${PHP_VERSION}-redis
            ;;
        centos|rhel|fedora)
            # 添加Remi仓库
            yum install -y epel-release
            yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm
            
            # 启用PHP仓库
            yum-config-manager --enable remi-php${PHP_VERSION//./}
            
            # 安装PHP和常用扩展
            yum install -y \
                php-fpm \
                php-cli \
                php-common \
                php-mysql \
                php-xml \
                php-xmlrpc \
                php-curl \
                php-gd \
                php-imagick \
                php-mbstring \
                php-zip \
                php-bcmath \
                php-intl \
                php-soap \
                php-opcache \
                php-redis
            ;;
    esac
    
    # 配置PHP-FPM
    configure_php_fpm
    
    # 启动PHP-FPM
    systemctl enable php${PHP_VERSION}-fpm 2>/dev/null || systemctl enable php-fpm 2>/dev/null
    systemctl start php${PHP_VERSION}-fpm 2>/dev/null || systemctl start php-fpm 2>/dev/null
    
    echo -e "${GREEN}✓ PHP安装完成${NC}"
}

# 函数: 配置PHP-FPM
configure_php_fpm() {
    echo -e "${CYAN}配置PHP-FPM...${NC}"
    
    # 确定PHP-FPM配置文件路径
    if [[ -d "/etc/php/${PHP_VERSION}/fpm" ]]; then
        PHP_FPM_CONF="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
        PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
    else
        PHP_FPM_CONF="/etc/php-fpm.d/www.conf"
        PHP_INI="/etc/php.ini"
    fi
    
    # 修改PHP-FPM配置
    sed -i 's/^user = .*/user = nginx/' $PHP_FPM_CONF
    sed -i 's/^group = .*/group = nginx/' $PHP_FPM_CONF
    sed -i 's/^listen.owner = .*/listen.owner = nginx/' $PHP_FPM_CONF
    sed -i 's/^listen.group = .*/listen.group = nginx/' $PHP_FPM_CONF
    
    # 优化PHP配置
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' $PHP_INI
    sed -i 's/^max_input_time = .*/max_input_time = 300/' $PHP_INI
    sed -i 's/^memory_limit = .*/memory_limit = 256M/' $PHP_INI
    sed -i 's/^post_max_size = .*/post_max_size = 50M/' $PHP_INI
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 50M/' $PHP_INI
    
    # 启用OPcache
    cat >> $PHP_INI <<EOF

; OPcache设置
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF
}

# 函数: 创建测试页面
create_test_pages() {
    echo -e "${BLUE}>>> 创建测试页面...${NC}"
    
    # 创建PHP信息页面
    cat > $WEB_ROOT/html/info.php <<'EOF'
<?php
phpinfo();
?>
EOF
    
    # 创建数据库连接测试页面
    cat > $WEB_ROOT/html/test-db.php <<EOF
<?php
\$servername = "localhost";
\$username = "root";
\$password = "$MYSQL_ROOT_PASSWORD";

try {
    \$conn = new PDO("mysql:host=\$servername", \$username, \$password);
    \$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "MySQL连接成功！<br>";
    
    // 显示MySQL版本
    \$stmt = \$conn->query("SELECT VERSION()");
    \$version = \$stmt->fetchColumn();
    echo "MySQL版本: " . \$version . "<br>";
    
    // 显示数据库列表
    echo "<h3>数据库列表:</h3>";
    \$stmt = \$conn->query("SHOW DATABASES");
    while (\$row = \$stmt->fetch()) {
        echo \$row[0] . "<br>";
    }
} catch(PDOException \$e) {
    echo "连接失败: " . \$e->getMessage();
}
?>
EOF
    
    # 创建默认首页
    cat > $WEB_ROOT/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>LNMP环境测试页面</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .info { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .success { color: green; }
        .link { margin: 10px 0; }
    </style>
</head>
<body>
    <h1>恭喜！LNMP环境安装成功</h1>
    <div class="info">
        <h2 class="success">✓ 环境信息</h2>
        <ul>
            <li>Nginx: $(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')</li>
            <li>MySQL: ${MYSQL_VERSION}</li>
            <li>PHP: ${PHP_VERSION}</li>
        </ul>
        
        <h2>测试链接</h2>
        <div class="link"><a href="/info.php">查看PHP信息</a></div>
        <div class="link"><a href="/test-db.php">测试数据库连接</a></div>
        
        <h2>配置信息</h2>
        <ul>
            <li>Web根目录: $WEB_ROOT/html</li>
            <li>Nginx配置: /etc/nginx/nginx.conf</li>
            <li>MySQL root密码: 请查看安装日志</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    # 设置权限
    chown -R nginx:nginx $WEB_ROOT/html
    
    echo -e "${GREEN}✓ 测试页面创建完成${NC}"
}

# 函数: 配置防火墙
configure_firewall() {
    echo -e "${BLUE}>>> 配置防火墙...${NC}"
    
    # 检查并配置防火墙
    if command -v ufw &> /dev/null; then
        # UFW (Ubuntu/Debian)
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 3306/tcp
        echo -e "${GREEN}✓ UFW防火墙规则已添加${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        # FirewallD (CentOS/RHEL)
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --permanent --add-port=3306/tcp
        firewall-cmd --reload
        echo -e "${GREEN}✓ FirewallD防火墙规则已添加${NC}"
    else
        echo -e "${YELLOW}未检测到防火墙服务${NC}"
    fi
}

# 函数: 卸载LNMP
uninstall_lnmp() {
    echo -e "${BLUE}>>> 卸载LNMP环境...${NC}"
    
    read -p "确定要卸载LNMP环境吗？这将删除所有相关数据。(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # 停止服务
    echo -e "${YELLOW}停止服务...${NC}"
    systemctl stop nginx 2>/dev/null
    systemctl stop mysql 2>/dev/null || systemctl stop mysqld 2>/dev/null
    systemctl stop php${PHP_VERSION}-fpm 2>/dev/null || systemctl stop php-fpm 2>/dev/null
    
    # 卸载软件包
    case $OS in
        ubuntu|debian)
            apt-get purge -y nginx* mysql* php*
            apt-get autoremove -y
            ;;
        centos|rhel|fedora)
            yum remove -y nginx* mysql* php*
            ;;
    esac
    
    # 删除配置和数据
    echo -e "${YELLOW}删除配置和数据...${NC}"
    rm -rf /etc/nginx
    rm -rf /etc/mysql
    rm -rf /var/lib/mysql
    rm -rf /etc/php*
    rm -rf $WEB_ROOT
    
    echo -e "${GREEN}✓ LNMP环境卸载完成${NC}"
}

# 函数: 显示安装总结
show_summary() {
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}LNMP环境安装完成！${NC}"
    echo -e "${GREEN}===================================================${NC}"
    
    # 获取服务器IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
    
    echo -e "\n${CYAN}安装信息:${NC}"
    echo -e "  Nginx版本: $(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    echo -e "  MySQL版本: ${MYSQL_VERSION}"
    echo -e "  PHP版本: ${PHP_VERSION}"
    echo -e "  Web根目录: $WEB_ROOT/html"
    
    echo -e "\n${CYAN}访问地址:${NC}"
    echo -e "  首页: http://$SERVER_IP/"
    echo -e "  PHP信息: http://$SERVER_IP/info.php"
    echo -e "  数据库测试: http://$SERVER_IP/test-db.php"
    
    echo -e "\n${CYAN}MySQL信息:${NC}"
    echo -e "  用户名: root"
    echo -e "  密码: $MYSQL_ROOT_PASSWORD"
    echo -e "  ${YELLOW}请妥善保管MySQL root密码！${NC}"
    
    echo -e "\n${CYAN}配置文件:${NC}"
    echo -e "  Nginx: /etc/nginx/nginx.conf"
    echo -e "  MySQL: /etc/mysql/my.cnf 或 /etc/my.cnf"
    echo -e "  PHP: $PHP_INI"
    
    echo -e "\n${CYAN}服务管理命令:${NC}"
    echo -e "  systemctl [start|stop|restart|status] nginx"
    echo -e "  systemctl [start|stop|restart|status] mysql"
    echo -e "  systemctl [start|stop|restart|status] php${PHP_VERSION}-fpm"
    
    echo -e "\n${CYAN}日志文件:${NC}"
    echo -e "  Nginx访问日志: /var/log/nginx/access.log"
    echo -e "  Nginx错误日志: /var/log/nginx/error.log"
    echo -e "  MySQL错误日志: /var/log/mysql/error.log"
    echo -e "  PHP错误日志: /var/log/php${PHP_VERSION}-fpm.log"
    
    echo -e "\n${CYAN}安全建议:${NC}"
    echo -e "  1. 修改MySQL root密码并创建独立数据库用户"
    echo -e "  2. 删除测试文件 info.php 和 test-db.php"
    echo -e "  3. 配置SSL证书启用HTTPS"
    echo -e "  4. 定期更新系统和软件包"
    echo -e "${GREEN}===================================================${NC}"
    
    # 保存安装信息
    save_installation_info
}

# 函数: 保存安装信息
save_installation_info() {
    local info_file="/root/lnmp_installation_info.txt"
    
    cat > $info_file <<EOF
LNMP安装信息
==================================================
安装时间: $(date)
操作系统: $OS $VERSION
系统架构: $(uname -m)

软件版本:
- Nginx: $(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
- MySQL: ${MYSQL_VERSION}
- PHP: ${PHP_VERSION}

配置信息:
- Web根目录: $WEB_ROOT/html
- MySQL root密码: $MYSQL_ROOT_PASSWORD

访问地址:
- 首页: http://$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")/
- PHP信息: http://$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_IP")/info.php

服务管理:
- systemctl [start|stop|restart|status] nginx
- systemctl [start|stop|restart|status] mysql
- systemctl [start|stop|restart|status] php${PHP_VERSION}-fpm
==================================================
EOF
    
    echo -e "\n${YELLOW}安装信息已保存到: $info_file${NC}"
}

# 主函数
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--nginx)
                NGINX_VERSION="$2"
                shift 2
                ;;
            -m|--mysql)
                MYSQL_VERSION="$2"
                shift 2
                ;;
            -p|--php)
                PHP_VERSION="$2"
                shift 2
                ;;
            -r|--root)
                WEB_ROOT="$2"
                shift 2
                ;;
            -P|--password)
                MYSQL_ROOT_PASSWORD="$2"
                shift 2
                ;;
            -c|--china-mirror)
                CHINA_MIRROR=true
                shift
                ;;
            -u|--uninstall)
                INSTALL_MODE="uninstall"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示脚本信息
    echo -e "${PURPLE}===================================================${NC}"
    echo -e "${PURPLE}VPS LNMP环境安装脚本${NC}"
    echo -e "${PURPLE}作者: Jensfrank${NC}"
    echo -e "${PURPLE}===================================================${NC}\n"
    
    # 执行相应操作
    if [[ "$INSTALL_MODE" == "uninstall" ]]; then
        uninstall_lnmp
    else
        # 检查系统要求
        check_requirements
        
        # 配置中国镜像（如果需要）
        if [[ "$CHINA_MIRROR" == true ]]; then
            setup_china_mirrors
        fi
        
        # 安装组件
        install_nginx
        install_mysql
        install_php
        
        # 创建测试页面
        create_test_pages
        
        # 配置防火墙
        configure_firewall
        
        # 显示安装总结
        show_summary
    fi
}

# 执行主函数
main "$@"
