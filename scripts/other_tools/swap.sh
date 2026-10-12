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

# Paths are overridable so the real (non-preview) path can be exercised in tests.
SWAP_FILE="${VPS_SWAP_FILE:-/swapfile}"
SWAPPINESS_DROPIN="${VPS_SWAPPINESS_DROPIN:-/etc/sysctl.d/99-swappiness.conf}"
FSTAB_FILE="${VPS_FSTAB_FILE:-/etc/fstab}"
PROC_SWAPS="${VPS_PROC_SWAPS:-/proc/swaps}"
DRY_RUN=false
AUTO_YES=false
SWAP_SIZE=""
ACTION="interactive"

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
  --status          仅显示当前 SWAP 状态，不修改系统
  --size <大小>      SWAP 大小，如 2G 或 1024M（非交互模式）
  --yes             跳过确认（需配合 --size 或 --remove）
  --remove          关闭并删除项目 SWAP 文件、fstab 条目与 swappiness 配置
  --dry-run         预览将执行的变更，不写入
  --help            显示帮助

无参数时进入交互配置流程。

示例：
  bash swap.sh --size 2G --dry-run
  bash swap.sh --size 2G --yes
  bash swap.sh --remove --yes
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
    if fstab_has_entry; then
        echo -e "${GREEN}${FSTAB_FILE}:${NC} 已包含 ${SWAP_FILE} 条目"
    else
        echo -e "${YELLOW}${FSTAB_FILE}:${NC} 未包含 ${SWAP_FILE} 条目"
    fi
}

validate_size() {
    [[ ${1} =~ ^[1-9][0-9]*[GM]$ ]]
}

size_to_mb() {
    if [[ ${1} =~ ^([1-9][0-9]*)G$ ]]; then
        echo $((BASH_REMATCH[1] * 1024))
    elif [[ ${1} =~ ^([1-9][0-9]*)M$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        return 1
    fi
}

fstab_has_entry() {
    [ -f "${FSTAB_FILE}" ] && awk -v f="${SWAP_FILE}" '$1 == f { found = 1 } END { exit !found }' "${FSTAB_FILE}"
}

# Rewrite fstab without our swap line, in place (keeps owner, mode, and inode).
fstab_remove_entry() {
    local tmp
    [ -f "${FSTAB_FILE}" ] || return 0
    tmp=$(mktemp "${FSTAB_FILE}.vps.XXXXXX") || return 1
    awk -v f="${SWAP_FILE}" '$1 != f' "${FSTAB_FILE}" > "${tmp}" || { rm -f -- "${tmp}"; return 1; }
    cat -- "${tmp}" > "${FSTAB_FILE}"
    rm -f -- "${tmp}"
}

swapfile_active() {
    [ -r "${PROC_SWAPS}" ] && awk -v f="${SWAP_FILE}" 'NR > 1 && $1 == f { found = 1 } END { exit !found }' "${PROC_SWAPS}"
}

# Turn off only the project-owned swapfile. Refuse to continue if it is still
# active afterwards: deleting an in-use swapfile corrupts swapped-out memory.
disable_project_swap() {
    if swapfile_active; then
        echo -e "${WHITE}关闭项目 SWAP 文件 ${SWAP_FILE}...${NC}"
        if ! swapoff -- "${SWAP_FILE}"; then
            echo -e "${RED}swapoff ${SWAP_FILE} 失败（可能内存不足），已中止，未删除文件${NC}" 1>&2
            return 1
        fi
    fi
}

check_disk_space() {
    local size_mb="${1}"
    local dir avail_mb existing_mb=0
    dir=$(dirname -- "${SWAP_FILE}")
    avail_mb=$(df -Pm -- "${dir}" 2>/dev/null | awk 'NR == 2 { print $4 }') || true
    if [[ ! ${avail_mb} =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}无法读取 ${dir} 的可用空间，跳过空间检查${NC}"
        return 0
    fi
    if [ -f "${SWAP_FILE}" ]; then
        existing_mb=$(( $(stat -c %s -- "${SWAP_FILE}" 2>/dev/null || echo 0) / 1048576 ))
    fi
    # Keep at least 512 MB free after creating the swapfile.
    if [ $((avail_mb + existing_mb)) -lt $((size_mb + 512)) ]; then
        echo -e "${RED}磁盘空间不足：${dir} 可用 $((avail_mb + existing_mb)) MB，需要 ${size_mb} MB + 512 MB 余量${NC}" 1>&2
        return 1
    fi
}

preview_plan() {
    local size_label="${1}"
    echo -e "${WHITE}DRY-RUN 预览${NC}"
    echo "------------------------"
    echo "将创建/替换: ${SWAP_FILE} (${size_label})"
    echo "将仅 swapoff ${SWAP_FILE}（不会关闭全部交换分区）"
    echo "将更新 ${FSTAB_FILE} 中唯一的 ${SWAP_FILE} 行"
    echo "将写入 ${SWAPPINESS_DROPIN} (vm.swappiness=10)"
    echo -e "${YELLOW}未实际修改系统。${NC}"
}

apply_swap() {
    local swap_size="${1}"
    local count_mb

    if ! count_mb=$(size_to_mb "${swap_size}"); then
        echo -e "${RED}无效的大小格式: ${swap_size}${NC}" 1>&2
        return 1
    fi

    if [ "${DRY_RUN}" = true ]; then
        preview_plan "${swap_size}"
        return 0
    fi

    check_disk_space "${count_mb}" || return 1

    # Only disable the project-owned swapfile; never disable all swap devices.
    disable_project_swap || return 1

    echo -e "${WHITE}创建SWAP文件...${NC}"
    rm -f -- "${SWAP_FILE}"
    if ! fallocate -l "${swap_size}" "${SWAP_FILE}" 2>/dev/null; then
        # Busybox / older systems: fall back to dd
        rm -f -- "${SWAP_FILE}"
        if ! dd if=/dev/zero of="${SWAP_FILE}" bs=1M count="${count_mb}" status=progress; then
            rm -f -- "${SWAP_FILE}"
            echo -e "${RED}创建 SWAP 文件失败${NC}" 1>&2
            return 1
        fi
    fi

    chmod 600 -- "${SWAP_FILE}"
    echo -e "${WHITE}创建SWAP空间...${NC}"
    mkswap -- "${SWAP_FILE}"
    echo -e "${WHITE}启用SWAP...${NC}"
    swapon -- "${SWAP_FILE}"

    echo -e "${WHITE}配置开机自动挂载...${NC}"
    fstab_remove_entry || return 1
    printf '%s none swap defaults 0 0\n' "${SWAP_FILE}" >> "${FSTAB_FILE}"

    echo -e "${WHITE}配置SWAP参数...${NC}"
    printf '%s\n' 'vm.swappiness=10' > "${SWAPPINESS_DROPIN}"
    sysctl -p "${SWAPPINESS_DROPIN}" >/dev/null 2>&1 || true

    if swapfile_active; then
        echo -e "${GREEN}SWAP创建成功：${SWAP_FILE} (${swap_size})${NC}"
    else
        echo -e "${RED}SWAP创建失败，请手动检查${NC}"
        return 1
    fi

    echo ""
    echo -e "${GREEN}SWAP设置完成${NC}"
    show_status
}

remove_swap() {
    if [ "${DRY_RUN}" = true ]; then
        echo -e "${WHITE}DRY-RUN 预览${NC}"
        echo "------------------------"
        echo "将仅 swapoff ${SWAP_FILE}（不会关闭全部交换分区）"
        echo "将删除 ${SWAP_FILE}"
        echo "将删除 ${FSTAB_FILE} 中的 ${SWAP_FILE} 行"
        echo "将删除 ${SWAPPINESS_DROPIN}"
        echo -e "${YELLOW}未实际修改系统。${NC}"
        return 0
    fi

    disable_project_swap || return 1
    rm -f -- "${SWAP_FILE}"
    fstab_remove_entry || return 1
    if [ -f "${SWAPPINESS_DROPIN}" ]; then
        rm -f -- "${SWAPPINESS_DROPIN}"
        echo -e "${YELLOW}已删除 ${SWAPPINESS_DROPIN}；当前 vm.swappiness 将在重启后恢复系统默认值${NC}"
    fi
    echo -e "${GREEN}已移除项目 SWAP 文件 ${SWAP_FILE}${NC}"
}

confirm_or_abort() {
    local prompt="${1}"
    local answer=""
    if [ "${AUTO_YES}" = true ]; then
        return 0
    fi
    if ! read -r -p "${prompt} (y/N): " answer; then
        echo ""
        echo -e "${YELLOW}未收到输入，已取消操作${NC}"
        return 1
    fi
    case "${answer}" in
        y|Y) return 0 ;;
        *) echo -e "${YELLOW}已取消操作${NC}"; return 1 ;;
    esac
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
    while [ "$#" -gt 0 ]; do
        case "${1}" in
            --help|-h)
                show_help
                return 0
                ;;
            --status)
                ACTION="status"
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --yes|-y)
                AUTO_YES=true
                ;;
            --remove)
                ACTION="remove"
                ;;
            --size)
                if [ "$#" -lt 2 ]; then
                    echo -e "${RED}--size 需要一个值，例如 2G${NC}" 1>&2
                    return 1
                fi
                SWAP_SIZE="${2}"
                shift
                ;;
            --size=*)
                SWAP_SIZE="${1#--size=}"
                ;;
            *)
                echo -e "${RED}未知参数: ${1}${NC}" 1>&2
                show_help
                return 1
                ;;
        esac
        shift
    done

    if [ -n "${SWAP_SIZE}" ] && ! validate_size "${SWAP_SIZE}"; then
        echo -e "${RED}无效的大小: ${SWAP_SIZE}（请使用正整数加 G 或 M 后缀）${NC}" 1>&2
        return 1
    fi

    case "${ACTION}" in
        status)
            show_status
            return 0
            ;;
        remove)
            if [ -n "${SWAP_SIZE}" ]; then
                echo -e "${RED}--remove 不能与 --size 同时使用${NC}" 1>&2
                return 1
            fi
            require_root
            if [ "${DRY_RUN}" != true ]; then
                confirm_or_abort "将关闭并删除 ${SWAP_FILE}，确定继续?" || return 0
            fi
            remove_swap
            return
            ;;
    esac

    if [ -n "${SWAP_SIZE}" ]; then
        require_root
        if [ "${DRY_RUN}" != true ]; then
            confirm_or_abort "将创建 ${SWAP_SIZE} SWAP（仅操作 ${SWAP_FILE}），确定继续?" || return 0
        fi
        apply_swap "${SWAP_SIZE}"
        return
    fi

    if [ "${DRY_RUN}" = true ]; then
        require_root
        preview_plan "1G (示例；可用 --size 指定)"
        return 0
    fi

    if [ "${AUTO_YES}" = true ]; then
        echo -e "${RED}--yes 需配合 --size 或 --remove 使用${NC}" 1>&2
        return 1
    fi

    require_root
    interactive_configure
}

main "$@"
