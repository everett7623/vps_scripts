#!/bin/bash
#/vps_scripts/scripts/other_tools/nezha.sh - VPS Scripts 哪吒监控安装工具

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

echo -e "${WHITE}哪吒监控安装工具${NC}"
echo "------------------------"

# 确认操作
echo -e "${YELLOW}警告: 安装哪吒监控将收集系统信息并发送至服务器${NC}"
read -p "确定要安装哪吒监控吗? (y/n): " confirm
case "$confirm" in 
  y|Y ) echo -e "${GREEN}开始安装哪吒监控...${NC}";;
  n|N ) echo -e "${YELLOW}已取消操作${NC}"; exit 0;;
  * ) echo -e "${RED}无效选择，已取消操作${NC}"; exit 1;;
esac

# 获取哪吒监控服务器信息
read -p "请输入哪吒监控服务器地址: " server
read -p "请输入哪吒监控服务器端口: " port
read -p "请输入客户端唯一标识: " secret

# 安装必要依赖
echo -e "${WHITE}安装必要依赖...${NC}"
if [ -f /etc/redhat-release ]; then
    yum -y install wget curl
else
    apt-get update
    apt-get -y install wget curl
fi

# 下载并安装哪吒客户端
echo -e "${WHITE}下载并安装哪吒客户端...${NC}"
mkdir -p /opt/nezha
cd /opt/nezha || exit

# 获取系统架构
arch=$(uname -m)
case $arch in
    x86_64)
        arch="amd64"
        ;;
    aarch64)
        arch="arm64"
        ;;
    armv7l)
        arch="armv7"
        ;;
    *)
        echo -e "${RED}不支持的系统架构: $arch${NC}"
        exit 1
        ;;
esac

# 下载客户端
wget -q https://github.com/naiba/nezha/releases/latest/download/nezha-agent_linux_$arch.tar.gz
tar -xzf nezha-agent_linux_$arch.tar.gz
rm nezha-agent_linux_$arch.tar.gz

# 创建服务
cat > /etc/systemd/system/nezha-agent.service << EOF
[Unit]
Description=Nezha Agent
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/opt/nezha
ExecStart=/opt/nezha/nezha-agent -s $server:$port -p $secret
Restart=always
RestartSec=5
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo -e "${WHITE}启动哪吒监控客户端...${NC}"
systemctl daemon-reload
systemctl enable nezha-agent
systemctl restart nezha-agent

# 检查服务状态
if systemctl is-active nezha-agent &> /dev/null; then
    echo -e "${GREEN}哪吒监控客户端已成功启动${NC}"
else
    echo -e "${RED}哪吒监控客户端启动失败，请手动检查${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}哪吒监控客户端安装完成${NC}"
echo -e "${WHITE}服务器地址: ${YELLOW}$server${NC}"
echo -e "${WHITE}服务器端口: ${YELLOW}$port${NC}"
echo -e "${WHITE}客户端标识: ${YELLOW}$secret${NC}"
echo ""
echo -e "${WHITE}管理命令:${NC}"
echo -e "${YELLOW}启动: systemctl start nezha-agent${NC}"
echo -e "${YELLOW}停止: systemctl stop nezha-agent${NC}"
echo -e "${YELLOW}重启: systemctl restart nezha-agent${NC}"
echo -e "${YELLOW}状态: systemctl status nezha-agent${NC}"
echo ""
