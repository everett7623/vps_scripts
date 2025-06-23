#!/bin/bash
#==============================================================================
# 脚本名称: amh.sh
# 脚本描述: AMH面板自动安装脚本 - 一键安装AMH服务器管理面板
# 脚本路径: vps_scripts/scripts/service_install/amh.sh
# 作者: Jensfrank
# 使用方法: bash amh_install.sh [选项]
# 选项: --version [版本号] (默认安装最新版)
#       --domain [域名] (可选，用于SSL配置)
#       --port [端口] (默认8888)
#       --uninstall (卸载AMH面板)
# 更新日期: 2025-01-23
#==============================================================================

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_VERSION="latest"
DEFAULT_PORT="8888"
INSTALL_PATH="/home/amh"
DOMAIN=""
ACTION="install"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 帮助信息
show_help() {
    echo "=================================================="
    echo "AMH面板安装脚本"
    echo "=================================================="
    echo "使用方法: bash amh.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --version [版本号]  指定安装版本 (默认: latest)"
    echo "  --domain [域名]     设置访问域名 (可选)"
    echo "  --port [端口]       设置面板端口 (默认: 8888)"
    echo "  --uninstall        卸载AMH面板"
    echo "  --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  bash amh.sh                     # 安装最新版"
    echo "  bash amh.sh --version 7.0       # 安装指定版本"
    echo "  bash amh.sh --domain example.com # 设置域名"
    echo "  bash amh.sh --uninstall         # 卸载面板"
    echo "=================================================="
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                DEFAULT_VERSION="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --port)
                DEFAULT_PORT="$2"
                shift 2
                ;;
            --uninstall)
                ACTION="uninstall"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查系统要求
check_system() {
    log_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        exit 1
    fi
    
    # 检查系统版本
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测系统版本"
        exit 1
    fi
    
    # 检查支持的系统
    case "$OS" in
        "CentOS Linux"|"CentOS Stream"|"Red Hat Enterprise Linux"|"Rocky Linux"|"AlmaLinux")
            if [[ ${VER%%.*} -lt 7 ]]; then
                log_error "系统版本过低，需要CentOS/RHEL 7及以上版本"
                exit 1
            fi
            PKG_MANAGER="yum"
            ;;
        "Ubuntu"|"Debian")
            PKG_MANAGER="apt"
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_info "系统检查通过: $OS $VER"
    
    # 检查网络连接
    log_info "检查网络连接..."
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    # 检查端口占用
    if ss -tlnp | grep -q ":$DEFAULT_PORT "; then
        log_warning "端口 $DEFAULT_PORT 已被占用"
        read -p "是否继续安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 安装依赖
install_dependencies() {
    log_info "安装系统依赖..."
    
    if [[ "$PKG_MANAGER" == "yum" ]]; then
        yum update -y
        yum install -y wget curl gcc gcc-c++ make perl unzip \
            libtool autoconf automake zlib-devel openssl-devel \
            pcre-devel libxml2-devel libcurl-devel libjpeg-devel \
            libpng-devel freetype-devel
    else
        apt update -y
        apt install -y wget curl gcc g++ make perl unzip \
            libtool autoconf automake zlib1g-dev libssl-dev \
            libpcre3-dev libxml2-dev libcurl4-openssl-dev \
            libjpeg-dev libpng-dev libfreetype6-dev
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "依赖安装失败"
        exit 1
    fi
    
    log_info "依赖安装完成"
}

# 下载AMH安装脚本
download_amh() {
    log_info "下载AMH安装程序..."
    
    # 创建临时目录
    TEMP_DIR="/tmp/amh_install_$$"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    # 下载安装脚本
    if [[ "$DEFAULT_VERSION" == "latest" ]]; then
        wget -O amh.sh http://dl.amh.sh/amh.sh
    else
        wget -O amh.sh http://dl.amh.sh/amh-${DEFAULT_VERSION}.sh
    fi
    
    if [[ ! -f amh.sh ]]; then
        log_error "AMH安装脚本下载失败"
        exit 1
    fi
    
    chmod +x amh.sh
    log_info "AMH安装脚本下载完成"
}

# 安装AMH
install_amh() {
    log_info "开始安装AMH面板..."
    
    # 创建安装目录
    mkdir -p $INSTALL_PATH
    
    # 执行安装
    cd $TEMP_DIR
    if [[ "$DEFAULT_VERSION" == "latest" ]]; then
        ./amh.sh
    else
        ./amh.sh $DEFAULT_VERSION
    fi
    
    if [[ $? -ne 0 ]]; then
        log_error "AMH安装失败"
        exit 1
    fi
    
    # 配置端口
    if [[ "$DEFAULT_PORT" != "8888" ]]; then
        log_info "配置面板端口为: $DEFAULT_PORT"
        sed -i "s/8888/$DEFAULT_PORT/g" /home/amh/server/nginx/conf/nginx.conf
        /home/amh/server/nginx/sbin/nginx -s reload
    fi
    
    # 配置域名
    if [[ -n "$DOMAIN" ]]; then
        log_info "配置访问域名: $DOMAIN"
        # 这里可以添加域名配置逻辑
    fi
    
    log_info "AMH面板安装完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 检查并配置firewalld
    if command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$DEFAULT_PORT/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=21/tcp
        firewall-cmd --permanent --add-port=3306/tcp
        firewall-cmd --reload
        log_info "firewalld防火墙规则已配置"
    fi
    
    # 检查并配置ufw
    if command -v ufw &> /dev/null; then
        ufw allow $DEFAULT_PORT/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        ufw allow 21/tcp
        ufw allow 3306/tcp
        log_info "ufw防火墙规则已配置"
    fi
}

# 显示安装信息
show_install_info() {
    echo ""
    echo "=================================================="
    echo -e "${GREEN}AMH面板安装成功！${NC}"
    echo "=================================================="
    echo "访问地址: http://$(curl -s ip.sb):$DEFAULT_PORT"
    if [[ -n "$DOMAIN" ]]; then
        echo "域名访问: http://$DOMAIN:$DEFAULT_PORT"
    fi
    echo "默认用户名: admin"
    echo "默认密码: admin (请立即修改)"
    echo ""
    echo "常用命令:"
    echo "  amh start    - 启动AMH"
    echo "  amh stop     - 停止AMH"
    echo "  amh restart  - 重启AMH"
    echo "  amh info     - 查看信息"
    echo ""
    echo "请及时修改默认密码并配置安全设置！"
    echo "=================================================="
}

# 卸载AMH
uninstall_amh() {
    log_warning "准备卸载AMH面板..."
    read -p "确定要卸载AMH面板吗？所有数据将被删除！(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "取消卸载"
        exit 0
    fi
    
    log_info "开始卸载AMH面板..."
    
    # 停止服务
    if [[ -f /home/amh/amh ]]; then
        /home/amh/amh stop
    fi
    
    # 删除文件
    rm -rf /home/amh
    rm -rf /home/wwwroot
    rm -rf /home/mysql_data
    rm -f /usr/local/bin/amh
    rm -f /etc/init.d/amh-*
    
    # 删除用户
    userdel -r www 2>/dev/null
    userdel -r mysql 2>/dev/null
    
    log_info "AMH面板已完全卸载"
}

# 清理函数
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# 主函数
main() {
    # 设置错误处理
    set -e
    trap cleanup EXIT
    
    # 解析参数
    parse_arguments "$@"
    
    # 根据操作执行
    if [[ "$ACTION" == "uninstall" ]]; then
        uninstall_amh
    else
        # 执行安装流程
        check_system
        install_dependencies
        download_amh
        install_amh
        configure_firewall
        show_install_info
    fi
}

# 执行主函数
main "$@"
