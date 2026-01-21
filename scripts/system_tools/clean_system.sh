#!/bin/bash
# ==============================================================================
# 脚本名称: clean_system.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/clean_system.sh
# 描述: VPS 系统深度清理工具
#       安全清理包管理器缓存、旧内核、日志文件、Docker 镜像及用户缓存。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Full Feature)
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
LOG_FILE="$LOG_DIR/clean_system_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/system_clean"

# 运行模式开关
DRY_RUN=false
AUTO_MODE=false
DEEP_CLEAN=false
ANALYZE_ONLY=false

# 统计变量
TOTAL_CLEANED=0
INITIAL_DISK_USAGE=""
FINAL_DISK_USAGE=""

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    [ -n "$LOG_DIR" ] && LOG_FILE="${LOG_DIR}/clean_system.log"
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

# 获取目录大小 (bytes)
get_dir_size() {
    local dir=$1
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | awk '{print $1}'
    else
        echo 0
    fi
}

# 获取磁盘使用率
get_disk_usage() {
    df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}'
}

# 检测系统与包管理器
detect_system() {
    OS_TYPE=$(get_os_release)
    case $OS_TYPE in
        ubuntu|debian|kali) PKG_MANAGER="apt" ;;
        centos|rhel|fedora|rocky|almalinux|amzn) 
            command -v dnf &>/dev/null && PKG_MANAGER="dnf" || PKG_MANAGER="yum" ;;
        alpine) PKG_MANAGER="apk" ;;
        pacman|arch) PKG_MANAGER="pacman" ;;
        *) PKG_MANAGER="unknown" ;;
    esac
    log "System: $OS_TYPE, Manager: $PKG_MANAGER"
}

# ------------------------------------------------------------------------------
# 3. 核心清理模块
# ------------------------------------------------------------------------------

# 模块1: 包管理器缓存清理
clean_package_cache() {
    print_info "清理包管理器缓存..."
    local before=$(get_dir_size "/var/cache/$PKG_MANAGER")
    [ "$PKG_MANAGER" == "apt" ] && before=$(get_dir_size "/var/cache/apt")
    
    if [ "$DRY_RUN" = false ]; then
        case $PKG_MANAGER in
            apt) apt-get clean &>> "$LOG_FILE"; apt-get autoclean &>> "$LOG_FILE" ;;
            yum|dnf) $PKG_MANAGER clean all &>> "$LOG_FILE" ;;
            pacman) pacman -Sc --noconfirm &>> "$LOG_FILE" ;;
            apk) apk cache clean &>> "$LOG_FILE" ;;
        esac
    fi
    
    local after=$(get_dir_size "/var/cache/$PKG_MANAGER")
    [ "$PKG_MANAGER" == "apt" ] && after=$(get_dir_size "/var/cache/apt")
    
    local cleaned=$((before - after))
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    print_success "已释放: $(human_readable $cleaned)"
}

# 模块2: 临时文件清理
clean_temp_files() {
    print_info "清理临时文件..."
    local dirs=("/tmp" "/var/tmp" "/var/cache/man")
    local cleaned=0
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            local before=$(get_dir_size "$dir")
            if [ "$DRY_RUN" = false ]; then
                # 仅清理 7 天前的文件
                find "$dir" -type f -atime +7 -delete 2>/dev/null
                find "$dir" -type d -empty -delete 2>/dev/null
            fi
            local after=$(get_dir_size "$dir")
            cleaned=$((cleaned + (before - after)))
        fi
    done
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    print_success "已释放: $(human_readable $cleaned)"
}

# 模块3: 日志清理
clean_log_files() {
    print_info "清理旧日志文件..."
    local before=$(get_dir_size "/var/log")
    
    if [ "$DRY_RUN" = false ]; then
        # 清理旧的归档日志
        find /var/log -type f -name "*.gz" -mtime +30 -delete
        find /var/log -type f -name "*.old" -mtime +30 -delete
        find /var/log -type f -name "*.1" -mtime +30 -delete
        
        # 清空超大日志 (>100MB)
        find /var/log -type f -size +100M | while read f; do
            [[ ! "$f" =~ (journal|lastlog|wtmp|btmp) ]] && echo "" > "$f"
        done
        
        # Systemd journal 真空清理
        if command -v journalctl &>/dev/null; then
            journalctl --vacuum-time=7d &>> "$LOG_FILE"
            journalctl --vacuum-size=100M &>> "$LOG_FILE"
        fi
    fi
    
    local after=$(get_dir_size "/var/log")
    local cleaned=$((before - after))
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    print_success "已释放: $(human_readable $cleaned)"
}

# 模块4: 孤立软件包清理
clean_orphans() {
    print_info "扫描孤立软件包..."
    if [ "$DRY_RUN" = false ]; then
        case $PKG_MANAGER in
            apt) apt-get autoremove -y &>> "$LOG_FILE" ;;
            yum|dnf) $PKG_MANAGER autoremove -y &>> "$LOG_FILE" ;;
            pacman) pacman -Qtdq | pacman -Rns - --noconfirm &>> "$LOG_FILE" ;;
        esac
    fi
    print_success "孤立包清理完成。"
}

# 模块5: 旧内核清理 (Deep Mode)
clean_old_kernels() {
    if [ "$DEEP_CLEAN" = false ]; then return; fi
    print_info "检查旧内核版本..."
    
    local current=$(uname -r)
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        if [ "$DRY_RUN" = false ]; then
            # 保留当前内核，卸载其他 image 和 headers
            dpkg -l | grep -E "linux-image-[0-9]" | grep -v "$current" | awk '{print $2}' | xargs -r apt-get purge -y &>> "$LOG_FILE"
            dpkg -l | grep -E "linux-headers-[0-9]" | grep -v "$current" | awk '{print $2}' | xargs -r apt-get purge -y &>> "$LOG_FILE"
            print_success "旧内核已清理。"
        fi
    elif [[ "$PKG_MANAGER" =~ (yum|dnf) ]]; then
        if command -v package-cleanup &>/dev/null && [ "$DRY_RUN" = false ]; then
            package-cleanup --oldkernels --count=2 -y &>> "$LOG_FILE"
            print_success "旧内核已清理 (保留2个)。"
        fi
    fi
}

# 模块6: Docker 清理
clean_docker() {
    if ! command -v docker &>/dev/null; then return; fi
    print_info "清理 Docker 垃圾..."
    
    if [ "$DRY_RUN" = false ]; then
        docker container prune -f &>> "$LOG_FILE"
        docker image prune -f &>> "$LOG_FILE"
        docker volume prune -f &>> "$LOG_FILE"
        
        if [ "$DEEP_CLEAN" = true ]; then
            docker system prune -a -f &>> "$LOG_FILE"
            print_success "Docker 深度清理完成 (含未使用镜像)。"
        else
            print_success "Docker 基础清理完成。"
        fi
    fi
}

# 模块7: 用户缓存清理 (Deep Mode)
clean_user_cache() {
    if [ "$DEEP_CLEAN" = false ]; then return; fi
    print_info "清理用户级缓存..."
    local cleaned=0
    
    # 扫描 /home 和 /root
    for home_dir in /home/* /root; do
        local cache_dir="$home_dir/.cache"
        if [ -d "$cache_dir" ]; then
            local size=$(get_dir_size "$cache_dir")
            if [ "$DRY_RUN" = false ]; then
                rm -rf "$cache_dir"/* 2>/dev/null
            fi
            cleaned=$((cleaned + size))
        fi
    done
    TOTAL_CLEANED=$((TOTAL_CLEANED + cleaned))
    print_success "已释放: $(human_readable $cleaned)"
}

# 分析磁盘
analyze_disk() {
    print_header "磁盘空间分析"
    echo -e "${CYAN}当前使用:${NC} $(get_disk_usage)"
    echo ""
    print_info "Top 10 大文件/目录 (根分区):"
    du -ahx / 2>/dev/null | sort -rh | head -10
    echo ""
}

# 生成报告
generate_report() {
    FINAL_DISK_USAGE=$(get_disk_usage)
    local report_file="$LOG_DIR/clean_report.txt"
    
    cat > "$report_file" <<EOF
==================================================
           系统清理报告
==================================================
时间: $(date)
模式: $([ "$DEEP_CLEAN" = true ] && echo "深度清理" || echo "标准清理")
--------------------------------------------------
清理前: $INITIAL_DISK_USAGE
清理后: $FINAL_DISK_USAGE
共释放: $(human_readable $TOTAL_CLEANED)

[清理项目]
- 包管理器缓存: DONE
- 系统日志归档: DONE
- 临时文件垃圾: DONE
- 孤立软件包:   DONE
- 旧内核版本:   $([ "$DEEP_CLEAN" = true ] && echo "DONE" || echo "SKIP")
- Docker 垃圾:  $(command -v docker &>/dev/null && echo "DONE" || echo "N/A")

日志文件: $LOG_FILE
==================================================
EOF
    print_success "报告已生成: $report_file"
    cat "$report_file"
}

# ------------------------------------------------------------------------------
# 4. 交互菜单与入口
# ------------------------------------------------------------------------------

custom_menu() {
    clear
    print_header "自定义清理"
    echo "1. 清理包管理器缓存"
    echo "2. 清理临时文件 & 日志"
    echo "3. 清理孤立软件包"
    echo "4. 清理旧内核 (慎用)"
    echo "5. 清理 Docker 垃圾"
    echo "6. 清理用户缓存"
    echo "0. 返回上一级"
    echo ""
    read -p "请输入数字组合 (如 1 2 5): " sel
    
    if [[ "$sel" == "0" ]]; then return; fi
    
    [[ "$sel" =~ "1" ]] && clean_package_cache
    [[ "$sel" =~ "2" ]] && { clean_temp_files; clean_log_files; }
    [[ "$sel" =~ "3" ]] && clean_orphans
    [[ "$sel" =~ "4" ]] && { DEEP_CLEAN=true; clean_old_kernels; }
    [[ "$sel" =~ "5" ]] && clean_docker
    [[ "$sel" =~ "6" ]] && { DEEP_CLEAN=true; clean_user_cache; }
    
    echo ""
    read -n 1 -s -r -p "按任意键返回..."
}

interactive_menu() {
    while true; do
        clear
        print_header "系统垃圾清理工具"
        echo -e "${CYAN}磁盘使用:${NC} $(get_disk_usage)"
        echo ""
        echo "1. 快速清理 (缓存/日志/临时文件)"
        echo "2. 标准清理 (快速 + 孤立包 + Docker)"
        echo "3. 深度清理 (标准 + 旧内核 + 用户缓存)"
        echo "4. 仅分析磁盘占用"
        echo "5. 自定义清理项"
        echo "0. 退出"
        echo ""
        read -p "请选择 [0-5]: " choice
        
        case $choice in
            1)
                clean_package_cache; clean_temp_files; clean_log_files
                ;;
            2)
                clean_package_cache; clean_temp_files; clean_log_files
                clean_orphans; clean_docker
                ;;
            3)
                DEEP_CLEAN=true
                clean_package_cache; clean_temp_files; clean_log_files
                clean_orphans; clean_docker; clean_old_kernels; clean_user_cache
                ;;
            4)
                analyze_disk
                read -n 1 -s -r -p "按任意键返回..."
                continue
                ;;
            5)
                custom_menu
                continue
                ;;
            0) exit 0 ;;
            *) print_error "无效输入"; sleep 1; continue ;;
        esac
        
        if [ "$DRY_RUN" = false ]; then generate_report; fi
        read -n 1 -s -r -p "按任意键返回..."
    done
}

main() {
    check_root
    detect_system
    INITIAL_DISK_USAGE=$(get_disk_usage)
    
    # 命令行参数支持
    if [ -n "$1" ]; then
        case "$1" in
            --auto|-a)
                AUTO_MODE=true
                clean_package_cache; clean_temp_files; clean_log_files
                clean_orphans; clean_docker
                generate_report
                ;;
            --deep|-d)
                DEEP_CLEAN=true
                clean_package_cache; clean_temp_files; clean_log_files
                clean_orphans; clean_docker; clean_old_kernels; clean_user_cache
                generate_report
                ;;
            --analyze)
                ANALYZE_ONLY=true
                analyze_disk
                ;;
            --dry-run)
                DRY_RUN=true
                print_warn "DRY RUN 模式: 不会删除任何文件。"
                interactive_menu
                ;;
            --help|-h)
                echo "Usage: bash clean_system.sh [--auto | --deep | --analyze | --dry-run]"
                ;;
            *)
                print_error "未知参数: $1"
                exit 1
                ;;
        esac
    else
        interactive_menu
    fi
}

main "$@"
