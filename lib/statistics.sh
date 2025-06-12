#!/bin/bash
# lib/statistics.sh - VPS Scripts 统计功能库

# 防止重复加载
if [ -n "$VPS_SCRIPTS_STATISTICS_LOADED" ]; then
    return 0
fi
VPS_SCRIPTS_STATISTICS_LOADED=1

# 加载依赖
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 统计文件路径
export STATS_DIR="$HOME/.vps_scripts"
export STATS_FILE="$STATS_DIR/statistics.db"
export USAGE_LOG="$STATS_DIR/usage.log"
export PERFORMANCE_LOG="$STATS_DIR/performance.log"

# 初始化统计目录
init_stats_directory() {
    if [ ! -d "$STATS_DIR" ]; then
        mkdir -p "$STATS_DIR"
        chmod 700 "$STATS_DIR"
    fi
}

# 初始化统计数据库
init_stats_database() {
    init_stats_directory
    
    if [ ! -f "$STATS_FILE" ]; then
        cat > "$STATS_FILE" << EOF
# VPS Scripts Statistics Database
# Format: key=value
# Last updated: $(date)

# 运行统计
total_runs=0
daily_runs=0
weekly_runs=0
monthly_runs=0
last_run_date=$(date +%Y-%m-%d)
last_run_time=$(date +%H:%M:%S)
install_date=$(date +%Y-%m-%d)

# 功能使用统计
function_usage={}

# 系统信息
os_type=$OS
os_version=$OS_VERSION
script_version=$VERSION

# 性能统计
avg_execution_time=0
total_execution_time=0
EOF
        debug "统计数据库已初始化"
    fi
}

# 读取统计值
get_stat() {
    local key="$1"
    local default="${2:-0}"
    
    if [ -f "$STATS_FILE" ]; then
        local value=$(grep "^${key}=" "$STATS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# 设置统计值
set_stat() {
    local key="$1"
    local value="$2"
    
    init_stats_database
    
    # 更新或添加键值
    if grep -q "^${key}=" "$STATS_FILE" 2>/dev/null; then
        # 使用临时文件避免问题
        local temp_file=$(mktemp)
        sed "s|^${key}=.*|${key}=${value}|" "$STATS_FILE" > "$temp_file"
        mv "$temp_file" "$STATS_FILE"
    else
        echo "${key}=${value}" >> "$STATS_FILE"
    fi
}

# 增加计数器
increment_stat() {
    local key="$1"
    local increment="${2:-1}"
    
    local current=$(get_stat "$key" 0)
    local new_value=$((current + increment))
    set_stat "$key" "$new_value"
}

# 更新运行统计
update_run_statistics() {
    local current_date=$(date +%Y-%m-%d)
    local last_run_date=$(get_stat "last_run_date")
    
    # 总运行次数
    increment_stat "total_runs"
    
    # 每日统计
    if [ "$current_date" != "$last_run_date" ]; then
        set_stat "daily_runs" 1
        set_stat "last_run_date" "$current_date"
        
        # 重置周和月统计（如果需要）
        local current_week=$(date +%Y-%U)
        local last_week=$(date -d "$last_run_date" +%Y-%U 2>/dev/null || echo "")
        if [ "$current_week" != "$last_week" ]; then
            set_stat "weekly_runs" 1
        fi
        
        local current_month=$(date +%Y-%m)
        local last_month=$(date -d "$last_run_date" +%Y-%m 2>/dev/null || echo "")
        if [ "$current_month" != "$last_month" ]; then
            set_stat "monthly_runs" 1
        fi
    else
        increment_stat "daily_runs"
        increment_stat "weekly_runs"
        increment_stat "monthly_runs"
    fi
    
    # 更新最后运行时间
    set_stat "last_run_time" "$(date +%H:%M:%S)"
}

# 记录功能使用
record_function_usage() {
    local function_name="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 记录到使用日志
    echo "$timestamp | $function_name | $USER | $(hostname)" >> "$USAGE_LOG"
    
    # 更新功能使用计数
    local usage_key="function_${function_name//[^a-zA-Z0-9_]/_}_count"
    increment_stat "$usage_key"
    
    # 记录最后使用时间
    set_stat "function_${function_name//[^a-zA-Z0-9_]/_}_last_used" "$timestamp"
}

# 记录性能数据
record_performance() {
    local function_name="$1"
    local start_time="$2"
    local end_time="$3"
    
    local execution_time=$((end_time - start_time))
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 记录到性能日志
    echo "$timestamp | $function_name | ${execution_time}s" >> "$PERFORMANCE_LOG"
    
    # 更新平均执行时间
    local total_time=$(get_stat "total_execution_time" 0)
    local total_count=$(get_stat "total_runs" 1)
    
    total_time=$((total_time + execution_time))
    local avg_time=$((total_time / total_count))
    
    set_stat "total_execution_time" "$total_time"
    set_stat "avg_execution_time" "$avg_time"
}

# 获取使用统计报告
get_usage_report() {
    local report=""
    
    report+="=== VPS Scripts 使用统计报告 ===\n"
    report+="生成时间: $(date)\n\n"
    
    # 基本统计
    report+="【运行统计】\n"
    report+="总运行次数: $(get_stat total_runs)\n"
    report+="今日运行: $(get_stat daily_runs)\n"
    report+="本周运行: $(get_stat weekly_runs)\n"
    report+="本月运行: $(get_stat monthly_runs)\n"
    report+="安装日期: $(get_stat install_date)\n"
    report+="最后运行: $(get_stat last_run_date) $(get_stat last_run_time)\n\n"
    
    # 功能使用TOP10
    if [ -f "$USAGE_LOG" ]; then
        report+="【热门功能 TOP10】\n"
        local top_functions=$(awk -F' \\| ' '{print $2}' "$USAGE_LOG" | \
                             sort | uniq -c | sort -rn | head -10)
        
        local rank=1
        while IFS= read -r line; do
            local count=$(echo "$line" | awk '{print $1}')
            local func=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
            report+="$rank. $func - 使用 $count 次\n"
            ((rank++))
        done <<< "$top_functions"
        report+="\n"
    fi
    
    # 性能统计
    report+="【性能统计】\n"
    report+="平均执行时间: $(get_stat avg_execution_time) 秒\n"
    
    if [ -f "$PERFORMANCE_LOG" ]; then
        local slowest=$(tail -100 "$PERFORMANCE_LOG" | sort -t'|' -k3 -rn | head -5)
        if [ -n "$slowest" ]; then
            report+="最慢的操作:\n"
            while IFS= read -r line; do
                local func=$(echo "$line" | cut -d'|' -f2 | xargs)
                local time=$(echo "$line" | cut -d'|' -f3 | xargs)
                report+="  - $func: $time\n"
            done <<< "$slowest"
        fi
    fi
    
    echo -e "$report"
}

# 导出统计数据
export_statistics() {
    local export_file="${1:-vps_scripts_stats_$(date +%Y%m%d_%H%M%S).tar.gz}"
    
    info "导出统计数据到: $export_file"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    
    # 复制统计文件
    cp -r "$STATS_DIR" "$temp_dir/"
    
    # 生成报告
    get_usage_report > "$temp_dir/statistics_report.txt"
    
    # 添加系统信息
    cat > "$temp_dir/system_info.txt" << EOF
System Information Export
Generated: $(date)

OS: $(get_system_info os_type)
Version: $(get_system_info os_version)
Kernel: $(get_system_info kernel_version)
Architecture: $(uname -m)
Hostname: $(hostname)
EOF
    
    # 打包
    tar czf "$export_file" -C "$temp_dir" .
    
    # 清理
    rm -rf "$temp_dir"
    
    success "统计数据已导出到: $export_file"
}

# 清理旧的统计数据
cleanup_old_stats() {
    local days="${1:-30}"
    
    info "清理 $days 天前的统计数据..."
    
    # 清理旧的日志条目
    if [ -f "$USAGE_LOG" ]; then
        local temp_file=$(mktemp)
        local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d)
        
        while IFS= read -r line; do
            local log_date=$(echo "$line" | cut -d' ' -f1)
            if [[ "$log_date" > "$cutoff_date" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$USAGE_LOG"
        
        mv "$temp_file" "$USAGE_LOG"
    fi
    
    # 同样处理性能日志
    if [ -f "$PERFORMANCE_LOG" ]; then
        local temp_file=$(mktemp)
        local cutoff_date=$(date -d "$days days ago" +%Y-%m-%d)
        
        while IFS= read -r line; do
            local log_date=$(echo "$line" | cut -d' ' -f1)
            if [[ "$log_date" > "$cutoff_date" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$PERFORMANCE_LOG"
        
        mv "$temp_file" "$PERFORMANCE_LOG"
    fi
    
    success "统计数据清理完成"
}

# 获取统计摘要
get_stats_summary() {
    local total_runs=$(get_stat "total_runs" 0)
    local daily_runs=$(get_stat "daily_runs" 0)
    
    echo "今日运行: ${daily_runs} 次 | 累计运行: ${total_runs} 次"
}

# 实时监控
monitor_realtime() {
    local refresh_interval="${1:-5}"
    
    info "开始实时监控 (按 Ctrl+C 退出)"
    
    while true; do
        clear
        echo "=== VPS Scripts 实时监控 ==="
        echo "时间: $(date)"
        echo ""
        
        # 系统资源
        echo "【系统资源】"
        echo "CPU使用率: $(get_system_resources cpu_usage)"
        echo "内存使用率: $(get_system_resources memory_usage)"
        echo "磁盘使用率: $(get_system_resources disk_usage)"
        echo "系统负载: $(get_system_resources load_average)"
        echo ""
        
        # 运行统计
        echo "【运行统计】"
        get_stats_summary
        echo ""
        
        # 最近活动
        echo "【最近活动】"
        if [ -f "$USAGE_LOG" ]; then
            tail -5 "$USAGE_LOG" | while IFS='|' read -r timestamp function user host; do
                echo "  $timestamp - $function"
            done
        fi
        
        sleep "$refresh_interval"
    done
}

# Web统计接口（JSON格式）
generate_stats_json() {
    local json="{"
    
    # 基本统计
    json+="\"total_runs\":$(get_stat total_runs 0),"
    json+="\"daily_runs\":$(get_stat daily_runs 0),"
    json+="\"weekly_runs\":$(get_stat weekly_runs 0),"
    json+="\"monthly_runs\":$(get_stat monthly_runs 0),"
    json+="\"last_run_date\":\"$(get_stat last_run_date)\","
    json+="\"last_run_time\":\"$(get_stat last_run_time)\","
    json+="\"install_date\":\"$(get_stat install_date)\","
    json+="\"script_version\":\"$(get_stat script_version)\","
    
    # 系统信息
    json+="\"system\":{"
    json+="\"os\":\"$(get_stat os_type)\","
    json+="\"version\":\"$(get_stat os_version)\","
    json+="\"kernel\":\"$(uname -r)\","
    json+="\"arch\":\"$(uname -m)\""
    json+="},"
    
    # 功能使用统计
    json+="\"function_usage\":["
    
    if [ -f "$USAGE_LOG" ]; then
        local first=true
        awk -F' \\| ' '{print $2}' "$USAGE_LOG" | sort | uniq -c | sort -rn | head -10 | \
        while read count func; do
            if [ "$first" = false ]; then
                json+=","
            fi
            json+="{\"name\":\"$func\",\"count\":$count}"
            first=false
        done
    fi
    
    json+="],"
    
    # 性能数据
    json+="\"performance\":{"
    json+="\"avg_execution_time\":$(get_stat avg_execution_time 0)"
    json+="}"
    
    json+="}"
    
    echo "$json"
}

# 发送统计数据到远程服务器（可选）
send_stats_to_server() {
    local server_url="${1:-}"
    local api_key="${2:-}"
    
    if [ -z "$server_url" ]; then
        debug "未配置统计服务器，跳过发送"
        return 0
    fi
    
    local stats_json=$(generate_stats_json)
    
    # 发送数据
    if command_exists curl; then
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $api_key" \
            -d "$stats_json" \
            "$server_url" >/dev/null 2>&1 || true
    fi
}

# 统计数据可视化（简单版）
show_stats_visualization() {
    clear
    echo "=== VPS Scripts 统计可视化 ==="
    echo ""
    
    # 每日运行趋势（最近7天）
    echo "【每日运行趋势】"
    if [ -f "$USAGE_LOG" ]; then
        local today=$(date +%Y-%m-%d)
        for i in {6..0}; do
            local date=$(date -d "$i days ago" +%Y-%m-%d)
            local count=$(grep "^$date" "$USAGE_LOG" 2>/dev/null | wc -l)
            printf "%s: " "$date"
            
            # 绘制简单条形图
            local bar_length=$((count / 2))
            [ $bar_length -gt 50 ] && bar_length=50
            printf '%*s' "$bar_length" | tr ' ' '█'
            echo " ($count)"
        done
    fi
    echo ""
    
    # 功能使用分布
    echo "【功能使用分布】"
    if [ -f "$USAGE_LOG" ]; then
        awk -F' \\| ' '{print $2}' "$USAGE_LOG" | sort | uniq -c | sort -rn | head -5 | \
        while read count func; do
            printf "%-30s: " "$func"
            local bar_length=$((count / 5))
            [ $bar_length -gt 40 ] && bar_length=40
            printf '%*s' "$bar_length" | tr ' ' '▓'
            echo " ($count)"
        done
    fi
    
    echo ""
    read -n 1 -s -r -p "按任意键返回..."
}

# 初始化统计系统
init_statistics_system() {
    init_stats_directory
    init_stats_database
    
    # 设置定期清理任务（如果支持）
    if command_exists crontab && [ -z "$(crontab -l 2>/dev/null | grep vps_scripts_cleanup)" ]; then
        debug "设置统计数据自动清理任务"
        (crontab -l 2>/dev/null; echo "0 3 * * 0 $0 cleanup_stats # vps_scripts_cleanup") | crontab - 2>/dev/null || true
    fi
}

# 导出所有函数
export -f init_stats_directory init_stats_database
export -f get_stat set_stat increment_stat
export -f update_run_statistics record_function_usage record_performance
export -f get_usage_report export_statistics cleanup_old_stats
export -f get_stats_summary monitor_realtime
export -f generate_stats_json send_stats_to_server
export -f show_stats_visualization init_statistics_system
