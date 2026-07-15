#!/bin/bash
set -euo pipefail
#==============================================================================
# 脚本名称: rust.sh
# 脚本描述: Rust 语言环境安装脚本 - 支持rustup、工具链管理和开发工具安装
# 脚本路径: vps_scripts/scripts/service_install/rust.sh
# 作者: everettlabs
# 使用方法: bash rust.sh [选项]
# 选项说明:
#   --channel <频道>     安装频道 (stable/beta/nightly)
#   --profile <配置>     安装配置 (minimal/default/complete)
#   --components <组件>  额外组件 (rust-src,rust-analysis,rls)
#   --targets <目标>     交叉编译目标 (如: wasm32-unknown-unknown)
#   --china-mirror      使用中国镜像源
#   --dev-tools         安装开发工具集
#   --web-tools         安装Web开发工具
#   --cargo-plugins     安装常用cargo插件
#   --no-modify-path    不修改PATH环境变量
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
RUST_CHANNEL="stable"
INSTALL_PROFILE="default"
EXTRA_COMPONENTS=""
EXTRA_TARGETS=""
USE_CHINA_MIRROR=false
INSTALL_DEV_TOOLS=false
INSTALL_WEB_TOOLS=false
INSTALL_CARGO_PLUGINS=false
MODIFY_PATH=true
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/rust_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Rust 语言环境安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash rust.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --channel <频道>     安装频道:"
    echo "                       stable  - 稳定版 (默认)"
    echo "                       beta    - 测试版"
    echo "                       nightly - 每夜版"
    echo "  --profile <配置>     安装配置:"
    echo "                       minimal  - 最小安装"
    echo "                       default  - 默认安装"
    echo "                       complete - 完整安装"
    echo "  --components <组件>  额外组件 (逗号分隔):"
    echo "                       rust-src       - Rust源码"
    echo "                       rust-analysis  - 代码分析"
    echo "                       rls            - Rust语言服务器"
    echo "                       rust-analyzer  - 新版语言服务器"
    echo "                       clippy         - 代码检查工具"
    echo "                       rustfmt        - 代码格式化"
    echo "  --targets <目标>     交叉编译目标 (逗号分隔):"
    echo "                       wasm32-unknown-unknown - WebAssembly"
    echo "                       x86_64-pc-windows-gnu  - Windows"
    echo "                       aarch64-linux-android  - Android"
    echo "  --china-mirror      使用中国镜像源加速"
    echo "  --dev-tools         安装开发工具集"
    echo "  --web-tools         安装Web开发工具"
    echo "  --cargo-plugins     安装常用cargo插件"
    echo "  --no-modify-path    不修改PATH环境变量"
    echo "  --force             强制重新安装"
    echo "  --help              显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash rust.sh                                      # 默认安装"
    echo "  bash rust.sh --channel nightly --dev-tools"
    echo "  bash rust.sh --china-mirror --cargo-plugins"
    echo "  bash rust.sh --targets wasm32-unknown-unknown --web-tools"
    echo "  bash rust.sh --components rust-src,rust-analyzer"
}

# 检查权限
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log "${YELLOW}警告: 建议以普通用户身份安装Rust${NC}"
        log "${YELLOW}root用户安装可能导致权限问题${NC}"
        read -p "是否继续? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
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
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            RUST_ARCH="x86_64"
            ;;
        aarch64)
            RUST_ARCH="aarch64"
            ;;
        armv7l)
            RUST_ARCH="armv7"
            ;;
        *)
            log "${RED}错误: 不支持的系统架构 ${ARCH}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}检测到系统: ${OS} ${VER} (${ARCH})${NC}"
}

# 安装基础依赖
install_dependencies() {
    log "${YELLOW}正在安装基础依赖...${NC}"
    
    case $OS in
        ubuntu|debian)
            if [[ $EUID -eq 0 ]]; then
                apt-get update
                apt-get install -y \
                    build-essential \
                    curl \
                    wget \
                    git \
                    pkg-config \
                    libssl-dev \
                    cmake
            else
                log "${YELLOW}需要sudo权限安装依赖${NC}"
                sudo apt-get update
                sudo apt-get install -y \
                    build-essential \
                    curl \
                    wget \
                    git \
                    pkg-config \
                    libssl-dev \
                    cmake
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ $EUID -eq 0 ]]; then
                yum groupinstall -y "Development Tools"
                yum install -y \
                    curl \
                    wget \
                    git \
                    pkgconfig \
                    openssl-devel \
                    cmake
            else
                log "${YELLOW}需要sudo权限安装依赖${NC}"
                sudo yum groupinstall -y "Development Tools"
                sudo yum install -y \
                    curl \
                    wget \
                    git \
                    pkgconfig \
                    openssl-devel \
                    cmake
            fi
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}基础依赖安装完成${NC}"
}

# 检查Rust是否已安装
check_rust_installed() {
    if command -v rustc &> /dev/null && [[ "$FORCE_INSTALL" = false ]]; then
        local current_version=$(rustc --version 2>&1)
        log "${YELLOW}检测到Rust已安装: ${current_version}${NC}"
        read -p "是否继续安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "${YELLOW}安装已取消${NC}"
            exit 0
        fi
    fi
}

# 配置中国镜像
configure_china_mirrors() {
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        log "${CYAN}配置中国镜像源...${NC}"
        
        # 设置rustup镜像
        export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
        export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
        
        # 创建cargo配置目录
        mkdir -p "$CARGO_HOME"
        
        # 配置cargo镜像
        cat > "$CARGO_HOME/config.toml" << 'EOF'
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"

[net]
git-fetch-with-cli = true

[http]
check-revoke = false
EOF
        
        log "${GREEN}中国镜像源配置完成${NC}"
    fi
}

# 安装rustup
install_rustup() {
    log "${CYAN}安装rustup...${NC}"
    
    # 设置安装选项
    local rustup_init_args="--default-toolchain $RUST_CHANNEL --profile $INSTALL_PROFILE"
    
    if [[ "$MODIFY_PATH" = false ]]; then
        rustup_init_args="$rustup_init_args --no-modify-path"
    fi
    
    # 下载并运行rustup安装脚本
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
        export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
    fi
    
    local rustup_script
    rustup_script=$(mktemp "/tmp/rustup-init.XXXXXX") || { log "${RED}创建临时文件失败${NC}"; exit 1; }
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$rustup_script"; then
        log "${RED}错误: 下载rustup安装脚本失败${NC}"
        rm -f -- "$rustup_script"
        exit 1
    fi
    # shellcheck disable=SC2086
    sh "$rustup_script" -y $rustup_init_args
    rm -f -- "$rustup_script"
    
    # 加载环境变量
    source "$CARGO_HOME/env"
    
    log "${GREEN}rustup安装完成${NC}"
}

# 安装额外组件
install_components() {
    if [[ -n "$EXTRA_COMPONENTS" ]]; then
        log "${CYAN}安装额外组件...${NC}"
        
        # 分割组件列表
        IFS=',' read -ra COMPONENTS <<< "$EXTRA_COMPONENTS"
        for component in "${COMPONENTS[@]}"; do
            log "${YELLOW}安装组件: $component${NC}"
            rustup component add "$component"
        done
    fi
    
    # 安装常用组件
    log "${CYAN}安装常用组件...${NC}"
    rustup component add rustfmt clippy
}

# 安装交叉编译目标
install_targets() {
    if [[ -n "$EXTRA_TARGETS" ]]; then
        log "${CYAN}安装交叉编译目标...${NC}"
        
        # 分割目标列表
        IFS=',' read -ra TARGETS <<< "$EXTRA_TARGETS"
        for target in "${TARGETS[@]}"; do
            log "${YELLOW}安装目标: $target${NC}"
            rustup target add "$target"
        done
    fi
}

# 安装开发工具
install_dev_tools() {
    log "${CYAN}安装Rust开发工具集...${NC}"
    
    # 基础开发工具
    local tools=(
        "cargo-edit"        # 添加/更新/删除依赖
        "cargo-watch"       # 文件监控自动编译
        "cargo-expand"      # 宏展开
        "cargo-outdated"    # 检查过期依赖
        "cargo-audit"       # 安全审计
        "cargo-tree"        # 依赖树查看
        "cargo-bloat"       # 二进制大小分析
        "cargo-udeps"       # 查找未使用的依赖
        "tokei"            # 代码统计
        "bat"              # 带语法高亮的cat
        "exa"              # 现代化的ls
        "ripgrep"          # 快速搜索工具
        "fd-find"          # 现代化的find
        "hyperfine"        # 基准测试工具
        "cargo-flamegraph" # 性能分析火焰图
    )
    
    for tool in "${tools[@]}"; do
        log "${YELLOW}安装 $tool...${NC}"
        cargo install "$tool" || log "${RED}$tool 安装失败(非致命)${NC}"
    done
    
    # 安装sccache（编译缓存）
    log "${YELLOW}安装sccache编译缓存...${NC}"
    cargo install sccache || log "${RED}sccache 安装失败(非致命)${NC}"
    
    # 配置sccache
    echo 'export RUSTC_WRAPPER=sccache' >> ~/.bashrc
    if [[ -f ~/.zshrc ]]; then
        echo 'export RUSTC_WRAPPER=sccache' >> ~/.zshrc
    fi
    
    log "${GREEN}开发工具集安装完成${NC}"
}

# 安装Web开发工具
install_web_tools() {
    log "${CYAN}安装Rust Web开发工具...${NC}"
    
    # 安装wasm-pack
    log "${YELLOW}安装wasm-pack...${NC}"
    local wasm_pack_script
    wasm_pack_script=$(mktemp "/tmp/wasm-pack-install.XXXXXX") || { log "${RED}创建临时文件失败${NC}"; return 1; }
    if curl -sSf https://rustwasm.github.io/wasm-pack/installer/init.sh -o "$wasm_pack_script"; then
        sh "$wasm_pack_script"
    else
        log "${RED}wasm-pack 下载失败${NC}"
    fi
    rm -f -- "$wasm_pack_script"
    
    # 安装trunk (WASM web应用打包工具)
    log "${YELLOW}安装trunk...${NC}"
    cargo install trunk
    
    # 安装其他Web相关工具
    local web_tools=(
        "wasm-bindgen-cli"  # WASM绑定生成
        "cargo-web"         # Web项目管理
        "basic-http-server" # 简单HTTP服务器
        "miniserve"        # 另一个HTTP服务器
    )
    
    for tool in "${web_tools[@]}"; do
        log "${YELLOW}安装 $tool...${NC}"
        cargo install "$tool" || log "${RED}$tool 安装失败(非致命)${NC}"
    done
    
    log "${GREEN}Web开发工具安装完成${NC}"
}

# 安装cargo插件
install_cargo_plugins() {
    log "${CYAN}安装常用cargo插件...${NC}"
    
    local plugins=(
        "cargo-make"        # 任务运行器
        "cargo-generate"    # 项目模板生成
        "cargo-deny"        # 依赖检查
        "cargo-release"     # 发布自动化
        "cargo-tarpaulin"   # 代码覆盖率
        "cargo-criterion"   # 基准测试框架
        "cargo-nextest"     # 下一代测试运行器
        "cargo-machete"     # 查找未使用的依赖
        "cargo-update"      # 更新已安装的工具
        "cross"            # 交叉编译工具
    )
    
    for plugin in "${plugins[@]}"; do
        log "${YELLOW}安装 $plugin...${NC}"
        cargo install "$plugin" || log "${RED}$plugin 安装失败(非致命)${NC}"
    done
    
    log "${GREEN}cargo插件安装完成${NC}"
}

# 创建测试项目
create_test_project() {
    log "${CYAN}创建Rust测试项目...${NC}"
    
    # 创建测试目录
    TEST_DIR="$HOME/rust_test"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # 创建Hello World项目
    cargo new hello_rust
    cd hello_rust
    
    # 修改main.rs
    cat > src/main.rs << 'EOF'
use std::env;

fn main() {
    println!("Hello from Rust!");
    println!("Rust version: {}", env!("RUSTC_VERSION"));
    
    // 显示系统信息
    println!("\nSystem Info:");
    println!("OS: {}", env::consts::OS);
    println!("Architecture: {}", env::consts::ARCH);
    
    // 简单的向量操作示例
    let numbers = vec![1, 2, 3, 4, 5];
    let sum: i32 = numbers.iter().sum();
    println!("\nSum of {:?} = {}", numbers, sum);
    
    // 字符串操作示例
    let greeting = String::from("Hello");
    let name = "Rust";
    let message = format!("{}, {}! 🦀", greeting, name);
    println!("\n{}", message);
}
EOF
    
    # 创建一个库项目示例
    cd "$TEST_DIR"
    cargo new rust_lib --lib
    cd rust_lib
    
    # 创建库代码
    cat > src/lib.rs << 'EOF'
//! 一个简单的Rust库示例

/// 计算两个数的和
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

/// 问候函数
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 3), 5);
    }

    #[test]
    fn test_greet() {
        assert_eq!(greet("Rust"), "Hello, Rust!");
    }
}
EOF
    
    # 编译测试项目
    log "${YELLOW}编译测试项目...${NC}"
    cd "$TEST_DIR/hello_rust"
    cargo build
    
    log "${GREEN}测试项目创建成功: ${TEST_DIR}${NC}"
}

# 配置开发环境
configure_dev_environment() {
    log "${CYAN}配置开发环境...${NC}"
    
    # 创建rustfmt配置
    cat > "$HOME/.rustfmt.toml" << 'EOF'
# Rust代码格式化配置
edition = "2021"
max_width = 100
tab_spaces = 4
use_field_init_shorthand = true
use_try_shorthand = true
EOF
    
    # 创建clippy配置
    cat > "$HOME/.clippy.toml" << 'EOF'
# Clippy代码检查配置
avoid-breaking-exported-api = false
msrv = "1.56.0"
EOF
    
    # 添加有用的别名
    if [[ -f ~/.bashrc ]]; then
        cat >> ~/.bashrc << 'EOF'

# Rust别名
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias cf='cargo fmt'
alias cl='cargo clippy'
alias cu='cargo update'
alias cw='cargo watch -x run'
EOF
    fi
    
    log "${GREEN}开发环境配置完成${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Rust安装...${NC}"
    
    # 重新加载环境变量
    source "$CARGO_HOME/env"
    
    # 检查Rust版本
    if command -v rustc &> /dev/null; then
        rustc_version=$(rustc --version)
        cargo_version=$(cargo --version)
        
        log "${GREEN}Rust安装成功!${NC}"
        log "${GREEN}Rustc: ${rustc_version}${NC}"
        log "${GREEN}Cargo: ${cargo_version}${NC}"
        
        # 显示安装信息
        log "${CYAN}工具链信息:${NC}"
        rustup show
        
        # 显示已安装的组件
        log "${CYAN}已安装的组件:${NC}"
        rustup component list --installed
        
        # 显示已安装的目标
        log "${CYAN}已安装的编译目标:${NC}"
        rustup target list --installed
    else
        log "${RED}错误: Rust安装验证失败${NC}"
        exit 1
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Rust环境安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- Rust频道: ${RUST_CHANNEL}"
    echo "- 安装配置: ${INSTALL_PROFILE}"
    echo "- RUSTUP_HOME: ${RUSTUP_HOME}"
    echo "- CARGO_HOME: ${CARGO_HOME}"
    
    if [[ "$USE_CHINA_MIRROR" = true ]]; then
        echo "- 镜像源: USTC (中国科学技术大学)"
    fi
    
    echo
    echo -e "${CYAN}快速开始:${NC}"
    echo "1. 创建新项目:"
    echo "   cargo new my_project"
    echo "   cd my_project"
    echo
    echo "2. 构建项目:"
    echo "   cargo build          # 调试构建"
    echo "   cargo build --release # 发布构建"
    echo
    echo "3. 运行项目:"
    echo "   cargo run"
    echo
    echo "4. 运行测试:"
    echo "   cargo test"
    echo
    
    echo -e "${CYAN}常用命令:${NC}"
    echo "- cargo new <n> --bin  # 创建可执行项目"
    echo "- cargo new <n> --lib  # 创建库项目"
    echo "- cargo add <crate>        # 添加依赖(需要cargo-edit)"
    echo "- cargo update             # 更新依赖"
    echo "- cargo doc --open         # 生成并打开文档"
    echo "- cargo fmt                # 格式化代码"
    echo "- cargo clippy             # 运行代码检查"
    echo "- cargo bench              # 运行基准测试"
    echo
    
    echo -e "${CYAN}Rustup管理:${NC}"
    echo "- rustup update            # 更新Rust"
    echo "- rustup default <channel> # 切换默认频道"
    echo "- rustup component add <c> # 添加组件"
    echo "- rustup target add <t>    # 添加编译目标"
    echo "- rustup self uninstall    # 卸载Rust"
    echo
    
    if [[ "$INSTALL_DEV_TOOLS" = true ]]; then
        echo -e "${CYAN}已安装的开发工具:${NC}"
        echo "- cargo-watch: 自动重新编译"
        echo "- cargo-edit: 管理依赖"
        echo "- cargo-audit: 安全审计"
        echo "- sccache: 编译缓存"
        echo "- 更多工具请查看 cargo install --list"
        echo
    fi
    
    echo -e "${YELLOW}注意事项:${NC}"
    echo "1. 请重新打开终端或执行 source ~/.cargo/env 以加载环境变量"
    echo "2. 首次编译可能需要下载依赖，请耐心等待"
    echo "3. 使用 cargo doc --open 查看依赖文档"
    echo "4. 访问 https://doc.rust-lang.org 查看官方文档"
    
    if [[ -d "$HOME/rust_test" ]]; then
        echo
        echo -e "${YELLOW}测试项目位置:${NC}"
        echo "- Hello World: $HOME/rust_test/hello_rust"
        echo "- 库项目: $HOME/rust_test/rust_lib"
        echo -e "${YELLOW}运行测试: cd $HOME/rust_test/hello_rust && cargo run${NC}"
    fi
    
    echo
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --channel)
                RUST_CHANNEL="$2"
                shift 2
                ;;
            --profile)
                INSTALL_PROFILE="$2"
                shift 2
                ;;
            --components)
                EXTRA_COMPONENTS="$2"
                shift 2
                ;;
            --targets)
                EXTRA_TARGETS="$2"
                shift 2
                ;;
            --china-mirror)
                USE_CHINA_MIRROR=true
                shift
                ;;
            --dev-tools)
                INSTALL_DEV_TOOLS=true
                shift
                ;;
            --web-tools)
                INSTALL_WEB_TOOLS=true
                shift
                ;;
            --cargo-plugins)
                INSTALL_CARGO_PLUGINS=true
                shift
                ;;
            --no-modify-path)
                MODIFY_PATH=false
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
    check_permissions
    
    # 检测系统
    detect_system
    
    # 检查是否已安装
    check_rust_installed
    
    # 安装依赖
    install_dependencies
    
    # 配置镜像
    configure_china_mirrors
    
    # 安装rustup
    install_rustup
    
    # 安装组件
    install_components
    
    # 安装编译目标
    install_targets
    
    # 安装额外工具
    if [[ "$INSTALL_DEV_TOOLS" = true ]]; then
        install_dev_tools
    fi
    
    if [[ "$INSTALL_WEB_TOOLS" = true ]]; then
        install_web_tools
    fi
    
    if [[ "$INSTALL_CARGO_PLUGINS" = true ]]; then
        install_cargo_plugins
    fi
    
    # 配置开发环境
    configure_dev_environment
    
    # 创建测试项目
    create_test_project
    
    # 验证安装
    verify_installation
    
    # 显示安装后信息
    show_post_install_info
}

# 执行主函数
main "$@"