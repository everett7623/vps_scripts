#!/bin/bash
# 子脚本模板 - 展示如何正确使用核心功能库
# 所有子脚本都应该遵循这个结构

# 获取脚本所在目录
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_PATH")"

# 加载核心功能库
if [[ -f "${PARENT_DIR}/lib/common_functions.sh" ]]; then
    source "${PARENT_DIR}/lib/common_functions.sh"
else
    echo "错误：无法找到核心功能库" >&2
    exit 1
fi

# 脚本信息
SCRIPT_NAME="template"
SCRIPT_VERSION="1.0.0"
SCRIPT_DESCRIPTION="这是一个子脚本模板"

# 脚本特定的函数
show_help() {
    cat << EOF
${SCRIPT_DESCRIPTION}
版本: ${SCRIPT_VERSION}

用法: $0 [选项]

选项:
    -h, --help      显示此帮助信息
    -v, --version   显示版本信息
    -d, --debug     启用调试模式
    
示例:
    $0              运行脚本
    $0 --debug      以调试模式运行

EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
                exit 0
                ;;
            -d|--debug)
                DEBUG=1
                export DEBUG
                log DEBUG "调试模式已启用"
                ;;
            *)
                log ERROR "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# 主函数
main() {
    log INFO "开始执行 ${SCRIPT_NAME}..."
    
    # 检查权限
    check_root
    
    # 检测系统
    detect_os
    
    # 获取系统信息
    get_system_info
    
    # 显示系统信息
    echo -e "${CYAN}=== 系统信息 ===${NC}"
    echo -e "${WHITE}操作系统:${NC} ${OS_PRETTY_NAME}"
    echo -e "${WHITE}CPU型号:${NC} ${CPU_INFO}"
    echo -e "${WHITE}CPU核心:${NC} ${CPU_CORES}"
    echo -e "${WHITE}内存使用:${NC} ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)"
    echo -e "${WHITE}磁盘使用:${NC} ${DISK_INFO}"
    echo ""
    
    # 执行具体功能
    if confirm_action "是否继续执行测试功能？" "y"; then
        log INFO "执行测试功能..."
        
        # 模拟进度条
        for i in {1..10}; do
            show_progress $i 10
            sleep 0.2
        done
        echo ""
        
        log INFO "测试功能执行完成"
    else
        log INFO "用户取消操作"
    fi
    
    # 按任意键返回
    press_any_key
}

# 清理函数
cleanup() {
    log DEBUG "执行清理操作..."
    # 在这里添加清理代码
}

# 设置信号处理
trap cleanup EXIT

# 程序入口
parse_arguments "$@"
main
