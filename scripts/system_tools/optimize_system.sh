#!/bin/bash
# ==============================================================================
# 脚本名称: optimize_system.sh
# 仓库地址: https://github.com/everett7623/vps_scripts
# 脚本路径: scripts/system_tools/optimize_system.sh
# 描述: VPS 系统深度优化工具
#       包含内核参数调优、网络栈优化、文件系统加速、服务精简、安全加固及CPU调优。
# 作者: Jensfrank (Optimized by AI)
# 版本: 1.2.1 (Full Feature)
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化与依赖加载
# ------------------------------------------------------------------------------

# 获取脚本真实路径
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

# 默认日志路径
LOG_FILE="/var/log/vps_scripts/optimize_system.log"
BACKUP_DIR="/var/backups/system_optimize"

# 加载公共函数库
LIB_FILE="$PROJECT_ROOT/lib/common_functions.sh"
CONFIG_FILE="$PROJECT_ROOT/config/vps_scripts.conf"

if [ -f "$LIB_FILE" ]; then
    source "$LIB_FILE"
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
else
    # [远程模式回退] 定义必需的 UI 和辅助函数
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
    print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
    print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
    print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
    print_error() { echo -e "${RED}[错误] $1${NC}"; }
    print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }
    check_root() { [[ $EUID -ne 0 ]] && { echo -e "${RED}需要 root 权限${NC}"; exit 1; }; }
    get_total_memory() { free -m | awk '/^Mem:/{print $2}'; }
    get_cpu_cores() { nproc; }
fi

# 确保目录存在
mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_DIR"

# 全局变量
TOTAL_RAM=$(get_total_memory)
CPU_CORES=$(get_cpu_cores)
IS_VIRTUAL=$(systemd-detect-virt 2>/dev/null || echo "none")

# ------------------------------------------------------------------------------
# 2. 辅助功能函数
# ------------------------------------------------------------------------------

log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp -a "$file" "$BACKUP_DIR/$(basename "$file")_$(date +%Y%m%d_%H%M%S)"
    fi
}

# ------------------------------------------------------------------------------
# 3. 核心优化模块
# ------------------------------------------------------------------------------

# 模块1: 内核参数优化 (Sysctl)
optimize_kernel() {
    print_info "正在优化内核参数..."
    backup_file "/etc/sysctl.conf"
    
    cat > /etc/sysctl.d/99-vps-optimize.conf <<EOF
# 网络优化
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.ip_local_port_range = 10000 65535

# 缓冲区优化 (动态适配: $TOTAL_RAM MB)
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.optmem_max = 25165824
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000

# 内存管理
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# 安全相关
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
EOF

    # 加载自定义配置
    if [ -n "$SYSCTL_OPTIMIZATIONS" ]; then
        echo "$SYSCTL_OPTIMIZATIONS" >> /etc/sysctl.d/99-vps-optimize.conf
    fi

    sysctl -p /etc/sysctl.d/99-vps-optimize.conf >> "$LOG_FILE" 2>&1
    print_success "内核参数优化完成。"
}

# 模块2: 系统限制优化 (Limits)
optimize_limits() {
    print_info "正在优化系统资源限制..."
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

    if [ -d "/etc/systemd/system.conf.d" ]; then
        cat > /etc/systemd/system.conf.d/limit.conf <<EOF
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF
        systemctl daemon-reexec
    fi
    print_success "系统限制优化完成。"
}

# 模块3: 磁盘与文件系统优化
optimize_filesystem() {
    print_info "正在优化文件系统..."
    
    # 智能选择调度器
    local scheduler="deadline"
    if [ "$IS_VIRTUAL" != "none" ]; then scheduler="noop"; fi
    
    for dev in $(ls /sys/block/ | grep -E '^(sd|vd|nvme)'); do
        if [ -f "/sys/block/$dev/queue/scheduler" ]; then
            echo "$scheduler" > "/sys/block/$dev/queue/scheduler" 2>/dev/null
            echo 1024 > "/sys/block/$dev/queue/read_ahead_kb" 2>/dev/null
        fi
    done
    print_success "I/O 调度器已设为: $scheduler"
}

# 模块4: 内存与 Swap 优化
optimize_memory() {
    print_info "正在优化内存配置..."
    
    local swap_size=$(free -m | awk '/^Swap:/{print $2}')
    if [ "$swap_size" -eq 0 ]; then
        print_warn "未检测到 Swap，建议创建 Swap 文件。"
        if [ ! -f /swapfile ]; then
            dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
            chmod 600 /swapfile
            mkswap /swapfile >> "$LOG_FILE"
            swapon /swapfile
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
            print_success "已创建 1GB Swap 文件。"
        fi
    fi
}

# 模块5: 基础服务精简
optimize_services() {
    print_info "正在精简系统服务..."
    local svcs=("bluetooth" "cups" "avahi-daemon" "postfix")
    for svc in "${svcs[@]}"; do
        if systemctl is-active "$svc" &>/dev/null; then
            systemctl stop "$svc"
            systemctl disable "$svc" >> "$LOG_FILE" 2>&1
            print_warn "已禁用服务: $svc"
        fi
    done
}

# 模块6: 安全加固
optimize_security() {
    print_info "正在应用基础安全加固..."
    cat > /etc/modprobe.d/blacklist-security.conf <<EOF
blacklist usb-storage
blacklist firewire-core
blacklist thunderbolt
EOF
    if [ -f /etc/ssh/sshd_config ]; then
        backup_file "/etc/ssh/sshd_config"
        sed -i 's/#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
        systemctl reload sshd
    fi
    print_success "安全加固完成。"
}

# 模块7: CPU 性能优化 (本次找回的功能!)
optimize_cpu() {
    print_info "正在优化 CPU 性能模式..."
    
    # 1. 尝试使用 cpupower
    if command -v cpupower &> /dev/null; then
        cpupower frequency-set -g performance >> "$LOG_FILE" 2>&1
        print_success "CPU 频率已设为 performance 模式"
    fi
    
    # 2. 禁用 Intel CPU 节能 (针对物理机或透传环境)
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
        print_success "已禁用 Intel Turbo Boost 限制"
    fi
    
    # 3. 强制激活所有核心
    for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
        if [ -f "$cpu/online" ]; then
            echo 1 > "$cpu/online" 2>/dev/null
        fi
    done
}

# ------------------------------------------------------------------------------
# 4. 交互菜单与入口
# ------------------------------------------------------------------------------

interactive_menu() {
    while true; do
        clear
        print_header "VPS 系统优化工具"
        echo -e "${CYAN}系统概况:${NC} 内存 ${TOTAL_RAM}MB | CPU ${CPU_CORES}核 | 虚拟化 $IS_VIRTUAL"
        echo ""
        echo "1. 一键全自动优化 (推荐)"
        echo "2. 仅优化内核参数 (Network/TCP)"
        echo "3. 仅优化系统限制 (Limits)"
        echo "4. 仅优化磁盘 I/O"
        echo "5. 执行安全加固"
        echo "6. 优化 CPU 性能"
        echo "0. 退出"
        echo ""
        read -p "请选择 [0-6]: " choice
        
        case $choice in
            1)
                backup_configs
                optimize_kernel; optimize_limits; optimize_filesystem
                optimize_memory; optimize_services; optimize_security
                optimize_cpu
                ;;
            2) optimize_kernel ;;
            3) optimize_limits ;;
            4) optimize_filesystem ;;
            5) optimize_security ;;
            6) optimize_cpu ;;
            0) exit 0 ;;
            *) print_error "无效输入"; sleep 1; continue ;;
        esac
        
        echo ""
        print_success "操作完成！"
        read -p "是否立即重启? (y/N): " rb
        [[ "$rb" =~ ^[Yy]$ ]] && reboot
        break
    done
}

backup_configs() {
    print_info "备份当前配置..."
    backup_file "/etc/sysctl.conf"
    backup_file "/etc/security/limits.conf"
    backup_file "/etc/ssh/sshd_config"
}

main() {
    check_root
    
    if [ -n "$1" ]; then
        case "$1" in
            --auto|-a)
                backup_configs
                optimize_kernel; optimize_limits; optimize_filesystem
                optimize_memory; optimize_services; optimize_security
                optimize_cpu
                print_success "自动优化完成，请择机重启。"
                ;;
            --network) optimize_kernel ;;
            --security) optimize_security ;;
            --cpu) optimize_cpu ;;
            --help|-h)
                echo "Usage: bash optimize_system.sh [--auto | --network | --security | --cpu]"
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
