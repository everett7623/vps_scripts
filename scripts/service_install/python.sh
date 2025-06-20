#!/bin/bash
#==============================================================================
# 脚本名称: install_python.sh
# 脚本描述: Python安装脚本 - 支持多种安装方式、版本管理和虚拟环境配置
# 脚本路径: vps_scripts/scripts/service_install/install_python.sh
# 作者: Jensfrank
# 使用方法: bash install_python.sh [选项]
# 选项: 
#   --version VERSION    指定Python版本 (如: 3.9, 3.10, 3.11, 3.12)
#   --method METHOD      安装方式 (system/source/pyenv, 默认: system)
#   --cn                 使用国内镜像源
#   --with-pip           确保安装pip (默认已包含)
#   --with-venv          安装虚拟环境工具
#   --with-packages      安装常用Python包
#   --dev-tools          安装开发工具包
#   --remove             卸载Python
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
readonly SCRIPT_NAME="Python安装脚本"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/tmp/python_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
PYTHON_VERSION="3.11"
INSTALL_METHOD="system"
USE_CN_MIRROR=false
INSTALL_VENV=false
INSTALL_PACKAGES=false
INSTALL_DEV_TOOLS=false
ACTION="install"

# 系统信息
OS=""
VERSION=""
ARCH=""

# Python相关路径
PYTHON_PREFIX="/usr/local"
PYENV_ROOT="$HOME/.pyenv"

#==============================================================================
# 函数定义
#==============================================================================

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

使用方法: $(basename "$0") [选项]

选项:
    --version VERSION    指定Python版本
                        - 3.8, 3.9, 3.10, 3.11, 3.12
                        默认: 3.11
    
    --method METHOD      安装方式
                        - system: 使用系统包管理器（快速）
                        - source: 从源码编译（可定制）
                        - pyenv: 使用pyenv版本管理器
                        默认: system
    
    --cn                使用国内镜像源（推荐国内用户使用）
    --with-venv         安装虚拟环境工具（virtualenv, venv）
    --with-packages     安装常用Python包
    --dev-tools         安装开发工具包（适合开发环境）
    --remove            卸载Python
    --list              列出可用版本
    -h, --help          显示此帮助信息

示例:
    $(basename "$0")                          # 使用系统包管理器安装
    $(basename "$0") --version 3.12 --cn      # 安装Python 3.12，使用国内源
    $(basename "$0") --method source          # 从源码编译安装
    $(basename "$0") --method pyenv --cn      # 使用pyenv管理多版本
    $(basename "$0") --with-venv --with-packages  # 安装并配置完整环境

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
        if [[ "$INSTALL_METHOD" == "pyenv" ]]; then
            log INFO "pyenv安装模式不需要root权限"
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
    else
        error_exit "无法检测操作系统信息"
    fi
    
    # 检测架构
    ARCH=$(uname -m)
    
    log SUCCESS "系统信息: $OS $VERSION ($ARCH)"
}

# 检查Python版本格式
validate_python_version() {
    local version=$1
    if [[ ! "$version" =~ ^3\.(8|9|10|11|12)$ ]]; then
        error_exit "不支持的Python版本: $version"
    fi
}

# 设置pip镜像源
setup_pip_mirror() {
    if [[ $USE_CN_MIRROR == true ]]; then
        log INFO "配置pip国内镜像源..."
        
        # 创建pip配置目录
        mkdir -p ~/.pip
        
        # 配置pip镜像
        cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 120

[install]
use-mirrors = true
mirrors = https://pypi.tuna.tsinghua.edu.cn/simple
EOF
        
        # 对于root用户，也创建全局配置
        if [[ $EUID -eq 0 ]]; then
            mkdir -p /etc/pip
            cp ~/.pip/pip.conf /etc/pip/pip.conf
        fi
        
        log SUCCESS "pip镜像源配置完成"
    fi
}

# 安装编译依赖
install_build_deps() {
    log INFO "安装编译依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq \
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
        centos|rhel|almalinux|rocky)
            yum groupinstall -y "Development Tools"
            yum install -y \
                openssl-devel \
                bzip2-devel \
                libffi-devel \
                zlib-devel \
                readline-devel \
                sqlite-devel \
                tk-devel \
                xz-devel \
                wget \
                git
            ;;
        fedora)
            dnf groupinstall -y "Development Tools"
            dnf install -y \
                openssl-devel \
                bzip2-devel \
                libffi-devel \
                zlib-devel \
                readline-devel \
                sqlite-devel \
                tk-devel \
                xz-devel \
                wget \
                git
            ;;
    esac
    
    log SUCCESS "编译依赖安装完成"
}

# 通过系统包管理器安装
install_via_system() {
    log INFO "使用系统包管理器安装Python..."
    
    local pkg_version=${PYTHON_VERSION/./}  # 3.11 -> 311
    
    case $OS in
        ubuntu|debian)
            # 添加deadsnakes PPA (Ubuntu)
            if [[ "$OS" == "ubuntu" ]]; then
                add-apt-repository -y ppa:deadsnakes/ppa
                apt-get update -qq
            fi
            
            # 安装Python
            apt-get install -y \
                python${PYTHON_VERSION} \
                python${PYTHON_VERSION}-dev \
                python${PYTHON_VERSION}-venv \
                python${PYTHON_VERSION}-distutils
            
            # 安装pip
            if [[ ! -f /usr/bin/python${PYTHON_VERSION} ]]; then
                error_exit "Python ${PYTHON_VERSION} 安装失败"
            fi
            
            # 安装pip
            curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}
            
            # 创建符号链接
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1
            update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip${PYTHON_VERSION} 1
            ;;
            
        centos|rhel|almalinux|rocky)
            # CentOS/RHEL需要额外的仓库
            if [[ "$VERSION" == "7" ]]; then
                yum install -y epel-release
                yum install -y python${pkg_version} python${pkg_version}-devel python${pkg_version}-pip
            else
                # CentOS 8+
                dnf install -y python${pkg_version} python${pkg_version}-devel python${pkg_version}-pip
            fi
            ;;
            
        fedora)
            dnf install -y python${pkg_version} python${pkg_version}-devel python${pkg_version}-pip
            ;;
    esac
    
    log SUCCESS "Python ${PYTHON_VERSION} 系统包安装完成"
}

# 从源码编译安装
install_from_source() {
    log INFO "从源码编译安装Python ${PYTHON_VERSION}..."
    
    validate_python_version "$PYTHON_VERSION"
    install_build_deps
    
    # 获取最新的补丁版本
    local version_info=$(curl -s https://www.python.org/ftp/python/ | grep -oP "${PYTHON_VERSION}\.\d+" | sort -V | tail -1)
    if [[ -z "$version_info" ]]; then
        version_info="${PYTHON_VERSION}.0"
    fi
    
    local download_url="https://www.python.org/ftp/python/${version_info}/Python-${version_info}.tar.xz"
    if [[ $USE_CN_MIRROR == true ]]; then
        download_url="https://npm.taobao.org/mirrors/python/${version_info}/Python-${version_info}.tar.xz"
    fi
    
    local temp_dir="/tmp/python_build"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    log INFO "下载Python ${version_info}..."
    wget -q --show-progress "$download_url" -O Python-${version_info}.tar.xz || error_exit "下载失败"
    
    log INFO "解压源码..."
    tar -xf Python-${version_info}.tar.xz
    cd Python-${version_info}
    
    log INFO "配置编译选项..."
    ./configure \
        --prefix="$PYTHON_PREFIX" \
        --enable-optimizations \
        --enable-shared \
        --with-lto \
        --with-system-ffi \
        --with-computed-gotos \
        --enable-loadable-sqlite-extensions \
        LDFLAGS="-Wl,-rpath ${PYTHON_PREFIX}/lib"
    
    log INFO "编译安装（这可能需要几分钟）..."
    make -j$(nproc)
    make altinstall
    
    # 创建符号链接
    ln -sf ${PYTHON_PREFIX}/bin/python${PYTHON_VERSION} /usr/bin/python${PYTHON_VERSION}
    ln -sf ${PYTHON_PREFIX}/bin/pip${PYTHON_VERSION} /usr/bin/pip${PYTHON_VERSION}
    
    # 更新动态链接库
    echo "${PYTHON_PREFIX}/lib" > /etc/ld.so.conf.d/python${PYTHON_VERSION}.conf
    ldconfig
    
    # 清理
    cd /
    rm -rf "$temp_dir"
    
    log SUCCESS "Python ${version_info} 源码编译安装完成"
}

# 通过pyenv安装
install_via_pyenv() {
    log INFO "使用pyenv安装Python..."
    
    # 安装pyenv
    if [[ ! -d "$PYENV_ROOT" ]]; then
        log INFO "安装pyenv..."
        
        if [[ $USE_CN_MIRROR == true ]]; then
            git clone https://gitee.com/mirrors/pyenv.git "$PYENV_ROOT"
        else
            git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
        fi
        
        # 安装pyenv-virtualenv插件
        if [[ $USE_CN_MIRROR == true ]]; then
            git clone https://gitee.com/mirrors/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
        else
            git clone https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
        fi
    fi
    
    # 配置环境变量
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    
    # 设置镜像
    if [[ $USE_CN_MIRROR == true ]]; then
        export PYTHON_BUILD_MIRROR_URL="https://npm.taobao.org/mirrors/python/"
    fi
    
    # 安装编译依赖
    install_build_deps
    
    # 安装指定版本的Python
    log INFO "安装Python ${PYTHON_VERSION}..."
    pyenv install ${PYTHON_VERSION}
    pyenv global ${PYTHON_VERSION}
    
    # 更新pip
    pip install --upgrade pip
    
    # 添加到shell配置
    local shell_rc=""
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
    fi
    
    if [[ -n "$shell_rc" ]] && ! grep -q "PYENV_ROOT" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# pyenv配置
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi
EOF
        log INFO "pyenv配置已添加到 $shell_rc"
    fi
    
    log SUCCESS "Python ${PYTHON_VERSION} 通过pyenv安装完成"
}

# 安装虚拟环境工具
install_venv_tools() {
    if [[ $INSTALL_VENV == true ]]; then
        log INFO "安装虚拟环境工具..."
        
        # 确定Python命令
        local python_cmd="python${PYTHON_VERSION}"
        if ! command_exists "$python_cmd"; then
            python_cmd="python3"
        fi
        
        # 安装virtualenv
        $python_cmd -m pip install virtualenv virtualenvwrapper
        
        # 配置virtualenvwrapper
        local shell_rc=""
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            shell_rc="$HOME/.zshrc"
        fi
        
        if [[ -n "$shell_rc" ]] && ! grep -q "WORKON_HOME" "$shell_rc"; then
            cat >> "$shell_rc" << EOF

# virtualenvwrapper配置
export WORKON_HOME=\$HOME/.virtualenvs
export PROJECT_HOME=\$HOME/projects
export VIRTUALENVWRAPPER_PYTHON=$(which $python_cmd)
source $(which virtualenvwrapper.sh)
EOF
            log INFO "virtualenvwrapper配置已添加到 $shell_rc"
        fi
        
        log SUCCESS "虚拟环境工具安装完成"
    fi
}

# 安装常用Python包
install_common_packages() {
    if [[ $INSTALL_PACKAGES == true ]]; then
        log INFO "安装常用Python包..."
        
        local python_cmd="python${PYTHON_VERSION}"
        if ! command_exists "$python_cmd"; then
            python_cmd="python3"
        fi
        
        local packages=(
            "requests"      # HTTP库
            "numpy"         # 数值计算
            "pandas"        # 数据分析
            "matplotlib"    # 绘图
            "scikit-learn"  # 机器学习
            "flask"         # Web框架
            "django"        # Web框架
            "pytest"        # 测试框架
            "black"         # 代码格式化
            "flake8"        # 代码检查
        )
        
        for package in "${packages[@]}"; do
            log INFO "安装 $package..."
            $python_cmd -m pip install "$package" || log WARNING "$package 安装失败"
        done
        
        log SUCCESS "常用包安装完成"
    fi
}

# 安装开发工具
install_dev_tools() {
    if [[ $INSTALL_DEV_TOOLS == true ]]; then
        log INFO "安装Python开发工具..."
        
        local python_cmd="python${PYTHON_VERSION}"
        if ! command_exists "$python_cmd"; then
            python_cmd="python3"
        fi
        
        local dev_packages=(
            "ipython"           # 增强的Python shell
            "jupyter"           # Jupyter notebook
            "jupyterlab"        # JupyterLab
            "pylint"            # 代码分析
            "mypy"              # 类型检查
            "autopep8"          # 代码格式化
            "poetry"            # 依赖管理
            "tox"               # 测试工具
            "sphinx"            # 文档生成
            "pre-commit"        # Git钩子
            "debugpy"           # 调试器
        )
        
        for package in "${dev_packages[@]}"; do
            log INFO "安装 $package..."
            $python_cmd -m pip install "$package" || log WARNING "$package 安装失败"
        done
        
        log SUCCESS "开发工具安装完成"
    fi
}

# 配置Python环境
configure_python() {
    log INFO "配置Python环境..."
    
    # 更新pip
    local python_cmd="python${PYTHON_VERSION}"
    if ! command_exists "$python_cmd"; then
        python_cmd="python3"
    fi
    
    log INFO "更新pip..."
    $python_cmd -m pip install --upgrade pip setuptools wheel
    
    # 设置pip镜像
    setup_pip_mirror
    
    # 创建Python配置
    mkdir -p ~/.config/python
    cat > ~/.config/python/startup.py << 'EOF'
# Python启动配置
import sys
import os

# 添加用户site-packages到路径
user_site = os.path.expanduser('~/.local/lib/python{}.{}/site-packages'.format(
    sys.version_info.major, sys.version_info.minor))
if os.path.exists(user_site) and user_site not in sys.path:
    sys.path.append(user_site)

# 启用自动补全
try:
    import readline
    import rlcompleter
    readline.parse_and_bind("tab: complete")
except ImportError:
    pass
EOF
    
    # 设置PYTHONSTARTUP环境变量
    echo "export PYTHONSTARTUP=~/.config/python/startup.py" >> ~/.bashrc
    
    log SUCCESS "Python环境配置完成"
}

# 验证安装
verify_installation() {
    log INFO "验证安装..."
    
    # 检查Python
    local python_cmd="python${PYTHON_VERSION}"
    if ! command_exists "$python_cmd"; then
        python_cmd="python3"
    fi
    
    if command_exists "$python_cmd"; then
        local python_version=$($python_cmd --version 2>&1)
        log SUCCESS "Python已安装: $python_version"
    else
        error_exit "Python安装失败"
    fi
    
    # 检查pip
    if $python_cmd -m pip --version &>/dev/null; then
        local pip_version=$($python_cmd -m pip --version)
        log SUCCESS "pip已安装: $pip_version"
    else
        log WARNING "pip未安装"
    fi
    
    # 测试Python
    log INFO "测试Python运行..."
    $python_cmd -c "print('Python is working!')" || log WARNING "Python测试失败"
    
    # 显示Python信息
    $python_cmd -c "
import sys
import platform
print(f'Python路径: {sys.executable}')
print(f'平台: {platform.platform()}')
print(f'实现: {platform.python_implementation()}')
"
}

# 列出可用版本
list_versions() {
    log INFO "Python可用版本..."
    
    echo -e "${BLUE}推荐版本:${NC}"
    echo "  3.11 (当前稳定版，推荐)"
    echo "  3.12 (最新版本)"
    echo "  3.10 (长期支持版)"
    echo "  3.9  (旧稳定版)"
    echo "  3.8  (旧版本，仍在维护)"
    echo
    
    if command_exists pyenv; then
        echo -e "${BLUE}pyenv可安装的版本:${NC}"
        pyenv install --list | grep -E "^\s*3\.(8|9|10|11|12)\." | tail -20
    fi
}

# 卸载Python
remove_python() {
    log WARNING "开始卸载Python..."
    
    # 确定要卸载的版本
    local python_cmd="python${PYTHON_VERSION}"
    
    case $OS in
        ubuntu|debian)
            apt-get purge -y python${PYTHON_VERSION}* libpython${PYTHON_VERSION}*
            apt-get autoremove -y
            ;;
        centos|rhel|almalinux|rocky|fedora)
            local pkg_version=${PYTHON_VERSION/./}
            if [[ $OS == "fedora" ]] || [[ $VERSION -ge 8 ]]; then
                dnf remove -y python${pkg_version}*
            else
                yum remove -y python${pkg_version}*
            fi
            ;;
    esac
    
    # 删除源码编译的Python
    if [[ -f ${PYTHON_PREFIX}/bin/python${PYTHON_VERSION} ]]; then
        rm -f ${PYTHON_PREFIX}/bin/python${PYTHON_VERSION}*
        rm -f ${PYTHON_PREFIX}/bin/pip${PYTHON_VERSION}*
        rm -rf ${PYTHON_PREFIX}/lib/python${PYTHON_VERSION}
        rm -f /etc/ld.so.conf.d/python${PYTHON_VERSION}.conf
        ldconfig
    fi
    
    # 删除pip缓存和配置
    rm -rf ~/.cache/pip
    rm -rf ~/.pip
    
    # 删除pyenv（如果用户确认）
    if [[ -d "$PYENV_ROOT" ]]; then
        echo -e "${YELLOW}是否同时卸载pyenv？[y/N]:${NC} "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$PYENV_ROOT"
            sed -i '/PYENV_ROOT/d' ~/.bashrc ~/.zshrc 2>/dev/null || true
        fi
    fi
    
    log SUCCESS "Python卸载完成"
}

# 显示安装信息
show_installation_info() {
    local python_cmd="python${PYTHON_VERSION}"
    if ! command_exists "$python_cmd"; then
        python_cmd="python3"
    fi
    
    echo
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Python安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo
    echo -e "${BLUE}版本信息:${NC}"
    $python_cmd --version
    echo -n "pip: " && $python_cmd -m pip --version
    echo
    
    if [[ $INSTALL_METHOD == "pyenv" ]]; then
        echo -e "${BLUE}pyenv信息:${NC}"
        echo "  安装目录: $PYENV_ROOT"
        echo "  使用命令:"
        echo "    pyenv versions     # 查看已安装版本"
        echo "    pyenv install -l   # 列出可安装版本"
        echo "    pyenv global 3.x   # 设置全局版本"
        echo
    fi
    
    echo -e "${BLUE}pip配置:${NC}"
    echo "  配置文件: ~/.pip/pip.conf"
    if [[ $USE_CN_MIRROR == true ]]; then
        echo "  镜像源: https://pypi.tuna.tsinghua.edu.cn/simple"
    fi
    echo
    
    if [[ $INSTALL_VENV == true ]]; then
        echo -e "${BLUE}虚拟环境:${NC}"
        echo "  创建: $python_cmd -m venv myenv"
        echo "  激活: source myenv/bin/activate"
        echo "  退出: deactivate"
        echo
    fi
    
    echo -e "${BLUE}常用命令:${NC}"
    echo "  $python_cmd                    # 启动Python解释器"
    echo "  $python_cmd -m pip install pkg # 安装包"
    echo "  $python_cmd -m pip list        # 列出已安装包"
    echo "  $python_cmd script.py          # 运行脚本"
    echo
    
    if [[ $INSTALL_PACKAGES == true ]] || [[ $INSTALL_DEV_TOOLS == true ]]; then
        echo -e "${BLUE}已安装的包:${NC}"
        $python_cmd -m pip list --format=columns | head -20
        echo "  ..."
        echo
    fi
    
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
                PYTHON_VERSION="$2"
                validate_python_version "$PYTHON_VERSION"
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
            --with-pip)
                # pip现在默认包含，保留选项兼容性
                shift
                ;;
            --with-venv)
                INSTALL_VENV=true
                shift
                ;;
            --with-packages)
                INSTALL_PACKAGES=true
                shift
                ;;
            --dev-tools)
                INSTALL_DEV_TOOLS=true
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
            # 检查权限（pyenv模式除外）
            if [[ "$INSTALL_METHOD" != "pyenv" ]]; then
                check_root
            fi
            
            # 根据方法安装Python
            case $INSTALL_METHOD in
                system)
                    install_via_system
                    ;;
                source)
                    install_from_source
                    ;;
                pyenv)
                    install_via_pyenv
                    ;;
                *)
                    error_exit "不支持的安装方法: $INSTALL_METHOD"
                    ;;
            esac
            
            # 配置环境
            configure_python
            install_venv_tools
            install_common_packages
            install_dev_tools
            
            # 验证安装
            verify_installation
            show_installation_info
            ;;
            
        remove)
            if [[ "$INSTALL_METHOD" != "pyenv" ]]; then
                check_root
            fi
            remove_python
            ;;
            
        list)
            list_versions
            ;;
    esac
    
    log SUCCESS "操作完成！"
}

# 执行主函数
main "$@"
