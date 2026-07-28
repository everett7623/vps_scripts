#!/bin/bash
set -euo pipefail
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
read -r -p "请输入哪吒监控服务器地址: " server
read -r -p "请输入哪吒监控服务器端口: " port
read -r -p "请输入客户端唯一标识: " secret

if [[ ! "${server}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] &&
   [[ ! "${server}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "${RED}错误: 服务器地址必须是域名或 IPv4 地址${NC}"
    exit 1
fi
if [[ ! "${port}" =~ ^[0-9]+$ ]] || [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]; then
    echo -e "${RED}错误: 端口必须在 1-65535 范围内${NC}"
    exit 1
fi
if [ -z "${secret}" ] || [[ "${secret}" == *$'\n'* ]] || [[ "${secret}" == *$'\r'* ]]; then
    echo -e "${RED}错误: 客户端唯一标识不能为空且不能包含换行符${NC}"
    exit 1
fi

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
WORK_DIR=$(mktemp -d "/tmp/nezha-agent.XXXXXX") || {
    echo -e "${RED}错误: 创建临时目录失败${NC}"
    exit 1
}
trap 'rm -rf -- "${WORK_DIR}"' EXIT
mkdir -p /opt/nezha

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
ARCHIVE_FILE="${WORK_DIR}/nezha-agent.tar.gz"
if ! wget -qO "${ARCHIVE_FILE}" "https://github.com/naiba/nezha/releases/latest/download/nezha-agent_linux_${arch}.tar.gz" ||
   ! tar -tzf "${ARCHIVE_FILE}" | grep -qx 'nezha-agent'; then
    echo -e "${RED}错误: 下载内容无效或不包含 nezha-agent${NC}"
    exit 1
fi
tar -xzf "${ARCHIVE_FILE}" -C "${WORK_DIR}" --no-same-owner
if [ ! -f "${WORK_DIR}/nezha-agent" ]; then
    echo -e "${RED}错误: 未找到 Nezha Agent 可执行文件${NC}"
    exit 1
fi
install -m 0755 "${WORK_DIR}/nezha-agent" /opt/nezha/nezha-agent

# 创建服务
server_arg=$(systemd-escape -- "${server}:${port}")
secret_arg=$(systemd-escape -- "${secret}")
cat > /etc/systemd/system/nezha-agent.service << EOF
[Unit]
Description=Nezha Agent
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/opt/nezha
ExecStart=/opt/nezha/nezha-agent -s ${server_arg} -p ${secret_arg}
Restart=always
RestartSec=5
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF
if ! systemd-analyze verify /etc/systemd/system/nezha-agent.service; then
    echo -e "${RED}错误: systemd 服务配置校验失败${NC}"
    exit 1
fi

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
