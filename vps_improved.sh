#!/bin/bash
# VPS Scripts 主脚本框架（改进版）
# 说明：这是一个改进的框架，展示如何正确使用lib和scripts目录

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载核心功能库
if [[ -f "${SCRIPT_DIR}/lib/common_functions.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common_functions.sh"
else
    echo "错误：无法找到核心功能库" >&2
    exit 1
fi

# 加载配置文件
load_config

# 版本信息（从配置文件或默认值）
VERSION="${VERSION:-2025-05-19 v1.2.4}"

# 显示欢迎信息
show_welcome() {
    clear
    echo ""
    echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
    echo ""
    echo "VPS脚本集合 $VERSION"
    echo "GitHub地址: ${GITHUB_REPO:-https://github.com/everett7623/vps_scripts}"
    echo ""
    echo -e "${colors[0]} #     # #####   #####       #####   #####  #####   ### #####  #####  #####  ${NC}"
    echo -e "${colors[1]} #     # #    # #     #     #     # #     # #    #   #  #    #   #   #     # ${NC}"
    echo -e "${colors[2]} #     # #    # #           #       #       #    #   #  #    #   #   #       ${NC}"
    echo -e "${colors[3]} #     # #####   #####       #####  #       #####    #  #####    #    #####  ${NC}"
    echo -e "${colors[4]}  #   #  #            #           # #       #   #    #  #        #         # ${NC}"
    echo -e "${colors[3]}   # #   #      #     #     #     # #     # #    #   #  #        #   #     # ${NC}"
    echo -e "${colors[2]}    #    #       #####       #####   #####  #     # ### #        #    #####  ${NC}"
    echo ""
    echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
    echo ""
}

# 显示菜单
show_menu() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${RED}88)${NC} 更新脚本          ${RED}99)${NC} 卸载脚本          ${RED}0)${NC} 退出"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "请选择功能 [0-99]: " choice
}

# 执行本地脚本
execute_local_script() {
    local script_name="$1"
    shift
    local args="$@"
    
    if [[ -f "${SCRIPTS_DIR}/${script_name}" ]]; then
        log INFO "执行本地脚本: ${script_name}"
        run_script "${script_name}" $args
    else
        log WARN "本地脚本不存在: ${script_name}"
        return 1
    fi
}

# 执行远程脚本（兼容原有功能）
execute_remote_script() {
    local script_url="$1"
    local script_name="$2"
    
    log INFO "执行远程脚本: ${script_name}"
    
    # 检查是否需要下载到本地
    if [[ "${DOWNLOAD_SCRIPTS:-false}" == "true" ]]; then
        local temp_script="${TEMP_DIR:-/tmp}/${script_name}"
        if download_file "$script_url" "$temp_script"; then
            chmod +x "$temp_script"
            "$temp_script"
            rm -f "$temp_script"
        else
            log ERROR "下载脚本失败: ${script_name}"
            return 1
        fi
    else
        # 直接执行（保持向后兼容）
        bash <(curl -sL "$script_url")
    fi
}

# 更新脚本函数
update_scripts() {
    log INFO "检查脚本更新..."
    
    # 这里可以添加更复杂的更新逻辑
    # 比如从GitHub下载最新版本，更新本地文件等
    
    if confirm_action "是否从GitHub更新到最新版本？" "y"; then
        local temp_dir=$(mktemp -d)
        
        log INFO "下载最新版本..."
        if git clone --depth 1 "${GITHUB_REPO}" "$temp_dir/vps_scripts" 2>/dev/null; then
            # 备份当前配置
            cp -f "${CONFIG_DIR}/vps_scripts.conf" "$temp_dir/vps_scripts.conf.bak" 2>/dev/null
            
            # 更新文件
            cp -rf "$temp_dir/vps_scripts/"* "$SCRIPT_DIR/"
            
            # 恢复配置
            cp -f "$temp_dir/vps_scripts.conf.bak" "${CONFIG_DIR}/vps_scripts.conf" 2>/dev/null
            
            log INFO "更新完成！"
            rm -rf "$temp_dir"
            
            echo "请重新运行脚本以应用更新。"
            exit 0
        else
            log ERROR "更新失败"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
}

# 处理菜单选择
handle_choice() {
    case $1 in
        1)  # 系统信息
            execute_local_script "system_info.sh" || \
            execute_remote_script "https://raw.githubusercontent.com/everett7623/vps_scripts/main/scripts/system_tools/system_info.sh" "system_info.sh"
            ;;
        2)  # 更新系统
            execute_local_script "update_system.sh" || {
                log INFO "使用内置更新功能"
                detect_os
                get_package_manager
                $PKG_UPDATE && $PKG_UPGRADE
            }
            ;;
        3)  # 清理系统
            execute_local_script "clean_system.sh" || \
            execute_remote_script "https://raw.githubusercontent.com/everett7623/vps_scripts/main//scripts/system_tools/clean_system.sh" "clean_system.sh"
            ;;
        4)  # Yabs
            execute_remote_script "https://yabs.sh" "yabs.sh"
            ;;
        5)  # 融合怪
            execute_remote_script "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh" "ecs.sh"
            ;;
        6)  # IP质量
            execute_remote_script "https://raw.githubusercontent.com/xykt/IPQuality/main/ip_quality.sh" "ip_quality.sh"
            ;;
        7)  # 流媒体解锁
            execute_remote_script "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh" "media_check.sh"
            ;;
        8)  # 响应测试
            execute_remote_script "https://nodebench.mereith.com/scripts/curltime.sh" "response_test.sh"
            ;;
        9)  # 三网测速
            execute_remote_script "https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh" "speedtest.sh"
            ;;
        10) # 回程路由
            execute_remote_script "https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh" "autotrace.sh"
            ;;
        11) # iperf3
            execute_local_script "iperf3_server.sh" || {
                log INFO "安装并启动iperf3服务"
                install_package iperf3
                iperf3 -s -D
                log INFO "iperf3服务已在后台运行（端口5201）"
            }
            ;;
        12) # 超售测试
            execute_remote_script "https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh" "memoryCheck.sh"
            ;;
        13) # 工具箱
            execute_remote_script "https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh" "ssh_tool.sh"
            ;;
        14) # Docker
            if confirm_action "是否安装Docker？" "y"; then
                execute_remote_script "https://get.docker.com" "install_docker.sh"
            fi
            ;;
        88) # 更新脚本
            update_scripts
            ;;
        99) # 卸载脚本
            if confirm_action "确定要卸载脚本吗？这将删除所有相关文件。" "n"; then
                log WARN "开始卸载脚本..."
                rm -rf "$SCRIPT_DIR"
                log INFO "卸载完成"
                exit 0
            fi
            ;;
        0)  # 退出
            log INFO "感谢使用VPS脚本工具集！"
            exit 0
            ;;
        *)
            log ERROR "无效的选择: $1"
            sleep 2
            ;;
    esac
}

# 主函数
main() {
    # 检查权限
    check_root
    
    # 初始化
    init_directories
    detect_os
    get_package_manager
    
    # 安装基础依赖（首次运行）
    if [[ ! -f "${CONFIG_DIR}/.initialized" ]]; then
        log INFO "首次运行，安装基础依赖..."
        install_dependencies
        touch "${CONFIG_DIR}/.initialized"
    fi
    
    # 主循环
    while true; do
        show_welcome
        show_menu
        handle_choice "$choice"
        
        if [[ "$choice" != "0" ]]; then
            press_any_key
        fi
    done
}

# 清理函数
cleanup() {
    # 清理临时文件
    if [[ "${CLEAN_TEMP_ON_EXIT:-true}" == "true" ]]; then
        rm -rf "${TEMP_DIR:-/tmp/vps_scripts}"
    fi
}

# 设置信号处理
trap cleanup EXIT

# 程序入口
main "$@"━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}                           功能菜单                                  ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}【系统管理】${NC}"
    echo -e "${YELLOW}1)${NC} 系统信息          ${YELLOW}2)${NC} 更新系统          ${YELLOW}3)${NC} 清理系统"
    echo ""
    echo -e "${CYAN}【性能测试】${NC}"
    echo -e "${YELLOW}4)${NC} Yabs测试          ${YELLOW}5)${NC} 融合怪测试        ${YELLOW}6)${NC} IP质量检测"
    echo -e "${YELLOW}7)${NC} 流媒体解锁        ${YELLOW}8)${NC} 响应测试          ${YELLOW}9)${NC} 三网测速"
    echo -e "${YELLOW}10)${NC} 回程路由         ${YELLOW}11)${NC} iperf3测试       ${YELLOW}12)${NC} 超售测试"
    echo ""
    echo -e "${CYAN}【工具脚本】${NC}"
    echo -e "${YELLOW}13)${NC} 工具箱合集       ${YELLOW}14)${NC} Docker安装       ${YELLOW}15)${NC} 其他工具"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
