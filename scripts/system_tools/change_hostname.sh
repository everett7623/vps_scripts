#!/bin/bash
# ==============================================================================
# 脚本名称: change_hostname.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/change_hostname.sh
# 描述: VPS 主机名修改工具
#       安全修改系统主机名，自动更新 /etc/hosts、云配置及邮件服务，支持一键回滚。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.1.0 (Remote Ready)
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
LOG_FILE="$LOG_DIR/hostname_change_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/hostname_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# 尝试加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
fi

# ------------------------------------------------------------------------------
# 2. 本地辅助函数
# ------------------------------------------------------------------------------

# 写入文件日志 (不输出到屏幕)
write_log() {
    local level=$1
    shift
    local message="$@"
    # 确保日志目录存在
    if [ ! -d "$LOG_DIR" ]; then mkdir -p "$LOG_DIR"; fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 验证主机名格式
validate_hostname() {
    local hostname=$1
    
    # 长度检查 (1-63)
    if [ ${#hostname} -lt 1 ] || [ ${#hostname} -gt 63 ]; then
        print_error "主机名长度必须在 1-63 个字符之间"
        return 1
    fi
    
    # 格式检查 (字母数字连字符)
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        print_error "格式无效: 只能包含字母、数字、连字符，且不能以连字符开头/结尾"
        return 1
    fi
    
    # 纯数字检查
    if [[ "$hostname" =~ ^[0-9]+$ ]]; then
        print_error "主机名不能纯数字"
        return 1
    fi
    
    # 保留字检查
    local reserved=("localhost" "localdomain" "localhost.localdomain")
    for r in "${reserved[@]}"; do
        if [ "$hostname" = "$r" ]; then
            print_error "不能使用保留名称: $r"
            return 1
        fi
    done
    return 0
}

# ------------------------------------------------------------------------------
# 3. 核心功能函数
# ------------------------------------------------------------------------------

# 备份配置文件
backup_configs() {
    print_info "正在创建配置备份..."
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    local files=(
        "/etc/hostname" "/etc/hosts" "/etc/sysconfig/network"
        "/etc/HOSTNAME" "/etc/mailname" "/etc/postfix/main.cf"
        "/etc/cloud/cloud.cfg"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp -p "$file" "$backup_path/" 2>/dev/null
            write_log "BACKUP" "Backed up $file"
        fi
    done
    
    # 保存旧主机名
    hostname > "$backup_path/old_hostname.txt"
    print_success "备份已保存至: $backup_path"
}

# 修改核心配置
apply_new_hostname() {
    local new_name=$1
    local old_name=$(hostname)
    
    print_info "正在应用新主机名: $new_name"
    write_log "INFO" "Changing hostname from $old_name to $new_name"
    
    # 1. Hostnamectl (Systemd)
    if command -v hostnamectl &>/dev/null; then
        hostnamectl set-hostname "$new_name"
        write_log "INFO" "Updated via hostnamectl"
    fi
    
    # 2. /etc/hostname
    if [ -f /etc/hostname ]; then
        echo "$new_name" > /etc/hostname
    fi
    
    # 3. /etc/hosts (智能替换)
    if [ -f /etc/hosts ]; then
        # 修正 127.0.1.1 (Debian/Ubuntu 常见)
        if grep -q "^127\.0\.1\.1" /etc/hosts; then
            sed -i "s/^127\.0\.1\.1.*$/127.0.1.1\t$new_name/" /etc/hosts
        else
            # 如果没有，在 127.0.0.1 下面加一行
            sed -i "/^127\.0\.0\.1/a 127.0.1.1\t$new_name" /etc/hosts
        fi
        # 全局替换旧主机名
        sed -i "s/\b$old_name\b/$new_name/g" /etc/hosts
        write_log "INFO" "Updated /etc/hosts"
    fi
    
    # 4. 兼容性配置 (RHEL/CentOS 旧版)
    if [ -f /etc/sysconfig/network ]; then
        if grep -q "^HOSTNAME=" /etc/sysconfig/network; then
            sed -i "s/^HOSTNAME=.*/HOSTNAME=$new_name/" /etc/sysconfig/network
        else
            echo "HOSTNAME=$new_name" >> /etc/sysconfig/network
        fi
    fi
    
    # 5. 邮件配置
    if [ -f /etc/mailname ]; then echo "$new_name" > /etc/mailname; fi
    if [ -f /etc/postfix/main.cf ] && command -v postconf &>/dev/null; then
        postconf -e "myhostname = $new_name"
        postconf -e "mydestination = $new_name, localhost.localdomain, localhost"
        write_log "INFO" "Updated Postfix config"
    fi
    
    # 6. 立即生效
    hostname "$new_name"
}

# 处理云主机配置 (防止重启还原)
handle_cloud_init() {
    if [ -f /etc/cloud/cloud.cfg ]; then
        print_info "检测到 cloud-init，正在更新配置..."
        if grep -q "preserve_hostname:" /etc/cloud/cloud.cfg; then
            sed -i 's/preserve_hostname: false/preserve_hostname: true/' /etc/cloud/cloud.cfg
        else
            echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
        fi
        write_log "INFO" "Updated cloud-init preserve_hostname"
    fi
}

# 重启相关服务
restart_related_services() {
    print_info "正在刷新系统服务..."
    if systemctl is-active systemd-hostnamed &>/dev/null; then systemctl restart systemd-hostnamed; fi
    if systemctl is-active rsyslog &>/dev/null; then systemctl restart rsyslog; fi
    if systemctl is-active postfix &>/dev/null; then systemctl restart postfix; fi
}

# 回滚操作
rollback_action() {
    local latest=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        print_error "未找到备份文件，无法回滚。"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$latest"
    if [ -f "$backup_path/old_hostname.txt" ]; then
        local old_name=$(cat "$backup_path/old_hostname.txt")
        print_warn "正在回滚至主机名: $old_name"
        
        # 恢复文件
        cp -f "$backup_path/hostname" /etc/hostname 2>/dev/null
        cp -f "$backup_path/hosts" /etc/hosts 2>/dev/null
        
        # 重新应用
        hostname "$old_name"
        if command -v hostnamectl &>/dev/null; then hostnamectl set-hostname "$old_name"; fi
        
        print_success "回滚完成。请检查 /etc/hosts 内容确认。"
    else
        print_error "备份文件不完整。"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 4. 主程序入口
# ------------------------------------------------------------------------------

show_help() {
    echo "使用方法: bash change_hostname.sh [选项] [新主机名]"
    echo "  <新主机名>    直接修改为指定名称"
    echo "  --rollback    回滚到上一次修改"
    echo "  --help        显示此帮助"
}

main() {
    check_root
    
    # 参数处理
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        show_help
        exit 0
    elif [ "$1" == "--rollback" ]; then
        rollback_action
        exit $?
    fi

    # 获取主机名
    local new_hostname="$1"
    
    # 如果未提供参数，进入交互模式
    if [ -z "$new_hostname" ]; then
        clear
        print_header "VPS 主机名修改工具"
        echo -e "${CYAN}当前主机名:${NC} $(hostname)"
        echo -e "${CYAN}当前 IP   :${NC} $(hostname -I | awk '{print $1}')"
        echo ""
        read -p "请输入新的主机名 (留空退出): " new_hostname
    fi
    
    # 检查是否退出
    if [ -z "$new_hostname" ]; then
        print_warn "操作已取消。"
        exit 0
    fi
    
    # 验证与执行
    if validate_hostname "$new_hostname"; then
        if [ "$new_hostname" == "$(hostname)" ]; then
            print_warn "新主机名与当前相同，无需修改。"
            exit 0
        fi
        
        echo ""
        backup_configs
        apply_new_hostname "$new_hostname"
        handle_cloud_init
        restart_related_services
        
        echo ""
        print_success "主机名已成功修改为: $new_hostname"
        print_warn "建议重新连接 SSH 会话以更新提示符。"
        write_log "SUCCESS" "Hostname changed successfully"
    else
        exit 1
    fi
}

main "$@"
