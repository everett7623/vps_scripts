#!/bin/bash
# ==============================================================================
# 脚本名称: change_hostname.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/change_hostname.sh
# 描述: VPS 主机名修改工具 (全功能版)
#       包含交互菜单、修改验证、回滚机制、云配置适配及修改报告生成。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.0 (Full Feature)
# 更新日期: 2026-01-20
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
LOG_FILE="$LOG_DIR/hostname_change.log"
BACKUP_DIR="/var/backups/hostname_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# 确保目录存在
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    print_separator() { echo -e "${BLUE}------------------------------------------------${NC}"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
fi

# ------------------------------------------------------------------------------
# 2. 辅助功能函数
# ------------------------------------------------------------------------------

# 写入文件日志
write_log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 验证主机名格式
validate_hostname() {
    local hostname=$1
    if [ ${#hostname} -lt 1 ] || [ ${#hostname} -gt 63 ]; then
        print_error "长度错误: 必须在 1-63 个字符之间"
        return 1
    fi
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        print_error "格式错误: 只能包含字母、数字、连字符，且不能以连字符开头/结尾"
        return 1
    fi
    if [[ "$hostname" =~ ^[0-9]+$ ]]; then
        print_error "格式错误: 主机名不能纯数字"
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# 3. 核心逻辑函数
# ------------------------------------------------------------------------------

# 备份配置
backup_configs() {
    print_info "正在备份配置文件..."
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    local files=(
        "/etc/hostname" "/etc/hosts" "/etc/sysconfig/network"
        "/etc/mailname" "/etc/postfix/main.cf" "/etc/cloud/cloud.cfg"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp -p "$file" "$backup_path/" 2>/dev/null
            write_log "BACKUP" "Backed up $file"
        fi
    done
    
    hostname > "$backup_path/old_hostname.txt"
    print_success "备份已保存至: $backup_path"
}

# 修改主机名执行逻辑
perform_change() {
    local new_name=$1
    local old_name=$(hostname)
    
    print_info "正在应用修改: $old_name -> $new_name"
    write_log "INFO" "Changing hostname from $old_name to $new_name"
    
    # 1. Hostnamectl
    if command -v hostnamectl &>/dev/null; then
        hostnamectl set-hostname "$new_name"
    fi
    
    # 2. Files
    echo "$new_name" > /etc/hostname
    
    if [ -f /etc/hosts ]; then
        cp /etc/hosts /etc/hosts.bak
        # 修复 127.0.1.1
        if grep -q "^127\.0\.1\.1" /etc/hosts; then
            sed -i "s/^127\.0\.1\.1.*$/127.0.1.1\t$new_name/" /etc/hosts
        else
            sed -i "/^127\.0\.0\.1/a 127.0.1.1\t$new_name" /etc/hosts
        fi
        sed -i "s/\b$old_name\b/$new_name/g" /etc/hosts
    fi
    
    # 3. Legacy / Cloud
    if [ -f /etc/sysconfig/network ]; then
        if grep -q "^HOSTNAME=" /etc/sysconfig/network; then
            sed -i "s/^HOSTNAME=.*/HOSTNAME=$new_name/" /etc/sysconfig/network
        else
            echo "HOSTNAME=$new_name" >> /etc/sysconfig/network
        fi
    fi
    
    if [ -f /etc/cloud/cloud.cfg ]; then
        if grep -q "preserve_hostname:" /etc/cloud/cloud.cfg; then
            sed -i 's/preserve_hostname: false/preserve_hostname: true/' /etc/cloud/cloud.cfg
        else
            echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
        fi
    fi

    # 4. Apply
    hostname "$new_name"
    
    # 5. Services
    if systemctl is-active systemd-hostnamed &>/dev/null; then systemctl restart systemd-hostnamed; fi
    if systemctl is-active rsyslog &>/dev/null; then systemctl restart rsyslog; fi
    if systemctl is-active postfix &>/dev/null; then 
        postconf -e "myhostname = $new_name" 2>/dev/null
        systemctl restart postfix
    fi
}

# 验证修改结果 (还原原脚本的详细检查)
verify_change() {
    local target_name=$1
    local current_name=$(hostname)
    local success=true
    
    print_separator
    echo -e "${CYAN}验证检查清单:${NC}"
    
    # Check 1: hostname command
    if [ "$current_name" == "$target_name" ]; then
        echo -e "  [${GREEN}√${NC}] Kernel Hostname"
    else
        echo -e "  [${RED}×${NC}] Kernel Hostname (当前: $current_name)"
        success=false
    fi
    
    # Check 2: /etc/hostname
    if [ -f /etc/hostname ] && grep -q "$target_name" /etc/hostname; then
        echo -e "  [${GREEN}√${NC}] /etc/hostname"
    else
        echo -e "  [${RED}×${NC}] /etc/hostname"
        success=false
    fi
    
    # Check 3: /etc/hosts
    if grep -q "$target_name" /etc/hosts; then
        echo -e "  [${GREEN}√${NC}] /etc/hosts"
    else
        echo -e "  [${RED}×${NC}] /etc/hosts"
        success=false
    fi
    
    echo ""
    return $([ "$success" = true ] && echo 0 || echo 1)
}

# 生成修改报告 (还原原脚本功能)
generate_report() {
    local report_file="$LOG_DIR/change_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$report_file" << EOF
==================================================
           主机名修改报告
==================================================
时间: $(date)
旧名称: $1
新名称: $2
--------------------------------------------------
[检查项]
/etc/hostname: $([ -f /etc/hostname ] && echo "Updated" || echo "N/A")
/etc/hosts: Updated
Cloud-Init: $([ -f /etc/cloud/cloud.cfg ] && echo "Patched" || echo "N/A")

备份路径: $BACKUP_DIR/backup_$BACKUP_TIME
日志文件: $LOG_FILE
==================================================
EOF
    print_success "详细报告已生成: $report_file"
}

# 回滚功能
rollback_hostname() {
    local latest=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        print_error "无备份记录，无法回滚。"
        read -n 1 -s -r -p "按任意键返回..."
        return
    fi
    
    local backup_path="$BACKUP_DIR/$latest"
    if [ -f "$backup_path/old_hostname.txt" ]; then
        local old_name=$(cat "$backup_path/old_hostname.txt")
        print_warn "准备回滚至: $old_name (备份时间: ${latest#backup_})"
        
        read -p "确认回滚? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cp -f "$backup_path/hostname" /etc/hostname 2>/dev/null
            cp -f "$backup_path/hosts" /etc/hosts 2>/dev/null
            if [ -f "$backup_path/network" ]; then cp -f "$backup_path/network" /etc/sysconfig/network 2>/dev/null; fi
            hostname "$old_name"
            if command -v hostnamectl &>/dev/null; then hostnamectl set-hostname "$old_name"; fi
            
            write_log "ROLLBACK" "Rolled back to $old_name"
            print_success "回滚成功！"
        else
            print_info "已取消回滚。"
        fi
    else
        print_error "备份文件损坏。"
    fi
    read -n 1 -s -r -p "按任意键返回..."
}

# 查看历史记录
show_history() {
    clear
    print_header "修改历史记录"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lh "$BACKUP_DIR" | grep "backup_" | awk '{print $9}' | while read backup_dir; do
             local ts=${backup_dir#backup_}
             local old_h="未知"
             [ -f "$BACKUP_DIR/$backup_dir/old_hostname.txt" ] && old_h=$(cat "$BACKUP_DIR/$backup_dir/old_hostname.txt")
             echo -e "${CYAN}● 时间:${NC} ${ts:0:4}-${ts:4:2}-${ts:6:2} ${ts:9:2}:${ts:11:2}  ${YELLOW}原主机名:${NC} $old_h"
        done
    else
        echo "暂无历史记录。"
    fi
    echo ""
    read -n 1 -s -r -p "按任意键返回..."
}

# ------------------------------------------------------------------------------
# 4. 交互菜单 (还原原脚本菜单)
# ------------------------------------------------------------------------------

interactive_menu() {
    while true; do
        clear
        print_header "VPS 主机名管理工具"
        echo -e "${CYAN}当前主机名:${NC} $(hostname)"
        echo -e "${CYAN}当前 IP   :${NC} $(hostname -I | awk '{print $1}')"
        print_separator
        
        echo -e "${GREEN}1)${NC} 修改主机名"
        echo -e "${GREEN}2)${NC} 回滚上次修改"
        echo -e "${GREEN}3)${NC} 查看修改历史"
        echo -e "${GREEN}0)${NC} 退出"
        echo ""
        read -p "请输入选项 [0-3]: " choice
        
        case $choice in
            1)
                echo ""
                read -p "请输入新主机名: " new_name
                if [ -z "$new_name" ]; then continue; fi
                
                if validate_hostname "$new_name"; then
                    if [ "$new_name" == "$(hostname)" ]; then
                        print_warn "新名称与当前相同。"
                        sleep 1
                        continue
                    fi
                    
                    local old_name=$(hostname)
                    backup_configs
                    perform_change "$new_name"
                    
                    if verify_change "$new_name"; then
                        generate_report "$old_name" "$new_name"
                        print_success "修改成功！建议重新连接 SSH。"
                    else
                        print_error "部分验证失败，请检查日志。"
                    fi
                    read -n 1 -s -r -p "按任意键继续..."
                else
                    read -n 1 -s -r -p "按任意键继续..."
                fi
                ;;
            2) rollback_hostname ;;
            3) show_history ;;
            0) exit 0 ;;
            *) print_error "无效输入"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 5. 主程序入口
# ------------------------------------------------------------------------------

main() {
    check_root
    
    # 命令行模式支持
    if [ -n "$1" ]; then
        case "$1" in
            --rollback) rollback_hostname; exit ;;
            --help) echo "Usage: bash change_hostname.sh [new_hostname | --rollback]"; exit ;;
            *) 
                # 直接修改模式
                if validate_hostname "$1"; then
                    backup_configs
                    perform_change "$1"
                    verify_change "$1"
                fi
                exit
                ;;
        esac
    else
        # 默认进入交互菜单
        interactive_menu
    fi
}

main "$@"
