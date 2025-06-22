#!/bin/bash
#==============================================================================
# 脚本名称: ruby.sh
# 脚本描述: Ruby 语言环境安装脚本 - 支持系统包、rbenv、rvm和源码编译安装
# 脚本路径: vps_scripts/scripts/service_install/ruby.sh
# 作者: Jensfrank
# 使用方法: bash ruby.sh [选项]
# 选项说明:
#   --method <方式>      安装方式 (system/rbenv/rvm/source)
#   --version <版本>     Ruby版本 (如: 3.2.2, 3.1.4)
#   --install-rails     安装Rails框架
#   --install-bundler   安装Bundler
#   --china-mirror      使用中国镜像源
#   --dev-tools         安装开发工具集
#   --force             强制重新安装
#   --help              显示帮助信息
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
INSTALL_METHOD="rbenv"
RUBY_VERSION=""
INSTALL_RAILS=false
INSTALL_BUNDLER=false
USE_CHINA_MIRROR=false
INSTALL_DEV_TOOLS=false
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/ruby_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DEFAULT_RUBY_VERSION="3.2.2"
RBENV_ROOT="$HOME/.rbenv"
RVM_PATH="$HOME/.rvm"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Ruby 语言环境安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash ruby.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --method <方式>      安装方式:"
    echo "                       system - 使用系统包管理器"
    echo "                       rbenv  - 使用rbenv管理(推荐)"
    echo "                       rvm    - 使用RVM管理"
    echo "                       source - 从源码编译"
    echo "  --version <版本>     指定Ruby版本 (如: 3.2.2, 3.1.4)"
    echo "  --install-rails     安装Rails框架"
    echo "  --install-bundler   安装Bundler包管理器"
    echo "  --china-mirror      使用中国镜像源加速"
    echo "  --dev-tools         安装开发工具集"
    echo "  --force             强制重新安装"
    echo "  --help              显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash ruby.sh                                    # 使用rbenv安装最新版"
    echo "  bash ruby.sh --method rbenv --version 3.2.2"
    echo "  bash ruby.sh --method rvm --install-rails"
    echo "  bash ruby.sh --china-mirror --dev-tools"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]] && [[ "$INSTALL_METHOD" != "system" ]]; then
        log "${YELLOW}警告: rbenv/rvm建议以普通用户身份安装${NC}"
        log "${YELLOW}如需继续，请确保了解相关风险${NC}"
        read -p "是否继续? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    elif [[ $EUID -ne 0 ]] && [[ "$INSTALL_METHOD" == "system" ]]; then
        log "${RED}错误: 系统包安装需要root权限${NC}"
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
    
    if [[ $EUID -eq 0 ]]; then
        case $OS in
            ubuntu|debian)
                apt-get update
                apt-get install -y \
                    build-essential \
                    libssl-dev \
                    libreadline-dev \
                    zlib1g-dev \
                    libsqlite3-dev \
                    libxml2-dev \
                    libxslt1-dev \
                    libcurl4-openssl-dev \
                    libffi-dev \
                    libyaml-dev \
                    libgdbm-dev \
                    libncurses5-dev \
                    automake \
                    libtool \
                    bison \
                    curl \
                    wget \
                    git
                ;;
            centos|rhel|fedora|rocky|almalinux)
                yum groupinstall -y "Development Tools"
                yum install -y \
                    openssl-devel \
                    readline-devel \
                    zlib-devel \
                    sqlite-devel \
                    libxml2-devel \
                    libxslt-devel \
                    libcurl-devel \
                    libffi-devel \
                    libyaml-devel \
                    gdbm-devel \
                    ncurses-devel \
                    automake \
                    libtool \
                    bison \
                    curl \
                    wget \
                    git
                ;;
            *)
                log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
                exit 1
                ;;
        esac
    else
        log "${YELLOW}跳过依赖安装（需要root权限）${NC}"
        log "${YELLOW}请确保已安装必要的编译依赖${NC}"
    fi
    
    log "${GREEN}基础依赖处理完成${NC}"
}

# 检查Ruby是否已安装
check_ruby_installed() {
    if command -v ruby &> /dev/null; then
        local current_version=$(ruby --version 2>&1 | awk '{print $2}')
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到Ruby ${current_version} 已安装${NC}"
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
    fi
}

# 配置中国镜像
configure_china_mirrors() {
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        log "${CYAN}配置中国镜像源...${NC}"
        
        # 配置gem源
        gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
        
        # 配置bundle镜像
        bundle config mirror.https://rubygems.org https://gems.ruby-china.com
        
        log "${GREEN}镜像源配置完成${NC}"
    fi
}

# 使用系统包管理器安装
install_system_ruby() {
    log "${CYAN}使用系统包管理器安装Ruby...${NC}"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y ruby-full ruby-dev
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y ruby ruby-devel
            ;;
    esac
}

# 安装rbenv
install_rbenv() {
    log "${CYAN}安装rbenv...${NC}"
    
    # 克隆rbenv仓库
    if [[ -d "$RBENV_ROOT" ]] && [[ "$FORCE_INSTALL" = false ]]; then
        log "${YELLOW}rbenv已存在${NC}"
    else
        rm -rf "$RBENV_ROOT"
        git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
    fi
    
    # 编译动态bash扩展
    cd "$RBENV_ROOT" && src/configure && make -C src
    
    # 添加到PATH
    export PATH="$RBENV_ROOT/bin:$PATH"
    
    # 配置shell
    for shell_rc in ~/.bashrc ~/.zshrc; do
        if [[ -f "$shell_rc" ]]; then
            # 清理旧配置
            sed -i '/rbenv/d' "$shell_rc"
            # 添加新配置
            echo '' >> "$shell_rc"
            echo '# rbenv configuration' >> "$shell_rc"
            echo "export PATH=\"$RBENV_ROOT/bin:\$PATH\"" >> "$shell_rc"
            echo 'eval "$(rbenv init -)"' >> "$shell_rc"
        fi
    done
    
    # 安装ruby-build插件
    log "${CYAN}安装ruby-build插件...${NC}"
    mkdir -p "$RBENV_ROOT/plugins"
    if [[ -d "$RBENV_ROOT/plugins/ruby-build" ]]; then
        cd "$RBENV_ROOT/plugins/ruby-build" && git pull
    else
        git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
    fi
    
    # 初始化rbenv
    eval "$(rbenv init -)"
    
    # 获取可用版本
    if [[ -z "$RUBY_VERSION" ]]; then
        log "${CYAN}获取最新稳定版本...${NC}"
        RUBY_VERSION=$(rbenv install -l | grep -E '^\s*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
        if [[ -z "$RUBY_VERSION" ]]; then
            RUBY_VERSION="$DEFAULT_RUBY_VERSION"
        fi
    fi
    
    # 安装Ruby
    log "${CYAN}使用rbenv安装Ruby ${RUBY_VERSION}...${NC}"
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        export RUBY_BUILD_MIRROR_URL=https://cache.ruby-china.com
    fi
    rbenv install -v "$RUBY_VERSION"
    rbenv global "$RUBY_VERSION"
    rbenv rehash
}

# 安装RVM
install_rvm() {
    log "${CYAN}安装RVM...${NC}"
    
    # 安装GPG密钥
    gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
    
    # 下载并安装RVM
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        curl -sSL https://get.rvm.io | bash -s stable --ruby="$RUBY_VERSION" --auto-dotfiles
    else
        curl -sSL https://get.rvm.io | bash -s stable --ruby="$RUBY_VERSION" --auto-dotfiles
    fi
    
    # 加载RVM
    source "$RVM_PATH/scripts/rvm"
    
    # 设置默认Ruby版本
    if [[ -n "$RUBY_VERSION" ]]; then
        rvm install "$RUBY_VERSION"
        rvm use "$RUBY_VERSION" --default
    fi
}

# 从源码编译安装
install_from_source() {
    log "${CYAN}从源码编译安装Ruby...${NC}"
    
    # 确定版本
    if [[ -z "$RUBY_VERSION" ]]; then
        RUBY_VERSION="$DEFAULT_RUBY_VERSION"
    fi
    
    # 下载源码
    cd /tmp
    RUBY_MAJOR=$(echo $RUBY_VERSION | cut -d. -f1,2)
    wget "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/ruby-${RUBY_VERSION}.tar.gz"
    
    if [[ ! -f "ruby-${RUBY_VERSION}.tar.gz" ]]; then
        log "${RED}错误: Ruby源码下载失败${NC}"
        exit 1
    fi
    
    # 解压并编译
    tar -xzf "ruby-${RUBY_VERSION}.tar.gz"
    cd "ruby-${RUBY_VERSION}"
    
    # 配置编译选项
    ./configure \
        --prefix=/usr/local \
        --enable-shared \
        --disable-install-doc \
        --with-opt-dir=/usr/local
    
    # 编译并安装
    make -j$(nproc)
    
    if [[ $EUID -eq 0 ]]; then
        make install
    else
        log "${YELLOW}需要root权限安装，请输入密码${NC}"
        sudo make install
    fi
    
    # 清理临时文件
    cd /
    rm -rf /tmp/ruby-${RUBY_VERSION}*
}

# 安装Rails
install_rails() {
    log "${CYAN}安装Ruby on Rails...${NC}"
    
    # 配置镜像
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
    fi
    
    # 安装Rails
    gem install rails
    
    # 验证安装
    rails_version=$(rails --version 2>&1)
    log "${GREEN}Rails安装成功: ${rails_version}${NC}"
}

# 安装Bundler
install_bundler() {
    log "${CYAN}安装Bundler...${NC}"
    
    gem install bundler
    
    # 配置Bundler镜像
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        bundle config mirror.https://rubygems.org https://gems.ruby-china.com
    fi
    
    bundler_version=$(bundle --version 2>&1)
    log "${GREEN}Bundler安装成功: ${bundler_version}${NC}"
}

# 安装开发工具
install_dev_tools() {
    log "${CYAN}安装Ruby开发工具集...${NC}"
    
    # 常用开发gem
    local gems=(
        "pry"           # 强大的REPL
        "rubocop"       # 代码风格检查
        "rspec"         # 测试框架
        "sinatra"       # 轻量级Web框架
        "rake"          # 构建工具
        "yard"          # 文档生成
        "byebug"        # 调试器
        "solargraph"    # 语言服务器
        "rufo"          # 代码格式化
        "fastri"        # 文档查询
    )
    
    for gem_name in "${gems[@]}"; do
        log "${YELLOW}安装 ${gem_name}...${NC}"
        gem install "$gem_name" || log "${RED}${gem_name} 安装失败${NC}"
    done
    
    log "${GREEN}开发工具集安装完成${NC}"
}

# 创建测试项目
create_test_project() {
    log "${CYAN}创建Ruby测试项目...${NC}"
    
    # 创建测试目录
    TEST_DIR="$HOME/ruby_test"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # 创建Gemfile
    cat > Gemfile << 'EOF'
source 'https://rubygems.org'

gem 'sinatra'
gem 'puma'
EOF
    
    # 创建测试应用
    cat > app.rb << 'EOF'
require 'sinatra'

get '/' do
  "Hello from Ruby #{RUBY_VERSION}!"
end

get '/info' do
  content_type :json
  {
    ruby_version: RUBY_VERSION,
    ruby_platform: RUBY_PLATFORM,
    sinatra_version: Sinatra::VERSION,
    current_time: Time.now.to_s
  }.to_json
end
EOF
    
    # 创建config.ru
    cat > config.ru << 'EOF'
require './app'
run Sinatra::Application
EOF
    
    # 安装依赖
    if command -v bundle &> /dev/null; then
        bundle install
    fi
    
    log "${GREEN}测试项目创建成功: ${TEST_DIR}${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Ruby安装...${NC}"
    
    # 重新加载环境变量
    if [[ "$INSTALL_METHOD" == "rbenv" ]]; then
        export PATH="$RBENV_ROOT/bin:$PATH"
        eval "$(rbenv init -)"
    elif [[ "$INSTALL_METHOD" == "rvm" ]]; then
        source "$RVM_PATH/scripts/rvm"
    fi
    
    # 检查Ruby版本
    if command -v ruby &> /dev/null; then
        ruby_version=$(ruby --version)
        log "${GREEN}Ruby安装成功!${NC}"
        log "${GREEN}${ruby_version}${NC}"
        
        # 显示gem版本
        gem_version=$(gem --version)
        log "${GREEN}Gem版本: ${gem_version}${NC}"
        
        # 显示安装位置
        log "${CYAN}Ruby路径: $(which ruby)${NC}"
        log "${CYAN}Gem路径: $(which gem)${NC}"
        
        # 测试Ruby
        log "${CYAN}测试Ruby功能...${NC}"
        ruby -e "puts 'Ruby is working!'"
        ruby -e "p RUBY_VERSION"
    else
        log "${RED}错误: Ruby安装验证失败${NC}"
        exit 1
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Ruby环境安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- Ruby版本: ${RUBY_VERSION}"
    echo "- 安装方式: ${INSTALL_METHOD}"
    
    if [[ "$INSTALL_METHOD" == "rbenv" ]]; then
        echo "- rbenv路径: ${RBENV_ROOT}"
    elif [[ "$INSTALL_METHOD" == "rvm" ]]; then
        echo "- RVM路径: ${RVM_PATH}"
    fi
    
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        echo "- Gem源: https://gems.ruby-china.com/"
    fi
    
    echo
    echo -e "${CYAN}使用说明:${NC}"
    echo "1. 运行Ruby脚本: ruby script.rb"
    echo "2. 进入交互式环境: irb"
    echo "3. 安装gem包: gem install <package>"
    echo "4. 使用Bundler: bundle install"
    
    if [[ "$INSTALL_METHOD" == "rbenv" ]]; then
        echo
        echo -e "${CYAN}rbenv使用说明:${NC}"
        echo "- 列出可用版本: rbenv install -l"
        echo "- 安装新版本: rbenv install <version>"
        echo "- 切换版本: rbenv global <version>"
        echo "- 查看当前版本: rbenv version"
        echo "- 刷新shims: rbenv rehash"
    elif [[ "$INSTALL_METHOD" == "rvm" ]]; then
        echo
        echo -e "${CYAN}RVM使用说明:${NC}"
        echo "- 列出可用版本: rvm list known"
        echo "- 安装新版本: rvm install <version>"
        echo "- 切换版本: rvm use <version> --default"
        echo "- 查看当前版本: rvm current"
        echo "- 创建gemset: rvm gemset create <name>"
    fi
    
    if [[ "$INSTALL_RAILS" = true ]]; then
        echo
        echo -e "${CYAN}Rails使用说明:${NC}"
        echo "- 创建新应用: rails new myapp"
        echo "- 启动服务器: rails server"
        echo "- 生成控制器: rails generate controller"
        echo "- 数据库迁移: rails db:migrate"
    fi
    
    echo
    echo -e "${CYAN}常用命令:${NC}"
    echo "- gem list              # 列出已安装的gem"
    echo "- gem search <name>     # 搜索gem"
    echo "- gem update            # 更新所有gem"
    echo "- bundle init           # 创建Gemfile"
    echo "- bundle exec <cmd>     # 在bundle环境中执行命令"
    
    echo
    echo -e "${YELLOW}注意事项:${NC}"
    echo "1. 请重新打开终端或执行 source ~/.bashrc 以加载环境变量"
    echo "2. 首次使用可能需要执行 rbenv rehash (rbenv) 或 rvm reload (rvm)"
    echo "3. 建议为每个项目使用独立的Gemfile管理依赖"
    
    if [[ -d "$HOME/ruby_test" ]]; then
        echo
        echo -e "${YELLOW}测试项目位置: $HOME/ruby_test${NC}"
        echo -e "${YELLOW}运行测试应用: cd $HOME/ruby_test && ruby app.rb${NC}"
    fi
    
    echo
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
                RUBY_VERSION="$2"
                shift 2
                ;;
            --install-rails)
                INSTALL_RAILS=true
                shift
                ;;
            --install-bundler)
                INSTALL_BUNDLER=true
                shift
                ;;
            --china-mirror)
                USE_CHINA_MIRROR=true
                shift
                ;;
            --dev-tools)
                INSTALL_DEV_TOOLS=true
                shift
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
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_ruby_installed
    
    # 安装依赖
    install_dependencies
    
    # 根据方式安装
    case $INSTALL_METHOD in
        system)
            install_system_ruby
            ;;
        rbenv)
            install_rbenv
            ;;
        rvm)
            install_rvm
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
    
    # 配置镜像
    configure_china_mirrors
    
    # 安装额外组件
    if [[ "$INSTALL_BUNDLER" = true ]] || [[ "$INSTALL_RAILS" = true ]] || [[ "$INSTALL_DEV_TOOLS" = true ]]; then
        # 确保gem可用
        if ! command -v gem &> /dev/null; then
            log "${RED}错误: gem命令不可用${NC}"
            exit 1
        fi
        
        if [[ "$INSTALL_BUNDLER" = true ]]; then
            install_bundler
        fi
        
        if [[ "$INSTALL_RAILS" = true ]]; then
            install_rails
        fi
        
        if [[ "$INSTALL_DEV_TOOLS" = true ]]; then
            install_dev_tools
        fi
    fi
    
    # 创建测试项目
    create_test_project
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"