#!/bin/bash
#==============================================================================
# 脚本名称: go.sh
# 脚本描述: Go 语言环境安装脚本 - 支持官方二进制包和源码编译安装
# 脚本路径: vps_scripts/scripts/service_install/go.sh
# 作者: Jensfrank
# 使用方法: bash go.sh [选项]
# 选项说明:
#   --version <版本>    Go版本 (如: 1.21.5, 1.20.12)
#   --install-tools    安装常用Go工具
#   --setup-proxy      配置Go代理(国内加速)
#   --install-path     自定义安装路径(默认/usr/local)
#   --force           强制重新安装
#   --help            显示帮助信息
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
GO_VERSION=""
INSTALL_TOOLS=false
SETUP_PROXY=false
INSTALL_PATH="/usr/local"
FORCE_INSTALL=false
SCRIPT_VERSION="1.0.0"
LOG_FILE="/tmp/go_install_$(date +%Y%m%d_%H%M%S).log"

# 默认配置
DEFAULT_GO_VERSION="1.21.5"
GOPATH="$HOME/go"

# 记录日志
log() {
    echo -e "${1}" | tee -a "${LOG_FILE}"
}

# 显示标题
show_title() {
    clear
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${CYAN}    Go 语言环境安装脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
}

# 显示帮助信息
show_help() {
    echo -e "${GREEN}使用方法:${NC}"
    echo "  bash go.sh [选项]"
    echo
    echo -e "${GREEN}选项说明:${NC}"
    echo "  --version <版本>    指定Go版本 (如: 1.21.5, 1.20.12)"
    echo "                     不指定则安装最新稳定版"
    echo "  --install-tools    安装常用Go开发工具:"
    echo "                     - golangci-lint (代码检查)"
    echo "                     - delve (调试器)"
    echo "                     - air (热重载)"
    echo "                     - cobra-cli (CLI框架)"
    echo "  --setup-proxy      配置Go代理(国内加速):"
    echo "                     - GOPROXY=https://goproxy.cn"
    echo "  --install-path     自定义安装路径(默认/usr/local)"
    echo "  --force           强制重新安装"
    echo "  --help            显示此帮助信息"
    echo
    echo -e "${GREEN}示例:${NC}"
    echo "  bash go.sh                                     # 安装最新版Go"
    echo "  bash go.sh --version 1.21.5"
    echo "  bash go.sh --version 1.20.12 --install-tools"
    echo "  bash go.sh --setup-proxy --install-tools"
    echo "  bash go.sh --install-path /opt --force"
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
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            GO_ARCH="amd64"
            ;;
        i686)
            GO_ARCH="386"
            ;;
        aarch64)
            GO_ARCH="arm64"
            ;;
        armv7l)
            GO_ARCH="armv6l"
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
            apt-get update
            apt-get install -y wget curl git build-essential
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y wget curl git gcc make
            ;;
        *)
            log "${RED}错误: 不支持的系统类型 ${OS}${NC}"
            exit 1
            ;;
    esac
    
    log "${GREEN}基础依赖安装完成${NC}"
}

# 检查Go是否已安装
check_go_installed() {
    if command -v go &> /dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [[ "$FORCE_INSTALL" = false ]]; then
            log "${YELLOW}检测到已安装的Go版本: ${current_version}${NC}"
            read -p "是否继续安装? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "${YELLOW}安装已取消${NC}"
                exit 0
            fi
        fi
    fi
}

# 获取最新Go版本
get_latest_go_version() {
    log "${CYAN}获取最新Go版本...${NC}"
    
    # 从官方API获取最新版本
    local latest_version=$(curl -s https://go.dev/VERSION?m=text | head -1)
    
    if [[ -z "$latest_version" ]]; then
        # 如果获取失败，使用默认版本
        latest_version="go${DEFAULT_GO_VERSION}"
    fi
    
    # 去掉版本号前面的"go"
    GO_VERSION=${latest_version#go}
    log "${GREEN}最新Go版本: ${GO_VERSION}${NC}"
}

# 下载并安装Go
install_go() {
    # 如果没有指定版本，获取最新版本
    if [[ -z "$GO_VERSION" ]]; then
        get_latest_go_version
    fi
    
    log "${CYAN}开始安装 Go ${GO_VERSION}...${NC}"
    
    # 构建下载URL
    GO_DOWNLOAD_URL="https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    
    # 如果下载失败，尝试使用镜像站点
    MIRROR_URLS=(
        "https://golang.google.cn/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
        "https://mirrors.aliyun.com/golang/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
    )
    
    # 下载Go
    cd /tmp
    log "${YELLOW}正在下载 Go ${GO_VERSION}...${NC}"
    
    if ! wget -O go.tar.gz "$GO_DOWNLOAD_URL" 2>/dev/null; then
        log "${YELLOW}官方源下载失败，尝试镜像站点...${NC}"
        for mirror in "${MIRROR_URLS[@]}"; do
            if wget -O go.tar.gz "$mirror" 2>/dev/null; then
                log "${GREEN}从镜像站点下载成功${NC}"
                break
            fi
        done
    fi
    
    if [[ ! -f go.tar.gz ]]; then
        log "${RED}错误: Go下载失败${NC}"
        exit 1
    fi
    
    # 清理旧版本
    if [[ -d "${INSTALL_PATH}/go" ]]; then
        log "${YELLOW}删除旧版本Go...${NC}"
        rm -rf "${INSTALL_PATH}/go"
    fi
    
    # 解压安装
    log "${YELLOW}正在安装 Go...${NC}"
    tar -xzf go.tar.gz -C "${INSTALL_PATH}"
    
    # 清理下载文件
    rm -f go.tar.gz
    
    log "${GREEN}Go ${GO_VERSION} 安装完成${NC}"
}

# 配置Go环境变量
configure_go_env() {
    log "${CYAN}配置Go环境变量...${NC}"
    
    # 创建Go环境配置文件
    cat > /etc/profile.d/go.sh << EOF
# Go environment variables
export GOROOT=${INSTALL_PATH}/go
export GOPATH=${GOPATH}
export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH
EOF

    # 如果设置代理
    if [[ "$SETUP_PROXY" = true ]]; then
        cat >> /etc/profile.d/go.sh << EOF

# Go proxy settings
export GO111MODULE=on
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn
EOF
        log "${GREEN}已配置Go代理加速${NC}"
    fi
    
    # 创建GOPATH目录结构
    mkdir -p "${GOPATH}"/{bin,src,pkg}
    
    # 为当前会话加载环境变量
    export GOROOT="${INSTALL_PATH}/go"
    export GOPATH="${GOPATH}"
    export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
    
    if [[ "$SETUP_PROXY" = true ]]; then
        export GO111MODULE=on
        export GOPROXY=https://goproxy.cn,direct
        export GOSUMDB=sum.golang.google.cn
    fi
    
    # 创建go和gofmt的软链接
    ln -sf "${INSTALL_PATH}/go/bin/go" /usr/bin/go
    ln -sf "${INSTALL_PATH}/go/bin/gofmt" /usr/bin/gofmt
}

# 安装常用Go工具
install_go_tools() {
    log "${CYAN}安装常用Go开发工具...${NC}"
    
    # 确保环境变量已加载
    source /etc/profile.d/go.sh
    
    # 工具列表
    declare -A tools=(
        ["golangci-lint"]="github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
        ["delve"]="github.com/go-delve/delve/cmd/dlv@latest"
        ["air"]="github.com/cosmtrek/air@latest"
        ["cobra-cli"]="github.com/spf13/cobra-cli@latest"
        ["mockgen"]="github.com/golang/mock/mockgen@latest"
        ["swag"]="github.com/swaggo/swag/cmd/swag@latest"
        ["protoc-gen-go"]="google.golang.org/protobuf/cmd/protoc-gen-go@latest"
        ["protoc-gen-go-grpc"]="google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest"
        ["wire"]="github.com/google/wire/cmd/wire@latest"
        ["migrate"]="github.com/golang-migrate/migrate/v4/cmd/migrate@latest"
    )
    
    # 安装工具
    for tool_name in "${!tools[@]}"; do
        log "${YELLOW}安装 ${tool_name}...${NC}"
        if go install "${tools[$tool_name]}" 2>/dev/null; then
            log "${GREEN}${tool_name} 安装成功${NC}"
        else
            log "${RED}${tool_name} 安装失败${NC}"
        fi
    done
    
    # 特殊处理golangci-lint（使用官方安装脚本）
    log "${YELLOW}使用官方脚本安装 golangci-lint...${NC}"
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "${GOPATH}/bin" 2>/dev/null || true
    
    log "${GREEN}Go开发工具安装完成${NC}"
}

# 创建测试项目
create_test_project() {
    log "${CYAN}创建Go测试项目...${NC}"
    
    # 创建测试目录
    TEST_DIR="${GOPATH}/src/hello"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # 创建go.mod
    go mod init hello
    
    # 创建main.go
    cat > main.go << 'EOF'
package main

import (
    "fmt"
    "runtime"
)

func main() {
    fmt.Printf("Hello, Go!\n")
    fmt.Printf("Go Version: %s\n", runtime.Version())
    fmt.Printf("OS: %s\n", runtime.GOOS)
    fmt.Printf("Arch: %s\n", runtime.GOARCH)
}
EOF
    
    # 编译运行测试
    log "${YELLOW}编译并运行测试程序...${NC}"
    go build -o hello
    ./hello
    
    log "${GREEN}测试项目创建成功: ${TEST_DIR}${NC}"
}

# 验证安装
verify_installation() {
    log "${CYAN}验证Go安装...${NC}"
    
    # 重新加载环境变量
    source /etc/profile.d/go.sh 2>/dev/null || true
    
    # 检查Go版本
    if command -v go &> /dev/null; then
        go_version=$(go version)
        log "${GREEN}Go安装成功!${NC}"
        log "${GREEN}${go_version}${NC}"
        
        # 显示Go环境信息
        log "${CYAN}Go环境信息:${NC}"
        go env GOROOT
        go env GOPATH
        go env GOPROXY
        
        # 如果安装了工具，验证工具
        if [[ "$INSTALL_TOOLS" = true ]]; then
            log "${CYAN}已安装的Go工具:${NC}"
            for tool in golangci-lint dlv air cobra-cli; do
                if command -v $tool &> /dev/null; then
                    log "${GREEN}✓ $tool${NC}"
                fi
            done
        fi
    else
        log "${RED}错误: Go安装验证失败${NC}"
        exit 1
    fi
}

# 显示安装后说明
show_post_install_info() {
    echo
    echo -e "${PURPLE}======================================${NC}"
    echo -e "${GREEN}Go语言环境安装完成!${NC}"
    echo -e "${PURPLE}======================================${NC}"
    echo
    echo -e "${CYAN}安装信息:${NC}"
    echo "- Go版本: ${GO_VERSION}"
    echo "- 安装路径: ${INSTALL_PATH}/go"
    echo "- GOPATH: ${GOPATH}"
    
    if [[ "$SETUP_PROXY" = true ]]; then
        echo "- 代理设置: 已配置国内加速"
    fi
    
    if [[ "$INSTALL_TOOLS" = true ]]; then
        echo "- 开发工具: 已安装"
    fi
    
    echo
    echo -e "${CYAN}快速开始:${NC}"
    echo "1. 创建新项目:"
    echo "   mkdir myproject && cd myproject"
    echo "   go mod init myproject"
    echo
    echo "2. 创建main.go文件:"
    echo "   package main"
    echo "   import \"fmt\""
    echo "   func main() {"
    echo "       fmt.Println(\"Hello, Go!\")"
    echo "   }"
    echo
    echo "3. 运行程序:"
    echo "   go run main.go"
    echo
    echo "4. 构建程序:"
    echo "   go build -o myapp"
    echo
    
    if [[ "$INSTALL_TOOLS" = true ]]; then
        echo -e "${CYAN}开发工具使用:${NC}"
        echo "- 代码检查: golangci-lint run"
        echo "- 调试程序: dlv debug"
        echo "- 热重载开发: air"
        echo "- 创建CLI项目: cobra-cli init"
    fi
    
    echo
    echo -e "${CYAN}常用Go命令:${NC}"
    echo "- go mod download    # 下载依赖"
    echo "- go mod tidy        # 整理依赖"
    echo "- go test ./...      # 运行测试"
    echo "- go fmt ./...       # 格式化代码"
    echo "- go vet ./...       # 静态检查"
    echo "- go get -u ./...    # 更新依赖"
    echo
    echo -e "${YELLOW}注意: 请重新登录或执行 source /etc/profile 以加载环境变量${NC}"
    echo -e "${YELLOW}测试项目位置: ${GOPATH}/src/hello${NC}"
    echo -e "${YELLOW}日志文件: ${LOG_FILE}${NC}"
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                GO_VERSION="$2"
                shift 2
                ;;
            --install-tools)
                INSTALL_TOOLS=true
                shift
                ;;
            --setup-proxy)
                SETUP_PROXY=true
                shift
                ;;
            --install-path)
                INSTALL_PATH="$2"
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
    check_go_installed
    
    # 安装依赖
    install_dependencies
    
    # 安装Go
    install_go
    
    # 配置环境变量
    configure_go_env
    
    # 安装开发工具
    if [[ "$INSTALL_TOOLS" = true ]]; then
        install_go_tools
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