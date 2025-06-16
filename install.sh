#!/bin/bash

# VPS Scripts 快速安装脚本
# 用于快速部署 vps_scripts 项目到本地

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
INSTALL_DIR="/root/vps_scripts"
GITHUB_REPO="https://github.com/everett7623/vps_scripts.git"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   VPS Scripts 快速安装脚本     ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 此脚本需要 root 权限运行${NC}"
   echo -e "${YELLOW}请使用 sudo bash install.sh 重新运行${NC}"
   exit 1
fi

# 检查是否已安装
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}检测到已存在的安装目录: $INSTALL_DIR${NC}"
    read -p "是否要重新安装？这将删除现有文件 (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        echo -e "${YELLOW}正在删除旧文件...${NC}"
        rm -rf "$INSTALL_DIR"
    else
        echo -e "${GREEN}安装已取消${NC}"
        exit 0
    fi
fi

# 安装 git（如果未安装）
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}正在安装 git...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y git
    elif command -v yum &> /dev/null; then
        yum install -y git
    else
        echo -e "${RED}无法自动安装 git，请手动安装后重试${NC}"
        exit 1
    fi
fi

# 克隆项目
echo -e "${GREEN}正在克隆项目...${NC}"
git clone "$GITHUB_REPO" "$INSTALL_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}克隆失败！${NC}"
    echo -e "${YELLOW}请检查网络连接或使用以下命令手动安装：${NC}"
    echo -e "${BLUE}git clone $GITHUB_REPO $INSTALL_DIR${NC}"
    exit 1
fi

# 设置权限
echo -e "${GREEN}正在设置权限...${NC}"
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR"/scripts/*/*.sh 2>/dev/null

# 创建快捷命令
echo -e "${GREEN}正在创建快捷命令...${NC}"
cat > /usr/local/bin/vps << 'EOF'
#!/bin/bash
bash /root/vps_scripts/vps.sh
EOF

cat > /usr/local/bin/vps-dev << 'EOF'
#!/bin/bash
bash /root/vps_scripts/vps_dev.sh
EOF

chmod +x /usr/local/bin/vps
chmod +x /usr/local/bin/vps-dev

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}    安装完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}使用方法：${NC}"
echo -e "  1. 运行主脚本: ${BLUE}vps${NC} 或 ${BLUE}bash $INSTALL_DIR/vps.sh${NC}"
echo -e "  2. 运行测试脚本: ${BLUE}vps-dev${NC} 或 ${BLUE}bash $INSTALL_DIR/vps_dev.sh${NC}"
echo ""
echo -e "${YELLOW}项目目录: ${BLUE}$INSTALL_DIR${NC}"
echo ""
echo -e "${GREEN}感谢使用！${NC}"
