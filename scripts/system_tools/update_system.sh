#!/bin/bash

#==============================================================================
# 脚本名称: update_system.sh
# 描述: VPS系统更新脚本 - 安全地更新系统软件包、内核和安全补丁
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/update_system.sh
# 使用方法: bash update_system.sh [选项]
# 选项: --auto (自动确认) --kernel (包含内核更新) --security (仅安全更新)
# 更新日期: 2024-06-17
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

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/update_system_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/system_update"
UPDATE_CACHE_AGE=3600  # 1小时内不重复更新缓存
REBOOT_REQUIRED=false
AUTO_CONFIRM=false
UPDATE_KERNEL=false
SECURITY_ONLY=false

# 全局变量
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""
UPDATES_AVAILABLE=0
SECURITY_UPDATES=0

# 创建必要的目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
        echo -e "${YELLOW}请使用 sudo bash $0 或切换到root用户${NC}"
        exit 1
    fi
}

# 日志记录函数
log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 打印带颜色的消息并记录日志
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "INFO" "$msg"
}

# 打印错误消息
print_error() {
    local msg=$1
    echo -e "${RED}错误: ${msg}${NC}"
    log "ERROR" "$msg"
}

# 打印警告消息
print_warning() {
    local msg=$1
    echo -e "${YELLOW}警告: ${msg}${NC}"
    log "WARN" "$msg"
}

# 检测操作系统
detect_os() {
    print_msg "$BLUE" "正在检测操作系统..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
    else
        print_error "无法识别的操作系统"
        exit 1
    fi
    
    # 确定包管理器
    case $OS_TYPE in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            PKG_MANAGER="yum"
            if command -v dnf &> /dev/null; then
                PKG_MANAGER="dnf"
            fi
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            ;;
        opensuse*)
            PKG_MANAGER="zypper"
            ;;
        *)
            print_error "不支持的操作系统: $OS_TYPE"
            exit 1
            ;;
    esac
    
    print_msg "$GREEN" "检测到系统: $OS_TYPE $OS_VERSION (包管理器: $PKG_MANAGER)"
}

# 检查网络连接
check_network() {
    print_msg "$BLUE" "检查网络连接..."
    
    # 测试多个可靠的服务器
    local test_hosts=("8.8.8.8" "1.1.1.1" "114.114.114.114")
    local network_ok=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &> /dev/null; then
            network_ok=true
            break
        fi
    done
    
    if [ "$network_ok" = false ]; then
        print_error "网络连接失败，请检查网络设置"
        exit 1
    fi
    
    print_msg "$GREEN" "网络连接正常"
}

# 备份重要配置
backup_configs() {
    print_msg "$BLUE" "备份重要系统配置..."
    
    local backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$backup_date"
    
    mkdir -p "$backup_path"
    
    # 备份配置文件列表
    local configs=(
        "/etc/apt/sources.list"
        "/etc/yum.repos.d/"
        "/etc/ssh/sshd_config"
        "/etc/fstab"
        "/etc/network/interfaces"
        "/etc/netplan/"
        "/etc/systemd/network/"
    )
    
    for config in "${configs[@]}"; do
        if [ -e "$config" ]; then
            cp -a "$config" "$backup_path/" 2>/dev/null
        fi
    done
    
    # 备份已安装包列表
    case $PKG_MANAGER in
        apt)
            dpkg --get-selections > "$backup_path/installed_packages.txt"
            ;;
        yum|dnf)
            rpm -qa > "$backup_path/installed_packages.txt"
            ;;
        pacman)
            pacman -Qq > "$backup_path/installed_packages.txt"
            ;;
    esac
    
    print_msg "$GREEN" "配置备份完成: $backup_path"
}

# 更新包管理器缓存
update_cache() {
    print_msg "$BLUE" "更新软件包缓存..."
    
    # 检查缓存更新时间
    local cache_age=0
    case $PKG_MANAGER in
        apt)
            if [ -f /var/cache/apt/pkgcache.bin ]; then
                cache_age=$(($(date +%s) - $(stat -c %Y /var/cache/apt/pkgcache.bin)))
            fi
            ;;
    esac
    
    if [ $cache_age -lt $UPDATE_CACHE_AGE ] && [ "$AUTO_CONFIRM" = false ]; then
        print_msg "$YELLOW" "软件包缓存在1小时内已更新，跳过..."
        return 0
    fi
    
    case $PKG_MANAGER in
        apt)
            apt-get update 2>&1 | tee -a "$LOG_FILE"
            ;;
        yum|dnf)
            $PKG_MANAGER makecache 2>&1 | tee -a "$LOG_FILE"
            ;;
        apk)
            apk update 2>&1 | tee -a "$LOG_FILE"
            ;;
        pacman)
            pacman -Sy 2>&1 | tee -a "$LOG_FILE"
            ;;
        zypper)
            zypper refresh 2>&1 | tee -a "$LOG_FILE"
            ;;
    esac
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        print_msg "$GREEN" "软件包缓存更新成功"
    else
        print_error "软件包缓存更新失败"
        exit 1
    fi
}

# 检查可用更新
check_updates() {
    print_msg "$BLUE" "检查可用更新..."
    
    case $PKG_MANAGER in
        apt)
            # 获取可更新包列表
            apt list --upgradable 2>/dev/null | grep -c upgradable || true
            UPDATES_AVAILABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo 0)
            
            # 检查安全更新
            if command -v apt-check &> /dev/null; then
                SECURITY_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2)
            fi
            ;;
        yum|dnf)
            UPDATES_AVAILABLE=$($PKG_MANAGER check-update 2>/dev/null | grep -c "^[[:alnum:]]" || echo 0)
            SECURITY_UPDATES=$($PKG_MANAGER list-security 2>/dev/null | grep -c "^[[:alnum:]]" || echo 0)
            ;;
        apk)
            UPDATES_AVAILABLE=$(apk list -u 2>/dev/null | wc -l)
            ;;
        pacman)
            UPDATES_AVAILABLE=$(pacman -Qu 2>/dev/null | wc -l)
            ;;
    esac
    
    print_msg "$CYAN" "可用更新: $UPDATES_AVAILABLE 个软件包"
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        print_msg "$YELLOW" "其中安全更新: $SECURITY_UPDATES 个"
    fi
}

# 显示更新列表
show_updates() {
    if [ "$UPDATES_AVAILABLE" -eq 0 ]; then
        print_msg "$GREEN" "系统已是最新状态，无需更新"
        return 0
    fi
    
    print_msg "$BLUE" "\n可更新的软件包列表:"
    echo ""
    
    case $PKG_MANAGER in
        apt)
            apt list --upgradable 2>/dev/null | grep upgradable | head -20
            ;;
        yum|dnf)
            $PKG_MANAGER check-update 2>/dev/null | head -20
            ;;
        apk)
            apk list -u 2>/dev/null | head -20
            ;;
        pacman)
            pacman -Qu 2>/dev/null | head -20
            ;;
    esac
    
    if [ "$UPDATES_AVAILABLE" -gt 20 ]; then
        echo -e "\n... 还有 $((UPDATES_AVAILABLE - 20)) 个更新未显示"
    fi
    
    return 1
}

# 执行系统更新
perform_update() {
    print_msg "$BLUE" "\n开始更新系统..."
    
    local update_cmd=""
    local update_options=""
    
    # 设置更新命令
    case $PKG_MANAGER in
        apt)
            if [ "$SECURITY_ONLY" = true ]; then
                update_cmd="apt-get install -y \$(apt-get --just-print upgrade 2>&1 | grep -i security | awk '{print \$2}')"
            else
                update_cmd="apt-get upgrade -y"
                if [ "$UPDATE_KERNEL" = true ]; then
                    update_cmd="apt-get dist-upgrade -y"
                fi
            fi
            update_options="DEBIAN_FRONTEND=noninteractive"
            ;;
        yum|dnf)
            if [ "$SECURITY_ONLY" = true ]; then
                update_cmd="$PKG_MANAGER update-minimal --security -y"
            else
                update_cmd="$PKG_MANAGER update -y"
            fi
            ;;
        apk)
            update_cmd="apk upgrade"
            ;;
        pacman)
            update_cmd="pacman -Syu --noconfirm"
            ;;
        zypper)
            update_cmd="zypper update -y"
            ;;
    esac
    
    # 执行更新
    log "INFO" "执行命令: $update_cmd"
    
    if [ -n "$update_options" ]; then
        export $update_options
    fi
    
    # 使用脚本记录更新过程
    script -q -c "$update_cmd" "$LOG_DIR/update_output_$(date +%Y%m%d_%H%M%S).log"
    local update_result=$?
    
    if [ $update_result -eq 0 ]; then
        print_msg "$GREEN" "系统更新成功完成"
    else
        print_error "系统更新过程中出现错误，请查看日志: $LOG_FILE"
        return 1
    fi
    
    # 清理不需要的包
    cleanup_system
}

# 清理系统
cleanup_system() {
    print_msg "$BLUE" "清理系统..."
    
    case $PKG_MANAGER in
        apt)
            apt-get autoremove -y &>> "$LOG_FILE"
            apt-get autoclean -y &>> "$LOG_FILE"
            ;;
        yum|dnf)
            $PKG_MANAGER autoremove -y &>> "$LOG_FILE"
            $PKG_MANAGER clean all &>> "$LOG_FILE"
            ;;
        apk)
            # Alpine 没有autoremove
            ;;
        pacman)
            if command -v paccache &> /dev/null; then
                paccache -r &>> "$LOG_FILE"
            fi
            ;;
    esac
    
    print_msg "$GREEN" "系统清理完成"
}

# 检查是否需要重启
check_reboot() {
    print_msg "$BLUE" "检查是否需要重启系统..."
    
    case $OS_TYPE in
        ubuntu|debian)
            if [ -f /var/run/reboot-required ]; then
                REBOOT_REQUIRED=true
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if needs-restarting -r &> /dev/null; then
                REBOOT_REQUIRED=true
            elif [ -f /var/run/reboot-required ]; then
                REBOOT_REQUIRED=true
            fi
            ;;
    esac
    
    # 检查内核是否更新
    if [ "$UPDATE_KERNEL" = true ]; then
        local current_kernel=$(uname -r)
        local latest_kernel=""
        
        case $PKG_MANAGER in
            apt)
                latest_kernel=$(dpkg -l | grep linux-image | grep -v "$current_kernel" | tail -1 | awk '{print $2}')
                ;;
            yum|dnf)
                latest_kernel=$(rpm -q kernel | tail -1)
                ;;
        esac
        
        if [ -n "$latest_kernel" ] && [ "$latest_kernel" != "kernel-$current_kernel" ]; then
            REBOOT_REQUIRED=true
        fi
    fi
    
    if [ "$REBOOT_REQUIRED" = true ]; then
        print_warning "系统需要重启以完成更新"
    else
        print_msg "$GREEN" "系统不需要重启"
    fi
}

# 系统健康检查
health_check() {
    print_msg "$BLUE" "\n执行系统健康检查..."
    
    local issues=0
    
    # 检查关键服务
    local critical_services=("ssh" "sshd" "systemd-resolved" "systemd-networkd" "NetworkManager")
    
    for service in "${critical_services[@]}"; do
        if systemctl is-enabled "$service" &> /dev/null; then
            if ! systemctl is-active "$service" &> /dev/null; then
                print_warning "服务 $service 未运行"
                ((issues++))
            fi
        fi
    done
    
    # 检查磁盘空间
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_warning "根分区使用率超过90%: ${disk_usage}%"
        ((issues++))
    fi
    
    # 检查内存使用
    local mem_usage=$(free | awk 'NR==2 {print int($3/$2 * 100)}')
    if [ "$mem_usage" -gt 90 ]; then
        print_warning "内存使用率超过90%: ${mem_usage}%"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        print_msg "$GREEN" "系统健康检查通过"
    else
        print_warning "发现 $issues 个潜在问题，请检查"
    fi
}

# 生成更新报告
generate_report() {
    local report_file="$LOG_DIR/update_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
================================================================================
                          系统更新报告
================================================================================
更新时间: $(date '+%Y-%m-%d %H:%M:%S')
系统信息: $OS_TYPE $OS_VERSION
主机名称: $(hostname)
更新类型: $([ "$SECURITY_ONLY" = true ] && echo "仅安全更新" || echo "全部更新")
包含内核: $([ "$UPDATE_KERNEL" = true ] && echo "是" || echo "否")
--------------------------------------------------------------------------------

更新统计:
- 更新前可用更新: $UPDATES_AVAILABLE 个
- 安全更新: $SECURITY_UPDATES 个
- 需要重启: $([ "$REBOOT_REQUIRED" = true ] && echo "是" || echo "否")

更新日志: $LOG_FILE

================================================================================
EOF
    
    print_msg "$GREEN" "更新报告已生成: $report_file"
}

# 交互式确认
confirm_update() {
    if [ "$AUTO_CONFIRM" = true ]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}即将执行系统更新，这可能需要一些时间。${NC}"
    echo -e "${YELLOW}建议在系统负载较低时执行此操作。${NC}"
    echo ""
    read -p "是否继续？(y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_msg "$YELLOW" "用户取消更新"
        exit 0
    fi
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto|-y)
                AUTO_CONFIRM=true
                shift
                ;;
            --kernel|-k)
                UPDATE_KERNEL=true
                shift
                ;;
            --security|-s)
                SECURITY_ONLY=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --auto, -y      自动确认更新，无需手动确认
  --kernel, -k    包含内核更新（可能需要重启）
  --security, -s  仅安装安全更新
  --help, -h      显示此帮助信息

示例:
  $0              # 交互式更新
  $0 --auto       # 自动更新所有包
  $0 --security   # 仅安装安全更新
  $0 --kernel     # 包含内核更新

注意:
  - 此脚本需要root权限运行
  - 更新前会自动备份重要配置
  - 更新日志保存在: $LOG_DIR
EOF
}

# 显示更新摘要
show_summary() {
    echo ""
    print_msg "$PURPLE" "========== 更新摘要 =========="
    echo -e "${CYAN}更新时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}系统版本:${NC} $OS_TYPE $OS_VERSION"
    echo -e "${CYAN}更新类型:${NC} $([ "$SECURITY_ONLY" = true ] && echo "仅安全更新" || echo "全部更新")"
    echo -e "${CYAN}包含内核:${NC} $([ "$UPDATE_KERNEL" = true ] && echo "是" || echo "否")"
    echo -e "${CYAN}需要重启:${NC} $([ "$REBOOT_REQUIRED" = true ] && echo "是" || echo "否")"
    echo -e "${CYAN}日志文件:${NC} $LOG_FILE"
    echo ""
}

# 主函数
main() {
    # 显示标题
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                          VPS 系统更新工具 v1.0                             ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 初始化
    create_directories
    check_root
    parse_arguments "$@"
    
    # 开始更新流程
    log "INFO" "开始系统更新流程"
    
    detect_os
    check_network
    backup_configs
    update_cache
    check_updates
    
    # 显示更新信息并确认
    if show_updates; then
        # 系统已是最新
        health_check
        exit 0
    fi
    
    confirm_update
    
    # 执行更新
    if perform_update; then
        check_reboot
        health_check
        generate_report
        show_summary
        
        print_msg "$GREEN" "\n系统更新完成！"
        
        if [ "$REBOOT_REQUIRED" = true ]; then
            echo ""
            if [ "$AUTO_CONFIRM" = true ]; then
                print_warning "系统将在30秒后自动重启..."
                sleep 30
                reboot
            else
                print_warning "请尽快重启系统以完成更新"
                echo -e "${YELLOW}使用命令: sudo reboot${NC}"
            fi
        fi
    else
        print_error "系统更新失败，请查看日志文件"
        exit 1
    fi
}

# 运行主函数
main "$@"
