#!/bin/bash

#==============================================================================
# 脚本名称: clean_system.sh
# 描述: VPS系统清理脚本 - 安全清理系统垃圾文件、释放磁盘空间
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/clean_system.sh
# 使用方法: bash clean_system.sh [选项]
# 选项: --auto (自动模式) --deep (深度清理) --analyze (仅分析)
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
LOG_FILE="$LOG_DIR/clean_system_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/system_clean"
DRY_RUN=false
AUTO_MODE=false
DEEP_CLEAN=false
ANALYZE_ONLY=false

# 清理统计
TOTAL_CLEANED=0
CLEANED_FILES=0
INITIAL_DISK_USAGE=""
FINAL_DISK_USAGE=""

# 全局变量
OS_TYPE=""
OS_VERSION=""
PKG_MANAGER=""

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

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "INFO" "$msg"
}

# 转换大小单位
human_readable() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $size -gt 1024 ] && [ $unit -lt 4 ]; do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "$size${units[$unit]}"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS_TYPE="centos"
        OS_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
    else
        print_msg "$RED" "错误: 无法识别的操作系统"
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
        *)
            PKG_MANAGER="unknown"
            ;;
    esac
}

# 获取磁盘使用情况
get_disk_usage() {
    df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
}

# 获取目录大小
get_dir_size() {
    local dir=$1
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

# 分析磁盘空间
analyze_disk_space() {
    print_msg "$BLUE" "\n分析磁盘空间使用情况..."
    
    echo -e "${CYAN}当前磁盘使用:${NC} $(get_disk_usage)"
    echo ""
    
    # 分析大目录
    print_msg "$CYAN" "占用空间最大的目录:"
    du -h / 2>/dev/null | sort -rh | head -10 | while read size dir; do
        echo "  $size  $dir"
    done
    
    echo ""
    
    # 分析可清理的空间
    local cleanable_space=0
    local temp_size=$(get_dir_size "/tmp")
    local log_size=$(get_dir_size "/var/log")
    local cache_size=$(get_dir_size "/var/cache")
    
    cleanable_space=$((temp_size + log_size + cache_size))
    
    print_msg "$CYAN" "可清理空间估算:"
    echo -e "  临时文件: $(human_readable $temp_size)"
    echo -e "  日志文件: $(human_readable $log_size)"
    echo -e "  缓存文件: $(human_readable $cache_size)"
    echo -e "  ${GREEN}总计可清理: $(human_readable $cleanable_space)${NC}"
}

# 清理包管理器缓存
clean_package_cache() {
    print_msg "$BLUE" "\n清理包管理器缓存..."
    
    local before_size=0
    local after_size=0
    
    case $PKG_MANAGER in
        apt)
            before_size=$(get_dir_size "/var/cache/apt")
            if [ "$DRY_RUN" = false ]; then
                apt-get clean &>> "$LOG_FILE"
                apt-get autoclean &>> "$LOG_FILE"
            fi
            after_size=$(get_dir_size "/var/cache/apt")
            ;;
        yum|dnf)
            before_size=$(get_dir_size "/var/cache/$PKG_MANAGER")
            if [ "$DRY_RUN" = false ]; then
                $PKG_MANAGER clean all &>> "$LOG_FILE"
            fi
            after_size=$(get_dir_size "/var/cache/$PKG_MANAGER")
            ;;
        pacman)
            before_size=$(get_dir_size "/var/cache/pacman/pkg")
            if [ "$DRY_RUN" = false ]; then
                if command -v paccache &> /dev/null; then
                    paccache -r &>> "$LOG_FILE"
                else
                    pacman -Sc --noconfirm &>> "$LOG_FILE"
                fi
            fi
            after_size=$(get_dir_size "/var/cache/pacman/pkg")
            ;;
        apk)
            before_size=$(get_dir_size "/var/cache/apk")
            if [ "$DRY_RUN" = false ]; then
                apk cache clean &>> "$LOG_FILE"
            fi
            after_size=$(get_dir_size "/var/cache/apk")
            ;;
    esac
    
    local cleaned=$((before_size - after_size))
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    
    print_msg "$GREEN" "包管理器缓存已清理: $(human_readable $cleaned)"
}

# 清理临时文件
clean_temp_files() {
    print_msg "$BLUE" "\n清理临时文件..."
    
    local temp_dirs=(
        "/tmp"
        "/var/tmp"
        "/var/cache/man"
    )
    
    local before_size=0
    local after_size=0
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            before_size=$((before_size + $(get_dir_size "$dir")))
            
            if [ "$DRY_RUN" = false ]; then
                # 清理超过7天的临时文件
                find "$dir" -type f -atime +7 -delete 2>/dev/null
                find "$dir" -type d -empty -delete 2>/dev/null
            fi
            
            after_size=$((after_size + $(get_dir_size "$dir")))
        fi
    done
    
    local cleaned=$((before_size - after_size))
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    
    print_msg "$GREEN" "临时文件已清理: $(human_readable $cleaned)"
}

# 清理日志文件
clean_log_files() {
    print_msg "$BLUE" "\n清理日志文件..."
    
    local before_size=$(get_dir_size "/var/log")
    
    if [ "$DRY_RUN" = false ]; then
        # 清理旧的日志文件
        find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
        find /var/log -type f -name "*.old" -mtime +30 -delete 2>/dev/null
        find /var/log -type f -name "*.1" -mtime +30 -delete 2>/dev/null
        
        # 清空大于100MB的日志文件
        find /var/log -type f -size +100M | while read logfile; do
            if [[ ! "$logfile" =~ (journal|lastlog|wtmp|btmp) ]]; then
                echo "清空大日志文件: $logfile ($(du -h "$logfile" | cut -f1))" >> "$LOG_FILE"
                > "$logfile"
            fi
        done
        
        # 运行日志轮转
        if command -v logrotate &> /dev/null; then
            logrotate -f /etc/logrotate.conf &>> "$LOG_FILE"
        fi
        
        # 清理 systemd journal
        if command -v journalctl &> /dev/null; then
            journalctl --vacuum-time=7d &>> "$LOG_FILE"
            journalctl --vacuum-size=100M &>> "$LOG_FILE"
        fi
    fi
    
    local after_size=$(get_dir_size "/var/log")
    local cleaned=$((before_size - after_size))
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    
    print_msg "$GREEN" "日志文件已清理: $(human_readable $cleaned)"
}

# 清理孤立的包
clean_orphan_packages() {
    print_msg "$BLUE" "\n清理孤立的软件包..."
    
    local orphan_count=0
    
    case $PKG_MANAGER in
        apt)
            orphan_count=$(apt-get autoremove --dry-run 2>/dev/null | grep -c "^Remv" || echo 0)
            if [ $orphan_count -gt 0 ]; then
                print_msg "$YELLOW" "发现 $orphan_count 个孤立包"
                if [ "$DRY_RUN" = false ] && [ "$AUTO_MODE" = true ]; then
                    apt-get autoremove -y &>> "$LOG_FILE"
                    print_msg "$GREEN" "已移除孤立包"
                elif [ "$DRY_RUN" = false ]; then
                    read -p "是否移除这些孤立包？(y/N): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        apt-get autoremove -y &>> "$LOG_FILE"
                        print_msg "$GREEN" "已移除孤立包"
                    fi
                fi
            else
                print_msg "$GREEN" "没有发现孤立包"
            fi
            ;;
        yum|dnf)
            orphan_count=$($PKG_MANAGER list autoremove 2>/dev/null | grep -c "^[[:alnum:]]" || echo 0)
            if [ $orphan_count -gt 0 ]; then
                print_msg "$YELLOW" "发现 $orphan_count 个孤立包"
                if [ "$DRY_RUN" = false ] && [ "$AUTO_MODE" = true ]; then
                    $PKG_MANAGER autoremove -y &>> "$LOG_FILE"
                    print_msg "$GREEN" "已移除孤立包"
                fi
            else
                print_msg "$GREEN" "没有发现孤立包"
            fi
            ;;
        pacman)
            if command -v pacman-remove-orphans &> /dev/null; then
                orphan_count=$(pacman -Qtdq 2>/dev/null | wc -l)
                if [ $orphan_count -gt 0 ]; then
                    print_msg "$YELLOW" "发现 $orphan_count 个孤立包"
                    if [ "$DRY_RUN" = false ] && [ "$AUTO_MODE" = true ]; then
                        pacman -Qtdq | pacman -Rns - --noconfirm &>> "$LOG_FILE"
                        print_msg "$GREEN" "已移除孤立包"
                    fi
                else
                    print_msg "$GREEN" "没有发现孤立包"
                fi
            fi
            ;;
    esac
}

# 清理旧内核
clean_old_kernels() {
    if [ "$DEEP_CLEAN" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n清理旧内核..."
    
    local current_kernel=$(uname -r)
    local kernel_count=0
    
    case $OS_TYPE in
        ubuntu|debian)
            # 获取已安装的内核列表
            kernel_count=$(dpkg -l | grep -E "linux-image-[0-9]" | grep -v "$current_kernel" | wc -l)
            
            if [ $kernel_count -gt 0 ]; then
                print_msg "$YELLOW" "发现 $kernel_count 个旧内核（当前使用: $current_kernel）"
                
                if [ "$DRY_RUN" = false ]; then
                    if [ "$AUTO_MODE" = true ] || { read -p "是否清理旧内核？(y/N): " confirm && [[ "$confirm" =~ ^[Yy]$ ]]; }; then
                        # 保留当前内核和最新的一个备用内核
                        dpkg -l | grep -E "linux-image-[0-9]" | grep -v "$current_kernel" | \
                            awk '{print $2}' | sort -V | head -n -1 | \
                            xargs -r apt-get purge -y &>> "$LOG_FILE"
                        
                        # 清理相关的 headers
                        dpkg -l | grep -E "linux-headers-[0-9]" | grep -v "$current_kernel" | \
                            awk '{print $2}' | xargs -r apt-get purge -y &>> "$LOG_FILE"
                        
                        print_msg "$GREEN" "旧内核已清理"
                    fi
                fi
            else
                print_msg "$GREEN" "没有发现需要清理的旧内核"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            # 获取已安装的内核数量
            kernel_count=$(rpm -q kernel | grep -v "kernel-$current_kernel" | wc -l)
            
            if [ $kernel_count -gt 1 ]; then
                print_msg "$YELLOW" "发现多个内核版本"
                if [ "$DRY_RUN" = false ] && [ "$AUTO_MODE" = true ]; then
                    # 使用 package-cleanup 清理旧内核（保留2个）
                    if command -v package-cleanup &> /dev/null; then
                        package-cleanup --oldkernels --count=2 -y &>> "$LOG_FILE"
                        print_msg "$GREEN" "旧内核已清理"
                    fi
                fi
            else
                print_msg "$GREEN" "没有发现需要清理的旧内核"
            fi
            ;;
    esac
}

# 清理用户缓存
clean_user_cache() {
    print_msg "$BLUE" "\n清理用户缓存..."
    
    local cleaned=0
    
    # 清理所有用户的缓存目录
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            local username=$(basename "$user_home")
            
            # 清理常见的缓存目录
            local cache_dirs=(
                "$user_home/.cache"
                "$user_home/.local/share/Trash"
                "$user_home/.thumbnails"
                "$user_home/.npm/_cacache"
                "$user_home/.composer/cache"
            )
            
            for cache_dir in "${cache_dirs[@]}"; do
                if [ -d "$cache_dir" ]; then
                    local size=$(get_dir_size "$cache_dir")
                    if [ $size -gt 0 ]; then
                        if [ "$DRY_RUN" = false ]; then
                            rm -rf "$cache_dir"/* 2>/dev/null
                        fi
                        cleaned=$((cleaned + size))
                        log "INFO" "清理用户 $username 的缓存: $(human_readable $size)"
                    fi
                fi
            done
        fi
    done
    
    # 清理 root 用户缓存
    if [ -d "/root/.cache" ]; then
        local size=$(get_dir_size "/root/.cache")
        if [ "$DRY_RUN" = false ]; then
            rm -rf /root/.cache/* 2>/dev/null
        fi
        cleaned=$((cleaned + size))
    fi
    
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    print_msg "$GREEN" "用户缓存已清理: $(human_readable $cleaned)"
}

# 清理 Docker（如果安装）
clean_docker() {
    if ! command -v docker &> /dev/null; then
        return
    fi
    
    print_msg "$BLUE" "\n清理 Docker..."
    
    if [ "$DRY_RUN" = false ]; then
        # 清理停止的容器
        docker container prune -f &>> "$LOG_FILE"
        
        # 清理未使用的镜像
        docker image prune -f &>> "$LOG_FILE"
        
        # 清理未使用的网络
        docker network prune -f &>> "$LOG_FILE"
        
        # 清理未使用的卷
        docker volume prune -f &>> "$LOG_FILE"
        
        if [ "$DEEP_CLEAN" = true ]; then
            # 深度清理：移除所有停止的容器和未标记的镜像
            docker system prune -a -f &>> "$LOG_FILE"
        fi
    fi
    
    print_msg "$GREEN" "Docker 清理完成"
}

# 优化数据库（如果有）
optimize_databases() {
    if [ "$DEEP_CLEAN" = false ]; then
        return
    fi
    
    print_msg "$BLUE" "\n优化数据库..."
    
    # MySQL/MariaDB
    if command -v mysql &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            mysqlcheck -Aos --auto-repair &>> "$LOG_FILE" 2>&1 || true
            print_msg "$GREEN" "MySQL/MariaDB 优化完成"
        fi
    fi
    
    # PostgreSQL
    if command -v psql &> /dev/null; then
        if [ "$DRY_RUN" = false ]; then
            sudo -u postgres vacuumdb --all --analyze &>> "$LOG_FILE" 2>&1 || true
            print_msg "$GREEN" "PostgreSQL 优化完成"
        fi
    fi
}

# 生成清理报告
generate_report() {
    local report_file="$LOG_DIR/clean_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
================================================================================
                          系统清理报告
================================================================================
清理时间: $(date '+%Y-%m-%d %H:%M:%S')
系统信息: $OS_TYPE $OS_VERSION
主机名称: $(hostname)
清理模式: $([ "$DEEP_CLEAN" = true ] && echo "深度清理" || echo "标准清理")
--------------------------------------------------------------------------------

磁盘空间变化:
- 清理前: $INITIAL_DISK_USAGE
- 清理后: $FINAL_DISK_USAGE
- 释放空间: $(human_readable $TOTAL_CLEANED)

清理详情:
- 包管理器缓存: ✓
- 临时文件: ✓
- 日志文件: ✓
- 孤立软件包: ✓
$([ "$DEEP_CLEAN" = true ] && echo "- 旧内核: ✓")
$([ "$DEEP_CLEAN" = true ] && echo "- 用户缓存: ✓")
$(command -v docker &> /dev/null && echo "- Docker清理: ✓")

日志文件: $LOG_FILE

================================================================================
EOF
    
    print_msg "$GREEN" "\n清理报告已生成: $report_file"
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS 系统清理工具 v1.0                              ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示当前磁盘使用情况
    echo -e "${CYAN}当前磁盘使用:${NC} $(get_disk_usage)"
    echo ""
    
    echo -e "${CYAN}请选择清理选项:${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} 快速清理 (包缓存、临时文件、日志)"
    echo -e "${GREEN}2)${NC} 标准清理 (快速清理 + 孤立包)"
    echo -e "${GREEN}3)${NC} 深度清理 (标准清理 + 旧内核、用户缓存)"
    echo -e "${GREEN}4)${NC} 分析磁盘空间"
    echo -e "${GREEN}5)${NC} 自定义清理"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            clean_package_cache
            clean_temp_files
            clean_log_files
            ;;
        2)
            clean_package_cache
            clean_temp_files
            clean_log_files
            clean_orphan_packages
            clean_docker
            ;;
        3)
            DEEP_CLEAN=true
            clean_package_cache
            clean_temp_files
            clean_log_files
            clean_orphan_packages
            clean_old_kernels
            clean_user_cache
            clean_docker
            optimize_databases
            ;;
        4)
            analyze_disk_space
            echo ""
            read -p "按回车键继续..."
            interactive_menu
            ;;
        5)
            custom_clean_menu
            ;;
        0)
            print_msg "$YELLOW" "退出清理程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项，请重新选择"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 自定义清理菜单
custom_clean_menu() {
    clear
    echo -e "${CYAN}自定义清理选项${NC}"
    echo ""
    
    local options=(
        "清理包管理器缓存"
        "清理临时文件"
        "清理日志文件"
        "清理孤立软件包"
        "清理旧内核"
        "清理用户缓存"
        "清理Docker"
        "优化数据库"
    )
    
    local selected=()
    
    for i in "${!options[@]}"; do
        echo -e "${GREEN}$((i+1)))${NC} ${options[$i]}"
    done
    
    echo ""
    echo -e "${YELLOW}输入要执行的操作编号（用空格分隔），输入 'all' 选择全部:${NC}"
    read -p "> " input
    
    if [ "$input" = "all" ]; then
        selected=(1 2 3 4 5 6 7 8)
    else
        selected=($input)
    fi
    
    for num in "${selected[@]}"; do
        case $num in
            1) clean_package_cache ;;
            2) clean_temp_files ;;
            3) clean_log_files ;;
            4) clean_orphan_packages ;;
            5) DEEP_CLEAN=true; clean_old_kernels ;;
            6) clean_user_cache ;;
            7) clean_docker ;;
            8) DEEP_CLEAN=true; optimize_databases ;;
        esac
    done
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto|-a)
                AUTO_MODE=true
                shift
                ;;
            --deep|-d)
                DEEP_CLEAN=true
                shift
                ;;
            --analyze)
                ANALYZE_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_msg "$RED" "未知选项: $1"
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
  --auto, -a      自动模式，无需确认
  --deep, -d      深度清理（包括旧内核、用户缓存等）
  --analyze       仅分析磁盘空间，不执行清理
  --dry-run       模拟运行，显示将要清理的内容但不实际执行
  --help, -h      显示此帮助信息

示例:
  $0              # 交互式清理
  $0 --auto       # 自动执行标准清理
  $0 --deep       # 执行深度清理
  $0 --analyze    # 仅分析磁盘空间

注意:
  - 此脚本需要root权限运行
  - 清理操作不可逆，请谨慎使用
  - 建议先使用 --dry-run 查看将要清理的内容
EOF
}

# 主函数
main() {
    # 初始化
    create_directories
    check_root
    parse_arguments "$@"
    
    # 开始清理流程
    log "INFO" "开始系统清理流程"
    detect_os
    
    # 记录初始磁盘使用
    INITIAL_DISK_USAGE=$(get_disk_usage)
    
    if [ "$ANALYZE_ONLY" = true ]; then
        analyze_disk_space
        exit 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_msg "$YELLOW" "模拟运行模式 - 不会实际删除任何文件"
        echo ""
    fi
    
    # 根据模式执行清理
    if [ "$AUTO_MODE" = true ]; then
        print_msg "$BLUE" "自动清理模式启动..."
        clean_package_cache
        clean_temp_files
        clean_log_files
        clean_orphan_packages
        
        if [ "$DEEP_CLEAN" = true ]; then
            clean_old_kernels
            clean_user_cache
            optimize_databases
        fi
        
        clean_docker
    else
        interactive_menu
    fi
    
    # 记录最终磁盘使用
    FINAL_DISK_USAGE=$(get_disk_usage)
    
    # 生成报告
    if [ "$DRY_RUN" = false ]; then
        generate_report
    fi
    
    # 显示清理摘要
    echo ""
    print_msg "$PURPLE" "========== 清理摘要 =========="
    echo -e "${CYAN}清理前磁盘使用:${NC} $INITIAL_DISK_USAGE"
    echo -e "${CYAN}清理后磁盘使用:${NC} $FINAL_DISK_USAGE"
    echo -e "${CYAN}释放空间总计:${NC} $(human_readable $TOTAL_CLEANED)"
    echo -e "${CYAN}日志文件:${NC} $LOG_FILE"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        print_msg "$YELLOW" "这是模拟运行，实际未删除任何文件"
    else
        print_msg "$GREEN" "系统清理完成！"
    fi
}

# 运行主函数
main "$@"
