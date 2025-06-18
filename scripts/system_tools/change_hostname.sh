#!/bin/bash

#==============================================================================
# 脚本名称: change_hostname.sh
# 描述: VPS主机名修改脚本 - 安全修改系统主机名并更新相关配置
# 作者: Jensfrank
# 路径: vps_scripts/scripts/system_tools/change_hostname.sh
# 使用方法: bash change_hostname.sh [新主机名]
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
LOG_FILE="$LOG_DIR/change_hostname_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="/var/backups/hostname_change"
BACKUP_TIME=$(date +%Y%m%d_%H%M%S)

# 全局变量
OLD_HOSTNAME=""
NEW_HOSTNAME=""
OS_TYPE=""
OS_VERSION=""
USE_HOSTNAMECTL=false
ROLLBACK_MODE=false

# 创建必要目录
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

# 打印错误消息
print_error() {
    local msg=$1
    echo -e "${RED}错误: ${msg}${NC}"
    log "ERROR" "$msg"
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
        OS_TYPE="unknown"
    fi
    
    # 检查是否有hostnamectl命令
    if command -v hostnamectl &> /dev/null; then
        USE_HOSTNAMECTL=true
    fi
    
    print_msg "$GREEN" "检测到系统: $OS_TYPE $OS_VERSION"
}

# 获取当前主机名
get_current_hostname() {
    if [ "$USE_HOSTNAMECTL" = true ]; then
        OLD_HOSTNAME=$(hostnamectl hostname 2>/dev/null || hostname)
    else
        OLD_HOSTNAME=$(hostname)
    fi
    
    print_msg "$CYAN" "当前主机名: $OLD_HOSTNAME"
}

# 验证主机名格式
validate_hostname() {
    local hostname=$1
    
    # 检查长度（1-63个字符）
    if [ ${#hostname} -lt 1 ] || [ ${#hostname} -gt 63 ]; then
        print_error "主机名长度必须在1-63个字符之间"
        return 1
    fi
    
    # 检查格式（只能包含字母、数字和连字符）
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        print_error "主机名格式无效。只能包含字母、数字和连字符，且不能以连字符开头或结尾"
        return 1
    fi
    
    # 检查是否全是数字
    if [[ "$hostname" =~ ^[0-9]+$ ]]; then
        print_error "主机名不能全是数字"
        return 1
    fi
    
    # 检查保留名称
    local reserved_names=("localhost" "localdomain" "localhost.localdomain")
    for reserved in "${reserved_names[@]}"; do
        if [ "$hostname" = "$reserved" ]; then
            print_error "不能使用保留的主机名: $reserved"
            return 1
        fi
    done
    
    return 0
}

# 备份配置文件
backup_configs() {
    print_msg "$BLUE" "备份配置文件..."
    
    local backup_path="$BACKUP_DIR/backup_$BACKUP_TIME"
    mkdir -p "$backup_path"
    
    # 备份相关文件
    local files_to_backup=(
        "/etc/hostname"
        "/etc/hosts"
        "/etc/sysconfig/network"
        "/etc/HOSTNAME"
        "/etc/mailname"
        "/etc/postfix/main.cf"
        "/etc/cloud/cloud.cfg"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            cp -p "$file" "$backup_path/" 2>/dev/null
            log "INFO" "备份文件: $file"
        fi
    done
    
    # 保存当前主机名信息
    echo "$OLD_HOSTNAME" > "$backup_path/old_hostname.txt"
    
    print_msg "$GREEN" "配置备份完成: $backup_path"
}

# 修改主机名
change_hostname() {
    print_msg "$BLUE" "\n开始修改主机名..."
    
    # 1. 使用hostnamectl（如果可用）
    if [ "$USE_HOSTNAMECTL" = true ]; then
        print_msg "$CYAN" "使用hostnamectl设置主机名..."
        hostnamectl set-hostname "$NEW_HOSTNAME" &>> "$LOG_FILE"
        
        # 设置pretty hostname
        local pretty_hostname=$(echo "$NEW_HOSTNAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
        hostnamectl set-hostname "$pretty_hostname" --pretty &>> "$LOG_FILE"
    fi
    
    # 2. 修改/etc/hostname
    if [ -f /etc/hostname ]; then
        print_msg "$CYAN" "更新 /etc/hostname..."
        echo "$NEW_HOSTNAME" > /etc/hostname
    fi
    
    # 3. 修改/etc/hosts
    if [ -f /etc/hosts ]; then
        print_msg "$CYAN" "更新 /etc/hosts..."
        
        # 备份原始hosts文件
        cp /etc/hosts /etc/hosts.bak
        
        # 更新hosts文件中的主机名
        # 首先处理127.0.1.1行（Debian/Ubuntu）
        if grep -q "^127\.0\.1\.1" /etc/hosts; then
            sed -i "s/^127\.0\.1\.1.*$/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
        else
            # 如果没有127.0.1.1，添加一行
            sed -i "/^127\.0\.0\.1/a 127.0.1.1\t$NEW_HOSTNAME" /etc/hosts
        fi
        
        # 替换所有旧主机名
        sed -i "s/\b$OLD_HOSTNAME\b/$NEW_HOSTNAME/g" /etc/hosts
        
        # 确保localhost条目存在
        if ! grep -q "^127\.0\.0\.1.*localhost" /etc/hosts; then
            sed -i "1i 127.0.0.1\tlocalhost" /etc/hosts
        fi
    fi
    
    # 4. 修改网络配置文件（RHEL/CentOS）
    if [ -f /etc/sysconfig/network ]; then
        print_msg "$CYAN" "更新 /etc/sysconfig/network..."
        if grep -q "^HOSTNAME=" /etc/sysconfig/network; then
            sed -i "s/^HOSTNAME=.*/HOSTNAME=$NEW_HOSTNAME/" /etc/sysconfig/network
        else
            echo "HOSTNAME=$NEW_HOSTNAME" >> /etc/sysconfig/network
        fi
    fi
    
    # 5. 修改/etc/HOSTNAME（某些旧系统）
    if [ -f /etc/HOSTNAME ]; then
        print_msg "$CYAN" "更新 /etc/HOSTNAME..."
        echo "$NEW_HOSTNAME" > /etc/HOSTNAME
    fi
    
    # 6. 修改邮件配置
    if [ -f /etc/mailname ]; then
        print_msg "$CYAN" "更新 /etc/mailname..."
        echo "$NEW_HOSTNAME" > /etc/mailname
    fi
    
    # 7. 更新postfix配置（如果存在）
    if [ -f /etc/postfix/main.cf ]; then
        print_msg "$CYAN" "更新 Postfix 配置..."
        postconf -e "myhostname = $NEW_HOSTNAME" &>> "$LOG_FILE"
        postconf -e "mydestination = $NEW_HOSTNAME, localhost.localdomain, localhost" &>> "$LOG_FILE"
    fi
    
    # 8. 处理云服务器配置
    handle_cloud_config
    
    # 9. 立即应用新主机名
    if [ "$USE_HOSTNAMECTL" = false ]; then
        hostname "$NEW_HOSTNAME"
    fi
    
    print_msg "$GREEN" "主机名修改完成"
}

# 处理云服务器特殊配置
handle_cloud_config() {
    # 检查是否是云服务器
    if [ -f /etc/cloud/cloud.cfg ]; then
        print_msg "$CYAN" "检测到云服务器环境，更新cloud-init配置..."
        
        # 防止cloud-init覆盖主机名
        if grep -q "preserve_hostname:" /etc/cloud/cloud.cfg; then
            sed -i 's/preserve_hostname: false/preserve_hostname: true/' /etc/cloud/cloud.cfg
        else
            echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
        fi
        
        # 更新cloud-init的主机名设置
        if [ -f /etc/cloud/cloud.cfg.d/99_hostname.cfg ]; then
            echo "hostname: $NEW_HOSTNAME" > /etc/cloud/cloud.cfg.d/99_hostname.cfg
        fi
    fi
    
    # AWS EC2特殊处理
    if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ] && grep -q "EC2" /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null; then
        print_msg "$CYAN" "检测到AWS EC2环境..."
        # EC2实例可能需要特殊处理
    fi
    
    # 阿里云ECS特殊处理
    if [ -f /etc/motd ] && grep -q "Alibaba Cloud" /etc/motd; then
        print_msg "$CYAN" "检测到阿里云ECS环境..."
    fi
}

# 更新系统服务
update_services() {
    print_msg "$BLUE" "\n重启相关服务..."
    
    # 重启网络服务（根据系统类型）
    case $OS_TYPE in
        ubuntu|debian)
            if systemctl is-active systemd-hostnamed &> /dev/null; then
                systemctl restart systemd-hostnamed &>> "$LOG_FILE"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if systemctl is-active NetworkManager &> /dev/null; then
                systemctl restart NetworkManager &>> "$LOG_FILE"
            elif systemctl is-active network &> /dev/null; then
                systemctl restart network &>> "$LOG_FILE"
            fi
            ;;
    esac
    
    # 重启日志服务
    if systemctl is-active rsyslog &> /dev/null; then
        systemctl restart rsyslog &>> "$LOG_FILE"
    fi
    
    # 重启邮件服务（如果存在）
    if systemctl is-active postfix &> /dev/null; then
        systemctl restart postfix &>> "$LOG_FILE"
    fi
    
    print_msg "$GREEN" "服务重启完成"
}

# 验证修改结果
verify_change() {
    print_msg "$BLUE" "\n验证修改结果..."
    
    local current_hostname=$(hostname)
    local success=true
    
    echo -e "${CYAN}验证项目:${NC}"
    
    # 验证hostname命令
    if [ "$current_hostname" = "$NEW_HOSTNAME" ]; then
        echo -e "  ${GREEN}✓${NC} hostname命令: $current_hostname"
    else
        echo -e "  ${RED}✗${NC} hostname命令: $current_hostname (期望: $NEW_HOSTNAME)"
        success=false
    fi
    
    # 验证/etc/hostname
    if [ -f /etc/hostname ]; then
        local file_hostname=$(cat /etc/hostname)
        if [ "$file_hostname" = "$NEW_HOSTNAME" ]; then
            echo -e "  ${GREEN}✓${NC} /etc/hostname: $file_hostname"
        else
            echo -e "  ${RED}✗${NC} /etc/hostname: $file_hostname (期望: $NEW_HOSTNAME)"
            success=false
        fi
    fi
    
    # 验证/etc/hosts
    if grep -q "$NEW_HOSTNAME" /etc/hosts; then
        echo -e "  ${GREEN}✓${NC} /etc/hosts: 包含新主机名"
    else
        echo -e "  ${RED}✗${NC} /etc/hosts: 未找到新主机名"
        success=false
    fi
    
    # 验证hostnamectl（如果可用）
    if [ "$USE_HOSTNAMECTL" = true ]; then
        local ctl_hostname=$(hostnamectl hostname 2>/dev/null)
        if [ "$ctl_hostname" = "$NEW_HOSTNAME" ]; then
            echo -e "  ${GREEN}✓${NC} hostnamectl: $ctl_hostname"
        else
            echo -e "  ${RED}✗${NC} hostnamectl: $ctl_hostname (期望: $NEW_HOSTNAME)"
            success=false
        fi
    fi
    
    echo ""
    if [ "$success" = true ]; then
        print_msg "$GREEN" "主机名修改验证通过！"
        return 0
    else
        print_msg "$RED" "主机名修改验证失败，请检查日志"
        return 1
    fi
}

# 回滚功能
rollback_hostname() {
    print_msg "$YELLOW" "\n执行主机名回滚..."
    
    # 查找最新的备份
    local latest_backup=$(ls -t "$BACKUP_DIR" | head -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "没有找到备份文件，无法回滚"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$latest_backup"
    
    # 读取原始主机名
    if [ -f "$backup_path/old_hostname.txt" ]; then
        local original_hostname=$(cat "$backup_path/old_hostname.txt")
        NEW_HOSTNAME=$original_hostname
        
        print_msg "$CYAN" "恢复主机名为: $original_hostname"
        
        # 恢复备份的文件
        for file in "$backup_path"/*; do
            if [ -f "$file" ] && [ "$(basename "$file")" != "old_hostname.txt" ]; then
                local target="/$(basename "$file")"
                cp -p "$file" "$target" 2>/dev/null
                print_msg "$CYAN" "恢复文件: $target"
            fi
        done
        
        # 应用主机名
        if [ "$USE_HOSTNAMECTL" = true ]; then
            hostnamectl set-hostname "$original_hostname"
        else
            hostname "$original_hostname"
        fi
        
        print_msg "$GREEN" "回滚完成"
        return 0
    else
        print_error "备份文件损坏，无法回滚"
        return 1
    fi
}

# 显示主机名信息
show_hostname_info() {
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}主机名信息:${NC}"
    echo -e "  当前主机名: $(hostname)"
    [ "$USE_HOSTNAMECTL" = true ] && echo -e "  静态主机名: $(hostnamectl --static)"
    [ "$USE_HOSTNAMECTL" = true ] && echo -e "  瞬时主机名: $(hostnamectl --transient)"
    [ "$USE_HOSTNAMECTL" = true ] && echo -e "  美观主机名: $(hostnamectl --pretty)"
    echo -e "  完全限定域名: $(hostname -f 2>/dev/null || echo '未设置')"
    echo -e "  IP地址: $(hostname -I 2>/dev/null || echo '未知')"
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}"
}

# 生成修改报告
generate_report() {
    local report_file="$LOG_DIR/hostname_change_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
================================================================================
                          主机名修改报告
================================================================================
修改时间: $(date '+%Y-%m-%d %H:%M:%S')
系统信息: $OS_TYPE $OS_VERSION
原主机名: $OLD_HOSTNAME
新主机名: $NEW_HOSTNAME
--------------------------------------------------------------------------------

修改的配置文件:
$([ -f /etc/hostname ] && echo "✓ /etc/hostname")
✓ /etc/hosts
$([ -f /etc/sysconfig/network ] && echo "✓ /etc/sysconfig/network")
$([ -f /etc/mailname ] && echo "✓ /etc/mailname")
$([ -f /etc/postfix/main.cf ] && echo "✓ /etc/postfix/main.cf")
$([ -f /etc/cloud/cloud.cfg ] && echo "✓ /etc/cloud/cloud.cfg")

备份位置: $BACKUP_DIR/backup_$BACKUP_TIME
日志文件: $LOG_FILE

注意事项:
1. 某些应用可能需要重启才能识别新主机名
2. 如果使用了主机名作为配置的应用需要手动更新
3. SSH密钥可能需要重新生成

================================================================================
EOF
    
    print_msg "$GREEN" "\n修改报告已生成: $report_file"
}

# 交互式输入
interactive_input() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                         VPS 主机名修改工具 v1.0                            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示当前主机名信息
    show_hostname_info
    
    echo ""
    echo -e "${CYAN}请选择操作:${NC}"
    echo -e "${GREEN}1)${NC} 修改主机名"
    echo -e "${GREEN}2)${NC} 回滚上次修改"
    echo -e "${GREEN}3)${NC} 查看修改历史"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-3]: " choice
    
    case $choice in
        1)
            echo ""
            read -p "请输入新的主机名: " NEW_HOSTNAME
            
            # 去除首尾空格
            NEW_HOSTNAME=$(echo "$NEW_HOSTNAME" | xargs)
            
            if [ -z "$NEW_HOSTNAME" ]; then
                print_error "主机名不能为空"
                sleep 2
                interactive_input
                return
            fi
            
            if ! validate_hostname "$NEW_HOSTNAME"; then
                sleep 2
                interactive_input
                return
            fi
            
            if [ "$NEW_HOSTNAME" = "$OLD_HOSTNAME" ]; then
                print_msg "$YELLOW" "新主机名与当前主机名相同，无需修改"
                sleep 2
                interactive_input
                return
            fi
            
            echo ""
            echo -e "${YELLOW}确认修改:${NC}"
            echo -e "  原主机名: $OLD_HOSTNAME"
            echo -e "  新主机名: $NEW_HOSTNAME"
            echo ""
            read -p "是否继续？(y/N): " confirm
            
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                print_msg "$YELLOW" "操作已取消"
                exit 0
            fi
            ;;
        2)
            ROLLBACK_MODE=true
            rollback_hostname
            exit $?
            ;;
        3)
            echo ""
            echo -e "${CYAN}修改历史:${NC}"
            ls -la "$BACKUP_DIR" 2>/dev/null | grep -v "^total" | tail -n +2
            echo ""
            read -p "按回车键继续..."
            interactive_input
            ;;
        0)
            print_msg "$YELLOW" "退出程序"
            exit 0
            ;;
        *)
            print_error "无效选项"
            sleep 2
            interactive_input
            ;;
    esac
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项] [新主机名]

选项:
  新主机名        直接指定新的主机名
  --rollback      回滚到上次的主机名
  --info          显示当前主机名信息
  --help, -h      显示此帮助信息

示例:
  $0                  # 交互式修改
  $0 myserver         # 修改主机名为myserver
  $0 --rollback       # 回滚上次修改
  $0 --info           # 查看主机名信息

主机名规则:
  - 长度1-63个字符
  - 只能包含字母、数字和连字符(-)
  - 不能以连字符开头或结尾
  - 不能全是数字
  - 不能使用保留名称(如localhost)

注意:
  - 此脚本需要root权限运行
  - 修改前会自动备份相关配置
  - 某些服务可能需要重启
EOF
}

# 主函数
main() {
    # 初始化
    create_directories
    check_root
    
    # 解析参数
    if [ $# -eq 0 ]; then
        # 无参数，进入交互模式
        detect_os
        get_current_hostname
        interactive_input
    else
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --rollback)
                detect_os
                rollback_hostname
                exit $?
                ;;
            --info)
                detect_os
                get_current_hostname
                show_hostname_info
                exit 0
                ;;
            -*)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # 直接指定了新主机名
                NEW_HOSTNAME="$1"
                detect_os
                get_current_hostname
                
                if ! validate_hostname "$NEW_HOSTNAME"; then
                    exit 1
                fi
                
                if [ "$NEW_HOSTNAME" = "$OLD_HOSTNAME" ]; then
                    print_msg "$YELLOW" "新主机名与当前主机名相同，无需修改"
                    exit 0
                fi
                ;;
        esac
    fi
    
    # 开始修改流程
    log "INFO" "开始修改主机名: $OLD_HOSTNAME -> $NEW_HOSTNAME"
    
    backup_configs
    change_hostname
    update_services
    
    # 验证修改结果
    if verify_change; then
        generate_report
        echo ""
        show_hostname_info
        echo ""
        print_msg "$GREEN" "主机名修改成功！"
        print_msg "$YELLOW" "\n提示: 建议重新登录SSH会话以使用新主机名"
    else
        print_error "主机名修改可能未完全成功，请检查日志: $LOG_FILE"
        echo ""
        read -p "是否尝试回滚？(y/N): " rollback_confirm
        if [[ "$rollback_confirm" =~ ^[Yy]$ ]]; then
            rollback_hostname
        fi
        exit 1
    fi
}

# 运行主函数
main "$@"
