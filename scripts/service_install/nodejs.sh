#!/bin/bash
#==============================================================================
# 脚本名称: install_nodejs.sh
# 脚本描述: Node.js和npm安装脚本 - 支持多种安装方式和版本管理
# 脚本路径: vps_scripts/scripts/service_install/install_nodejs.sh
# 作者: Jensfrank
# 使用方法: bash install_nodejs.sh [选项]
# 选项: 
#   --version VERSION    指定Node.js版本 (如: 18, 20, lts, latest)
#   --method METHOD      安装方式 (nodesource/nvm/binary, 默认: nodesource)
#   --cn                 使用国内镜像源
#   --with-yarn          同时安装Yarn
#   --with-pnpm          同时安装pnpm
#   --global-packages    安装常用全局包
#   --remove             卸载Node.js
#   --list               列出可用版本
# 更新日期: 2025-01-17
#==============================================================================

# 严格模式
set -euo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# 全局变量
readonly SCRIPT_NAME="Node.js安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/nodejs_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
NODE_VERSION="lts"
INSTALL_METHOD="nodesource"
USE_CN_MIRROR=false
INSTALL_YARN=false
INSTALL_PNPM=false
INSTALL_GLOBAL_PACKAGES=false
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""
DISTRO=""

# Node.js相关路径
NODE_PREFIX="/usr/local"
NVM_DIR="$HOME/.nvm"

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --version VERSION    指定Node.js版本
                        - 数字版本: 16, 18, 20, 21 等
                        - 标签: lts, latest, current
                        默认: lts
    
    --method METHOD      安装方式
                        - nodesource: 使用NodeSource仓库（推荐）
                        - nvm: 使用Node Version Manager
                        - binary: 下载官方二进制文件
                        默认: nodesource
    
    --cn                使用国内镜像源（推荐国内用户使用）
    --with-yarn         同时安装Yarn包管理器
    --with-pnpm         同时安装pnpm包管理器
    --global-packages   安装常用全局npm包
    --remove            卸载Node.js
    --list              列出可用版本
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                          # 安装LTS版本
    $(basename "$0") --version 20             # 安装Node.js 20.x
    $(basename "$0") --method nvm --cn        # 使用nvm安装，使用国内源
    $(basename "$0") --with-yarn --with-pnpm  # 同时安装Yarn和pnpm

EOF
}

# 日志记录
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# 错误处理
error_exit() {
    log ERROR "$1"
    log ERROR "安装日志已保存到: $LOG_FILE"
    exit 1
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        if [[ "$INSTALL_METHOD" == "nvm" ]]; then
            log INFO "nvm安装模式不需要root权限"
        else
            error_exit "此脚本需要root权限运行，请使用 sudo bash $0"
        fi
    fi
}

# 检测系统信息
detect_system() {
    log INFO "检测系统信息..."
    
    # 检测操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        DISTRO=$ID_LIKE
    else
        error_exit "无法检测操作系统信息"
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) ARCH="x64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armv7l" ;;
        *) error_exit "不支持的系统架构: $ARCH" ;;
    esac
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 设置镜像源
setup_mirrors() {
    if [[ $USE_CN_MIRROR == true ]]; then
        log INFO "配置国内镜像源..."
        
        # npm镜像
        export NPM_CONFIG_REGISTRY="https://registry.npmmirror.com"
        
        # Node.js下载镜像
        export NODE_MIRROR="https://npmmirror.com/mirrors/node/"
        
        # nvm镜像
        export NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node"
        export NVM_IOJS_ORG_MIRROR="https://npmmirror.com/mirrors/iojs"
        
        log SUCCESS "国内镜像源配置完成"
    fi
}

# 安装依赖
install_dependencies() {
    log INFO "安装必要的依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq curl wget gnupg ca-certificates
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y -q curl wget ca-certificates
            ;;
        fedora)
            dnf install -y -q curl wget ca-certificates
            ;;
    esac
    
    log SUCCESS "依赖安装完成"
}

# 获取Node.js版本号
get_node_version() {
    local version=$1
    
    case $version in
        lts|LTS)
            # 获取最新LTS版本
            if [[ $USE_CN_MIRROR == true ]]; then
                version=$(curl -s https://npmmirror.com/mirrors/node/latest-lts/ | grep -oP 'node-v\K[0-9]+' | head -1)
            else
                version=$(curl -s https://nodejs.org/dist/latest-lts/ | grep -oP 'node-v\K[0-9]+' | head -1)
            fi
            ;;
        latest|current)
            # 获取最新版本
            if [[ $USE_CN_MIRROR == true ]]; then
                version=$(curl -s https://npmmirror.com/mirrors/node/latest/ | grep -oP 'node-v\K[0-9]+' | head -1)
            else
                version=$(curl -s https://nodejs.org/dist/latest/ | grep -oP 'node-v\K[0-9]+' | head -1)
            fi
            ;;
        *)
            # 确保是数字版本
            version=$(echo "$version" | grep -oP '^\d+')
            ;;
    esac
    
    echo "$version"
}

# 通过NodeSource安装
install_via_nodesource() {
    log INFO "使用NodeSource仓库安装Node.js..."
    
    local version=$(get_node_version "$NODE_VERSION")
    log INFO "安装版本: Node.js $version.x"
    
    case $OS in
        ubuntu|debian)
            # 添加NodeSource仓库
            if [[ $USE_CN_MIRROR == true ]]; then
                curl -fsSL https://deb.nodesource.com/setup_${version}.x | sed 's|deb.nodesource.com|mirrors.tuna.tsinghua.edu.cn/nodesource/deb|g' | bash -
            else
                curl -fsSL https://deb.nodesource.com/setup_${version}.x | bash -
            fi
            
            # 安装Node.js
            apt-get install -y nodejs
            ;;
            
        centos|rhel|almalinux|rocky|fedora)
            # 添加NodeSource仓库
            if [[ $USE_CN_MIRROR == true ]]; then
                curl -fsSL https://rpm.nodesource.com/setup_${version}.x | sed 's|rpm.nodesource.com|mirrors.tuna.tsinghua.edu.cn/nodesource/rpm|g' | bash -
            else
                curl -fsSL https://rpm.nodesource.com/setup_${version}.x | bash -
            fi
            
            # 安装Node.js
            if [[ $OS == "fedora" ]]; then
                dnf install -y nodejs
            else
                yum install -y nodejs
            fi
            ;;
    esac
    
    log SUCCESS "Node.js安装完成"
}

# 通过nvm安装
install_via_nvm() {
    log INFO "使用nvm安装Node.js..."
    
    # 安装nvm
    if [[ ! -d "$NVM_DIR" ]]; then
        log INFO "安装nvm..."
        
        if [[ $USE_CN_MIRROR == true ]]; then
            export NVM_SOURCE="https://gitee.com/mirrors/nvm.git"
            curl -o- https://gitee.com/mirrors/nvm/raw/master/install.sh | bash
        else
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        fi
        
        # 加载nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    else
        log INFO "nvm已安装，加载nvm..."
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    
    # 设置镜像
    if [[ $USE_CN_MIRROR == true ]]; then
        nvm node_mirror https://npmmirror.com/mirrors/node/
        nvm npm_mirror https://npmmirror.com/mirrors/npm/
    fi
    
    # 安装Node.js
    local version=$NODE_VERSION
    if [[ "$version" == "lts" ]]; then
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
    else
        nvm install "$version"
        nvm use "$version"
        nvm alias default "$version"
    fi
    
    log SUCCESS "Node.js通过nvm安装完成"
    
    # 添加到shell配置
    local shell_rc=""
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]] && ! grep -q "NVM_DIR" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# NVM配置
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
        log INFO "nvm配置已添加到 $shell_rc"
    fi
}

# 通过二进制文件安装
install_via_binary() {
    log INFO "使用官方二进制文件安装Node.js..."
    
    local version=$(get_node_version "$NODE_VERSION")
    local full_version=$(curl -s ${NODE_MIRROR:-https://nodejs.org/dist/}latest-v${version}.x/ | grep -oP "node-v${version}\.\d+\.\d+" | head -1)
    
    if [[ -z "$full_version" ]]; then
        error_exit "无法获取Node.js版本信息"
    fi
    
    local download_url="${NODE_MIRROR:-https://nodejs.org/dist/}latest-v${version}.x/${full_version}-linux-${ARCH}.tar.xz"
    local temp_dir="/tmp/nodejs_install"
    
    log INFO "下载Node.js ${full_version}..."
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    wget -q --show-progress "$download_url" -O nodejs.tar.xz || error_exit "下载失败"
    
    log INFO "解压并安装..."
    tar -xf nodejs.tar.xz
    
    # 移动到/usr/local
    rm -rf "$NODE_PREFIX/lib/node_modules"
    rm -f "$NODE_PREFIX/bin/node" "$NODE_PREFIX/bin/npm" "$NODE_PREFIX/bin/npx"
    
    cp -r ${full_version}-linux-${ARCH}/* "$NODE_PREFIX/"
    
    # 清理
    cd /
    rm -rf "$temp_dir"
    
    log SUCCESS "Node.js二进制安装完成"
}

# 配置npm
configure_npm() {
    log INFO "配置npm..."
    
    # 设置npm镜像
    if [[ $USE_CN_MIRROR == true ]]; then
        npm config set registry https://registry.npmmirror.com
        log SUCCESS "npm镜像已设置为: https://registry.npmmirror.com"
    fi
    
    # 更新npm到最新版本
    log INFO "更新npm到最新版本..."
    npm install -g npm@latest
    
    # 配置全局模块路径
    npm config set prefix "$NODE_PREFIX"
    
    log SUCCESS "npm配置完成"
}

# 安装Yarn
install_yarn() {
    if [[ $INSTALL_YARN == true ]]; then
        log INFO "安装Yarn包管理器..."
        
        if [[ $USE_CN_MIRROR == true ]]; then
            npm install -g yarn --registry=https://registry.npmmirror.com
            yarn config set registry https://registry.npmmirror.com
        else
            npm install -g yarn
        fi
        
        log SUCCESS "Yarn安装完成: $(yarn --version)"
    fi
}

# 安装pnpm
install_pnpm() {
    if [[ $INSTALL_PNPM == true ]]; then
        log INFO "安装pnpm包管理器..."
        
        if [[ $USE_CN_MIRROR == true ]]; then
            npm install -g pnpm --registry=https://registry.npmmirror.com
            pnpm config set registry https://registry.npmmirror.com
        else
            npm install -g pnpm
        fi
        
        log SUCCESS "pnpm安装完成: $(pnpm --version)"
    fi
}

# 安装全局包
install_global_packages() {
    if [[ $INSTALL_GLOBAL_PACKAGES == true ]]; then
        log INFO "安装常用全局npm包..."
        
        local packages=(
            "pm2"           # 进程管理器
            "nodemon"       # 开发热重载
            "typescript"    # TypeScript
            "ts-node"       # TypeScript执行器
            "eslint"        # 代码检查
            "prettier"      # 代码格式化
            "http-server"   # 静态文件服务器
            "npm-check-updates" # 依赖更新检查
        )
        
        for package in "${packages[@]}"; do
            log INFO "安装 $package..."
            npm install -g "$package" || log WARNING "$package 安装失败"
        done
        
        log SUCCESS "全局包安装完成"
    fi
}

# 验证安装
verify_installation() {
    log INFO "验证安装..."
    
    # 检查Node.js
    if command_exists node; then
        local node_version=$(node --version)
        log SUCCESS "Node.js已安装: $node_version"
    else
        error_exit "Node.js安装失败"
    fi
    
    # 检查npm
    if command_exists npm; then
        local npm_version=$(npm --version)
        log SUCCESS "npm已安装: $npm_version"
    else
        log WARNING "npm未安装"
    fi
    
    # 检查Yarn
    if [[ $INSTALL_YARN == true ]] && command_exists yarn; then
        local yarn_version=$(yarn --version)
        log SUCCESS "Yarn已安装: $yarn_version"
    fi
    
    # 检查pnpm
    if [[ $INSTALL_PNPM == true ]] && command_exists pnpm; then
        local pnpm_version=$(pnpm --version)
        log SUCCESS "pnpm已安装: $pnpm_version"
    fi
    
    # 测试Node.js
    log INFO "测试Node.js运行..."
    node -e "console.log('Node.js is working!')" || log WARNING "Node.js测试失败"
}

# 列出可用版本
list_versions() {
    log INFO "获取可用的Node.js版本..."
    
    echo -e "${BLUE}LTS版本:${NC}"
    if [[ $USE_CN_MIRROR == true ]]; then
        curl -s https://npmmirror.com/mirrors/node/ | grep -oP 'latest-v\d+\.x' | sort -V | uniq | tail -10
    else
        curl -s https://nodejs.org/dist/ | grep -oP 'latest-v\d+\.x' | sort -V | uniq | tail -10
    fi
    
    echo
    echo -e "${BLUE}最新版本:${NC}"
    if [[ $USE_CN_MIRROR == true ]]; then
        curl -s https://npmmirror.com/mirrors/node/latest/ | grep -oP 'node-v\d+\.\d+\.\d+' | head -1
    else
        curl -s https://nodejs.org/dist/latest/ | grep -oP 'node-v\d+\.\d+\.\d+' | head -1
    fi
}

# 卸载Node.js
remove_nodejs() {
    log WARNING "开始卸载Node.js..."
    
    # 卸载通过包管理器安装的Node.js
    case $OS in
        ubuntu|debian)
            apt-get purge -y nodejs npm
            apt-get autoremove -y
            ;;
        centos|rhel|almalinux|rocky|fedora)
            if [[ $OS == "fedora" ]]; then
                dnf remove -y nodejs npm
            else
                yum remove -y nodejs npm
            fi
            ;;
    esac
    
    # 删除全局npm包
    rm -rf /usr/lib/node_modules
    rm -rf "$NODE_PREFIX/lib/node_modules"
    
    # 删除二进制文件
    rm -f /usr/bin/node /usr/bin/npm /usr/bin/npx
    rm -f "$NODE_PREFIX/bin/node" "$NODE_PREFIX/bin/npm" "$NODE_PREFIX/bin/npx"
    
    # 删除npm缓存
    rm -rf ~/.npm
    
    # 删除nvm（如果存在）
    if [[ -d "$NVM_DIR" ]]; then
        echo -e "${YELLOW}是否同时卸载nvm？[y/N]:${NC} "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$NVM_DIR"
            sed -i '/NVM_DIR/d' ~/.bashrc ~/.zshrc 2>/dev/null || true
        fi
    fi
    
    log SUCCESS "Node.js卸载完成"
}

# 显示安装信息
show_installation_info() {
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Node.js安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}版本信息:${NC}"
    node --version
    echo -n "npm: " && npm --version
    [[ $INSTALL_YARN == true ]] && echo -n "Yarn: " && yarn --version
    [[ $INSTALL_PNPM == true ]] && echo -n "pnpm: " && pnpm --version
    echo
    
    if [[ $INSTALL_METHOD == "nvm" ]]; then
        echo -e "${BLUE}nvm信息:${NC}"
        echo "  安装目录: $NVM_DIR"
        echo "  使用命令: nvm list (查看已安装版本)"
        echo "           nvm use <version> (切换版本)"
        echo
    fi
    
    echo -e "${BLUE}配置信息:${NC}"
    echo "  npm registry: $(npm config get registry)"
    echo "  全局模块路径: $(npm config get prefix)"
    echo
    
    if [[ $INSTALL_GLOBAL_PACKAGES == true ]]; then
        echo -e "${BLUE}已安装的全局包:${NC}"
        npm list -g --depth=0
        echo
    fi
    
    echo -e "${BLUE}常用命令:${NC}"
    echo "  node -v                # 查看Node.js版本"
    echo "  npm install <package>  # 安装包"
    echo "  npm run <script>       # 运行脚本"
    echo "  npx <command>          # 执行包命令"
    echo
    echo -e "${BLUE}日志文件:${NC}"
    echo "  $LOG_FILE"
    echo
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                NODE_VERSION="$2"
                shift 2
                ;;
            --method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --cn)
                USE_CN_MIRROR=true
                shift
                ;;
            --with-yarn)
                INSTALL_YARN=true
                shift
                ;;
            --with-pnpm)
                INSTALL_PNPM=true
                shift
                ;;
            --global-packages)
                INSTALL_GLOBAL_PACKAGES=true
                shift
                ;;
            --remove)
                ACTION="remove"
                shift
                ;;
            --list)
                ACTION="list"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log ERROR "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检测系统
    detect_system
    
    # 执行操作
    echo -e "${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    case $ACTION in
        install)
            # 检查权限（nvm模式除外）
            if [[ "$INSTALL_METHOD" != "nvm" ]]; then
                check_root
            fi
            
            # 设置镜像
            setup_mirrors
            
            # 安装依赖
            install_dependencies
            
            # 根据方法安装Node.js
            case $INSTALL_METHOD in
                nodesource)
                    install_via_nodesource
                    ;;
                nvm)
                    install_via_nvm
                    ;;
                binary)
                    install_via_binary
                    ;;
                *)
                    error_exit "不支持的安装方法: $INSTALL_METHOD"
                    ;;
            esac
            
            # 配置和安装额外工具
            if [[ "$INSTALL_METHOD" != "nvm" ]]; then
                configure_npm
            fi
            
            install_yarn
            install_pnpm
            install_global_packages
            
            # 验证安装
            verify_installation
            show_installation_info
            ;;
            
        remove)
            check_root
            remove_nodejs
            ;;
            
        list)
            list_versions
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"
