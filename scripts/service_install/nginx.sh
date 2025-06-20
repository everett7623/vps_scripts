#!/bin/bash
#==============================================================================
# 脚本名称: nginx.sh
# 脚本描述: Nginx Web服务器安装与配置脚本 - 支持多种安装方式和SSL证书配置
# 脚本路径: vps_scripts/scripts/service_install/nginx.sh
# 作者: Jensfrank
# 使用方法: bash nginx.sh [选项]
# 选项: --stable (稳定版) --mainline (主线版) --source (源码编译)
# 更新日期: 2025-06-20
#==============================================================================

# 设置错误处理
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root用户运行"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    
    log_info "检测到系统: $OS $VER"
}

# 检查架构
check_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            ARCH="x86_64"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    log_info "系统架构: $ARCH"
}

# 更新系统包管理器
update_package_manager() {
    log_info "更新系统包管理器..."
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y curl wget software-properties-common gnupg2
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum makecache -q
            yum install -y curl wget yum-utils
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查Nginx是否已安装
check_nginx_installed() {
    if command -v nginx >/dev/null 2>&1; then
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3 | cut -d'/' -f2)
        log_warning "Nginx已安装，版本: $NGINX_VERSION"
        read -p "是否要重新安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "退出安装"
            exit 0
        fi
        # 停止并卸载现有Nginx
        systemctl stop nginx 2>/dev/null || true
        case $OS in
            ubuntu|debian)
                apt-get remove -y nginx nginx-common nginx-full
                ;;
            centos|rhel|fedora|almalinux|rocky)
                yum remove -y nginx
                ;;
        esac
    fi
}

# 从官方仓库安装Nginx
install_nginx_repo() {
    local version_type=$1
    log_info "从官方仓库安装Nginx $version_type 版本..."
    
    case $OS in
        ubuntu|debian)
            # 添加Nginx官方仓库
            curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
            
            if [[ "$version_type" == "stable" ]]; then
                echo "deb https://nginx.org/packages/$OS/ $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
            else
                echo "deb https://nginx.org/packages/mainline/$OS/ $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list
            fi
            
            apt-get update -qq
            apt-get install -y nginx
            ;;
            
        centos|rhel|fedora|almalinux|rocky)
            # 添加Nginx官方仓库
            cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-$version_type]
name=nginx $version_type repo
baseurl=https://nginx.org/packages$([ "$version_type" == "mainline" ] && echo "/mainline" || echo "")/$([[ "$OS" == "centos" || "$OS" == "rhel" ]] && echo "centos" || echo "$OS")/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            
            yum makecache -q
            yum install -y nginx
            ;;
    esac
}

# 从源码编译安装Nginx
install_nginx_source() {
    log_info "从源码编译安装Nginx..."
    
    # 安装编译依赖
    case $OS in
        ubuntu|debian)
            apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g zlib1g-dev \
                libssl-dev libgd-dev libxml2 libxml2-dev uuid-dev
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum groupinstall -y "Development Tools"
            yum install -y pcre pcre-devel zlib zlib-devel openssl openssl-devel \
                gd gd-devel libxml2 libxml2-devel libuuid-devel
            ;;
    esac
    
    # 获取最新版本号
    NGINX_VERSION=$(curl -s https://nginx.org/en/download.html | grep -oP 'nginx-\K[0-9.]+(?=\.tar\.gz)' | head -1)
    log_info "下载Nginx $NGINX_VERSION 源码..."
    
    cd /tmp
    wget -q https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
    tar -xzf nginx-${NGINX_VERSION}.tar.gz
    cd nginx-${NGINX_VERSION}
    
    # 配置编译选项
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-compat \
        --with-file-aio \
        --with-threads \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_mp4_module \
        --with-http_random_index_module \
        --with-http_realip_module \
        --with-http_secure_link_module \
        --with-http_slice_module \
        --with-http_ssl_module \
        --with-http_stub_status_module \
        --with-http_sub_module \
        --with-http_v2_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module
    
    # 编译安装
    make -j$(nproc)
    make install
    
    # 创建nginx用户和目录
    useradd -r -s /sbin/nologin nginx 2>/dev/null || true
    mkdir -p /var/cache/nginx/{client_temp,proxy_temp,fastcgi_temp,uwsgi_temp,scgi_temp}
    chown -R nginx:nginx /var/cache/nginx
    
    # 清理
    cd /
    rm -rf /tmp/nginx-${NGINX_VERSION}*
}

# 创建systemd服务文件
create_systemd_service() {
    if [[ ! -f /lib/systemd/system/nginx.service ]]; then
        log_info "创建systemd服务文件..."
        cat > /lib/systemd/system/nginx.service <<'EOF'
[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
    fi
}

# 优化Nginx配置
optimize_nginx_config() {
    log_info "优化Nginx配置..."
    
    # 备份原配置
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%Y%m%d%H%M%S)
    
    # 获取CPU核心数
    CPU_CORES=$(nproc)
    
    # 创建优化后的配置
    cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes $CPU_CORES;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

# 优化文件描述符
worker_rlimit_nofile 65535;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json 
               application/javascript application/xml+rss application/rss+xml 
               application/atom+xml image/svg+xml;

    # 安全相关
    server_tokens off;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # SSL优化
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 包含其他配置文件
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

    # 创建必要的目录
    mkdir -p /etc/nginx/{conf.d,sites-available,sites-enabled}
    
    # 创建默认站点配置
    cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    # 健康检查端点
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
    }
}
EOF

    # 创建软链接
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>/dev/null || true
    
    # 创建默认网站目录
    mkdir -p /var/www/html
    cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to nginx!</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>
<body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and working.</p>
    <p><em>Thank you for using nginx.</em></p>
</body>
</html>
EOF
    
    chown -R nginx:nginx /var/www/html
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙规则..."
    
    # 检查并配置防火墙
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 80/tcp comment "Nginx HTTP" >/dev/null 2>&1
        ufw allow 443/tcp comment "Nginx HTTPS" >/dev/null 2>&1
        log_success "UFW防火墙规则已添加"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-service=http >/dev/null 2>&1
        firewall-cmd --permanent --add-service=https >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        log_success "Firewalld防火墙规则已添加"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        # 保存iptables规则
        case $OS in
            ubuntu|debian)
                if command -v netfilter-persistent >/dev/null 2>&1; then
                    netfilter-persistent save
                fi
                ;;
            centos|rhel|fedora|almalinux|rocky)
                service iptables save 2>/dev/null || true
                ;;
        esac
        log_success "iptables防火墙规则已添加"
    else
        log_warning "未检测到防火墙，请手动配置"
    fi
}

# 启动Nginx服务
start_nginx_service() {
    log_info "启动Nginx服务..."
    
    # 测试配置
    nginx -t
    
    # 启动服务
    systemctl enable nginx
    systemctl start nginx
    
    # 检查服务状态
    if systemctl is-active --quiet nginx; then
        log_success "Nginx服务已成功启动"
    else
        log_error "Nginx服务启动失败"
        systemctl status nginx
        exit 1
    fi
}

# 显示安装信息
show_installation_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Nginx安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}版本信息:${NC}"
    nginx -v
    echo
    echo -e "${CYAN}配置文件:${NC}"
    echo "主配置: /etc/nginx/nginx.conf"
    echo "站点配置: /etc/nginx/sites-available/"
    echo "配置片段: /etc/nginx/conf.d/"
    echo
    echo -e "${CYAN}日志文件:${NC}"
    echo "访问日志: /var/log/nginx/access.log"
    echo "错误日志: /var/log/nginx/error.log"
    echo
    echo -e "${CYAN}网站目录:${NC}"
    echo "默认目录: /var/www/html"
    echo
    echo -e "${CYAN}服务管理:${NC}"
    echo "启动: systemctl start nginx"
    echo "停止: systemctl stop nginx"
    echo "重启: systemctl restart nginx"
    echo "重载: systemctl reload nginx"
    echo "状态: systemctl status nginx"
    echo
    echo -e "${CYAN}测试访问:${NC}"
    echo "http://$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")"
    echo
    echo -e "${GREEN}========================================${NC}"
}

# 主函数
main() {
    local install_type="stable"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --stable)
                install_type="stable"
                shift
                ;;
            --mainline)
                install_type="mainline"
                shift
                ;;
            --source)
                install_type="source"
                shift
                ;;
            -h|--help)
                echo "使用方法: $0 [选项]"
                echo "选项:"
                echo "  --stable    安装稳定版 (默认)"
                echo "  --mainline  安装主线版"
                echo "  --source    从源码编译安装"
                echo "  -h, --help  显示帮助信息"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 显示脚本信息
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${PURPLE}Nginx Web服务器安装脚本${NC}"
    echo -e "${PURPLE}作者: Jensfrank${NC}"
    echo -e "${PURPLE}版本: 2025-06-20${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    
    # 执行安装步骤
    check_root
    check_system
    check_arch
    update_package_manager
    check_nginx_installed
    
    # 根据安装类型执行不同的安装方法
    case $install_type in
        stable|mainline)
            install_nginx_repo $install_type
            ;;
        source)
            install_nginx_source
            ;;
    esac
    
    create_systemd_service
    optimize_nginx_config
    configure_firewall
    start_nginx_service
    show_installation_info
}

# 错误处理
trap 'log_error "脚本执行出错，行号: $LINENO"' ERR

# 执行主函数
main "$@"
