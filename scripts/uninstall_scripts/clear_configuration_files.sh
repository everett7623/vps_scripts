#!/bin/bash
#/vps_scripts/scripts/uninstall_scripts/clear_configuration_files.sh - VPS Scripts 配置文件清理工具

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

echo -e "${WHITE}VPS Scripts 配置文件清理工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 此操作将删除VPS Scripts生成的配置文件${NC}"
echo -e "${RED}此操作不可逆转，可能导致服务无法正常运行${NC}"
read -p "确定要继续吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始清理配置文件...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 获取当前脚本目录
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(realpath "$SCRIPT_DIR/..")

# 创建备份目录
BACKUP_DIR="$PARENT_DIR/backup/config_clean_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 配置文件列表
echo -e "${WHITE}可清理的配置文件:${NC}"
echo "1. Nginx配置"
echo "2. Apache配置"
echo "3. MySQL/MariaDB配置"
echo "4. PHP配置"
echo "5. Docker配置"
echo "6. 系统网络配置"
echo "7. 系统安全配置"
echo "8. 全部配置"
echo ""

# 获取用户选择
read -p "请选择要清理的配置文件编号 (1-8): " choice

# 根据用户选择清理配置文件
case "$choice" in
    1) # Nginx配置
        echo -e "${WHITE}清理Nginx配置...${NC}"
        
        # 停止服务
        systemctl stop nginx &> /dev/null
        
        # 备份配置
        if [ -d "/etc/nginx" ]; then
            cp -r "/etc/nginx" "$BACKUP_DIR/nginx"
        fi
        
        # 删除配置文件
        rm -rf /etc/nginx/conf.d/*
        rm -rf /etc/nginx/sites-available/*
        rm -rf /etc/nginx/sites-enabled/*
        
        # 恢复默认配置
        if [ -f "/etc/nginx/nginx.conf.bak" ]; then
            cp "/etc/nginx/nginx.conf.bak" "/etc/nginx/nginx.conf"
        fi
        
        echo -e "${GREEN}Nginx配置清理完成${NC}"
        ;;
        
    2) # Apache配置
        echo -e "${WHITE}清理Apache配置...${NC}"
        
        # 停止服务
        systemctl stop httpd &> /dev/null
        
        # 备份配置
        if [ -d "/etc/httpd" ]; then
            cp -r "/etc/httpd" "$BACKUP_DIR/apache"
        fi
        
        # 删除配置文件
        rm -rf /etc/httpd/conf.d/*
        rm -rf /etc/httpd/sites-available/*
        rm -rf /etc/httpd/sites-enabled/*
        
        # 恢复默认配置
        if [ -f "/etc/httpd/conf/httpd.conf.bak" ]; then
            cp "/etc/httpd/conf/httpd.conf.bak" "/etc/httpd/conf/httpd.conf"
        fi
        
        echo -e "${GREEN}Apache配置清理完成${NC}"
        ;;
        
    3) # MySQL/MariaDB配置
        echo -e "${WHITE}清理MySQL/MariaDB配置...${NC}"
        
        # 停止服务
        systemctl stop mysql &> /dev/null
        systemctl stop mysqld &> /dev/null
        systemctl stop mariadb &> /dev/null
        
        # 备份配置
        if [ -d "/etc/mysql" ]; then
            cp -r "/etc/mysql" "$BACKUP_DIR/mysql"
        fi
        
        if [ -d "/etc/my.cnf.d" ]; then
            cp -r "/etc/my.cnf.d" "$BACKUP_DIR/my.cnf.d"
        fi
        
        # 删除配置文件
        rm -rf /etc/mysql/conf.d/*
        rm -rf /etc/mysql/mariadb.conf.d/*
        rm -rf /etc/my.cnf.d/*
        
        # 恢复默认配置
        if [ -f "/etc/mysql/my.cnf.bak" ]; then
            cp "/etc/mysql/my.cnf.bak" "/etc/mysql/my.cnf"
        fi
        
        if [ -f "/etc/my.cnf.bak" ]; then
            cp "/etc/my.cnf.bak" "/etc/my.cnf"
        fi
        
        echo -e "${GREEN}MySQL/MariaDB配置清理完成${NC}"
        ;;
        
    4) # PHP配置
        echo -e "${WHITE}清理PHP配置...${NC}"
        
        # 停止服务
        systemctl stop php-fpm &> /dev/null
        
        # 备份配置
        if [ -d "/etc/php" ]; then
            cp -r "/etc/php" "$BACKUP_DIR/php"
        fi
        
        # 删除配置文件
        rm -rf /etc/php/*/fpm/pool.d/*
        rm -rf /etc/php/*/conf.d/*
        
        # 恢复默认配置
        if [ -f "/etc/php.ini.bak" ]; then
            cp "/etc/php.ini.bak" "/etc/php.ini"
        fi
        
        echo -e "${GREEN}PHP配置清理完成${NC}"
        ;;
        
    5) # Docker配置
        echo -e "${WHITE}清理Docker配置...${NC}"
        
        # 停止服务
        systemctl stop docker &> /dev/null
        
        # 备份配置
        if [ -d "/etc/docker" ]; then
            cp -r "/etc/docker" "$BACKUP_DIR/docker"
        fi
        
        # 删除配置文件
        rm -rf /etc/docker/*
        
        # 恢复默认配置
        if [ -f "/etc/docker/daemon.json.bak" ]; then
            cp "/etc/docker/daemon.json.bak" "/etc/docker/daemon.json"
        fi
        
        echo -e "${GREEN}Docker配置清理完成${NC}"
        ;;
        
    6) # 系统网络配置
        echo -e "${WHITE}清理系统网络配置...${NC}"
        
        # 备份配置
        cp /etc/network/interfaces "$BACKUP_DIR/interfaces.bak" 2> /dev/null
        cp /etc/netplan/*.yaml "$BACKUP_DIR/" 2> /dev/null
        cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak"
        
        # 恢复默认网络配置
        if [ -f "/etc/network/interfaces.bak" ]; then
            cp "/etc/network/interfaces.bak" "/etc/network/interfaces"
        fi
        
        # 恢复默认sysctl配置
        if [ -f "/etc/sysctl.conf.bak" ]; then
            cp "/etc/sysctl.conf.bak" "/etc/sysctl.conf"
        fi
        
        # 应用新配置
        sysctl -p
        
        echo -e "${GREEN}系统网络配置清理完成${NC}"
        ;;
        
    7) # 系统安全配置
        echo -e "${WHITE}清理系统安全配置...${NC}"
        
        # 备份配置
        cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak" 2> /dev/null
        cp /etc/fail2ban/jail.conf "$BACKUP_DIR/jail.conf.bak" 2> /dev/null
        cp /etc/firewalld/zones/public.xml "$BACKUP_DIR/public.xml.bak" 2> /dev/null
        cp /etc/ufw/applications.d/* "$BACKUP_DIR/" 2> /dev/null
        
        # 恢复默认SSH配置
        if [ -f "/etc/ssh/sshd_config.bak" ]; then
            cp "/etc/ssh/sshd_config.bak" "/etc/ssh/sshd_config"
        fi
        
        # 重启SSH服务
        systemctl restart sshd &> /dev/null
        
        echo -e "${GREEN}系统安全配置清理完成${NC}"
        ;;
        
    8) # 全部配置
        echo -e "${WHITE}清理所有配置文件...${NC}"
        
        # 执行所有清理操作
        bash "$0" <<< "1"
        bash "$0" <<< "2"
        bash "$0" <<< "3"
        bash "$0" <<< "4"
        bash "$0" <<< "5"
        bash "$0" <<< "6"
        bash "$0" <<< "7"
        
        echo -e "${GREEN}所有配置文件清理完成${NC}"
        ;;
        
    *) 
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}配置文件清理完成${NC}"
echo -e "${WHITE}备份目录: ${YELLOW}$BACKUP_DIR${NC}"
echo ""
read -n 1 -s -r -p "按任意键返回主菜单..."
