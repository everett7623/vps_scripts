#!/bin/bash
#/scripts/service_install/install_lnmp.sh - VPS Scripts LEMP栈安装工具

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat/CentOS"
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo -e "${YELLOW}检测到操作系统: ${GREEN}$OS $VER${NC}"
}

# 更新系统
update_system() {
    echo -e "${BLUE}正在更新系统...${NC}"
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt update -y
        apt upgrade -y
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum update -y
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -Syu --noconfirm
    else
        echo -e "${YELLOW}跳过系统更新，未知操作系统${NC}"
    fi
    
    echo -e "${GREEN}系统更新完成。${NC}"
}

# 安装Nginx
install_nginx() {
    echo -e "${BLUE}正在安装Nginx...${NC}"
    
    if command -v nginx &>/dev/null; then
        echo -e "${YELLOW}Nginx已安装，跳过安装。${NC}"
        return 0
    fi
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt install -y nginx
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum install -y nginx
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm nginx
    else
        echo -e "${RED}不支持的操作系统，无法安装Nginx。${NC}"
        return 1
    fi
    
    # 启动Nginx服务
    systemctl enable nginx
    systemctl start nginx
    
    echo -e "${GREEN}Nginx安装完成。${NC}"
    
    # 验证安装
    nginx -v
    
    return 0
}

# 安装PHP
install_php() {
    echo -e "${BLUE}正在安装PHP...${NC}"
    
    if command -v php &>/dev/null; then
        echo -e "${YELLOW}PHP已安装，跳过安装。${NC}"
        return 0
    fi
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        # 添加PHP PPA (Ubuntu)
        if [ "$OS" = "Ubuntu" ]; then
            apt install -y software-properties-common
            add-apt-repository -y ppa:ondrej/php
            apt update -y
        fi
        
        # 安装PHP和常用扩展
        apt install -y php8.1 php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-intl php8.1-mbstring php8.1-xml php8.1-zip
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        # 添加Remi仓库
        yum install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
        dnf module enable php:remi-8.1 -y
        yum install -y php php-fpm php-mysqlnd php-curl php-gd php-intl php-mbstring php-xml php-zip
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm php php-fpm php-mysql
    else
        echo -e "${RED}不支持的操作系统，无法安装PHP。${NC}"
        return 1
    fi
    
    # 启动PHP-FPM服务
    systemctl enable php-fpm
    systemctl start php-fpm
    
    echo -e "${GREEN}PHP安装完成。${NC}"
    
    # 验证安装
    php -v
    
    return 0
}

# 安装MySQL/MariaDB
install_mysql() {
    echo -e "${BLUE}正在安装MySQL/MariaDB...${NC}"
    
    if command -v mysql &>/dev/null; then
        echo -e "${YELLOW}MySQL/MariaDB已安装，跳过安装。${NC}"
        return 0
    fi
    
    if [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ]; then
        apt install -y mariadb-server mariadb-client
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        yum install -y mariadb-server mariadb-client
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm mariadb
        mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
    else
        echo -e "${RED}不支持的操作系统，无法安装MySQL/MariaDB。${NC}"
        return 1
    fi
    
    # 启动MySQL/MariaDB服务
    systemctl enable mariadb
    systemctl start mariadb
    
    echo -e "${GREEN}MySQL/MariaDB安装完成。${NC}"
    
    # 安全配置MySQL/MariaDB
    read -p "是否执行MySQL/MariaDB安全配置？(y/n): " secure_choice
    
    if [ "$secure_choice" = "y" ] || [ "$secure_choice" = "Y" ]; then
        if [ "$OS" != "Arch Linux" ]; then
            mysql_secure_installation
        else
            echo -e "${YELLOW}在Arch Linux上，请手动执行安全配置。${NC}"
        fi
    fi
    
    # 验证安装
    mysql --version
    
    return 0
}

# 配置Nginx与PHP-FPM
configure_lemp() {
    echo -e "${BLUE}正在配置Nginx与PHP-FPM...${NC}"
    
    # 创建默认网站目录
    mkdir -p /var/www/html
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html
    
    # 备份原始配置
    if [ -f /etc/nginx/sites-available/default ]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    fi
    
    # 创建Nginx配置文件
    cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.php index.html index.htm;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    
    # 测试Nginx配置
    if ! nginx -t; then
        echo -e "${RED}Nginx配置测试失败，恢复原始配置。${NC}"
        if [ -f /etc/nginx/sites-available/default.backup ]; then
            cp /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
        fi
        return 1
    fi
    
    # 重启Nginx
    systemctl restart nginx
    
    # 创建PHP测试文件
    cat > /var/www/html/info.php << 'EOF'
<?php
phpinfo();
?>
EOF
    
    echo -e "${GREEN}Nginx + PHP + MySQL配置完成。${NC}"
    echo -e "${YELLOW}PHP测试文件已创建在 /var/www/html/info.php${NC}"
    echo -e "${YELLOW}请访问 http://服务器IP/info.php 验证安装${NC}"
    
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           LEMP栈安装工具                    ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    # 安装LEMP组件
    install_nginx
    install_php
    install_mysql
    
    # 配置LEMP
    configure_lemp
    
    echo -e "${GREEN}LEMP栈安装工具执行完成!${NC}"
}

# 执行主函数
main
