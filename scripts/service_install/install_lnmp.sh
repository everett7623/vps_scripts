#!/bin/bash
#/vps_scripts/scripts/service_install/install_lnmp.sh - VPS Scripts LNMP栈安装工具

# 动态定位项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/system.sh"

# 模块信息
MODULE_NAME="LNMP栈安装"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="一键安装 Nginx + PHP + MySQL/MariaDB 环境"

# 定义安装选项
declare -A PHP_VERSIONS=(
    ["8.2"]="PHP 8.2"
    ["8.1"]="PHP 8.1"
    ["8.0"]="PHP 8.0"
    ["7.4"]="PHP 7.4"
)

declare -A DB_CHOICES=(
    ["mariadb"]="MariaDB (推荐)"
    ["mysql"]="MySQL"
)

# 检查root权限
check_root_permission() {
    if [ "$(id -u)" != "0" ]; then
        error "此脚本需要root权限运行"
        exit 1
    fi
}

# 显示欢迎界面
show_welcome() {
    clear
    draw_menu_border "LNMP 环境安装工具"
    echo ""
    info "LNMP 是 Nginx + PHP + MySQL/MariaDB 的经典组合"
    echo ""
}

# 检测操作系统
detect_operating_system() {
    local os_info=$(detect_os_distro)
    OS_DISTRO=${os_info%%:*}
    OS_VERSION=${os_info#*:}
    info "检测到操作系统: $OS_DISTRO $OS_VERSION"
}

# 系统更新函数
update_system() {
    if confirm "是否先更新系统软件包?"; then
        info "正在更新系统..."
        if execute "apt update && apt upgrade -y" "Debian/Ubuntu 系统更新"; then
            success "系统更新完成"
        elif execute "yum update -y" "CentOS/RHEL 系统更新"; then
            success "系统更新完成"
        elif execute "dnf update -y" "Fedora 系统更新"; then
            success "系统更新完成"
        elif execute "pacman -Syu --noconfirm" "Arch Linux 系统更新"; then
            success "系统更新完成"
        else
            warning "不支持的操作系统，跳过系统更新"
        fi
    fi
}

# 选择PHP版本
select_php_version() {
    clear
    draw_menu_border "选择PHP版本"
    echo ""
    
    local choices=()
    local i=1
    for version in "${!PHP_VERSIONS[@]}"; do
        choices+=("$i|${PHP_VERSIONS[$version]}")
        ((i++))
    done
    
    local selected_version=$(show_choice_menu "请选择PHP版本" "${choices[@]}" "1")
    if [ -n "$selected_version" ]; then
        PHP_VERSION=${!PHP_VERSIONS[*]:selected_version-1:1}
        info "已选择: ${PHP_VERSIONS[$PHP_VERSION]}"
        return 0
    fi
    error "未选择PHP版本，安装取消"
    exit 1
}

# 选择数据库
select_database() {
    clear
    draw_menu_border "选择数据库"
    echo ""
    
    local choices=()
    local i=1
    for db in "${!DB_CHOICES[@]}"; do
        choices+=("$i|${DB_CHOICES[$db]}")
        ((i++))
    done
    
    local selected_db=$(show_choice_menu "请选择数据库" "${choices[@]}" "1")
    if [ -n "$selected_db" ]; then
        DB_CHOICE=${!DB_CHOICES[*]:selected_db-1:1}
        info "已选择: ${DB_CHOICES[$DB_CHOICE]}"
        return 0
    fi
    error "未选择数据库，安装取消"
    exit 1
}

# 安装Nginx
install_nginx() {
    info "开始安装Nginx..."
    local install_cmd=""
    
    if command_exists nginx; then
        warning "Nginx已安装，跳过安装"
        return 0
    fi
    
    case $OS_DISTRO in
        "ubuntu"|"debian")
            install_cmd="apt install -y nginx"
            ;;
        "centos"|"rhel"|"rocky"|"almalinux")
            install_cmd="yum install -y nginx"
            ;;
        "fedora")
            install_cmd="dnf install -y nginx"
            ;;
        "arch"|"manjaro")
            install_cmd="pacman -S --noconfirm nginx"
            ;;
        *)
            error "不支持的操作系统: $OS_DISTRO"
            return 1
            ;;
    esac
    
    if execute "$install_cmd" "安装Nginx"; then
        if execute "systemctl enable nginx && systemctl start nginx" "启动Nginx服务"; then
            success "Nginx安装完成"
            nginx -v
            return 0
        fi
    fi
    error "Nginx安装失败"
    return 1
}

# 安装PHP
install_php() {
    info "开始安装PHP $PHP_VERSION..."
    local install_cmd=""
    local php_fpm_service=""
    
    if command_exists php; then
        warning "PHP已安装，跳过安装"
        return 0
    fi
    
    case $OS_DISTRO in
        "ubuntu"|"debian")
            # 添加PHP PPA
            if execute "apt install -y software-properties-common" "安装软件属性工具"; then
                if execute "add-apt-repository -y ppa:ondrej/php" "添加PHP PPA"; then
                    if execute "apt update" "更新软件源"; then
                        install_cmd="apt install -y php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-intl php${PHP_VERSION}-mbstring php${PHP_VERSION}-xml php${PHP_VERSION}-zip"
                        php_fpm_service="php${PHP_VERSION}-fpm"
                    fi
                fi
            fi
            ;;
        "centos"|"rhel"|"rocky"|"almalinux")
            # 添加Remi仓库
            if execute "yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm" "添加Remi仓库"; then
                if execute "dnf module enable php:remi-${PHP_VERSION} -y" "启用PHP模块"; then
                    install_cmd="yum install -y php php-fpm php-mysqlnd php-curl php-gd php-intl php-mbstring php-xml php-zip"
                    php_fpm_service="php-fpm"
                fi
            fi
            ;;
        "fedora")
            install_cmd="dnf install -y php php-fpm php-mysqlnd php-curl php-gd php-intl php-mbstring php-xml php-zip"
            php_fpm_service="php-fpm"
            ;;
        "arch"|"manjaro")
            install_cmd="pacman -S --noconfirm php php-fpm php-mysql"
            php_fpm_service="php-fpm"
            ;;
        *)
            error "不支持的操作系统: $OS_DISTRO"
            return 1
            ;;
    esac
    
    if [ -n "$install_cmd" ]; then
        if execute "$install_cmd" "安装PHP"; then
            if execute "systemctl enable $php_fpm_service && systemctl start $php_fpm_service" "启动PHP-FPM服务"; then
                success "PHP安装完成"
                php -v
                return 0
            fi
        fi
    fi
    error "PHP安装失败"
    return 1
}

# 安装数据库
install_database() {
    info "开始安装${DB_CHOICES[$DB_CHOICE]}..."
    local install_cmd=""
    local db_service=""
    
    if command_exists mysql; then
        warning "数据库已安装，跳过安装"
        return 0
    fi
    
    case $OS_DISTRO in
        "ubuntu"|"debian")
            if [ "$DB_CHOICE" = "mariadb" ]; then
                install_cmd="apt install -y mariadb-server mariadb-client"
                db_service="mariadb"
            else
                install_cmd="apt install -y mysql-server mysql-client"
                db_service="mysql"
            fi
            ;;
        "centos"|"rhel"|"rocky"|"almalinux")
            if [ "$DB_CHOICE" = "mariadb" ]; then
                install_cmd="yum install -y mariadb-server mariadb-client"
                db_service="mariadb"
            else
                install_cmd="yum install -y mysql-server mysql-client"
                db_service="mysql"
            fi
            ;;
        "fedora")
            if [ "$DB_CHOICE" = "mariadb" ]; then
                install_cmd="dnf install -y mariadb-server mariadb-client"
                db_service="mariadb"
            else
                install_cmd="dnf install -y mysql-server mysql-client"
                db_service="mysql"
            fi
            ;;
        "arch"|"manjaro")
            if [ "$DB_CHOICE" = "mariadb" ]; then
                install_cmd="pacman -S --noconfirm mariadb"
                db_service="mariadb"
            else
                install_cmd="pacman -S --noconfirm mysql"
                db_service="mysql"
            fi
            ;;
        *)
            error "不支持的操作系统: $OS_DISTRO"
            return 1
            ;;
    esac
    
    if execute "$install_cmd" "安装数据库"; then
        if execute "systemctl enable $db_service && systemctl start $db_service" "启动数据库服务"; then
            success "数据库安装完成"
            mysql --version
            
            # 安全配置数据库
            if confirm "是否执行数据库安全配置?"; then
                if [ "$OS_DISTRO" = "arch" ] || [ "$OS_DISTRO" = "manjaro" ]; then
                    if [ "$DB_CHOICE" = "mariadb" ]; then
                        info "在Arch Linux上，MariaDB安全配置需要手动执行:"
                        info "1. mysql_secure_installation"
                        info "2. 按照提示设置root密码和安全选项"
                    else
                        info "在Arch Linux上，MySQL安全配置需要手动执行:"
                        info "1. mysql_secure_installation"
                        info "2. 按照提示设置root密码和安全选项"
                    fi
                else
                    mysql_secure_installation
                fi
            fi
            return 0
        fi
    fi
    error "数据库安装失败"
    return 1
}

# 配置LNMP
configure_lnmp() {
    info "配置Nginx与PHP-FPM..."
    
    # 创建网站目录
    if execute "mkdir -p /var/www/html && chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html" "创建网站目录"; then
        # 备份原始配置
        local nginx_default="/etc/nginx/sites-available/default"
        if [ -f "$nginx_default" ]; then
            cp "$nginx_default" "$nginx_default.backup"
            info "已备份Nginx默认配置"
        fi
        
        # 创建Nginx配置
        local php_fpm_sock=""
        if [ "$OS_DISTRO" = "arch" ] || [ "$OS_DISTRO" = "manjaro" ]; then
            php_fpm_sock="unix:/run/php-fpm/php-fpm.sock"
        else
            php_fpm_sock="unix:/run/php/php${PHP_VERSION}-fpm.sock"
        fi
        
        cat > "$nginx_default" << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass $php_fpm_sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
        
        # 测试Nginx配置
        if execute "nginx -t" "测试Nginx配置"; then
            # 重启Nginx
            if execute "systemctl restart nginx" "重启Nginx服务"; then
                # 创建PHP测试文件
                cat > /var/www/html/info.php << EOF
<?php
phpinfo();
?>
EOF
                chown www-data:www-data /var/www/html/info.php
                
                success "LNMP配置完成"
                info "PHP测试文件已创建: /var/www/html/info.php"
                info "请访问 http://服务器IP/info.php 验证安装"
                return 0
            fi
        else
            warning "Nginx配置测试失败，恢复原始配置"
            if [ -f "$nginx_default.backup" ]; then
                cp "$nginx_default.backup" "$nginx_default"
                execute "systemctl restart nginx" "重启Nginx服务"
            fi
        fi
    fi
    error "LNMP配置失败"
    return 1
}

# 主函数
main() {
    check_root_permission
    show_welcome
    detect_operating_system
    update_system
    
    select_php_version
    select_database
    
    # 显示安装摘要
    clear
    draw_menu_border "安装摘要"
    echo ""
    info "即将安装:"
    info "- Nginx Web服务器"
    info "- PHP $PHP_VERSION"
    info "- ${DB_CHOICES[$DB_CHOICE]}"
    echo ""
    
    if ! confirm "确认开始安装LNMP环境?"; then
        info "安装已取消"
        exit 0
    fi
    
    # 执行安装
    install_nginx
    install_php
    install_database
    configure_lnmp
    
    success "LNMP环境安装完成!"
    info "您现在可以开始部署Web应用程序"
    record_function_usage "lnmp_install"
    pause_for_continue
}

# 执行主函数
main
