#!/bin/bash
#==============================================================================
# 脚本名称: 1panel.sh
# 脚本描述: 1Panel官方安装脚本增强版 - 基于官方quick_start.sh
# 脚本路径: vps_scripts/scripts/service_install/1panel.sh
# 作者: Jensfrank
# 使用方法: bash 1panel_official.sh [选项]
# 选项说明:
#   --port <端口>         面板端口 (默认: 随机)
#   --user <用户名>       管理员用户名 (默认: 1panel)
#   --password <密码>     管理员密码 (默认: 随机生成)
#   --entrance <入口>     安全入口 (默认: 随机生成)
#   --install-path       安装路径 (默认: /opt)
#   --cn-mirror          使用中国镜像源
#   --install-apps       安装常用应用
#   --skip-docker        跳过Docker检查
#   --help               显示帮助信息
# 更新日期: 2025-06-22
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
PANEL_PORT=""
PANEL_USER=""
PANEL_PASSWORD=""
PANEL_ENTRANCE=""
INSTALL_PATH="/opt"
USE_CN_MIRROR=false
INSTALL_APPS=false
SKIP_DOCKER=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/1panel_install_$(date +%Y%m%d_%H%M%S).log"

# 官方脚本URL
OFFICIAL_SCRIPT="https://resource.1panel.pro/quick_start.sh"
OFFICIAL_SCRIPT_CN="https://resource.fit2cloud.com/1panel/package/quick_start.sh"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}   1Panel官方安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash 1panel_official.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --port <端口>         面板端口 (默认: 随机)"
    echo "  --user <用户名>       管理员用户名 (默认: 1panel)"
    echo "  --password <密码>     管理员密码 (默认: 随机生成)"
    echo "  --entrance <入口>     安全入口 (默认: 随机生成)"
    echo "  --install-path       安装路径 (默认: /opt)"
    echo "  --cn-mirror          使用中国镜像源"
    echo "  --install-apps       安装常用应用"
    echo "  --skip-docker        跳过Docker检查"
    echo "  --help               显示帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash 1panel_official.sh                    # 默认安装"
    echo "  bash 1panel_official.sh --cn-mirror        # 使用中国镜像"
    echo "  bash 1panel_official.sh --port 8080 --user admin"
}

# 检查系统要求
check_requirements() {
    log "${CYAN}检查系统要求...${NC}"
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
    
    # 检查系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        log "${GREEN}检测到系统: ${OS}${NC}"
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    # 检查命令
    for cmd in curl wget; do
        if ! command -v $cmd &> /dev/null; then
            log "${RED}错误: 缺少必要的命令 $cmd${NC}"
            exit 1
        fi
    done
    
    log "${GREEN}系统要求检查通过${NC}"
}

# 准备安装环境
prepare_environment() {
    log "${CYAN}准备安装环境...${NC}"
    
    # 创建临时目录
    TEMP_DIR="/tmp/1panel_install_$$"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # 设置环境变量
    if [[ -n "$PANEL_PORT" ]]; then
        export INSTALL_PORT="$PANEL_PORT"
    fi
    
    if [[ -n "$PANEL_USER" ]]; then
        export INSTALL_USERNAME="$PANEL_USER"
    fi
    
    if [[ -n "$PANEL_PASSWORD" ]]; then
        export INSTALL_PASSWORD="$PANEL_PASSWORD"
    fi
    
    if [[ -n "$PANEL_ENTRANCE" ]]; then
        export INSTALL_ENTRANCE="$PANEL_ENTRANCE"
    fi
    
    if [[ -n "$INSTALL_PATH" ]]; then
        export INSTALL_BASE_DIR="$INSTALL_PATH"
    fi
    
    if [[ "$SKIP_DOCKER" == true ]]; then
        export SKIP_DOCKER_CHECK="true"
    fi
}

# 下载官方脚本
download_official_script() {
    log "${CYAN}下载官方安装脚本...${NC}"
    
    # 选择下载URL
    if [[ "$USE_CN_MIRROR" == true ]]; then
        DOWNLOAD_URL="$OFFICIAL_SCRIPT_CN"
        log "${YELLOW}使用中国镜像源${NC}"
    else
        DOWNLOAD_URL="$OFFICIAL_SCRIPT"
    fi
    
    # 下载脚本
    if ! curl -sSL "$DOWNLOAD_URL" -o quick_start.sh; then
        log "${RED}错误: 下载安装脚本失败${NC}"
        # 尝试备用方法
        if ! wget -q "$DOWNLOAD_URL" -O quick_start.sh; then
            exit 1
        fi
    fi
    
    # 检查脚本
    if [[ ! -f quick_start.sh ]]; then
        log "${RED}错误: 安装脚本不存在${NC}"
        exit 1
    fi
    
    chmod +x quick_start.sh
    log "${GREEN}官方脚本下载成功${NC}"
}

# 执行安装
execute_installation() {
    log "${CYAN}开始执行1Panel安装...${NC}"
    
    # 执行官方安装脚本
    if [[ "$USE_CN_MIRROR" == true ]]; then
        # 中国版本自动处理
        bash quick_start.sh
    else
        # 国际版本
        bash quick_start.sh
    fi
    
    # 检查安装结果
    if [[ $? -ne 0 ]]; then
        log "${RED}错误: 1Panel安装失败${NC}"
        exit 1
    fi
    
    log "${GREEN}1Panel安装完成${NC}"
}

# 安装后配置
post_install_config() {
    log "${CYAN}执行安装后配置...${NC}"
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if systemctl is-active --quiet 1panel; then
        log "${GREEN}1Panel服务运行正常${NC}"
    else
        log "${YELLOW}1Panel服务未运行，尝试启动...${NC}"
        systemctl start 1panel
    fi
}

# 安装常用应用
install_common_apps() {
    if [[ "$INSTALL_APPS" != true ]]; then
        return
    fi
    
    log "${CYAN}安装常用应用...${NC}"
    
    # 等待面板完全启动
    sleep 10
    
    # 使用1panel命令安装应用
    if command -v 1panel &> /dev/null; then
        log "${YELLOW}安装Nginx...${NC}"
        1panel app install nginx --yes 2>/dev/null || true
        
        log "${YELLOW}安装MySQL...${NC}"
        1panel app install mysql --yes 2>/dev/null || true
        
        log "${YELLOW}安装Redis...${NC}"
        1panel app install redis --yes 2>/dev/null || true
    else
        log "${YELLOW}1panel命令不可用，跳过应用安装${NC}"
    fi
}

# 获取安装信息
get_install_info() {
    log "${CYAN}获取安装信息...${NC}"
    
    # 尝试从1panel命令获取信息
    if command -v 1panel &> /dev/null; then
        PANEL_INFO=$(1panel info 2>/dev/null || echo "")
    fi
    
    # 获取服务器IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
}

# 保存配置信息
save_config_info() {
    log "${CYAN}保存配置信息...${NC}"
    
    # 获取安装信息
    get_install_info
    
    # 保存到文件
    cat > /root/1panel_info.txt << EOF
1Panel Installation Information
===============================

Panel Access: Please check the installation output above
Server IP: ${SERVER_IP}

Installation Date: $(date)
Installation Path: ${INSTALL_PATH}
Log File: ${LOG_FILE}

Common Commands:
- 1panel info       # Show panel information
- 1panel start      # Start panel service
- 1panel stop       # Stop panel service
- 1panel restart    # Restart panel service
- 1panel update     # Update panel
- 1panel uninstall  # Uninstall panel

Service Management:
- systemctl status 1panel   # Check service status
- systemctl start 1panel    # Start service
- systemctl stop 1panel     # Stop service
- systemctl restart 1panel  # Restart service

Default Paths:
- Installation: /opt/1panel
- Data: /opt/1panel/data
- Logs: /opt/1panel/log

Official Documentation:
- GitHub: https://github.com/1Panel-dev/1Panel
- Docs: https://1panel.cn/docs/
EOF
    
    chmod 600 /root/1panel_info.txt
}

# 显示安装信息
show_install_info() {
    echo
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}1Panel Installation Complete!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo
    echo -e "${YELLOW}Please check the installation output above for access information${NC}"
    echo
    echo -e "${CYAN}Configuration saved to: /root/1panel_info.txt${NC}"
    echo
    echo -e "${CYAN}Common Commands:${NC}"
    echo "- 1panel info       # Show panel information"
    echo "- 1panel restart    # Restart panel service"
    echo "- 1panel update     # Update panel"
    echo
    echo -e "${YELLOW}Security Tips:${NC}"
    echo "1. Save the access URL and credentials securely"
    echo "2. Do not share the security entrance with others"
    echo "3. Use strong passwords for all accounts"
    echo "4. Enable two-factor authentication if available"
    echo "5. Keep the panel updated regularly"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Access the panel using the URL provided above"
    echo "2. Complete the initial setup wizard"
    echo "3. Install required applications from the app store"
    echo "4. Configure backups and monitoring"
}

# 清理临时文件
cleanup() {
    log "${CYAN}清理临时文件...${NC}"
    cd /
    rm -rf "$TEMP_DIR"
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port)
                PANEL_PORT="$2"
                shift 2
                ;;
            --user)
                PANEL_USER="$2"
                shift 2
                ;;
            --password)
                PANEL_PASSWORD="$2"
                shift 2
                ;;
            --entrance)
                PANEL_ENTRANCE="$2"
                shift 2
                ;;
            --install-path)
                INSTALL_PATH="$2"
                shift 2
                ;;
            --cn-mirror)
                USE_CN_MIRROR=true
                shift
                ;;
            --install-apps)
                INSTALL_APPS=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    show_title
    
    # 检查系统要求
    check_requirements
    
    # 准备环境
    prepare_environment
    
    # 下载官方脚本
    download_official_script
    
    # 执行安装
    execute_installation
    
    # 安装后配置
    post_install_config
    
    # 安装应用
    install_common_apps
    
    # 保存配置
    save_config_info
    
    # 清理
    cleanup
    
    # 显示安装信息
    show_install_info
}

# 设置陷阱以确保清理
trap cleanup EXIT

# 执行主函数
main "$@"
