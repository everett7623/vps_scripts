#!/bin/bash
# scripts/network_test/port_scanner.sh - 端口扫描功能模块示例
# 
# 这是一个示例模块，展示如何在新架构下添加新功能
# 作者: VPS Scripts Team
# 版本: 1.0.0

# 加载核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
source "$SCRIPT_DIR/../../lib/system.sh"
source "$SCRIPT_DIR/../../lib/menu.sh"
source "$SCRIPT_DIR/../../lib/statistics.sh"

# 模块信息
MODULE_NAME="端口扫描"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="扫描目标主机的开放端口"

# 模块配置
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

# 常用端口组
declare -A PORT_GROUPS=(
    ["web"]="80,443,8080,8443"
    ["mail"]="25,110,143,587,993,995"
    ["database"]="1433,3306,5432,6379,27017"
    ["remote"]="22,23,3389,5900"
    ["common"]="21,22,23,25,53,80,110,143,443,445,3306,3389"
)

# 扫描单个端口
scan_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-3}"
    
    if check_port "$port" "$host" "$timeout"; then
        return 0
    else
        return 1
    fi
}

# 并发扫描多个端口
scan_ports_parallel() {
    local host="$1"
    shift
    local ports=("$@")
    local max_threads=50
    local results=()
    
    # 创建临时文件存储结果
    local temp_dir=$(create_temp_dir "port_scan")
    local result_file="$temp_dir/results"
    
    # 启动进度显示
    local total=${#ports[@]}
    local progress_info=$(show_progress_box "扫描端口" "$total")
    local current=0
    
    # 扫描函数
    scan_worker() {
        local h="$1"
        local p="$2"
        local idx="$3"
        
        if scan_port "$h" "$p" 2; then
            echo "$p:open" >> "$result_file"
        else
            echo "$p:closed" >> "$result_file"
        fi
        
        # 更新进度
        echo "$idx" >> "$temp_dir/progress"
    }
    
    # 并发执行扫描
    local jobs=0
    for i in "${!ports[@]}"; do
        port="${ports[$i]}"
        
        # 控制并发数
        while [ $(jobs -r | wc -l) -ge $max_threads ]; do
            sleep 0.1
        done
        
        scan_worker "$host" "$port" "$((i+1))" &
    done
    
    # 等待所有任务完成并更新进度
    while [ $(jobs -r | wc -l) -gt 0 ]; do
        if [ -f "$temp_dir/progress" ]; then
            current=$(wc -l < "$temp_dir/progress" 2>/dev/null || echo 0)
            update_progress_box "$progress_info" "$current"
        fi
        sleep 0.1
    done
    
    # 关闭进度框
    close_progress_box "$progress_info"
    
    # 读取结果
    if [ -f "$result_file" ]; then
        while IFS=':' read -r port status; do
            results+=("$port:$status")
        done < "$result_file"
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 返回结果
    printf '%s\n' "${results[@]}"
}

# 显示扫描结果
display_scan_results() {
    local host="$1"
    shift
    local results=("$@")
    
    clear
    echo ""
    draw_menu_border "端口扫描结果 - $host"
    echo ""
    
    # 统计信息
    local total=${#results[@]}
    local open_count=0
    local closed_count=0
    
    for result in "${results[@]}"; do
        if [[ "$result" == *":open" ]]; then
            ((open_count++))
        else
            ((closed_count++))
        fi
    done
    
    echo -e "${WHITE}扫描统计:${NC}"
    echo -e "总端口数: ${YELLOW}$total${NC}"
    echo -e "开放端口: ${GREEN}$open_count${NC}"
    echo -e "关闭端口: ${RED}$closed_count${NC}"
    echo ""
    
    # 显示开放端口
    if [ $open_count -gt 0 ]; then
        echo -e "${GREEN}开放的端口:${NC}"
        echo "-------------------"
        
        for result in "${results[@]}"; do
            if [[ "$result" == *":open" ]]; then
                local port="${result%:*}"
                local service="${PORT_NAMES[$port]:-Unknown}"
                printf "${GREEN}%-6s${NC} - %-15s\n" "$port" "$service"
            fi
        done
        echo ""
    fi
    
    # 生成报告
    local report_file="$HOME/port_scan_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "端口扫描报告"
        echo "============="
        echo "目标主机: $host"
        echo "扫描时间: $(date)"
        echo "扫描端口数: $total"
        echo "开放端口数: $open_count"
        echo ""
        echo "开放端口列表:"
        for result in "${results[@]}"; do
            if [[ "$result" == *":open" ]]; then
                local port="${result%:*}"
                local service="${PORT_NAMES[$port]:-Unknown}"
                printf "%-6s - %s\n" "$port" "$service"
            fi
        done
    } > "$report_file"
    
    echo -e "${BLUE}报告已保存到: $report_file${NC}"
    echo ""
}

# 快速扫描（常用端口）
quick_scan() {
    local host="$1"
    
    info "开始快速扫描常用端口..."
    
    # 获取常用端口列表
    local common_ports=(21 22 23 25 53 80 110 143 443 445 3306 3389 8080 8443)
    
    # 执行扫描
    local results=($(scan_ports_parallel "$host" "${common_ports[@]}"))
    
    # 显示结果
    display_scan_results "$host" "${results[@]}"
}

# 全端口扫描
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
    for ((i=start_port; i<=end_port; i++)); do
        ports+=($i)
    done
    
    # 执行扫描
    local results=($(scan_ports_parallel "$host" "${ports[@]}"))
    
    # 显示结果
    display_scan_results "$host" "${results[@]}"
}

# 自定义端口扫描
custom_scan() {
    local host="$1"
    
    # 获取用户输入
    local port_input=$(show_input_box "自定义端口扫描" \
        "请输入要扫描的端口（逗号分隔，如: 80,443,8080）\n或端口范围（如: 1-1000）:" \
        "" \
        "validate_port_input")
    
    if [ -z "$port_input" ]; then
        return
    fi
    
    # 解析端口列表
    local ports=()
    IFS=',' read -ra port_parts <<< "$port_input"
    
    for part in "${port_parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # 端口范围
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                ports+=($i)
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # 单个端口
            ports+=($part)
        fi
    done
    
    info "开始扫描 ${#ports[@]} 个端口..."
    
    # 执行扫描
    local results=($(scan_ports_parallel "$host" "${ports[@]}"))
    
    # 显示结果
    display_scan_results "$host" "${results[@]}"
}

# 端口组扫描
group_scan() {
    local host="$1"
    
    # 显示端口组选择菜单
    local groups=("web:Web服务端口" "mail:邮件服务端口" "database:数据库端口" "remote:远程访问端口" "common:常用端口")
    
    clear
    echo ""
    draw_menu_border "选择端口组"
    echo ""
    
    for i in "${!groups[@]}"; do
        local group_info="${groups[$i]}"
        local group_name="${group_info%:*}"
        local group_desc="${group_info#*:}"
        echo -e "${YELLOW}$((i+1)))${NC} $group_desc"
    done
    echo ""
    echo -e "${YELLOW}0)${NC} 返回"
    echo ""
    
    read -p "请选择端口组: " choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#groups[@]}" ]; then
        local selected_group="${groups[$((choice-1))]}"
        local group_name="${selected_group%:*}"
        local group_ports="${PORT_GROUPS[$group_name]}"
        
        # 转换端口列表
        IFS=',' read -ra ports <<< "$group_ports"
        
        info "开始扫描 $group_name 端口组..."
        
        # 执行扫描
        local results=($(scan_ports_parallel "$host" "${ports[@]}"))
        
        # 显示结果
        display_scan_results "$host" "${results[@]}"
    else
        error "无效的选择"
    fi
}

# 验证端口输入
validate_port_input() {
    local input="$1"
    
    # 检查是否为空
    if [ -z "$input" ]; then
        return 1
    fi
    
    # 检查格式
    if [[ ! "$input" =~ ^[0-9,\-]+$ ]]; then
        return 1
    fi
    
    return 0
}

# 主菜单
main_menu() {
    while true; do
        clear
        show_menu "端口扫描工具" \
            "1|快速扫描（常用端口）" \
            "2|全端口扫描" \
            "3|自定义端口扫描" \
            "4|端口组扫描" \
            "5|扫描历史" \
            "0|返回主菜单"
        
        read -p "请选择: " choice
        
        case $choice in
            1)
                local host=$(show_input_box "快速扫描" "请输入目标主机IP或域名:" "" "validate_host")
                if [ -n "$host" ]; then
                    record_function_usage "port_scan_quick"
                    quick_scan "$host"
                    read -n 1 -s -r -p "按任意键继续..."
                fi
                ;;
            2)
                local host=$(show_input_box "全端口扫描" "请输入目标主机IP或域名:" "" "validate_host")
                if [ -n "$host" ]; then
                    record_function_usage "port_scan_full"
                    full_scan "$host"
                    read -n 1 -s -r -p "按任意键继续..."
                fi
                ;;
            3)
                local host=$(show_input_box "自定义端口扫描" "请输入目标主机IP或域名:" "" "validate_host")
                if [ -n "$host" ]; then
                    record_function_usage "port_scan_custom"
                    custom_scan "$host"
                    read -n 1 -s -r -p "按任意键继续..."
                fi
                ;;
            4)
                local host=$(show_input_box "端口组扫描" "请输入目标主机IP或域名:" "" "validate_host")
                if [ -n "$host" ]; then
                    record_function_usage "port_scan_group"
                    group_scan "$host"
                    read -n 1 -s -r -p "按任意键继续..."
                fi
                ;;
            5)
                show_scan_history
                read -n 1 -s -r -p "按任意键继续..."
                ;;
            0)
                return
                ;;
            *)
                error "无效的选择"
                sleep 1
                ;;
        esac
    done
}

# 验证主机输入
validate_host() {
    local input="$1"
    
    # 检查是否为空
    if [ -z "$input" ]; then
        return 1
    fi
    
    # 简单的主机名验证（可以是IP或域名）
    if [[ "$input" =~ ^[a-zA-Z0-9\.\-]+$ ]]; then
        return 0
    fi
    
    return 1
}

# 显示扫描历史
show_scan_history() {
    clear
    echo ""
    draw_menu_border "扫描历史"
    echo ""
    
    local history_files=($(ls -t "$HOME"/port_scan_*.txt 2>/dev/null | head -10))
    
    if [ ${#history_files[@]} -eq 0 ]; then
        info "暂无扫描历史"
        return
    fi
    
    echo -e "${WHITE}最近的扫描报告:${NC}"
    echo "-------------------"
    
    for i in "${!history_files[@]}"; do
        local file="${history_files[$i]}"
        local filename=$(basename "$file")
        local date="${filename#port_scan_}"
        date="${date%.txt}"
        date="${date//_/ }"
        
        echo -e "${YELLOW}$((i+1)))${NC} $date"
    done
    echo ""
    echo -e "${YELLOW}0)${NC} 返回"
    echo ""
    
    read -p "选择要查看的报告: " choice
    
    if [ "$choice" = "0" ]; then
        return
    fi
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#history_files[@]}" ]; then
        local selected_file="${history_files[$((choice-1))]}"
        show_paged_output "扫描报告" "$(cat "$selected_file")"
    fi
}

# 模块初始化
init_module() {
    # 检查依赖
    local deps=("nc" "telnet")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warning "缺少可选依赖: ${missing_deps[*]}"
        info "端口扫描功能可能受限"
    fi
    
    # 记录模块加载
    debug "端口扫描模块已加载 (v$MODULE_VERSION)"
}

# 主函数
main() {
    init_module
    main_menu
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
