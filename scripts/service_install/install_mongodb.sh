#!/bin/bash
#/scripts/service_install/install_mongodb.sh - VPS Scripts MongoDB安装工具

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

# 安装MongoDB
install_mongodb() {
    echo -e "${BLUE}正在安装MongoDB...${NC}"
    
    if command -v mongod &>/dev/null; then
        echo -e "${YELLOW}MongoDB已安装，当前版本: $(mongod --version | head -1)${NC}"
        
        read -p "是否更新到最新版本？(y/n): " update_choice
        
        if [ "$update_choice" != "y" ] && [ "$update_choice" != "Y" ]; then
            return 0
        fi
    fi
    
    if [ "$OS" = "Ubuntu" ]; then
        # 添加MongoDB仓库
        wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
        apt update -y
        apt install -y mongodb-org
    elif [ "$OS" = "Debian" ]; then
        # 添加MongoDB仓库
        wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian $(lsb_release -cs)/mongodb-org/6.0 main" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
        apt update -y
        apt install -y mongodb-org
    elif [ "$OS" = "CentOS Linux" ] || [ "$OS" = "Red Hat/CentOS" ]; then
        # 创建MongoDB仓库文件
        cat > /etc/yum.repos.d/mongodb-org-6.0.repo << EOF
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
        yum install -y mongodb-org
    elif [ "$OS" = "Arch Linux" ]; then
        pacman -S --noconfirm mongodb-bin
    else
        echo -e "${RED}不支持的操作系统，无法安装MongoDB。${NC}"
        return 1
    fi
    
    echo -e "${GREEN}MongoDB安装完成。${NC}"
    
    # 配置MongoDB
    configure_mongodb
    
    # 验证安装
    mongod --version | head -1
    
    return 0
}

# 配置MongoDB
configure_mongodb() {
    echo -e "${BLUE}正在配置MongoDB...${NC}"
    
    # 备份原始配置
    if [ -f /etc/mongod.conf ]; then
        cp /etc/mongod.conf /etc/mongod.conf.backup
    fi
    
    # 配置MongoDB
    sed -i 's/^bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    
    # 询问是否启用认证
    read -p "是否为MongoDB启用认证？(y/n): " enable_auth
    
    if [ "$enable_auth" = "y" ] || [ "$enable_auth" = "Y" ]; then
        sed -i 's/^#security:/security:/g'
        sed -i 's/^#  authorization: enabled/  authorization: enabled/g'
        
        echo -e "${YELLOW}MongoDB认证已启用。${NC}"
        echo -e "${YELLOW}请在MongoDB启动后创建管理员用户。${NC}"
    fi
    
    # 配置MongoDB作为服务启动
    systemctl enable mongod
    systemctl restart mongod
    
    # 验证MongoDB服务状态
    if systemctl is-active --quiet mongod; then
        echo -e "${GREEN}MongoDB服务已成功启动。${NC}"
    else
        echo -e "${RED}MongoDB服务启动失败，请检查日志。${NC}"
        return 1
    fi
    
    # 如果启用了认证，创建管理员用户
    if [ "$enable_auth" = "y" ] || [ "$enable_auth" = "Y" ]; then
        create_admin_user
    fi
    
    return 0
}

# 创建MongoDB管理员用户
create_admin_user() {
    echo -e "${BLUE}正在创建MongoDB管理员用户...${NC}"
    
    # 询问管理员用户名和密码
    read -p "请输入管理员用户名: " admin_username
    read -s -p "请输入管理员密码: " admin_password
    echo ""
    read -s -p "请再次输入管理员密码: " admin_password_confirm
    echo ""
    
    if [ "$admin_password" != "$admin_password_confirm" ]; then
        echo -e "${RED}密码不匹配，跳过创建管理员用户。${NC}"
        return 1
    fi
    
    # 创建管理员用户
    cat > create_admin.js << EOF
use admin
db.createUser(
  {
    user: "$admin_username",
    pwd: "$admin_password",
    roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
  }
)
EOF
    
    # 执行JavaScript文件创建用户
    mongo < create_admin.js
    
    # 删除临时文件
    rm create_admin.js
    
    echo -e "${GREEN}MongoDB管理员用户创建成功。${NC}"
    echo -e "${YELLOW}请使用以下命令连接MongoDB:${NC}"
    echo -e "${YELLOW}mongo -u $admin_username -p --authenticationDatabase admin${NC}"
    
    return 0
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           MongoDB安装工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    check_root
    detect_os
    
    read -p "是否更新系统？(y/n): " update_choice
    
    if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
        update_system
    fi
    
    # 安装MongoDB
    install_mongodb
    
    echo -e "${GREEN}MongoDB安装工具执行完成!${NC}"
}

# 执行主函数
main
