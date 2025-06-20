#!/bin/bash
#==============================================================================
# 脚本名称: nodejs.sh
# 脚本描述: Node.js运行环境安装脚本 - 支持多版本管理和包管理器安装
# 脚本路径: vps_scripts/scripts/service_install/nodejs.sh
# 作者: Jensfrank
# 使用方法: bash nodejs.sh [选项]
# 选项: --version=X.X --nvm --yarn --pnpm --pm2 --all
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

# 全局变量
NODE_VERSION="20"  # 默认安装 Node.js 20 LTS
INSTALL_METHOD="nodesource"  # 默认使用 NodeSource 安装
INSTALL_NVM=false
INSTALL_YARN=false
INSTALL_PNPM=false
INSTALL_PM2=false
NVM_DIR="$HOME/.nvm"

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
            ARCH="x64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7l"
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
            apt-get install -y curl wget git build-essential
            ;;
        centos|rhel|fedora|almalinux|rocky)
            yum makecache -q
            yum install -y curl wget git gcc-c++ make
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 检查Node.js是否已安装
check_nodejs_installed() {
    if command -v node >/dev/null 2>&1; then
        CURRENT_VERSION=$(node -v)
        log_warning "Node.js 已安装，版本: $CURRENT_VERSION"
        
        # 如果是通过nvm安装的，提示用户
        if [[ -d "$NVM_DIR" ]] && [[ -s "$NVM_DIR/nvm.sh" ]]; then
            log_info "检测到 NVM 管理的 Node.js"
        fi
        
        read -p "是否要继续安装？(y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "退出安装"
            exit 0
        fi
    fi
}

# 安装nvm (Node Version Manager)
install_nvm() {
    log_info "安装 NVM (Node Version Manager)..."
    
    # 获取最新版本的nvm
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    
    # 下载并安装nvm
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    
    # 添加nvm到环境变量
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # 添加到profile文件
    for profile in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.profile; do
        if [[ -f "$profile" ]]; then
            if ! grep -q "NVM_DIR" "$profile"; then
                cat >> "$profile" <<'EOF'

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
            fi
        fi
    done
    
    log_success "NVM 安装完成"
}

# 通过nvm安装Node.js
install_nodejs_with_nvm() {
    log_info "通过 NVM 安装 Node.js ${NODE_VERSION}..."
    
    # 确保nvm可用
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # 安装指定版本
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    
    log_success "Node.js ${NODE_VERSION} 通过 NVM 安装完成"
}

# 通过NodeSource安装Node.js
install_nodejs_nodesource() {
    log_info "通过 NodeSource 仓库安装 Node.js ${NODE_VERSION}..."
    
    case $OS in
        ubuntu|debian)
            # 添加NodeSource仓库
            curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
            apt-get install -y nodejs
            ;;
            
        centos|rhel|fedora|almalinux|rocky)
            # 添加NodeSource仓库
            curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash -
            yum install -y nodejs
            ;;
    esac
    
    log_success "Node.js ${NODE_VERSION} 通过 NodeSource 安装完成"
}

# 通过官方二进制文件安装Node.js
install_nodejs_binary() {
    log_info "通过官方二进制文件安装 Node.js ${NODE_VERSION}..."
    
    # 获取完整版本号
    FULL_VERSION=$(curl -s https://nodejs.org/dist/latest-v${NODE_VERSION}.x/ | grep -oE 'node-v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [[ -z "$FULL_VERSION" ]]; then
        log_error "无法获取 Node.js ${NODE_VERSION} 的版本信息"
        exit 1
    fi
    
    # 下载二进制文件
    DOWNLOAD_URL="https://nodejs.org/dist/latest-v${NODE_VERSION}.x/${FULL_VERSION}-linux-${ARCH}.tar.xz"
    log_info "下载 Node.js: $DOWNLOAD_URL"
    
    cd /tmp
    wget -q "$DOWNLOAD_URL" -O nodejs.tar.xz
    
    # 解压并安装
    tar -xf nodejs.tar.xz
    cp -r ${FULL_VERSION}-linux-${ARCH}/* /usr/local/
    
    # 创建软链接
    ln -sf /usr/local/bin/node /usr/bin/node
    ln -sf /usr/local/bin/npm /usr/bin/npm
    ln -sf /usr/local/bin/npx /usr/bin/npx
    
    # 清理
    rm -rf nodejs.tar.xz ${FULL_VERSION}-linux-${ARCH}
    
    log_success "Node.js ${NODE_VERSION} 通过二进制文件安装完成"
}

# 安装Yarn包管理器
install_yarn() {
    log_info "安装 Yarn 包管理器..."
    
    if command -v yarn >/dev/null 2>&1; then
        log_warning "Yarn 已安装，版本: $(yarn --version)"
        return
    fi
    
    # 通过npm全局安装yarn
    npm install -g yarn
    
    log_success "Yarn 安装完成，版本: $(yarn --version)"
}

# 安装pnpm包管理器
install_pnpm() {
    log_info "安装 pnpm 包管理器..."
    
    if command -v pnpm >/dev/null 2>&1; then
        log_warning "pnpm 已安装，版本: $(pnpm --version)"
        return
    fi
    
    # 通过npm全局安装pnpm
    npm install -g pnpm
    
    # 设置pnpm存储路径
    pnpm config set store-dir ~/.pnpm-store
    
    log_success "pnpm 安装完成，版本: $(pnpm --version)"
}

# 安装PM2进程管理器
install_pm2() {
    log_info "安装 PM2 进程管理器..."
    
    if command -v pm2 >/dev/null 2>&1; then
        log_warning "PM2 已安装，版本: $(pm2 --version)"
        return
    fi
    
    # 通过npm全局安装pm2
    npm install -g pm2
    
    # 设置PM2开机自启
    pm2 startup systemd -u root --hp /root
    
    # 安装PM2日志轮转模块
    pm2 install pm2-logrotate
    
    # 配置日志轮转
    pm2 set pm2-logrotate:max_size 10M
    pm2 set pm2-logrotate:retain 7
    pm2 set pm2-logrotate:compress true
    
    log_success "PM2 安装完成，版本: $(pm2 --version)"
}

# 配置npm镜像源
configure_npm_registry() {
    log_info "配置 npm 镜像源..."
    
    # 创建npmrc配置文件
    cat > ~/.npmrc <<EOF
# npm配置文件
registry=https://registry.npmjs.org/

# 可选：使用淘宝镜像（中国大陆用户）
# registry=https://registry.npmmirror.com/

# 设置缓存目录
cache=~/.npm-cache

# 设置全局安装目录
prefix=/usr/local

# 其他优化配置
fetch-retries=3
fetch-retry-mintimeout=5000
fetch-retry-maxtimeout=15000
EOF
    
    # 配置全局npm
    npm config set registry https://registry.npmjs.org/
    npm config set cache ~/.npm-cache
    npm config set prefix /usr/local
    
    log_success "npm 配置完成"
}

# 创建示例项目
create_demo_project() {
    log_info "创建 Node.js 示例项目..."
    
    # 创建项目目录
    DEMO_DIR="/opt/nodejs-demo"
    mkdir -p "$DEMO_DIR"
    cd "$DEMO_DIR"
    
    # 初始化package.json
    cat > package.json <<'EOF'
{
  "name": "nodejs-demo",
  "version": "1.0.0",
  "description": "Node.js Demo Application",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["demo", "nodejs"],
  "author": "LDNMP",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    # 创建Express应用
    cat > app.js <<'EOF'
const express = require('express');
const os = require('os');
const app = express();
const port = process.env.PORT || 3000;

// 中间件
app.use(express.json());
app.use(express.static('public'));

// 路由
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>Node.js Demo</title>
            <style>
                body { 
                    font-family: Arial, sans-serif; 
                    max-width: 800px; 
                    margin: 0 auto; 
                    padding: 20px;
                    background-color: #f5f5f5;
                }
                .container {
                    background: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h1 { color: #339933; }
                .info {
                    background: #e8f5e9;
                    padding: 15px;
                    border-radius: 5px;
                    margin: 10px 0;
                }
                code {
                    background: #f5f5f5;
                    padding: 2px 5px;
                    border-radius: 3px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🎉 Node.js 安装成功!</h1>
                <div class="info">
                    <h2>系统信息</h2>
                    <p><strong>Node.js 版本:</strong> ${process.version}</p>
                    <p><strong>操作系统:</strong> ${os.type()} ${os.release()}</p>
                    <p><strong>平台:</strong> ${os.platform()}</p>
                    <p><strong>架构:</strong> ${os.arch()}</p>
                    <p><strong>内存:</strong> ${Math.round(os.totalmem() / 1024 / 1024)} MB</p>
                </div>
                <div class="info">
                    <h2>API 端点</h2>
                    <ul>
                        <li><a href="/api/info">/api/info</a> - 获取服务器信息</li>
                        <li><a href="/api/health">/api/health</a> - 健康检查</li>
                    </ul>
                </div>
                <div class="info">
                    <h2>管理命令</h2>
                    <p><code>cd ${process.cwd()}</code></p>
                    <p><code>npm start</code> - 启动应用</p>
                    <p><code>npm run dev</code> - 开发模式（需要安装依赖）</p>
                    <p><code>pm2 start app.js --name nodejs-demo</code> - 使用PM2管理</p>
                </div>
            </div>
        </body>
        </html>
    `);
});

// API路由
app.get('/api/info', (req, res) => {
    res.json({
        node: process.version,
        npm: process.env.npm_version || 'N/A',
        platform: os.platform(),
        arch: os.arch(),
        uptime: process.uptime(),
        memory: {
            total: os.totalmem(),
            free: os.freemem(),
            used: os.totalmem() - os.freemem()
        },
        cpu: os.cpus()
    });
});

app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// 启动服务器
app.listen(port, () => {
    console.log(`🚀 Node.js Demo 应用运行在 http://localhost:${port}`);
    console.log(`📁 工作目录: ${process.cwd()}`);
    console.log(`🔧 Node.js 版本: ${process.version}`);
});
EOF

    # 创建public目录
    mkdir -p public
    
    # 安装依赖
    log_info "安装项目依赖..."
    npm install --production
    
    # 创建PM2配置文件
    cat > ecosystem.config.js <<'EOF'
module.exports = {
  apps: [{
    name: 'nodejs-demo',
    script: './app.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
EOF
    
    # 如果安装了PM2，启动示例应用
    if command -v pm2 >/dev/null 2>&1; then
        pm2 start ecosystem.config.js
        pm2 save
    fi
    
    log_success "示例项目创建完成，路径: $DEMO_DIR"
}

# 创建systemd服务文件
create_systemd_service() {
    log_info "创建 systemd 服务文件..."
    
    cat > /etc/systemd/system/nodejs-demo.service <<EOF
[Unit]
Description=Node.js Demo Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nodejs-demo
ExecStart=/usr/bin/node /opt/nodejs-demo/app.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=nodejs-demo
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    log_success "systemd 服务文件创建完成"
}

# 显示安装信息
show_installation_info() {
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Node.js 环境安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${CYAN}已安装组件:${NC}"
    echo "✓ Node.js $(node -v)"
    echo "✓ npm $(npm -v)"
    
    if $INSTALL_NVM && [[ -d "$NVM_DIR" ]]; then
        echo "✓ NVM $(cat $NVM_DIR/package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[",]//g' | tr -d ' ')"
    fi
    
    command -v yarn >/dev/null 2>&1 && echo "✓ Yarn $(yarn --version)"
    command -v pnpm >/dev/null 2>&1 && echo "✓ pnpm $(pnpm --version)"
    command -v pm2 >/dev/null 2>&1 && echo "✓ PM2 $(pm2 --version)"
    
    echo
    echo -e "${CYAN}配置文件:${NC}"
    echo "npm配置: ~/.npmrc"
    if $INSTALL_NVM; then
        echo "NVM目录: $NVM_DIR"
    fi
    
    echo
    echo -e "${CYAN}示例项目:${NC}"
    echo "项目路径: /opt/nodejs-demo"
    echo "访问地址: http://${server_ip}:3000"
    
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "node -v              # 查看Node.js版本"
    echo "npm -v               # 查看npm版本"
    
    if $INSTALL_NVM; then
        echo "nvm list             # 列出已安装的Node.js版本"
        echo "nvm install 18       # 安装Node.js 18"
        echo "nvm use 18           # 切换到Node.js 18"
    fi
    
    if command -v pm2 >/dev/null 2>&1; then
        echo "pm2 list             # 查看PM2进程列表"
        echo "pm2 start app.js     # 使用PM2启动应用"
        echo "pm2 logs             # 查看PM2日志"
        echo "pm2 monit            # PM2监控面板"
    fi
    
    echo
    echo -e "${CYAN}包管理器使用:${NC}"
    echo "npm install <包名>    # 安装包"
    command -v yarn >/dev/null 2>&1 && echo "yarn add <包名>       # 使用Yarn安装包"
    command -v pnpm >/dev/null 2>&1 && echo "pnpm add <包名>       # 使用pnpm安装包"
    
    echo
    echo -e "${GREEN}========================================${NC}"
    
    # 如果安装了nvm，提醒用户重新加载shell
    if $INSTALL_NVM; then
        echo
        echo -e "${YELLOW}注意: 如果使用NVM，请运行以下命令或重新登录以加载NVM:${NC}"
        echo "source ~/.bashrc"
    fi
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version=*)
                NODE_VERSION="${1#*=}"
                shift
                ;;
            --nvm)
                INSTALL_NVM=true
                INSTALL_METHOD="nvm"
                shift
                ;;
            --yarn)
                INSTALL_YARN=true
                shift
                ;;
            --pnpm)
                INSTALL_PNPM=true
                shift
                ;;
            --pm2)
                INSTALL_PM2=true
                shift
                ;;
            --all)
                INSTALL_NVM=true
                INSTALL_YARN=true
                INSTALL_PNPM=true
                INSTALL_PM2=true
                INSTALL_METHOD="nvm"
                shift
                ;;
            -h|--help)
                echo "使用方法: $0 [选项]"
                echo "选项:"
                echo "  --version=X.X  指定Node.js版本 (默认: 20)"
                echo "  --nvm          使用NVM安装（版本管理器）"
                echo "  --yarn         安装Yarn包管理器"
                echo "  --pnpm         安装pnpm包管理器"
                echo "  --pm2          安装PM2进程管理器"
                echo "  --all          安装所有组件"
                echo "  -h, --help     显示帮助信息"
                echo
                echo "示例:"
                echo "  $0                     # 默认安装Node.js 20"
                echo "  $0 --version=18        # 安装Node.js 18"
                echo "  $0 --nvm --all         # 使用NVM安装所有组件"
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
    echo -e "${PURPLE}Node.js 运行环境安装脚本${NC}"
    echo -e "${PURPLE}作者: Jensfrank${NC}"
    echo -e "${PURPLE}版本: 2025-06-20${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    
    # 执行安装步骤
    check_root
    check_system
    check_arch
    update_package_manager
    check_nodejs_installed
    
    # 安装Node.js
    if [[ "$INSTALL_METHOD" == "nvm" ]]; then
        install_nvm
        install_nodejs_with_nvm
    else
        install_nodejs_nodesource
    fi
    
    # 配置npm
    configure_npm_registry
    
    # 安装额外的包管理器和工具
    $INSTALL_YARN && install_yarn
    $INSTALL_PNPM && install_pnpm
    $INSTALL_PM2 && install_pm2
    
    # 创建示例项目和服务
    create_demo_project
    create_systemd_service
    
    # 显示安装信息
    show_installation_info
}

# 错误处理
trap 'log_error "脚本执行出错，行号: $LINENO"' ERR

# 执行主函数
main "$@"