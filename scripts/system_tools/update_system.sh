#!/bin/bash
# ==============================================================================
# 脚本名称: update_system.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/update_system.sh
# 描述: VPS 系统安全更新工具
#       支持全量更新、仅安全更新、内核更新，包含自动备份、清理及重启检测。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Stable & Remote Ready)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化与依赖加载
# ------------------------------------------------------------------------------

# 获取脚本真实路径
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/system_update.log"
BACKUP_DIR="/var/backups/system_update"
UPDATE_CACHE_AGE=3600  # 缓存有效期 (秒)

# 默认开关
AUTO_CONFIRM=false
UPDATE_KERNEL=false
SECURITY_ONLY=false
REBOOT_REQUIRED=false

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    [ -n "$LOG_DIR" ] && LOG_FILE="${LOG_DIR}/system_update.log"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
    get_os_release() { [ -f /etc/os-release ] && . /etc/os-release && echo "$ID" || echo "unknown"; }
fi

# 确保目录存在
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# ------------------------------------------------------------------------------
# 2. 辅助功能函数
# ------------------------------------------------------------------------------

log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
}

# 检测系统与包管理器
detect_system() {
    OS_TYPE=$(get_os_release)
    case $OS_TYPE in
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            UPDATE_CMD="apt-get update -qq"
            # 安全更新逻辑
            SEC_UPDATE_CMD="apt-get install --only-upgrade -y" 
            FULL_UPDATE_CMD="apt-get upgrade -y"
            DIST_UPDATE_CMD="apt-get dist-upgrade -y"
            CLEAN_CMD="apt-get autoremove -y && apt-get autoclean"
            CHECK_CMD="apt list --upgradable 2>/dev/null | grep -c upgradable"
            ;;
        centos|rhel|fedora|rocky|almalinux|amzn)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                UPDATE_CMD="dnf makecache -q"
                SEC_UPDATE_CMD="dnf update-minimal --security -y"
                FULL_UPDATE_CMD="dnf update -y"
                CLEAN_CMD="dnf autoremove -y && dnf clean all"
                CHECK_CMD="dnf check-update --security | grep -c security"
            else
                PKG_MANAGER="yum"
                UPDATE_CMD="yum makecache -q"
                SEC_UPDATE_CMD="yum update-minimal --security -y"
                FULL_UPDATE_CMD="yum update -y"
                CLEAN_CMD="yum autoremove -y && yum clean all"
                CHECK_CMD="yum check-update --security | grep -c security"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            UPDATE_CMD="apk update -q"
            FULL_UPDATE_CMD="apk upgrade"
            CLEAN_CMD="rm -rf /var/cache/apk/*"
            CHECK_CMD="apk list -u | wc -l"
            ;;
        pacman|arch)
            PKG_MANAGER="pacman"
            UPDATE_CMD="pacman -Sy"
            FULL_UPDATE_CMD="pacman -Su --noconfirm"
            CLEAN_CMD="pacman -Sc --noconfirm"
            CHECK_CMD="pacman -Qu | wc -l"
            ;;
        *)
            print_error "不支持的系统: $OS_TYPE"
            exit 1
            ;;
    esac
    print_info "检测到系统: $OS_TYPE (包管理器: $PKG_MANAGER)"
}

# 网络检查
check_network() {
    print_info "检查网络连接..."
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null && ! ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        print_error "网络连接失败，无法执行更新。"
        exit 1
    fi
}

# 备份配置
backup_configs() {
    print_info "正在备份关键配置..."
    local backup_path="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_path"
    
    local files=(
        "/etc/apt/sources.list" "/etc/yum.repos.d" 
        "/etc/ssh/sshd_config" "/etc/fstab" 
        "/etc/network/interfaces" "/etc/netplan"
    )
    
    for f in "${files[@]}"; do
        if [ -e "$f" ]; then cp -r "$f" "$backup_path/" 2>/dev/null; fi
    done
    
    # 导出已安装包列表
    if [ "$PKG_MANAGER" == "apt" ]; then dpkg --get-selections > "$backup_path/packages.list"; fi
    if [[ "$PKG_MANAGER" =~ (yum|dnf) ]]; then rpm -qa > "$backup_path/packages.list"; fi
    
    log "Backup created at $backup_path"
    print_success "备份完成: $backup_path"
}

# ------------------------------------------------------------------------------
# 3. 核心更新逻辑
# ------------------------------------------------------------------------------

# 刷新缓存
refresh_cache() {
    print_info "正在刷新软件包缓存..."
    local last_update=0
    # 简单的缓存时间检查 (仅针对 apt)
    if [ "$PKG_MANAGER" == "apt" ] && [ -f /var/cache/apt/pkgcache.bin ]; then
        last_update=$(stat -c %Y /var/cache/apt/pkgcache.bin)
        local now=$(date +%s)
        if (( now - last_update < UPDATE_CACHE_AGE )) && [ "$AUTO_CONFIRM" == "false" ]; then
            print_info "缓存较新，跳过刷新。"
            return
        fi
    fi
    
    eval "$UPDATE_CMD" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        print_success "缓存刷新成功。"
    else
        print_warn "缓存刷新遇到问题，尝试继续..."
    fi
}

# 检查更新
check_available_updates() {
    print_info "正在检查可用更新..."
    local count=0
    
    # 获取更新数量
    if [ "$PKG_MANAGER" == "apt" ]; then
        count=$(apt list --upgradable 2>/dev/null | grep -c "upgradable")
    elif [[ "$PKG_MANAGER" =~ (yum|dnf) ]]; then
        count=$($PKG_MANAGER check-update -q | grep -c -v "^$")
    elif [ "$PKG_MANAGER" == "apk" ]; then
        count=$(apk list -u 2>/dev/null | wc -l)
    fi
    
    if [ "$count" -eq 0 ]; then
        print_success "系统已是最新，无需更新。"
        exit 0
    else
        print_info "发现 $count 个可用更新。"
        # 显示前 10 个
        if [ "$PKG_MANAGER" == "apt" ]; then
            apt list --upgradable 2>/dev/null | head -n 11
        fi
    fi
}

# 执行更新
perform_update() {
    print_info "开始执行更新..."
    
    local cmd=""
    if [ "$SECURITY_ONLY" == "true" ] && [[ "$PKG_MANAGER" =~ (yum|dnf) ]]; then
        cmd="$SEC_UPDATE_CMD"
        print_info "模式: 仅安全更新"
    elif [ "$UPDATE_KERNEL" == "true" ] && [ "$PKG_MANAGER" == "apt" ]; then
        cmd="$DIST_UPDATE_CMD"
        print_info "模式: 包含内核更新 (Dist-Upgrade)"
    else
        cmd="$FULL_UPDATE_CMD"
        print_info "模式: 标准全量更新"
    fi
    
    log "Executing: $cmd"
    
    # 交互确认
    if [ "$AUTO_CONFIRM" == "false" ]; then
        read -p "确认开始更新? (y/N): " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && { print_warn "取消操作。"; exit 0; }
    fi
    
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        print_success "系统更新成功！"
    else
        print_error "更新过程中出现错误，请检查日志: $LOG_FILE"
        exit 1
    fi
}

# 清理垃圾
cleanup_system() {
    print_info "正在清理系统残留..."
    eval "$CLEAN_CMD" >> "$LOG_FILE" 2>&1
    print_success "清理完成。"
}

# 检查重启
check_reboot_needed() {
    if [ -f /var/run/reboot-required ]; then
        REBOOT_REQUIRED=true
    elif [[ "$PKG_MANAGER" =~ (yum|dnf) ]] && needs-restarting -r &>/dev/null; then
        REBOOT_REQUIRED=true
    fi
    
    if [ "$REBOOT_REQUIRED" == "true" ]; then
        print_warn "警告: 系统内核已更新，需要重启生效！"
        if [ "$AUTO_CONFIRM" == "true" ]; then
            print_warn "自动模式: 5秒后重启..."
            sleep 5
            reboot
        else
            read -p "是否立即重启? (y/N): " rb
            [[ "$rb" =~ ^[Yy]$ ]] && reboot
        fi
    else
        print_success "无需重启。"
    fi
}

# 生成报告
generate_report() {
    local report_file="$LOG_DIR/update_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" <<EOF
==================================================
           系统更新报告
==================================================
时间: $(date)
系统: $OS_TYPE
模式: $([ "$SECURITY_ONLY" == "true" ] && echo "仅安全" || echo "全量")
内核更新: $([ "$UPDATE_KERNEL" == "true" ] && echo "是" || echo "否")
重启需求: $([ "$REBOOT_REQUIRED" == "true" ] && echo "YES" || echo "NO")
日志: $LOG_FILE
==================================================
EOF
    print_info "报告已生成: $report_file"
}

# ------------------------------------------------------------------------------
# 4. 主程序入口
# ------------------------------------------------------------------------------

show_help() {
    echo "使用方法: bash update_system.sh [选项]"
    echo "  --auto, -y      自动确认所有操作"
    echo "  --kernel, -k    包含内核更新 (apt dist-upgrade)"
    echo "  --security, -s  仅安装安全更新 (仅限 RHEL/CentOS)"
    echo "  --help          显示此帮助"
}

main() {
    check_root
    
    # 参数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --auto|-y) AUTO_CONFIRM=true; shift ;;
            --kernel|-k) UPDATE_KERNEL=true; shift ;;
            --security|-s) SECURITY_ONLY=true; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) print_error "未知参数: $1"; exit 1 ;;
        esac
    done
    
    # 流程执行
    print_header "系统安全更新工具"
    detect_system
    check_network
    
    backup_configs
    refresh_cache
    check_available_updates
    perform_update
    cleanup_system
    check_reboot_needed
    generate_report
}

main "$@"
