#!/bin/bash
#/vps_scripts/scripts/other_tools/fail2ban.sh - VPS Scripts Fail2ban安全工具

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

echo -e "${WHITE}Fail2ban安全工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 安装Fail2ban将增强系统安全性，但可能影响正常访问${NC}"
read -p "确定要安装Fail2ban吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始安装Fail2ban...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 检测系统类型
if [ -f /etc/redhat-release ]; then
    system_type="centos"
elif [ -f /etc/debian_version ]; then
    if grep -q "ubuntu" /etc/os-release; then
        system_type="ubuntu"
    else
        system_type="debian"
    fi
else
    echo -e "${RED}不支持的操作系统类型${NC}"
    exit 1
fi

echo -e "${WHITE}检测到系统类型: ${YELLOW}$system_type${NC}"

# 根据系统类型安装Fail2ban
echo -e "${WHITE}安装Fail2ban...${NC}"
if [ "$system_type" == "centos" ]; then
    yum -y install epel-release
    yum -y install fail2ban
else
    apt-get update
    apt-get -y install fail2ban
fi

# 检查Fail2ban是否安装成功
if ! command -v fail2ban-server &> /dev/null; then
    echo -e "${RED}Fail2ban安装失败，请手动检查${NC}"
    exit 1
fi

# 配置Fail2ban
echo -e "${WHITE}配置Fail2ban...${NC}"

# 创建自定义配置
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400  # 封禁时间(秒)
findtime = 3600   # 查找时间(秒)
maxretry = 5      # 最大尝试次数
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
EOF

# 启动Fail2ban服务
echo -e "${WHITE}启动Fail2ban服务...${NC}"
if [ "$system_type" == "centos" ]; then
    systemctl enable fail2ban
    systemctl restart fail2ban
else
    systemctl enable fail2ban
    systemctl restart fail2ban
fi

# 检查服务状态
if systemctl is-active fail2ban &> /dev/null; then
    echo -e "${GREEN}Fail2ban服务已成功启动${NC}"
else
    echo -e "${RED}Fail2ban服务启动失败，请手动检查${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Fail2ban安装配置完成${NC}"
echo -e "${WHITE}主要配置参数:${NC}"
echo -e "${YELLOW}封禁时间: 24小时${NC}"
echo -e "${YELLOW}最大尝试次数: 3次${NC}"
echo -e "${YELLOW}保护服务: SSH${NC}"
echo ""
echo -e "${WHITE}查看封禁IP: ${YELLOW}fail2ban-client status sshd${NC}"
echo -e "${WHITE}解封IP: ${YELLOW}fail2ban-client set sshd unbanip IP地址${NC}"
echo ""
