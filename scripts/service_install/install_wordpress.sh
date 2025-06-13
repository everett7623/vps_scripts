#!/bin/bash
#/vps_scripts/scripts/service_install/install_wordpress.sh - VPS Scripts WordPress安装工具

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
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
   exit 1
fi

echo -e "${WHITE}WordPress安装工具${NC}"
echo "------------------------"

# 确认安装
echo -e "${YELLOW}警告: 安装WordPress需要LAMP/LNMP环境，确保已安装${NC}"
echo -e "${YELLOW}此脚本仅安装WordPress，不配置Web服务器${NC}"
read -p "确定要安装WordPress吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始安装WordPress...${NC}";;
  n|N ) echo -e "${YELLOW}已取消安装${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消安装${NC}"; exit 1;;
esac

# 检查是否已安装Web服务器
if command -v apache2 >/dev/null 2>&1 || command -v nginx >/dev/null 2>&1; then
    echo -e "${GREEN}检测到Web服务器已安装${NC}"
else
    echo -e "${RED}未检测到Web服务器，请先安装Apache或Nginx${NC}"
    exit 1
fi

# 检查是否已安装PHP
if command -v php >/dev/null 2>&1; then
    php_version=$(php -v | head -n 1 | cut -d " " -f 2 | cut -d "." -f 1,2)
    echo -e "${GREEN}检测到PHP $php_version 已安装${NC}"
    
    # 检查PHP版本是否符合WordPress要求
    if (( $(echo "$php_version >= 7.4" | bc -l) )); then
        echo -e "${GREEN}PHP版本符合WordPress要求${NC}"
    else
        echo -e "${YELLOW}警告: PHP版本可能低于WordPress推荐版本(7.4+)${NC}"
    fi
else
    echo -e "${RED}未检测到PHP，请先安装PHP 7.4或更高版本${NC}"
    exit 1
fi

# 检查是否已安装MySQL/MariaDB
if command -v mysql >/dev/null 2>&1; then
    echo -e "${GREEN}检测到MySQL/MariaDB已安装${NC}"
else
    echo -e "${RED}未检测到MySQL/MariaDB，请先安装数据库服务器${NC}"
    exit 1
fi

# 获取WordPress安装信息
read -p "请输入WordPress安装目录 [/var/www/html/wordpress]: " wp_dir
wp_dir=${wp_dir:-/var/www/html/wordpress}

read -p "请输入数据库名称: " db_name
read -p "请输入数据库用户名: " db_user
read -p "请输入数据库密码: " db_pass
read -p "请输入数据库主机 [localhost]: " db_host
db_host=${db_host:-localhost}

# 创建WordPress目录
echo -e "${WHITE}创建WordPress目录...${NC}"
mkdir -p "$wp_dir"
chown -R www-data:www-data "$wp_dir"
chmod -R 755 "$wp_dir"

# 下载WordPress
echo -e "${WHITE}下载WordPress...${NC}"
cd "$wp_dir" || exit
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
rm latest.tar.gz

# 配置WordPress
echo -e "${WHITE}配置WordPress...${NC}"
cp wp-config-sample.php wp-config.php

# 生成安全密钥
echo -e "${WHITE}生成安全密钥...${NC}"
sed -i "/AUTH_KEY/d" wp-config.php
sed -i "/SECURE_AUTH_KEY/d" wp-config.php
sed -i "/LOGGED_IN_KEY/d" wp-config.php
sed -i "/NONCE_KEY/d" wp-config.php
sed -i "/AUTH_SALT/d" wp-config.php
sed -i "/SECURE_AUTH_SALT/d" wp-config.php
sed -i "/LOGGED_IN_SALT/d" wp-config.php
sed -i "/NONCE_SALT/d" wp-config.php

# 添加新的安全密钥
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php

# 配置数据库信息
sed -i "s/database_name_here/$db_name/g" wp-config.php
sed -i "s/username_here/$db_user/g" wp-config.php
sed -i "s/password_here/$db_pass/g" wp-config.php
sed -i "s/localhost/$db_host/g" wp-config.php

# 设置文件权限
chown -R www-data:www-data "$wp_dir"
chmod -R 755 "$wp_dir"

# 检查数据库连接
echo -e "${WHITE}检查数据库连接...${NC}"
mysql -h "$db_host" -u "$db_user" -p"$db_pass" -e "CREATE DATABASE IF NOT EXISTS $db_name;"

if [ $? -ne 0 ]; then
    echo -e "${RED}数据库连接失败，请检查数据库信息${NC}"
    exit 1
else
    echo -e "${GREEN}数据库连接成功${NC}"
fi

echo ""
echo -e "${GREEN}WordPress安装完成${NC}"
echo -e "${WHITE}访问地址: ${YELLOW}http://服务器IP/wordpress${NC}"
echo -e "${WHITE}请访问上述地址完成WordPress安装向导${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
