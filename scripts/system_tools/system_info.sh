#!/bin/bash
# ==============================================================================
# Script: scripts/system_tools/system_info.sh
# Purpose: Consistent VPS system inventory report with safer fallbacks.
# ==============================================================================

set -u
set -o pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")

LIB_FILE="${PROJECT_ROOT}/lib/common_functions.sh"
SHOW_SECTION="all"
PAUSE_ON_EXIT=true

if [ -f "${LIB_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${LIB_FILE}"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'
    print_msg() { echo -e "${1}${2}${NC}"; }
    print_info() { print_msg "${CYAN}" "[信息] $1"; }
    print_success() { print_msg "${GREEN}" "[完成] $1"; }
    print_warn() { print_msg "${YELLOW}" "[警告] $1"; }
    print_error() { print_msg "${RED}" "[错误] $1"; }
    print_separator() { printf '%b%s%b\n' "${BLUE}" "$(printf '%*s' "${2:-80}" '' | tr ' ' "${1:--}")" "${NC}"; }
    print_header() { echo ""; print_separator "=" 80; printf "%b%*s %s %b\n" "${BOLD}${WHITE}" 30 "" "$1" "${NC}"; print_separator "=" 80; echo ""; }
    print_title() { echo ""; printf "%b>> %s%b\n" "${BOLD}${YELLOW}" "$1" "${NC}"; print_separator "-" 80; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    get_public_ip() { echo "unavailable"; }
fi

show_help() {
    cat <<'EOF'
用法：bash system_info.sh [选项]

选项：
  --section <名称>  仅显示指定部分：overview、cpu、memory、disk、network、
                    virtualization、services、users
  --no-pause        输出报告后立即退出
  --help, -h        显示此帮助信息
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --section)
                shift
                [ $# -gt 0 ] || { print_error "--section 缺少名称。"; exit 1; }
                SHOW_SECTION="$1"
                case "${SHOW_SECTION}" in
                    all|overview|cpu|memory|disk|network|virtualization|services|users) ;;
                    *)
                        print_error "不支持的报告部分：${SHOW_SECTION}"
                        exit 1
                        ;;
                esac
                ;;
            --no-pause)
                PAUSE_ON_EXIT=false
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项：$1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

run_section() {
    local section_name="$1"
    local section_func="$2"

    if [ "${SHOW_SECTION}" = "all" ] || [ "${SHOW_SECTION}" = "${section_name}" ]; then
        "${section_func}"
    fi
}

print_kv() {
    local key="$1"
    local value="$2"
    printf "%b%-18s%b %s\n" "${CYAN}" "${key}:" "${NC}" "${value}"
}

read_os_name() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-unknown}}"
    else
        uname -s
    fi
}

read_timezone() {
    if [ -f /etc/timezone ]; then
        cat /etc/timezone
    elif command_exists timedatectl; then
        timedatectl show -p Timezone --value 2>/dev/null || date +%Z
    else
        date +%Z
    fi
}

read_cpu_usage() {
    if command_exists top; then
        local top_output
        top_output=$(top -bn1 2>/dev/null | grep -m1 "Cpu(s)" || true)
        if [ -n "${top_output}" ]; then
            awk -F'[:, ]+' '{for (i=1; i<=NF; i++) { if ($i ~ /us/) user=$(i-1); if ($i ~ /sy/) sys=$(i-1) } if (user == "") user=0; if (sys == "") sys=0; printf "%.1f", user + sys }' <<<"${top_output}"
            return 0
        fi
    fi
    echo "unavailable"
}

read_load_average() {
    awk '{print $1 ", " $2 ", " $3}' /proc/loadavg 2>/dev/null || echo "unavailable"
}

read_memory_stat() {
    local key="$1"
    awk -v k="${key}" '$1 == k ":" {print $2}' /proc/meminfo 2>/dev/null
}

to_mb() {
    local value_kb="${1:-0}"
    echo $((value_kb / 1024))
}

get_system_overview() {
    print_title "系统概览"
    print_kv "主机名" "$(hostname)"
    print_kv "操作系统" "$(read_os_name)"
    print_kv "内核版本" "$(uname -r)"
    print_kv "系统架构" "$(uname -m)"
    print_kv "运行时间" "$(uptime -p 2>/dev/null | sed 's/^up //')"
    print_kv "系统时间" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    print_kv "系统时区" "$(read_timezone)"
}

get_cpu_details() {
    local cpu_model=""
    local cpu_cores=""
    local cpu_freq=""
    local cpu_usage=""

    print_title "CPU"

    cpu_model=$(awk -F': *' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
    cpu_cores=$(nproc 2>/dev/null || awk '/^processor/ {count++} END {print count+0}' /proc/cpuinfo 2>/dev/null)
    cpu_freq=$(awk -F': *' '/cpu MHz/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
    cpu_usage=$(read_cpu_usage)

    print_kv "型号" "${cpu_model:-未知}"
    print_kv "核心数" "${cpu_cores:-未知}"
    [ -n "${cpu_freq}" ] && print_kv "频率" "${cpu_freq} MHz"
    if [ "${cpu_usage}" = "unavailable" ]; then
        print_kv "使用率" "不可用"
    else
        print_kv "使用率" "${cpu_usage}%"
    fi
    print_kv "平均负载" "$(read_load_average)"
}

get_memory_details() {
    local mem_total_kb=0
    local mem_available_kb=0
    local swap_total_kb=0
    local swap_free_kb=0
    local mem_used_mb=0
    local mem_total_mb=0
    local mem_usage_pct=0
    local swap_total_mb=0
    local swap_used_mb=0
    local swap_usage_pct=0

    print_title "内存"

    mem_total_kb=$(read_memory_stat "MemTotal")
    mem_available_kb=$(read_memory_stat "MemAvailable")
    swap_total_kb=$(read_memory_stat "SwapTotal")
    swap_free_kb=$(read_memory_stat "SwapFree")

    mem_total_mb=$(to_mb "${mem_total_kb:-0}")
    mem_used_mb=$((mem_total_mb - $(to_mb "${mem_available_kb:-0}")))
    if [ "${mem_total_mb}" -gt 0 ]; then
        mem_usage_pct=$((mem_used_mb * 100 / mem_total_mb))
    fi

    print_kv "RAM" "${mem_used_mb}MB / ${mem_total_mb}MB (${mem_usage_pct}%)"
    print_kv "可用内存" "$(to_mb "${mem_available_kb:-0}")MB"

    if [ "${swap_total_kb:-0}" -gt 0 ]; then
        swap_total_mb=$(to_mb "${swap_total_kb}")
        swap_used_mb=$((swap_total_mb - $(to_mb "${swap_free_kb:-0}")))
        if [ "${swap_total_mb}" -gt 0 ]; then
            swap_usage_pct=$((swap_used_mb * 100 / swap_total_mb))
        fi
        print_kv "Swap" "${swap_used_mb}MB / ${swap_total_mb}MB (${swap_usage_pct}%)"
    else
        print_kv "Swap" "未启用"
    fi
}

get_disk_details() {
    local total_line=""

    print_title "磁盘"
    printf "%b%-16s %-10s %-10s %-10s %-7s %s%b\n" "${CYAN}" "挂载点" "容量" "已用" "可用" "使用率" "设备" "${NC}"

    df -hP 2>/dev/null | awk '$1 ~ "^/dev/" {printf "%-16s %-10s %-10s %-10s %-7s %s\n", $6, $2, $3, $4, $5, $1}'

    if df --help 2>&1 | grep -q -- "--total"; then
        total_line=$(df -hP --total 2>/dev/null | awk '$1 == "total" {print $2 "|" $3 "|" $5}')
        if [ -n "${total_line}" ]; then
            echo ""
            print_kv "总计" "容量 $(cut -d'|' -f1 <<<"${total_line}")，已用 $(cut -d'|' -f2 <<<"${total_line}")，使用率 $(cut -d'|' -f3 <<<"${total_line}")"
        fi
    fi
}

get_network_details() {
    local interfaces=""
    local iface=""
    local ipv4=""
    local ipv6=""
    local mac=""
    local state=""
    local public_ipv4=""
    local public_ipv6=""
    local region=""

    print_title "网络"

    if command_exists ip; then
        interfaces=$(ip -o link show 2>/dev/null | awk -F': ' '$2 != "lo" {print $2}' | cut -d'@' -f1)
        for iface in ${interfaces}; do
            ipv4=$(ip -o -4 addr show dev "${iface}" scope global 2>/dev/null | awk '{print $4}' | head -n1)
            ipv6=$(ip -o -6 addr show dev "${iface}" scope global 2>/dev/null | awk '{print $4}' | head -n1)
            mac=$(ip link show "${iface}" 2>/dev/null | awk '/link\/ether/ {print $2; exit}')
            state=$(ip link show "${iface}" 2>/dev/null | awk '/state/ {for (i=1; i<=NF; i++) if ($i == "state") {print $(i+1); exit}}')

            if [ -n "${ipv4}" ] || [ "${state:-DOWN}" = "UP" ]; then
                print_kv "网卡" "${iface} (${state:-未知})"
                [ -n "${ipv4}" ] && print_kv "IPv4" "${ipv4}"
                [ -n "${ipv6}" ] && print_kv "IPv6" "${ipv6}"
                [ -n "${mac}" ] && print_kv "MAC" "${mac}"
                echo ""
            fi
        done
    else
        print_warn "系统没有 ip 命令，跳过网卡详情。"
    fi

    public_ipv4=$(get_public_ip 4 3 2>/dev/null || echo "unavailable")
    public_ipv6=$(get_public_ip 6 3 2>/dev/null || echo "unavailable")
    print_kv "公网 IPv4" "${public_ipv4:-不可用}"
    if [ "${public_ipv6:-unavailable}" != "unavailable" ]; then
        print_kv "公网 IPv6" "${public_ipv6}"
    fi

    if command_exists curl && [ -n "${public_ipv4}" ] && [ "${public_ipv4}" != "unavailable" ]; then
        region=$(curl -fsS --max-time 3 "https://ipapi.co/${public_ipv4}/country_name/" 2>/dev/null || true)
        [ -n "${region}" ] && print_kv "地区" "${region}"
    fi

    if [ -f /etc/resolv.conf ]; then
        print_kv "DNS" "$(awk '/^nameserver/ {print $2}' /etc/resolv.conf | paste -sd', ' -)"
    fi
}

get_virtualization_details() {
    local virt_type="physical"
    local product=""

    print_title "虚拟化"

    if command_exists systemd-detect-virt; then
        product=$(systemd-detect-virt 2>/dev/null || true)
        [ -n "${product}" ] && [ "${product}" != "none" ] && virt_type="${product}"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="virtualized"
    fi

    if [ "${EUID}" -eq 0 ] && command_exists dmidecode; then
        product=$(dmidecode -s system-product-name 2>/dev/null || true)
        case "${product}" in
            *VirtualBox*) virt_type="virtualbox" ;;
            *VMware*) virt_type="vmware" ;;
            *KVM*) virt_type="kvm" ;;
            *Alibaba*) virt_type="aliyun ecs" ;;
            *Tencent*) virt_type="tencent cvm" ;;
        esac
    fi

    print_kv "平台" "${virt_type}"

    if [ -f /.dockerenv ]; then
        print_kv "容器" "docker"
    elif [ -f /run/.containerenv ]; then
        print_kv "容器" "podman"
    elif grep -q "lxc" /proc/1/cgroup 2>/dev/null; then
        print_kv "容器" "lxc"
    fi
}

get_service_status() {
    local services=("ssh" "sshd" "nginx" "apache2" "docker" "mysql" "mariadb" "redis" "ufw" "iptables" "fail2ban" "cron")
    local service=""
    local found_any=false

    print_title "服务状态"

    if ! command_exists systemctl; then
        print_warn "当前主机无法使用 systemctl。"
        return 0
    fi

    for service in "${services[@]}"; do
        if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
            found_any=true
            if systemctl is-active --quiet "${service}"; then
                printf "  [%b运行中%b] %s\n" "${GREEN}" "${NC}" "${service}"
            else
                printf "  [%b已停止%b] %s\n" "${YELLOW}" "${NC}" "${service}"
            fi
        fi
    done

    [ "${found_any}" = false ] && print_warn "未检测到监控列表中的常见服务。"
}

get_user_details() {
    print_title "用户信息"
    print_kv "当前用户" "$(whoami)"
    print_kv "会话数量" "$(who 2>/dev/null | wc -l | awk '{print $1}')"

    if command_exists last; then
        echo ""
        printf "%b最近登录:%b\n" "${CYAN}" "${NC}"
        last -n 5 2>/dev/null | head -n 5 | awk 'NF >= 6 {printf "  %-12s %-18s %s %s %s\n", $1, $3, $4, $5, $6}'
    fi
}

pause_if_needed() {
    if [ "${PAUSE_ON_EXIT}" = true ] && [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [ -t 0 ]; then
        echo ""
        read -r -n 1 -s -p "按任意键退出..."
        echo ""
    fi
}

main() {
    parse_args "$@"

    clear 2>/dev/null || true
    print_header "VPS 系统信息"

    run_section "overview" get_system_overview
    run_section "cpu" get_cpu_details
    run_section "memory" get_memory_details
    run_section "disk" get_disk_details
    run_section "network" get_network_details
    run_section "virtualization" get_virtualization_details
    run_section "services" get_service_status
    run_section "users" get_user_details

    echo ""
    print_separator
    print_success "系统信息采集完成。"
    pause_if_needed
}

main "$@"
