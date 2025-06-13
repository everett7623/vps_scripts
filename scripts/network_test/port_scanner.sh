#!/bin/bash
# scripts/network_test/port_scanner.sh - VPS Scripts 端口扫描功能模块

# 模块信息
MODULE_NAME="端口扫描"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="扫描目标主机的开放端口，支持多种扫描模式及历史记录查看"

# 模块配置 - 端口与服务映射
declare -A PORT_NAMES=(
    [21]="FTP"
    [22]="SSH"
    [23]="Telnet"
    [25]="SMTP"
    [53]="DNS"
    [80]="HTTP"
    [110]="POP3"
    [143]="IMAP"
    [443]="HTTPS"
    [445]="SMB"
    [3306]="MySQL"
    [3389]="RDP"
    [5432]="PostgreSQL"
    [6379]="Redis"
    [8080]="HTTP-Alt"
    [8443]="HTTPS-Alt"
    [27017]="MongoDB"
)

# 模块配置 - 常用端口组
declare -A PORT_GROUPS=(
    ["web"]="80,443,8080,8443"
    ["mail"]="25,110,143,587,993,995"
    ["database"]="1433,3306,5432,6379,27017"
    ["remote"]="22,23,3389,5900"
    ["common"]="21,22,23,25,53,80,110,143,443,445,3306,3389"
)

# ------------------------------ 函数定义 ------------------------------ #

# 扫描单个端口
# 参数: host(目标主机), port(目标端口), timeout(超时时间，可选，默认3秒)
scan_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-3}"
    
    # 使用 nc 检测端口状态，超时时间控制
    if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
        return 0  # 端口开放
    else
        return 1  # 端口关闭或超时
    fi
}

# 并发扫描多个端口（核心并发逻辑）
# 参数: host(目标主机), 后续为要扫描的端口列表
scan_ports_parallel() {
    local host="$1"
    shift
    local ports=("$@")
    local max_threads=50  # 控制最大并发数
    local temp_dir=$(mktemp -d "port_scan_XXXXXX")
    local result_file="$temp_dir/results"
    local progress_file="$temp_dir/progress"
    local total_ports=${#ports[@]}
    local current_progress=0

    # 进度显示初始化
    printf "\n"
    draw_progress_box "端口扫描中" "$total_ports" >&2
    printf "\n"

    # 扫描工作函数（子进程执行）
    scan_worker() {
        local h="$1"
        local p="$2"
        local idx="$3"
        
        if scan_port "$h" "$p" 2; then
            echo "$p:open" >> "$result_file"
        else
            echo "$p:closed" >> "$result_file"
        fi
        echo "$idx" >> "$progress_file"  # 标记该端口扫描完成
    }

    # 启动并发扫描
    for idx in "${!ports[@]}"; do
        local port="${ports[$idx]}"
        # 控制并发数，避免过多进程
        while [ $(jobs -r | wc -l) -ge $max_threads ]; do
            sleep 0.1
        done
        # 后台执行扫描，传递端口索引（从1开始）
        scan_worker "$host" "$port" $((idx + 1)) &
    done

    # 实时更新进度
    while [ $(jobs -r | wc -l) -gt 0 ]; do
        if [ -f "$progress_file" ]; then
            current_progress=$(wc -l < "$progress_file" 2>/dev/null)
            update_progress_box "端口扫描中" "$current_progress" "$total_ports" >&2
        fi
        sleep 0.1
    done
    # 收尾进度显示
    close_progress_box "端口扫描中" >&2

    # 读取扫描结果
    local results=()
    if [ -f "$result_file" ]; then
        while IFS=':' read -r port status; do
            results+=("$port:$status")
        done < "$result_file"
    fi

    # 清理临时目录
    rm -rf "$temp_dir"

    # 返回结果（数组形式）
    printf "%s\n" "${results[@]}"
}

# 显示扫描结果（含统计、报告生成）
# 参数: host(目标主机), 后续为扫描结果数组
display_scan_results() {
    local host="$1"
    shift
    local results=("$@")
    local total_ports=${#results[@]}
    local open_count=0
    local closed_count=0
    local report_file="$HOME/port_scan_$(date +%Y%m%d_%H%M%S).txt"

    clear
    draw_menu_border "端口扫描结果 - $host"
    printf "\n"

    # 统计开放/关闭端口数量
    for result in "${results[@]}"; do
        if [[ "$result" == *":open" ]]; then
            ((open_count++))
        else
            ((closed_count++))
        fi
    done

    # 显示统计信息
    printf "${WHITE}扫描统计:${NC}\n"
    printf "总端口数: ${YELLOW}%d${NC}\n" "$total_ports"
    printf "开放端口: ${GREEN}%d${NC}\n" "$open_count"
    printf "关闭端口: ${RED}%d${NC}\n" "$closed_count"
    printf "\n"

    # 显示开放端口详情（含服务名映射）
    if [ $open_count -gt 0 ]; then
        printf "${GREEN}开放的端口:${NC}\n"
        printf "-------------------\n"
        for result in "${results[@]}"; do
            if [[ "$result" == *":open" ]]; then
                local port="${result%:*}"
                local service="${PORT_NAMES[$port]:-Unknown}"
                printf "${GREEN}%-6s${NC} - %-15s\n" "$port" "$service"
            fi
        done
        printf "\n"
    fi

    # 生成扫描报告
    {
        printf "端口扫描报告\n"
        printf "=============\n"
        printf "目标主机: %s\n" "$host"
        printf "扫描时间: %s\n" "$(date)"
        printf "扫描端口数: %d\n" "$total_ports"
        printf "开放端口数: %d\n\n" "$open_count"
        printf "开放端口列表:\n"
        for result in "${results[@]}"; do
            if [[ "$result" == *":open" ]]; then
                local port="${result%:*}"
                local service="${PORT_NAMES[$port]:-Unknown}"
                printf "%-6s - %s\n" "$port" "$service"
            fi
        done
    } > "$report_file"

    printf "${BLUE}报告已保存到: %s${NC}\n" "$report_file"
    printf "\n"

    # 询问是否查看报告内容
    read -rp "是否显示详细结果? (y/n): " show_choice
    if [[ "$show_choice" =~ ^[Yy]$ ]]; then
        cat "$report_file"
    fi
}

# 快速扫描（常用端口组）
quick_scan() {
    local host="$1"
    info "开始快速扫描常用端口..."
    # 常用端口列表
    local common_ports=(21 22 23 25 53 80 110 143 443 445 3306 3389 8080 8443)
    # 执行并发扫描
    local results=($(scan_ports_parallel "$host" "${common_ports[@]}"))
    # 展示结果
    display_scan_results "$host" "${results[@]}"
    record_function_usage "port_scan_quick"  # 记录功能使用
}

# 全端口扫描（1-65535）
full_scan() {
    local host="$1"
    local start_port="${2:-1}"
    local end_port="${3:-65535}"

    warning "全端口扫描需要较长时间，是否继续？"
    if ! confirm "确定要扫描端口 $start_port-$end_port 吗？"; then
        return
    fi

    info "开始扫描端口 $start_port 到 $end_port..."
    # 生成端口列表
    local ports=()
    for ((i = start_port; i <= end_port; i++)); do
        ports+=($i)
    done
    # 执行并发扫描
    local results=($(scan_ports_parallel "$host" "${ports[@]}"))
    # 展示结果
    display_scan_results "$host" "${results[@]}"
    record_function_usage "port_scan_full"  # 记录功能使用
}

# 自定义端口扫描（支持逗号分隔、范围格式）
custom_scan() {
    local host="$1"
    # 获取用户输入，校验函数为 validate_port_input
    local port_input=$(show_input_box "自定义端口扫描" \
        "请输入要扫描的端口（逗号分隔，如: 80,443,8080）\n或端口范围（如: 1-1000）:" \
        "" \
        "validate_port_input")
    
    if [ -z "$port_input" ]; then
        return
    fi

    # 解析用户输入的端口
    local ports=()
    IFS=',' read -ra port_parts <<< "$port_input"
    for part in "${port_parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # 处理端口范围
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for ((i = start; i <= end; i++)); do
                ports+=($i)
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # 处理单个端口
            ports+=($part)
        fi
    done

    info "开始扫描 ${#ports[@]} 个端口..."
    # 执行并发扫描
    local results=($(scan_ports_parallel "$host" "${ports[@]}"))
    # 展示结果
    display_scan_results "$host" "${results[@]}"
    record_function_usage "port_scan_custom"  # 记录功能使用
}

# 端口组扫描（调用 PORT_GROUPS 定义的分组）
group_scan() {
    local host="$1"
    clear
    draw_menu_border "选择端口组"
    printf "\n"

    # 展示可选端口组
    local group_index=1
    for group_name in "${!PORT_GROUPS[@]}"; do
        printf "${YELLOW}%d)${NC} %s 端口组\n" "$group_index" "$group_name"
        ((group_index++))
    done
    printf "\n${YELLOW}0)${NC} 返回\n\n"

    read -rp "请选择端口组: " choice
    if [ "$choice" = "0" ]; then
        return
    fi

    # 校验选择是否有效
    local group_names=("${!PORT_GROUPS[@]}")
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#group_names[@]}" ]; then
        local selected_group="${group_names[$((choice - 1))]}"
        local group_ports="${PORT_GROUPS[$selected_group]}"
        # 转换为数组
        IFS=',' read -ra ports <<< "$group_ports"
        
        info "开始扫描 $selected_group 端口组..."
        # 执行并发扫描
        local results=($(scan_ports_parallel "$host" "${ports[@]}"))
        # 展示结果
        display_scan_results "$host" "${results[@]}"
        record_function_usage "port_scan_group"  # 记录功能使用
    else
        error "无效的选择"
    fi
}

# 验证端口输入（自定义扫描时用）
validate_port_input() {
    local input="$1"
    # 允许数字、逗号、短横线（范围）
    if [[ "$input" =~ ^[0-9,\-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证主机输入（通用）
validate_host() {
    local input="$1"
    # 简单校验：允许IP、域名格式（字母、数字、点、短横线）
    if [[ "$input" =~ ^[a-zA-Z0-9\.\-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 显示扫描历史（最近10条报告）
show_scan_history() {
    clear
    draw_menu_border "扫描历史"
    printf "\n"

    local history_files=($(ls -t "$HOME/port_scan_*.txt" 2>/dev/null | head -10))
    if [ ${#history_files[@]} -eq 0 ]; then
        info "暂无扫描历史"
        return
    fi

    printf "${WHITE}最近的扫描报告:${NC}\n-------------------\n"
    local file_index=1
    for file in "${history_files[@]}"; do
        local filename=$(basename "$file")
        # 解析日期（去掉前缀和后缀）
        local report_date="${filename#port_scan_}"
        report_date="${report_date%.txt}"
        report_date="${report_date//_/ }"
        printf "${YELLOW}%d)${NC} %s\n" "$file_index" "$report_date"
        ((file_index++))
    done
    printf "\n${YELLOW}0)${NC} 返回\n\n"

    read -rp "选择要查看的报告: " choice
    if [ "$choice" = "0" ]; then
        return
    fi

    # 校验选择并展示报告
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#history_files[@]}" ]; then
        local selected_file="${history_files[$((choice - 1))]}"
        show_paged_output "扫描报告" "$(cat "$selected_file")"
    fi
}

# 模块初始化（依赖检查、调试记录）
init_module() {
    # 检查可选依赖（nc 等，不强制但影响功能完整性）
    local deps=("nc")
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            warning "缺少依赖: $dep，部分端口扫描功能可能受限"
        fi
    done
    debug "端口扫描模块已加载 (v$MODULE_VERSION)"  # 记录模块加载
}

# ------------------------------ 主流程 ------------------------------ #

# 主菜单逻辑
main_menu() {
    while true; do
        clear
        draw_menu_border "端口扫描工具"
        printf "\n"
        printf "${YELLOW}1)${NC} 快速扫描（常用端口）\n"
        printf "${YELLOW}2)${NC} 全端口扫描\n"
        printf "${YELLOW}3)${NC} 自定义端口扫描\n"
        printf "${YELLOW}4)${NC} 端口组扫描\n"
        printf "${YELLOW}5)${NC} 扫描历史\n"
        printf "${YELLOW}0)${NC} 返回主菜单\n\n"

        read -rp "请选择: " choice
        case $choice in
            1)
                local host=$(show_input_box "快速扫描" "请输入目标主机IP或域名:" "" "validate_host")
                if [ -n "$host" ]; then
                    quick_scan "$host"
                    pause_for_continue  # 按任意键继续
                fi
