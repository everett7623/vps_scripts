#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/install_deps.sh
# Purpose: Install baseline, development, monitoring, and security dependencies.
# ==============================================================================

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_FILE="/tmp/install_deps_$(date +%Y%m%d_%H%M%S).log"
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    # shellcheck source=/dev/null
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    [ -n "${LOG_DIR:-}" ] && LOG_FILE="${LOG_DIR}/install_deps.log"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[完成] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    print_key_value() { printf "%b%-14s%b %s\n" "${CYAN}" "${1}:" "${NC}" "${2:-}"; }
    print_step() { printf "%b[%s/%s]%b %s\n" "${PURPLE}" "${1}" "${2}" "${NC}" "${3}"; }
    print_runtime_context() { print_key_value "脚本" "$1"; print_key_value "模式" "${2:-交互模式}"; [ -n "${3:-}" ] && print_key_value "日志" "$3"; echo ""; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}此脚本需要 root 权限。${NC}"; exit 1; }; }
    get_os_release() { [ -f /etc/os-release ] && . /etc/os-release && echo "$ID" || echo "unknown"; }
fi

[ -z "${BASIC_PACKAGES:-}" ] && BASIC_PACKAGES="curl wget git vim nano htop iotop iftop net-tools dnsutils mtr traceroute tcpdump telnet openssh-server ca-certificates gnupg lsb-release software-properties-common unzip zip tar gzip bzip2 screen tmux tree jq bc rsync cron logrotate"
[ -z "${DEV_PACKAGES:-}" ] && DEV_PACKAGES="build-essential gcc g++ make cmake automake autoconf libtool pkg-config python3 python3-pip python3-dev nodejs npm golang default-jdk maven ruby perl php-cli composer docker.io docker-compose ansible terraform"
MONITOR_PACKAGES="sysstat iostat vmstat dstat nmon glances nethogs iptraf-ng nload speedtest-cli sysbench stress fio"
SECURITY_PACKAGES="fail2ban ufw iptables-persistent rkhunter chkrootkit lynis aide clamav clamav-daemon"

PKG_MANAGER=""
OS_TYPE=""

declare -a UPDATE_CMD=()
declare -a INSTALL_CMD=()

detect_package_manager() {
    OS_TYPE=$(get_os_release)
    case "$OS_TYPE" in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            UPDATE_CMD=(apt-get update -qq)
            INSTALL_CMD=(apt-get install -y -qq)
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
                UPDATE_CMD=(dnf makecache -q)
                INSTALL_CMD=(dnf install -y -q)
            else
                PKG_MANAGER="yum"
                UPDATE_CMD=(yum makecache -q)
                INSTALL_CMD=(yum install -y -q)
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            UPDATE_CMD=(apk update)
            INSTALL_CMD=(apk add)
            ;;
        *)
            print_error "不支持的操作系统：$OS_TYPE"
            exit 1
            ;;
    esac

    print_info "检测到系统：$OS_TYPE（软件包管理器：$PKG_MANAGER）"
}

adjust_package_names() {
    local list="$1"
    case "$OS_TYPE" in
        centos|rhel|fedora|rocky|almalinux|amzn)
            list=${list//dnsutils/bind-utils}
            list=${list//software-properties-common/}
            list=${list//apt-transport-https/}
            list=${list//lsb-release/redhat-lsb-core}
            list=${list//build-essential/gcc-c++ kernel-devel kernel-headers}
            list=${list//default-jdk/java-11-openjdk-devel}
            list=${list//docker.io/docker-ce}
            list=${list//ufw/firewalld}
            ;;
        alpine)
            list=${list//dnsutils/bind-tools}
            list=${list//build-essential/build-base}
            list=${list//python3-dev/python3-dev python3}
            list=${list//docker-compose/docker-cli-compose}
            ;;
    esac
    echo "$list"
}

package_is_installed() {
    local package="$1"
    case "$PKG_MANAGER" in
        apt)
            dpkg -s "$package" >/dev/null 2>&1
            ;;
        yum|dnf)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        apk)
            apk info -e "$package" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

normalize_package_list() {
    local raw_list="$1"
    local package=""
    local normalized=()
    local seen=" "

    for package in $raw_list; do
        [ -z "$package" ] && continue
        if [[ "$seen" == *" $package "* ]]; then
            continue
        fi
        seen="${seen}${package} "
        normalized+=("$package")
    done

    printf '%s\n' "${normalized[@]}"
}

run_update_cache() {
    print_info "正在刷新软件包元数据..."
    if env DEBIAN_FRONTEND=noninteractive "${UPDATE_CMD[@]}" >> "$LOG_FILE" 2>&1; then
        print_success "软件包元数据刷新完成。"
    else
        print_warn "软件包元数据刷新出现问题，将继续执行。"
    fi
}

install_one_package() {
    local package="$1"
    env DEBIAN_FRONTEND=noninteractive "${INSTALL_CMD[@]}" "$package" >> "$LOG_FILE" 2>&1
}

configure_extra_repos() {
    print_info "正在按需配置附加软件源..."

    case "$OS_TYPE" in
        ubuntu|debian)
            if ! command -v docker >/dev/null 2>&1; then
                install_one_package ca-certificates || true
                install_one_package curl || true
                install_one_package gnupg || true
                install_one_package lsb-release || true

                mkdir -p /usr/share/keyrings
                if curl -fsSL "https://download.docker.com/linux/${OS_TYPE}/gpg" \
                    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${OS_TYPE} $(lsb_release -cs) stable" \
                        > /etc/apt/sources.list.d/docker.list
                else
                    print_warn "Docker 软件源密钥配置失败。"
                fi
            fi

            if ! command -v node >/dev/null 2>&1; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - >> "$LOG_FILE" 2>&1 || \
                    print_warn "NodeSource 初始化失败。"
            fi
            ;;
        centos|rhel|rocky|almalinux)
            if ! rpm -q epel-release >/dev/null 2>&1; then
                install_one_package epel-release || print_warn "安装 epel-release 失败。"
            fi
            if ! command -v docker >/dev/null 2>&1 && command -v yum-config-manager >/dev/null 2>&1; then
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >> "$LOG_FILE" 2>&1 || \
                    print_warn "添加 Docker CE 软件源失败。"
            fi
            ;;
    esac
}

install_pkg_list() {
    local raw_list="$1"
    local adjusted_list
    local package_list=()
    local to_install=()
    local installed=()
    local failed=()
    local package=""
    local total=0
    local current=0

    adjusted_list=$(adjust_package_names "$raw_list")
    while IFS= read -r package; do
        [ -z "$package" ] && continue
        package_list+=("$package")
    done < <(normalize_package_list "$adjusted_list")

    for package in "${package_list[@]}"; do
        if package_is_installed "$package"; then
            installed+=("$package")
        else
            to_install+=("$package")
        fi
    done

    if [ ${#installed[@]} -gt 0 ]; then
        print_info "跳过已安装的软件包（${#installed[@]} 个）：${installed[*]}"
    fi

    total=${#to_install[@]}
    if [ "$total" -eq 0 ]; then
        print_success "所需软件包均已安装。"
        return 0
    fi

    print_info "正在安装 $total 个软件包..."

    for package in "${to_install[@]}"; do
        current=$((current + 1))
        print_step "${current}" "${total}" "正在安装 ${package}"
        if install_one_package "$package"; then
            :
        else
            print_error "安装失败：$package"
            failed+=("$package")
        fi
    done
    echo ""

    if [ ${#failed[@]} -eq 0 ]; then
        print_success "所需软件包安装完成。"
        return 0
    fi

    print_warn "部分软件包安装失败，请查看日志：$LOG_FILE"
    echo "${failed[*]}"
    return 1
}

post_install_setup() {
    local service=""
    local services=("ssh" "sshd" "cron" "crond" "docker")

    print_info "正在执行安装后的服务配置..."

    if command -v systemctl >/dev/null 2>&1; then
        for service in "${services[@]}"; do
            if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
                systemctl enable "$service" >> "$LOG_FILE" 2>&1 || true
                systemctl start "$service" >> "$LOG_FILE" 2>&1 || true
            fi
        done
    fi

    if command -v git >/dev/null 2>&1; then
        git config --global init.defaultBranch main
        git config --global color.ui auto
    fi
}

run_install_flow() {
    local package_groups="$1"
    local status=0

    configure_extra_repos
    run_update_cache
    install_pkg_list "$package_groups" || status=$?
    post_install_setup
    return "$status"
}

custom_menu() {
    local install_list=""
    local selections=""

    clear
    print_header "自定义依赖安装"
    echo "1. 基础工具"
    echo "2. 开发工具"
    echo "3. 监控工具"
    echo "4. 安全工具"
    echo "0. 返回"
    echo ""
    read -r -p "请输入一个或多个选项（例如：1 3）: " selections

    [[ "$selections" == "0" ]] && return
    [[ "$selections" == *"1"* ]] && install_list="$install_list $BASIC_PACKAGES"
    [[ "$selections" == *"2"* ]] && install_list="$install_list $DEV_PACKAGES"
    [[ "$selections" == *"3"* ]] && install_list="$install_list $MONITOR_PACKAGES"
    [[ "$selections" == *"4"* ]] && install_list="$install_list $SECURITY_PACKAGES"

    if [ -z "$install_list" ]; then
        print_warn "未选择有效的软件包分组。"
        sleep 1
        return
    fi

    run_install_flow "$install_list"
    read -n 1 -s -r -p "按任意键返回..."
}

interactive_menu() {
    local status=0

    while true; do
        clear
        print_header "常用依赖安装向导"
        print_runtime_context "install_deps.sh" "软件包安装" "${LOG_FILE}"
        print_key_value "当前系统" "$OS_TYPE ($PKG_MANAGER)"
        echo ""
        echo "1. 安装基础工具"
        echo "2. 安装开发工具"
        echo "3. 安装监控与安全工具"
        echo "4. 安装全部工具"
        echo "5. 自定义选择"
        echo "0. 退出"
        echo ""
        read -r -p "请选择 [0-5]: " choice

        status=0
        case "$choice" in
            1) run_install_flow "$BASIC_PACKAGES" || status=$? ;;
            2) run_install_flow "$DEV_PACKAGES" || status=$? ;;
            3) run_install_flow "$MONITOR_PACKAGES $SECURITY_PACKAGES" || status=$? ;;
            4) run_install_flow "$BASIC_PACKAGES $DEV_PACKAGES $MONITOR_PACKAGES $SECURITY_PACKAGES" || status=$? ;;
            5) custom_menu; continue ;;
            0) exit 0 ;;
            *) print_error "无效选项"; sleep 1; continue ;;
        esac

        echo ""
        if [ "$status" -eq 0 ]; then
            print_success "任务执行完成。"
        else
            print_warn "任务已完成，但存在警告，请查看：$LOG_FILE"
        fi
        read -n 1 -s -r -p "按任意键返回..."
    done
}

main() {
    case "${1:-}" in
        --help|-h)
            echo "用法：bash install_deps.sh [--basic | --dev | --all]"
            return 0
            ;;
    esac

    check_root
    detect_package_manager
    if [ -n "${1:-}" ]; then
        print_header "常用依赖安装向导"
        print_runtime_context "install_deps.sh" "软件包安装" "${LOG_FILE}"
        print_key_value "当前系统" "$OS_TYPE ($PKG_MANAGER)"
        echo ""
    fi

    case "${1:-}" in
        --basic)
            run_install_flow "$BASIC_PACKAGES"
            ;;
        --dev)
            run_install_flow "$DEV_PACKAGES"
            ;;
        --all)
            run_install_flow "$BASIC_PACKAGES $DEV_PACKAGES $MONITOR_PACKAGES $SECURITY_PACKAGES"
            ;;
        "")
            interactive_menu
            ;;
        *)
            print_error "未知参数：$1"
            exit 1
            ;;
    esac
}

main "$@"
