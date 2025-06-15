#!/bin/bash
#/scripts/system_tools/clean_system.sh - VPS Scripts 系统清理脚本 - 清理系统垃圾文件和释放空间

# 加载核心功能库
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

if [[ -f "${PARENT_DIR}/lib/common_functions.sh" ]]; then
    source "${PARENT_DIR}/lib/common_functions.sh"
else
    echo "错误：无法找到核心功能库" >&2
    exit 1
fi

# 脚本信息
SCRIPT_NAME="clean_system"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="系统清理工具 - 清理垃圾文件、日志、缓存等"

# 清理前的磁盘使用情况
show_disk_usage() {
    echo -e "${CYAN}当前磁盘使用情况：${NC}"
    df -h | grep -E '^/dev/|^Filesystem'
    echo ""
}

# 清理包管理器缓存
clean_package_cache() {
    log INFO "清理包管理器缓存..."
    
    case "$PKG_MANAGER" in
        apt-get)
            apt-get clean -y
            apt-get autoclean -y
            apt-get autoremove --purge -y
            # 清理不再需要的包
            dpkg -l | awk '/^rc/ {print $2}' | xargs -r dpkg --purge
            ;;
        yum)
            yum clean all
            yum autoremove -y
            ;;
        dnf)
            dnf clean all
            dnf autoremove -y
            ;;
        pacman)
            pacman -Sc --noconfirm
            # 清理孤儿包
            pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
            ;;
        zypper)
            zypper clean --all
            ;;
        *)
            log WARN "未知的包管理器: $PKG_MANAGER"
            return 1
            ;;
    esac
    
    log INFO "包管理器缓存清理完成"
}

# 清理系统日志
clean_logs() {
    log INFO "清理系统日志..."
    
    # 清理 journalctl 日志（保留最近1周）
    if command_exists journalctl; then
        journalctl --vacuum-time=7d
    fi
    
    # 清理其他日志文件
    local log_dirs=(
        "/var/log"
        "/var/log/nginx"
        "/var/log/apache2"
        "/var/log/httpd"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            # 清理超过30天的日志
            find "$dir" -type f -name "*.log" -mtime +30 -delete 2>/dev/null
            find "$dir" -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
            # 清空当前日志文件但保留文件
            find "$dir" -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null
        fi
    done
    
    log INFO "日志清理完成"
}

# 清理临时文件
clean_temp_files() {
    log INFO "清理临时文件..."
    
    # 清理 /tmp 目录（保留最近7天的文件）
    find /tmp -type f -atime +7 -delete 2>/dev/null
    find /var/tmp -type f -atime +7 -delete 2>/dev/null
    
    # 清理用户缓存
    if [[ -d "$HOME/.cache" ]]; then
        find "$HOME/.cache" -type f -atime +30 -delete 2>/dev/null
    fi
    
    log INFO "临时文件清理完成"
}

# 清理内核文件
clean_kernels() {
    if [[ "$PKG_MANAGER" == "apt-get" ]]; then
        log INFO "清理旧内核文件..."
        
        # 获取当前内核版本
        local current_kernel=$(uname -r)
        
        # 列出所有内核
        local kernels=$(dpkg -l | grep linux-image | grep -v "$current_kernel" | awk '{print $2}')
        
        if [[ -n "$kernels" ]]; then
            echo -e "${YELLOW}发现以下旧内核：${NC}"
            echo "$kernels"
            
            if confirm_action "是否删除这些旧内核？" "n"; then
                apt-get remove --purge $kernels -y
            fi
        else
            log INFO "没有发现需要清理的旧内核"
        fi
    fi
}

# 清理Docker（如果存在）
clean_docker() {
    if command_exists docker; then
        log INFO "清理Docker资源..."
        
        # 清理未使用的容器、网络、镜像和卷
        docker system prune -a --volumes -f
        
        log INFO "Docker清理完成"
    fi
}

# 计算清理节省的空间
calculate_saved_space() {
    local before=$1
    local after=$2
    
    # 提取使用的空间（GB）
    local before_used=$(echo "$before" | awk '/\/$/ {print $3}' | sed 's/G//')
    local after_used=$(echo "$after" | awk '/\/$/ {print $3}' | sed 's/G//')
    
    # 计算差值
    local saved=$(echo "scale=2; $before_used - $after_used" | bc 2>/dev/null || echo "0")
    
    if [[ "$saved" != "0" ]] && [[ "$saved" != "-"* ]]; then
        echo -e "${GREEN}总共释放了 ${saved}GB 空间${NC}"
    fi
}

# 主函数
main() {
    clear
    echo -e "${GREEN}=== 系统清理工具 v${SCRIPT_VERSION} ===${NC}"
    echo -e "${YELLOW}${SCRIPT_DESCRIPTION}${NC}"
    echo ""
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_os
    get_package_manager
    
    # 显示清理前的磁盘使用情况
    echo -e "${CYAN}清理前：${NC}"
    local before_usage=$(df -h)
    show_disk_usage
    
    # 确认操作
    echo -e "${YELLOW}警告：系统清理将删除缓存、日志和临时文件。${NC}"
    if ! confirm_action "确定要继续吗？" "n"; then
        log INFO "用户取消清理"
        return 0
    fi
    
    echo ""
    # 执行清理操作
    local tasks=(
        "clean_package_cache|清理包管理器缓存"
        "clean_logs|清理系统日志"
        "clean_temp_files|清理临时文件"
        "clean_kernels|清理旧内核"
        "clean_docker|清理Docker资源"
    )
    
    local total=${#tasks[@]}
    local current=0
    
    for task in "${tasks[@]}"; do
        current=$((current + 1))
        local func="${task%%|*}"
        local desc="${task##*|}"
        
        echo -e "${BLUE}[$current/$total] ${desc}...${NC}"
        
        # 检查函数是否存在并执行
        if declare -f "$func" > /dev/null; then
            $func
        fi
        
        show_progress $current $total
        echo ""
    done
    
    echo ""
    # 显示清理后的磁盘使用情况
    echo -e "${CYAN}清理后：${NC}"
    local after_usage=$(df -h)
    show_disk_usage
    
    # 计算节省的空间
    calculate_saved_space "$before_usage" "$after_usage"
    
    echo ""
    log INFO "系统清理完成！"
    
    # 提示重启
    if confirm_action "建议重启系统以确保所有更改生效。是否现在重启？" "n"; then
        log WARN "系统将在5秒后重启..."
        sleep 5
        reboot
    fi
    
    press_any_key
}

# 清理函数（脚本退出时执行）
cleanup() {
    # 这里可以添加脚本退出时的清理操作
    :
}

# 设置信号处理
trap cleanup EXIT

# 执行主函数
main "$@"
