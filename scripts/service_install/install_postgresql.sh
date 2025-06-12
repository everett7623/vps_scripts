#!/bin/bash
#/scripts/service_install/install_postgresql.sh - VPS Scripts PostgreSQL安装工具

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

# 安装PostgreSQL
install_postgresql() {
    echo -e "${BLUE}正在安装PostgreSQL...${NC}"
    
    if command -v psql &>/dev/null; then
        echo -e "${YELLOW}PostgreSQL已安装，当前版本: $(psql --version)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    # 选择PostgreSQL版本
    echo "请选择要安装的PostgreSQL版本:"
    echo "1) PostgreSQL 15 (最新稳定版)"
    echo "2) PostgreSQL 14"
    echo "3) PostgreSQL 13"
    
    read -p "请输入选项 (1-3): " version_choice
    
    case $version_choice in
        1)
            PG_VERSION="15"
            ;;
        2)
            PG_VERSION="14"
            ;;
        3)
            PG_VERSION="13"
            ;;
        *)
            echo -e "${RED}无效选项，默认安装PostgreSQL 15${NC}"
            PG_VERSION="15"
            ;;
    esac
    
    if [ "$OS" = "Ubuntu" ]; then
        # 添加PostgreSQL仓库
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
        apt update -y
        apt install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION
    elif [ "$OS" = "Debian" ]; then
        # 添加PostgreSQL仓库
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
        echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
        apt update -y
        apt install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        # 添加PostgreSQL仓库
        yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        yum install -y postgresql$PG_VERSION postgresql$PG_VERSION-server
        /usr/pgsql-$PG_VERSION/bin/postgresql-$PG_VERSION-setup initdb
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm postgresql
        mkdir -p /var/lib/postgres/data
        chown postgres:postgres /var/lib/postgres/data
        sudo -u postgres initdb -D /var/lib/postgres/data
    else
        echo -e "${RED}不支持的操作系统，无法安装PostgreSQL。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}PostgreSQL安装完成。${NC}"
    
    # 配置PostgreSQL
    configure_postgresql
    
    # 验证安装
    psql --version
    
    return 0
}

# 配置PostgreSQL
configure_postgresql() {
    echo -e "${BLUE}正在配置PostgreSQL...${NC}"
    
    # 启动PostgreSQL服务
    if [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        systemctl enable postgresql-$PG_VERSION
        systemctl start postgresql-$PG_VERSION
    elif [ "$OS" = "Arch Linux" ]; then
        systemctl enable postgresql
        systemctl start postgresql
    else
        systemctl enable postgresql
        systemctl start postgresql
    fi
    
    # 验证PostgreSQL服务状态
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}PostgreSQL服务已成功启动。${NC}"
    else
        echo -e "${RED}PostgreSQL服务启动失败，请检查日志。${NC}"
        return 1
    fi
    
    # 询问是否设置postgres用户密码
    read -p "是否为postgres用户设置密码？(y/n): " set_password
    
    if [ "$set_password" = "y" ] || [ "$set_password" = "Y" ]; then
        read -s -p "请输入postgres用户密码: " postgres_password
        echo ""
        read -s -p "请再次输入postgres用户密码: " postgres_password_confirm
        echo ""
        
        if [ "$postgres_password" != "$postgres_password_confirm" ]; then
            echo -e "${RED}密码不匹配，使用默认配置。${NC}"
        else
            # 设置postgres用户密码
            sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$postgres_password';"
            
            # 修改认证方式
            if [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
                sed -i "s/ident/md5/g" /var/lib/pgsql/$PG_VERSION/data/pg_hba.conf
            elif [ "$OS" = "Arch Linux" ]; then
                sed -i "s/ident/md5/g" /var/lib/postgres/data/pg_hba.conf
            else
                sed -i "s/peer/md5/g" /etc/postgresql/$PG_VERSION/main/pg_hba.conf
            fi
            
            # 重启PostgreSQL服务
            if [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
                systemctl restart postgresql-$PG_VERSION
            elif [ "$OS" = "Arch Linux" ]; then
                systemctl restart postgresql
            else
                systemctl restart postgresql
            fi
            
            echo -e "${GREEN}postgres用户密码已设置。${NC}"
            echo -e "${YELLOW}请使用以下命令连接PostgreSQL:${NC}"
            echo -e "${YELLOW}psql -U postgres -W${NC}"
        fi
    fi
    
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           PostgreSQL安装工具                ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    # 安装PostgreSQL
    install_postgresql
    
    echo -e "${GREEN}PostgreSQL安装工具执行完成!${NC}"
}

# 执行主函数
main
