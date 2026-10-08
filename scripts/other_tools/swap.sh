#!/bin/bash
set -euo pipefail
# ==============================================================================
# Script: scripts/other_tools/swap.sh
# Purpose: Configure a project-owned /swapfile with preview and status modes.
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
WHITE='\033[0;37m'
NC='\033[0m'

SWAP_FILE="/swapfile"
SWAPPINESS_DROPIN="/etc/sysctl.d/99-swappiness.conf"
DRY_RUN=false

require_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误: 此脚本需要root权限运行${NC}" 1>&2
        exit 1
    fi
}

show_help() {
    cat <<'EOF'
用法：bash swap.sh [选项]

选项：
  --status    仅显示当前 SWAP 状态，不修改系统
  --dry-run   预览将执行的变更，不写入
  --help      显示帮助

无参数时进入交互配置流程。
EOF
}

show_status() {
    echo -e "${WHITE}SWAP 状态${NC}"
    echo "------------------------"
    free -m | grep -E 'Mem|Swap' || true
    echo ""
    if [ -f "${SWAP_FILE}" ]; then
        echo -e "${GREEN}SWAP 文件:${NC} ${SWAP_FILE}"
        ls -lh -- "${SWAP_FILE}" 2>/dev/null || true
    else
        echo -e "${YELLOW}未找到项目 SWAP 文件 ${SWAP_FILE}${NC}"
    fi
    if [ -f "${SWAPPINESS_DROPIN}" ]; then
        echo -e "${GREEN}swappiness 配置:${NC}"
        cat -- "${SWAPPINESS_DROPIN}"
    fi
    if grep -qE '^/swapfile[[:space:]]' /etc/fstab 2>/dev/null; then
        echo -e "${GREEN}/etc/fstab:${NC} 已包含 /swapfile 条目"
    else
        echo -e "${YELLOW}/etc/fstab:${NC} 未包含 /swapfile 条目"
    fi
}

preview_plan() {
    local size_label="${1}"
    echo -e "${WHITE}DRY-RUN 预览${NC}"
    echo "------------------------"
    echo "将创建/替换: ${SWAP_FILE} (${size_label})"
    echo "将仅 swapoff ${SWAP_FILE}（不会关闭全部交换分区）"
    echo "将更新 /etc/fstab 中唯一的 /swapfile 行"
    echo "将写入 ${SWAPPINESS_DROPIN} (vm.swappiness=10)"
    echo -e "${YELLOW}未实际修改系统。${NC}"
}

apply_swap() {
    local swap_size="${1}"
    local current_swap
    current_swap=$(free -m | awk '/Swap/ {print $2}')

    if [ "${DRY_RUN}" = true ]; then
        preview_plan "${swap_size}"
        return 0
    fi

    # Only disable the project-owned swapfile; never disable all swap devices.
    if [ -f "${SWAP_FILE}" ] || [ "${current_swap}" -gt 0 ]; then
        echo -e "${WHITE}关闭项目 SWAP 文件（如存在）...${NC}"
        swapoff -- "${SWAP_FILE}" 2>/dev/null || true
    fi

    echo -e "${WHITE}创建SWAP文件...${NC}"
    rm -f -- "${SWAP_FILE}"
    if ! fallocate -l "${swap_size}" "${SWAP_FILE}" 2>/dev/null; then
        # Busybox / older systems: fall back to dd
        local count_mb
        if [[ ${swap_size} =~ ^([1-9][0-9]*)G$ ]]; then
            count_mb=$((BASH_REMATCH[1] * 1024))
        elif [[ ${swap_size} =~ ^([1-9][0-9]*)M$ ]]; then
            count_mb=${BASH_REMATCH[1]}
        else
            echo -e "${RED}无效的大小格式${NC}"
            return 1
        fi
        dd if=/dev/zero of="${SWAP_FILE}" bs=1M count="${count_mb}" status=progress
    fi

    chmod 600 -- "${SWAP_FILE}"
    echo -e "${WHITE}创建SWAP空间...${NC}"
    mkswap -- "${SWAP_FILE}"
    echo -e "${WHITE}启用SWAP...${NC}"
    swapon -- "${SWAP_FILE}"

    echo -e "${WHITE}配置开机自动挂载...${NC}"
    if [ -f /etc/fstab ]; then
        sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab
    fi
    echo '/swapfile none swap defaults 0 0' >> /etc/fstab

    echo -e "${WHITE}配置SWAP参数...${NC}"
    printf '%s\n' 'vm.swappiness=10' > "${SWAPPINESS_DROPIN}"
    sysctl -p "${SWAPPINESS_DROPIN}" >/dev/null 2>&1 || true

    local new_swap
    new_swap=$(free -m | awk '/Swap/ {print $2}')
    if [ "${new_swap}" -gt 0 ]; then
        echo -e "${GREEN}SWAP创建成功，大小为 ${new_swap} MB${NC}"
    else
        echo -e "${RED}SWAP创建失败，请手动检查${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}SWAP设置完成${NC}"
    show_status
}

interactive_configure() {
    local current_swap
    local swap_size=""
    local size_choice=""
    local confirm=""
    local reconfig=""

    echo -e "${WHITE}SWAP设置工具${NC}"
    echo "------------------------"

    current_swap=$(free -m | awk '/Swap/ {print $2}')
    if [ "${current_swap}" -gt 0 ]; then
        echo -e "${YELLOW}检测到当前系统已有 ${current_swap} MB SWAP${NC}"
        read -r -p "是否要重新配置SWAP? (y/n): " reconfig
        case "${reconfig}" in
            y|Y) echo -e "${GREEN}开始重新配置SWAP...${NC}" ;;
            n|N) echo -e "${YELLOW}已取消操作${NC}"; return 0 ;;
            *) echo -e "${RED}无效选择，已取消操作${NC}"; return 1 ;;
        esac
    else
        echo -e "${GREEN}当前系统没有SWAP，将创建新的SWAP${NC}"
    fi

    echo -e "${WHITE}请选择SWAP大小:${NC}"
    echo "1. 1GB"
    echo "2. 2GB"
    echo "3. 4GB"
    echo "4. 8GB"
    echo "5. 自定义大小"
    read -r -p "请选择 (1-5): " size_choice

    case "${size_choice}" in
        1) swap_size="1G" ;;
        2) swap_size="2G" ;;
        3) swap_size="4G" ;;
        4) swap_size="8G" ;;
        5) read -r -p "请输入SWAP大小 (例如: 2G, 1024M): " swap_size ;;
        *) echo -e "${RED}无效选择，已取消操作${NC}"; return 1 ;;
    esac

    if [[ ! ${swap_size} =~ ^([1-9][0-9]*)[GM]$ ]]; then
        echo -e "${RED}无效的大小格式，请使用正整数和G或M后缀${NC}"
        return 1
    fi

    echo -e "${WHITE}将创建 ${swap_size} SWAP（仅操作 ${SWAP_FILE}）${NC}"
    read -r -p "确定要继续吗? (y/n): " confirm
    case "${confirm}" in
        y|Y) echo -e "${GREEN}开始创建SWAP...${NC}" ;;
        n|N) echo -e "${YELLOW}已取消操作${NC}"; return 0 ;;
        *) echo -e "${RED}无效选择，已取消操作${NC}"; return 1 ;;
    esac

    apply_swap "${swap_size}"
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            return 0
            ;;
        --status)
            show_status
            return 0
            ;;
        --dry-run)
            DRY_RUN=true
            require_root
            preview_plan "1G (示例；交互模式中可选大小)"
            return 0
            ;;
        "")
            require_root
            interactive_configure
            ;;
        *)
            echo -e "${RED}未知参数: ${1}${NC}"
            show_help
            return 1
            ;;
    esac
}

main "$@"
