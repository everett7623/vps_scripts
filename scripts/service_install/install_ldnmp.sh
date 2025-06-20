#!/bin/bash
#==============================================================================
# 脚本名称: ldnmp.sh
# 脚本描述: LNMP(Linux+Nginx+MySQL/MariaDB+PHP)环境一键安装脚本
# 脚本路径: vps_scripts/scripts/service_install/ldnmp.sh
# 作者: Jensfrank
# 使用方法: bash ldnmp.sh [选项]
# 选项: --nginx --mysql --mariadb --php=X.X --docker --all
# 更新日期: 2025-06-20
#==============================================================================

# 设置错误处理
set -euo pipefail

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
INSTALL_DIR="/opt/ldnmp"
WEB_ROOT="/var/www"
LOG_FILE="/var/log/ldnmp-install.log"
INSTALL_NGINX=false
INSTALL_MYSQL=false
INSTALL_MARIADB=false
INSTALL_PHP=false
INSTALL_DOCKER=false
PHP_VERSION="8.2"
DB_ROOT_PASSWORD=""

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root用户运行"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    log_info "检测到系统: $OS $VER"
}

# 生成随机密码
generate_password() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c "$length"
}

# 更新系统
update_system() {
    log_info "更新系统包..."
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y curl wget software-properties-common gnupg2 lsb-release
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum makecache -q
            yum install -y curl wget yum-utils epel-release
            ;;
    esac
}

# 安装Nginx
install_nginx() {
    if command -v nginx >/dev/null 2>&1; then
        log_warning "Nginx已安装"
        return
    fi
    
    log_info "安装Nginx..."
    case $OS in
        ubuntu|debian)
            curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
            echo "deb https://nginx.org/packages/$OS/ $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
            apt-get update -qq && apt-get install -y nginx
            ;;
        centos|rhel|fedora|almalinux|rocky)
            cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=https://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
EOF
            yum install -y nginx
            ;;
    esac
    
    mkdir -p /etc/nginx/{sites-available,sites-enabled} /var/www/html
    systemctl enable nginx && systemctl start nginx
    log_success "Nginx安装完成"
}

# 安装数据库
install_database() {
    if $INSTALL_MYSQL; then
        install_mysql_server
    elif $INSTALL_MARIADB; then
        install_mariadb_server
    fi
}

# 安装MySQL
install_mysql_server() {
    if command -v mysql >/dev/null 2>&1; then
        log_warning "MySQL已安装"
        return
    fi
    
    log_info "安装MySQL..."
    DB_ROOT_PASSWORD=$(generate_password)
    
    case $OS in
        ubuntu|debian)
            wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb -O /tmp/mysql-apt.deb
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/mysql-apt.deb
            apt-get update -qq
            debconf-set-selections <<< "mysql-server mysql-server/root-password password $DB_ROOT_PASSWORD"
            debconf-set-selections <<< "mysql-server mysql-server/root-password-again password $DB_ROOT_PASSWORD"
            DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
            rm -f /tmp/mysql-apt.deb
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y https://dev.mysql.com/get/mysql80-community-release-el${VER%%.*}-9.noarch.rpm
            yum install -y mysql-community-server
            ;;
    esac
    
    echo "$DB_ROOT_PASSWORD" > /root/.mysql_root_password
    chmod 600 /root/.mysql_root_password
    systemctl enable mysqld 2>/dev/null || systemctl enable mysql
    systemctl start mysqld 2>/dev/null || systemctl start mysql
    log_success "MySQL安装完成"
}

# 安装MariaDB
install_mariadb_server() {
    if command -v mariadb >/dev/null 2>&1; then
        log_warning "MariaDB已安装"
        return
    fi
    
    log_info "安装MariaDB..."
    DB_ROOT_PASSWORD=$(generate_password)
    
    case $OS in
        ubuntu|debian)
            curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash
            apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server
            ;;
        centos|rhel|almalinux|rocky)
            cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://mirror.mariadb.org/yum/10.11/centos\$releasever-\$basearch
gpgkey = https://mirror.mariadb.org/yum/RPM-GPG-KEY-MariaDB
gpgcheck = 1
EOF
            yum install -y MariaDB-server
            ;;
    esac
    
    systemctl enable mariadb && systemctl start mariadb
    mysql -uroot <<EOF
UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
    
    echo "$DB_ROOT_PASSWORD" > /root/.mysql_root_password
    chmod 600 /root/.mysql_root_password
    log_success "MariaDB安装完成"
}

# 安装PHP
install_php() {
    log_info "安装PHP ${PHP_VERSION}..."
    
    case $OS in
        ubuntu|debian)
            if [[ "$OS" == "ubuntu" ]]; then
                add-apt-repository -y ppa:ondrej/php
            else
                wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
            fi
            apt-get update -qq
            apt-get install -y php${PHP_VERSION}-{fpm,cli,common,mysql,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
            systemctl enable php${PHP_VERSION}-fpm && systemctl start php${PHP_VERSION}-fpm
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum install -y https://rpms.remirepo.net/enterprise/remi-release-${VER%%.*}.rpm
            yum module reset php -y && yum module enable php:remi-${PHP_VERSION} -y
            yum install -y php php-{fpm,cli,common,mysqlnd,curl,gd,mbstring,xml,zip,bcmath,intl,opcache}
            systemctl enable php-fpm && systemctl start php-fpm
            ;;
    esac
    
    # 配置PHP-FPM统一sock路径
    mkdir -p /var/run/php
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        ln -sf /var/run/php/php${PHP_VERSION}-fpm.sock /var/run/php/php-fpm.sock 2>/dev/null || true
    else
        ln -sf /var/run/php-fpm/php-fpm.sock /var/run/php/php-fpm.sock 2>/dev/null || true
    fi
    
    log_success "PHP ${PHP_VERSION} 安装完成"
}

# 安装Docker
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log_warning "Docker已安装"
        return
    fi
    
    log_info "安装Docker..."
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl start docker
    
    # 安装Docker Compose
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    log_success "Docker安装完成"
}

# 创建示例站点
create_demo_site() {
    log_info "创建示例站点..."
    
    # 创建网站目录
    mkdir -p ${WEB_ROOT}/default
    
    # 创建测试页面
    cat > ${WEB_ROOT}/default/index.php <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LDNMP环境测试页面</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .info { background: #e8f4f8; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .success { color: #27ae60; }
        .error { color: #e74c3c; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="container">
        <h1>LDNMP环境测试页面</h1>
        <div class="info">
            <h2>系统信息</h2>
            <p><strong>服务器软件:</strong> <?php echo $_SERVER['SERVER_SOFTWARE']; ?></p>
            <p><strong>PHP版本:</strong> <?php echo phpversion(); ?></p>
            <p><strong>服务器时间:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
        
        <div class="info">
            <h2>数据库连接测试</h2>
            <?php
            $db_file = '/root/.mysql_root_password';
            if (file_exists($db_file) && is_readable($db_file)) {
                $password = trim(file_get_contents($db_file));
                try {
                    $conn = new PDO('mysql:host=localhost', 'root', $password);
                    echo '<p class="success">✓ 数据库连接成功</p>';
                    echo '<p>数据库版本: ' . $conn->getAttribute(PDO::ATTR_SERVER_VERSION) . '</p>';
                } catch(PDOException $e) {
                    echo '<p class="error">✗ 数据库连接失败: ' . $e->getMessage() . '</p>';
                }
            } else {
                echo '<p class="error">✗ 无法读取数据库密码文件</p>';
            }
            ?>
        </div>
        
        <div class="info">
            <h2>PHP扩展</h2>
            <table>
                <tr>
                    <th>扩展名</th>
                    <th>状态</th>
                </tr>
                <?php
                $extensions = ['pdo', 'pdo_mysql', 'mbstring', 'gd', 'curl', 'xml', 'zip', 'opcache'];
                foreach ($extensions as $ext) {
                    echo '<tr>';
                    echo '<td>' . $ext . '</td>';
                    echo '<td class="' . (extension_loaded($ext) ? 'success' : 'error') . '">';
                    echo extension_loaded($ext) ? '✓ 已安装' : '✗ 未安装';
                    echo '</td>';
                    echo '</tr>';
                }
                ?>
            </table>
        </div>
        
        <div class="info">
            <h2>phpinfo()</h2>
            <p><a href="phpinfo.php" target="_blank">查看完整PHP信息</a></p>
        </div>
    </div>
</body>
</html>
EOF

    # 创建phpinfo页面
    echo '<?php phpinfo(); ?>' > ${WEB_ROOT}/default/phpinfo.php
    
    # 创建Nginx配置
    cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root ${WEB_ROOT}/default;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    nginx -t && systemctl reload nginx
    
    chown -R www-data:www-data ${WEB_ROOT}/default 2>/dev/null || chown -R nginx:nginx ${WEB_ROOT}/default
    
    log_success "示例站点创建完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    # 创建站点管理脚本
    cat > /usr/local/bin/ldnmp <<'EOF'
#!/bin/bash
# LDNMP管理脚本

case "$1" in
    status)
        echo "服务状态:"
        systemctl status nginx --no-pager | grep Active
        systemctl status mysql --no-pager 2>/dev/null || systemctl status mariadb --no-pager 2>/dev/null | grep Active
        systemctl status php*-fpm --no-pager 2>/dev/null || systemctl status php-fpm --no-pager 2>/dev/null | grep Active
        command -v docker >/dev/null 2>&1 && systemctl status docker --no-pager | grep Active
        ;;
    restart)
        echo "重启所有服务..."
        systemctl restart nginx
        systemctl restart mysql 2>/dev/null || systemctl restart mariadb 2>/dev/null
        systemctl restart php*-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null
        command -v docker >/dev/null 2>&1 && systemctl restart docker
        echo "完成!"
        ;;
    *)
        echo "使用方法: $0 {status|restart}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/ldnmp
    log_success "管理脚本创建完成"
}

# 显示安装信息
show_installation_info() {
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}LDNMP环境安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}已安装组件:${NC}"
    $INSTALL_NGINX && echo "✓ Nginx $(nginx -v 2>&1 | cut -d' ' -f3 | cut -d'/' -f2)"
    if $INSTALL_MYSQL || $INSTALL_MARIADB; then
        if command -v mysql >/dev/null 2>&1; then
            echo "✓ MySQL $(mysql --version | awk '{print $5}' | sed 's/,$//')"
        else
            echo "✓ MariaDB $(mariadb --version | awk '{print $5}' | sed 's/,$//')"
        fi
        echo "  数据库root密码: $(cat /root/.mysql_root_password 2>/dev/null || echo '查看 /root/.mysql_root_password')"
    fi
    $INSTALL_PHP && echo "✓ PHP ${PHP_VERSION}"
    $INSTALL_DOCKER && echo "✓ Docker $(docker --version | awk '{print $3}' | sed 's/,$//')"
    echo
    echo -e "${CYAN}访问地址:${NC}"
    echo "http://${server_ip}/"
    echo
    echo -e "${CYAN}管理命令:${NC}"
    echo "ldnmp status  - 查看服务状态"
    echo "ldnmp restart - 重启所有服务"
    echo
    echo -e "${CYAN}配置文件:${NC}"
    echo "Nginx: /etc/nginx/"
    echo "PHP: /etc/php/ 或 /etc/php.ini"
    echo "MySQL: /etc/mysql/ 或 /etc/my.cnf"
    echo
    echo -e "${GREEN}========================================${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --nginx)
                INSTALL_NGINX=true
                shift
                ;;
            --mysql)
                INSTALL_MYSQL=true
                shift
                ;;
            --mariadb)
                INSTALL_MARIADB=true
                shift
                ;;
            --php=*)
                INSTALL_PHP=true
                PHP_VERSION="${1#*=}"
                shift
                ;;
            --php)
                INSTALL_PHP=true
                shift
                ;;
            --docker)
                INSTALL_DOCKER=true
                shift
                ;;
            --all)
                INSTALL_NGINX=true
                INSTALL_MARIADB=true
                INSTALL_PHP=true
                INSTALL_DOCKER=true
                shift
                ;;
            -h|--help)
                echo "使用方法: $0 [选项]"
                echo "选项:"
                echo "  --nginx      安装Nginx"
                echo "  --mysql      安装MySQL"
                echo "  --mariadb    安装MariaDB"
                echo "  --php[=X.X]  安装PHP (默认8.2)"
                echo "  --docker     安装Docker"
                echo "  --all        安装所有组件(Nginx+MariaDB+PHP+Docker)"
                echo "  -h, --help   显示帮助信息"
                echo
                echo "示例:"
                echo "  $0 --all                    # 安装所有组件"
                echo "  $0 --nginx --mariadb --php  # 安装LNMP"
                echo "  $0 --php=8.1               # 安装PHP 8.1"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定任何选项，显示交互式菜单
    if ! $INSTALL_NGINX && ! $INSTALL_MYSQL && ! $INSTALL_MARIADB && ! $INSTALL_PHP && ! $INSTALL_DOCKER; then
        echo -e "${PURPLE}======================================${NC}"
        echo -e "${PURPLE}LDNMP环境一键安装脚本${NC}"
        echo -e "${PURPLE}作者: Jensfrank${NC}"
        echo -e "${PURPLE}版本: 2025-06-20${NC}"
        echo -e "${PURPLE}======================================${NC}"
        echo
        echo "请选择要安装的组件:"
        echo "1) 完整安装 (Nginx + MariaDB + PHP + Docker)"
        echo "2) LNMP (Nginx + MariaDB + PHP)"
        echo "3) 自定义安装"
        echo "0) 退出"
        echo
        read -p "请输入选项 [0-3]: " choice
        
        case $choice in
            1)
                INSTALL_NGINX=true
                INSTALL_MARIADB=true
                INSTALL_PHP=true
                INSTALL_DOCKER=true
                ;;
            2)
                INSTALL_NGINX=true
                INSTALL_MARIADB=true
                INSTALL_PHP=true
                ;;
            3)
                read -p "安装Nginx? (y/n): " -n 1 -r
                [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_NGINX=true
                echo
                
                read -p "安装MySQL? (y/n): " -n 1 -r
                [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_MYSQL=true
                echo
                
                if ! $INSTALL_MYSQL; then
                    read -p "安装MariaDB? (y/n): " -n 1 -r
                    [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_MARIADB=true
                    echo
                fi
                
                read -p "安装PHP? (y/n): " -n 1 -r
                [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_PHP=true
                echo
                
                if $INSTALL_PHP; then
                    read -p "PHP版本 [7.4/8.0/8.1/8.2/8.3] (默认8.2): " php_ver
                    PHP_VERSION=${php_ver:-8.2}
                fi
                
                read -p "安装Docker? (y/n): " -n 1 -r
                [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_DOCKER=true
                echo
                ;;
            0)
                echo "退出安装"
                exit 0
                ;;
            *)
                log_error "无效选项"
                exit 1
                ;;
        esac
    fi
    
    # 创建日志文件
    mkdir -p $(dirname "$LOG_FILE")
    touch "$LOG_FILE"
    
    # 执行安装
    log_info "开始安装LDNMP环境..."
    echo "安装日志: $LOG_FILE"
    echo
    
    check_root
    check_system
    update_system
    
    # 安装各组件
    $INSTALL_NGINX && install_nginx
    ($INSTALL_MYSQL || $INSTALL_MARIADB) && install_database
    $INSTALL_PHP && install_php
    $INSTALL_DOCKER && install_docker
    
    # 创建示例站点和管理脚本
    if $INSTALL_NGINX && $INSTALL_PHP; then
        create_demo_site
    fi
    
    create_management_scripts
    show_installation_info
}

# 错误处理
trap 'log_error "脚本执行出错，行号: $LINENO"' ERR

# 执行主函数
main "$@"