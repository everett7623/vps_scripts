#!/bin/bash
# ==============================================================================
# 脚本名称: optimize_system.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/optimize_system.sh
# 描述: VPS 系统基础优化工具 (稳定优先版)
#       专注于提升系统稳定性与基础安全性，移除所有激进参数，防止小内存 OOM。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.2 (Stability First)
# 更新日期: 2026-01-20
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LOG_FILE="/var/log/vps_scripts/optimize_system.log"
BACKUP_DIR="/var/backups/system_optimize"

LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
    get_total_memory() { free -m | awk '/^Mem:/{print $2}'; }
fi

mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR"
TOTAL_RAM=$(get_total_memory)

# ------------------------------------------------------------------------------
# 2. 辅助函数
# ------------------------------------------------------------------------------

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp -a "$file" "$BACKUP_DIR/$(basename "$file")_$(date +%Y%m%d_%H%M%S)"
    fi
}

# ------------------------------------------------------------------------------
# 3. 核心优化模块 (保守策略)
# ------------------------------------------------------------------------------

# 模块1: 内核参数优化 (保守版)
optimize_kernel() {
    print_info "正在应用内核优化 (保守模式)..."
    backup_file "/etc/sysctl.conf"
    
    # 仅保留提升连接效率和开启 BBR 的参数
    # 移除了所有内存强制分配参数
    cat > /etc/sysctl.d/99-vps-optimize.conf <<EOF
# --- 网络连接优化 ---
# 开启 SYN cookies 防止 SYN Flood 攻击
net.ipv4.tcp_syncookies = 1
# 允许重用 TIME-WAIT sockets，对于 Web 服务器很有用
net.ipv4.tcp_tw_reuse = 1
# 缩短 FIN-WAIT-2 状态的时间
net.ipv4.tcp_fin_timeout = 30
# 缩短 Keepalive 探测时间，快速释放死连接
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000

# --- 拥塞控制 ---
# 开启 BBR (如果内核支持)，这对弱网环境稳定性至关重要
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# --- 内存保护 ---
# 降低 Swap 使用倾向，优先使用物理内存，但不完全禁用
vm.swappiness = 10
# 保证有保留内存给关键系统进程，防止死机
vm.min_free_kbytes = 65536

# --- 安全基础 ---
# 禁止 ICMP 广播回应
net.ipv4.icmp_echo_ignore_broadcasts = 1
# 开启恶意错误响应保护
net.ipv4.icmp_ignore_bogus_error_responses = 1
EOF

    sysctl -p /etc/sysctl.d/99-vps-optimize.conf >> "$LOG_FILE" 2>&1
    print_success "内核参数已优化 (稳定策略)。"
}

# 模块2: 系统限制优化 (防止高并发报错)
optimize_limits() {
    print_info "正在优化文件句柄限制..."
    backup_file "/etc/security/limits.conf"
    
    cat > /etc/security/limits.d/20-nproc.conf <<EOF
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
root soft nproc 65535
root hard nproc 65535
root soft nofile 65535
root hard nofile 65535
EOF
    
    # 仅在 Systemd 环境下配置
    if [ -d "/etc/systemd/system.conf.d" ]; then
        cat > /etc/systemd/system.conf.d/limit.conf <<EOF
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF
        systemctl daemon-reexec 2>/dev/null
    fi
    print_success "系统限制已提升 (避免 Too many open files)。"
}

# 模块3: 内存与 Swap (防 OOM 崩溃)
optimize_memory() {
    print_info "正在检查内存保障机制..."
    
    local swap_size=$(free -m | awk '/^Swap:/{print $2}')
    # 如果没有 Swap 且内存小于 2G，强制创建 Swap 以保命
    if [ "$swap_size" -eq 0 ]; then
        print_warn "检测到系统未启用 Swap，这对稳定性是巨大隐患。"
        if [ ! -f /swapfile ]; then
            print_info "正在创建 1GB Swap 文件作为内存缓冲..."
            dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
            chmod 600 /swapfile
            mkswap /swapfile >> "$LOG_FILE"
            swapon /swapfile
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
            print_success "Swap 创建成功，系统崩溃风险大幅降低。"
        fi
    else
        print_success "系统已启用 Swap ($swap_size MB)，状态良好。"
    fi
}

# 模块4: 服务精简 (减少资源占用)
optimize_services() {
    print_info "正在关闭无用的后台服务..."
    # 仅关闭绝对无用的桌面/打印级服务，不触碰核心网络服务
    local svcs=("bluetooth" "cups" "avahi-daemon" "postfix")
    
    for svc in "${svcs[@]}"; do
        if systemctl is-active "$svc" &>/dev/null; then
            systemctl stop "$svc"
            systemctl disable "$svc" >> "$LOG_FILE" 2>&1
            print_success "已禁用闲置服务: $svc"
        fi
    done
}

# 模块5: 基础安全
optimize_security() {
    print_info "正在应用基础安全策略..."
    
    # 仅修改 DNS 解析设置，不关闭 GSSAPI (防止部分旧客户端连接慢)
    if [ -f /etc/ssh/sshd_config ]; then
        backup_file "/etc/ssh/sshd_config"
        sed -i 's/#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
        # 仅当配置存在时修改
        if grep -q "UseDNS yes" /etc/ssh/sshd_config; then
             sed -i 's/UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
        fi
        systemctl reload sshd
    fi
    print_success "SSH 登录速度已优化。"
}

# ------------------------------------------------------------------------------
# 4. 交互菜单
# ------------------------------------------------------------------------------

interactive_menu() {
    while true; do
        clear
        print_header "VPS 稳定优化工具 (Safe Mode)"
        echo -e "${CYAN}说明:${NC} 此模式仅调整最安全的参数，绝不涉及风险操作。"
        echo ""
        echo "1. 一键稳定优化 (推荐)"
        echo "2. 仅优化内核网络 (BBR + TCP)"
        echo "3. 仅检查/创建 Swap (防崩溃)"
        echo "0. 退出"
        echo ""
        read -p "请选择 [0-3]: " choice
        
        case $choice in
            1)
                backup_file "/etc/sysctl.conf"
                optimize_kernel
                optimize_limits
                optimize_memory
                optimize_services
                optimize_security
                ;;
            2) optimize_kernel ;;
            3) optimize_memory ;;
            0) exit 0 ;;
            *) print_error "无效输入"; sleep 1; continue ;;
        esac
        
        echo ""
        print_success "优化完成！"
        print_info "无需重启，参数已即时生效 (Swap/Sysctl)。"
        read -p "按任意键返回..."
        break
    done
}

main() {
    check_root
    
    if [ -n "$1" ]; then
        case "$1" in
            --auto|-a)
                optimize_kernel; optimize_limits
                optimize_memory; optimize_services; optimize_security
                print_success "稳定优化已自动完成。"
                ;;
            --network) optimize_kernel ;;
            --help|-h)
                echo "Usage: bash optimize_system.sh [--auto]"
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
