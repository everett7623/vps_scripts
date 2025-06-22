#!/bin/bash
#==============================================================================
# 脚本名称: python.sh
# 脚本描述: Python 环境安装脚本 - 支持系统包管理器、pyenv和源码编译安装
# 脚本路径: vps_scripts/scripts/service_install/python.sh
# 作者: Jensfrank
# 使用方法: bash python.sh [选项]
# 选项说明:
#   --method <方式>  安装方式 (system/pyenv/source)
#   --version <版本> Python版本 (仅pyenv和source方式需要)
#   --force         强制重新安装
#   --help          显示帮助信息
# 更新日期: 2025-06-22
#==============================================================================

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
INSTALL_METHOD="system"
PYTHON_VERSION=""
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/python_install_$(date +%Y%m%d_%H%M%S).log"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Python 环境安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash python.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --method <方式>    安装方式:"
    echo "                     system - 使用系统包管理器安装"
    echo "                     pyenv  - 使用pyenv管理Python版本"
    echo "                     source - 从源码编译安装"
    echo "  --version <版本>   指定Python版本 (如: 3.9.16, 3.11.7)"
    echo "  --force           强制重新安装"
    echo "  --help            显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash python.sh                          # 使用系统包管理器安装"
    echo "  bash python.sh --method pyenv --version 3.11.7"
    echo "  bash python.sh --method source --version 3.10.13 --force"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "${RED}错误: 此脚本需要root权限运行${NC}"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        VER=$(lsb_release -sr)
    else
        log "${RED}错误: 无法检测系统类型${NC}"
        exit 1
    fi
    
    log "${GREEN}检测到系统: ${OS} ${VER}${NC}"
}

# 安装基础依赖
install_dependencies() {
    log "${YELLOW}正在安装基础依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                build-essential \
                libssl-dev \
                zlib1g-dev \
                libbz2-dev \
                libreadline-dev \
                libsqlite3-dev \
                wget \
                curl \
                llvm \
                libncurses5-dev \
                libncursesw5-dev \
                xz-utils \
                tk-dev \
                libffi-dev \
                liblzma-dev \
                python3-openssl \
                git
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum groupinstall -y "Development Tools"
            yum install -y \
                openssl-devel \
                bzip2-devel \
                libffi-devel \
                zlib-devel \
                xz-devel \
                sqlite-devel \
                readline-devel \
                tk-devel \
                wget \
                curl \
                git
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}基础依赖安装完成${NC}"
}

# 检查Python是否已安装
check_python_installed() {
    if command -v python3 &> /dev/null; then
        local current_version=$(python3 --version 2>&1 | awk '{print $2}')
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}Python ${current_version} 已安装${NC}"
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
    fi
}

# 使用系统包管理器安装
install_system_python() {
    log "${CYAN}使用系统包管理器安装Python...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y python3 python3-pip python3-dev python3-venv
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y python3 python3-pip python3-devel
            ;;
    esac
    
    # 创建python和pip的软链接
    if [[ ! -e /usr/bin/python ]]; then
        ln -s /usr/bin/python3 /usr/bin/python
    fi
    if [[ ! -e /usr/bin/pip ]]; then
        ln -s /usr/bin/pip3 /usr/bin/pip
    fi
}

# 安装pyenv
install_pyenv() {
    log "${CYAN}正在安装pyenv...${NC}"
    
    # 检查是否已安装pyenv
    if [[ -d "$HOME/.pyenv" ]] && [[ "$FORCE_INSTALL" = false ]]; then
        log "${YELLOW}pyenv已安装${NC}"
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
    else
        # 安装pyenv
        curl https://pyenv.run | bash
        
        # 配置环境变量
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        
        # 添加到shell配置文件
        for shell_rc in ~/.bashrc ~/.zshrc; do
            if [[ -f "$shell_rc" ]]; then
                if ! grep -q 'pyenv init' "$shell_rc"; then
                    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$shell_rc"
                    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$shell_rc"
                    echo 'eval "$(pyenv init -)"' >> "$shell_rc"
                fi
            fi
        done
        
        eval "$(pyenv init -)"
    fi
    
    # 使用pyenv安装指定版本
    if [[ -n "$PYTHON_VERSION" ]]; then
        log "${CYAN}使用pyenv安装Python ${PYTHON_VERSION}...${NC}"
        pyenv install -v "$PYTHON_VERSION"
        pyenv global "$PYTHON_VERSION"
    else
        # 获取最新稳定版本
        log "${CYAN}获取最新Python版本...${NC}"
        latest_version=$(pyenv install --list | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
        log "${CYAN}安装Python ${latest_version}...${NC}"
        pyenv install -v "$latest_version"
        pyenv global "$latest_version"
    fi
}

# 从源码编译安装
install_from_source() {
    log "${CYAN}从源码编译安装Python...${NC}"
    
    # 确定版本
    if [[ -z "$PYTHON_VERSION" ]]; then
        PYTHON_VERSION="3.11.7"
        log "${YELLOW}未指定版本，使用默认版本: ${PYTHON_VERSION}${NC}"
    fi
    
    # 下载源码
    cd /tmp
    wget "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
    
    if [[ ! -f "Python-${PYTHON_VERSION}.tgz" ]]; then
        log "${RED}错误: 下载Python源码失败${NC}"
        exit 1
    fi
    
    # 解压并编译
    tar -xzf "Python-${PYTHON_VERSION}.tgz"
    cd "Python-${PYTHON_VERSION}"
    
    # 配置编译选项
    ./configure --enable-optimizations \
                --enable-shared \
                --with-system-ffi \
                --with-ensurepip=install \
                --prefix=/usr/local
    
    # 编译并安装
    make -j$(nproc)
    make altinstall
    
    # 创建软链接
    major_version=$(echo $PYTHON_VERSION | cut -d. -f1,2)
    ln -sf /usr/local/bin/python${major_version} /usr/local/bin/python3
    ln -sf /usr/local/bin/pip${major_version} /usr/local/bin/pip3
    
    # 更新动态链接库缓存
    echo "/usr/local/lib" > /etc/ld.so.conf.d/python.conf
    ldconfig
    
    # 清理临时文件
    cd /
    rm -rf /tmp/Python-${PYTHON_VERSION}*
}

# 安装Python包管理工具
install_pip_tools() {
    log "${CYAN}安装Python包管理工具...${NC}"
    
    # 升级pip
    python3 -m pip install --upgrade pip
    
    # 安装常用工具
    python3 -m pip install --upgrade \
        setuptools \
        wheel \
        virtualenv \
        pipenv \
        poetry
        
    log "${GREEN}Python包管理工具安装完成${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Python安装...${NC}"
    
    if command -v python3 &> /dev/null; then
        python_version=$(python3 --version 2>&1)
        pip_version=$(python3 -m pip --version 2>&1)
        
        log "${GREEN}安装成功!${NC}"
        log "${GREEN}Python版本: ${python_version}${NC}"
        log "${GREEN}Pip版本: ${pip_version}${NC}"
        
        # 显示Python路径
        log "${CYAN}Python路径:${NC}"
        which python3
        
        # 测试基本功能
        log "${CYAN}测试Python功能...${NC}"
        python3 -c "import sys; print(f'Python {sys.version}')"
        python3 -c "import ssl; print(f'SSL支持: {ssl.OPENSSL_VERSION}')"
    else
        log "${RED}错误: Python安装验证失败${NC}"
        exit 1
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Python安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}使用说明:${NC}"
    echo "1. 运行Python: python3"
    echo "2. 安装包: pip3 install <package>"
    echo "3. 创建虚拟环境: python3 -m venv <env_name>"
    echo
    
    if [[ "$INSTALL_METHOD" = "pyenv" ]]; then
        echo -e "${CYAN}pyenv使用说明:${NC}"
        echo "- 列出可用版本: pyenv install --list"
        echo "- 安装其他版本: pyenv install <version>"
        echo "- 切换版本: pyenv global <version>"
        echo "- 查看已安装版本: pyenv versions"
        echo
    fi
    
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --version)
                PYTHON_VERSION="$2"
                shift 2
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示标题
    show_title
    
    # 检查root权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_python_installed
    
    # 安装依赖
    install_dependencies
    
    # 根据方式安装
    case $INSTALL_METHOD in
        system)
            install_system_python
            ;;
        pyenv)
            install_pyenv
            ;;
        source)
            install_from_source
            ;;
        *)
            log "${RED}错误: 无效的安装方式 ${INSTALL_METHOD}${NC}"
            show_help
            exit 1
            ;;
    esac
    
    # 安装pip工具
    install_pip_tools
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"