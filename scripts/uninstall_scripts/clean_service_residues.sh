#!/bin/bash
#/vps_scripts/scripts/uninstall_scripts/clean_service_residues.sh - VPS Scripts 服务残留清理工具

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

echo -e "${WHITE}VPS Scripts 服务残留清理工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 此操作将卸载通过VPS Scripts安装的服务${NC}"
echo -e "${YELLOW}并清理相关残留文件和配置${NC}"
echo -e "${RED}此操作不可逆转，可能导致数据丢失${NC}"
read -p "确定要继续吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始清理服务残留...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/service_clean_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 服务列表
echo -e "${WHITE}可清理的服务列表:${NC}"
echo "1. 宝塔面板"
echo "2. 1Panel面板"
echo "3. WordPress"
echo "4. Docker"
echo "5. Nginx"
echo "6. Apache"
echo "7. MySQL/MariaDB"
echo "8. PHP-FPM"
echo "9. 全部服务"
echo ""

# 获取用户选择
read -p "请选择要清理的服务编号 (1-9): " choice

# 根据用户选择清理服务
case "$choice" in
    1) # 宝塔面板
        echo -e "${WHITE}清理宝塔面板...${NC}"
        
        # 停止服务
        systemctl stop bt &> /dev/null
        systemctl disable bt &> /dev/null
        
        # 备份配置
        if [ -d "/www/server/panel" ]; then
            cp -r "/www/server/panel" "$BACKUP_DIR/bt_panel"
        fi
        
        # 执行官方卸载脚本
        if [ -f "/www/server/panel/install.sh" ]; then
            bash "/www/server/panel/install.sh" uninstall
        fi
        
        # 删除残留文件
        rm -rf /www/server/panel
        rm -rf /www/wwwroot/default
        rm -rf /www/server/nginx
        rm -rf /www/server/mysql
        rm -rf /www/server/php
        rm -rf /www/server/apache
        
        echo -e "${GREEN}宝塔面板清理完成${NC}"
        ;;
        
    2) # 1Panel面板
        echo -e "${WHITE}清理1Panel面板...${NC}"
        
        # 停止服务
        systemctl stop 1panel &> /dev/null
        systemctl disable 1panel &> /dev/null
        
        # 备份配置
        if [ -d "/opt/1panel" ]; then
            cp -r "/opt/1panel" "$BACKUP_DIR/1panel"
        fi
        
        # 删除服务文件
        rm -f /etc/systemd/system/1panel.service
        systemctl daemon-reload &> /dev/null
        
        # 删除安装目录
        rm -rf /opt/1panel
        
        echo -e "${GREEN}1Panel面板清理完成${NC}"
        ;;
        
    3) # WordPress
        echo -e "${WHITE}清理WordPress...${NC}"
        
        # 获取WordPress安装目录
        read -p "请输入WordPress安装目录 [/var/www/html/wordpress]: " wp_dir
        wp_dir=${wp_dir:-/var/www/html/wordpress}
        
        # 备份WordPress
        if [ -d "$wp_dir" ]; then
            cp -r "$wp_dir" "$BACKUP_DIR/wordpress"
        fi
        
        # 删除WordPress目录
        rm -rf "$wp_dir"
        
        echo -e "${GREEN}WordPress清理完成${NC}"
        echo -e "${YELLOW}注意: 数据库未删除，请手动清理${NC}"
        ;;
        
    4) # Docker
        echo -e "${WHITE}清理Docker...${NC}"
        
        # 停止服务
        systemctl stop docker &> /dev/null
        systemctl disable docker &> /dev/null
        
        # 备份配置
        if [ -d "/var/lib/docker" ]; then
            cp -r "/var/lib/docker" "$BACKUP_DIR/docker"
        fi
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
        else
            apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        fi
        
        # 删除残留文件
        rm -rf /var/lib/docker
        rm -rf /etc/docker
        
        echo -e "${GREEN}Docker清理完成${NC}"
        ;;
        
    5) # Nginx
        echo -e "${WHITE}清理Nginx...${NC}"
        
        # 停止服务
        systemctl stop nginx &> /dev/null
        systemctl disable nginx &> /dev/null
        
        # 备份配置
        if [ -d "/etc/nginx" ]; then
            cp -r "/etc/nginx" "$BACKUP_DIR/nginx"
        fi
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y nginx
        else
            apt-get purge -y nginx
        fi
        
        # 删除残留文件
        rm -rf /etc/nginx
        rm -rf /usr/share/nginx
        rm -rf /var/www/html
        
        echo -e "${GREEN}Nginx清理完成${NC}"
        ;;
        
    6) # Apache
        echo -e "${WHITE}清理Apache...${NC}"
        
        # 停止服务
        systemctl stop httpd &> /dev/null
        systemctl disable httpd &> /dev/null
        
        # 备份配置
        if [ -d "/etc/httpd" ]; then
            cp -r "/etc/httpd" "$BACKUP_DIR/apache"
        fi
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y httpd
        else
            apt-get purge -y apache2
        fi
        
        # 删除残留文件
        rm -rf /etc/httpd
        rm -rf /var/www/html
        
        echo -e "${GREEN}Apache清理完成${NC}"
        ;;
        
    7) # MySQL/MariaDB
        echo -e "${WHITE}清理MySQL/MariaDB...${NC}"
        
        # 停止服务
        systemctl stop mysql &> /dev/null
        systemctl stop mysqld &> /dev/null
        systemctl stop mariadb &> /dev/null
        
        systemctl disable mysql &> /dev/null
        systemctl disable mysqld &> /dev/null
        systemctl disable mariadb &> /dev/null
        
        # 备份配置
        if [ -d "/etc/mysql" ]; then
            cp -r "/etc/mysql" "$BACKUP_DIR/mysql_config"
        fi
        
        if [ -d "/var/lib/mysql" ]; then
            cp -r "/var/lib/mysql" "$BACKUP_DIR/mysql_data"
        fi
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y mysql mysql-server mysql-devel
            yum remove -y mariadb mariadb-server
        else
            apt-get purge -y mysql-server mysql-client mysql-common
            apt-get purge -y mariadb-server mariadb-client
        fi
        
        # 删除残留文件
        rm -rf /etc/mysql
        rm -rf /var/lib/mysql
        rm -rf /var/log/mysql
        
        echo -e "${GREEN}MySQL/MariaDB清理完成${NC}"
        ;;
        
    8) # PHP-FPM
        echo -e "${WHITE}清理PHP-FPM...${NC}"
        
        # 停止服务
        systemctl stop php-fpm &> /dev/null
        systemctl disable php-fpm &> /dev/null
        
        # 备份配置
        if [ -d "/etc/php" ]; then
            cp -r "/etc/php" "$BACKUP_DIR/php_config"
        fi
        
        # 检测系统类型
        if [ -f /etc/redhat-release ]; then
            yum remove -y php php-fpm php-mysql php-gd php-mbstring php-xml
        else
            apt-get purge -y php-fpm php-mysql php-gd php-mbstring php-xml
        fi
        
        # 删除残留文件
        rm -rf /etc/php
        rm -rf /var/lib/php
        
        echo -e "${GREEN}PHP-FPM清理完成${NC}"
        ;;
        
    9) # 全部服务
        echo -e "${WHITE}清理所有服务...${NC}"
        
        # 执行所有清理操作
        bash "$0" <<< "1"
        bash "$0" <<< "2"
        bash "$0" <<< "3"
        bash "$0" <<< "4"
        bash "$0" <<< "5"
        bash "$0" <<< "6"
        bash "$0" <<< "7"
        bash "$0" <<< "8"
        
        echo -e "${GREEN}所有服务清理完成${NC}"
        ;;
        
    *) 
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}服务残留清理完成${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
