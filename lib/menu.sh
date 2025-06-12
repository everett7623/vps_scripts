#!/bin/bash
# lib/menu.sh - VPS Scripts 菜单系统库

# 防止重复加载
if [ -n "$VPS_SCRIPTS_MENU_LOADED" ]; then
    return 0
fi
VPS_SCRIPTS_MENU_LOADED=1

# 加载依赖
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# 菜单配置
export MENU_WIDTH=70
export MENU_BORDER_CHAR="━"
export MENU_PROMPT="请选择"
export MENU_INVALID_MSG="无效的选择，请重新输入"
export MENU_BACK_OPTION="0"
export MENU_BACK_TEXT="返回"

# 菜单历史栈
declare -a MENU_HISTORY=()
export MENU_HISTORY

# 绘制菜单边框
draw_menu_border() {
    local title="$1"
    local width="${2:-$MENU_WIDTH}"
    local border_char="${3:-$MENU_BORDER_CHAR}"
    
    # 计算标题位置
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    local left_padding=$(printf "%${padding}s" | tr ' ' "$border_char")
    local right_padding_len=$(( width - padding - title_len - 2 ))
    local right_padding=$(printf "%${right_padding_len}s" | tr ' ' "$border_char")
    
    echo -e "${BLUE}${left_padding} ${title} ${right_padding}${NC}"
}

# 创建菜单项
create_menu_item() {
    local key="$1"
    local text="$2"
    local color="${3:-$YELLOW}"
    local key_width=4
    
    printf "${color}%-${key_width}s${NC} %s" "${key})" "$text"
}

# 显示菜单
show_menu() {
    local title="$1"
    shift
    local items=("$@")
    
    # 绘制标题
    draw_menu_border "$title"
    
    # 显示菜单项
    local i=0
    while [ $i -lt ${#items[@]} ]; do
        local item="${items[$i]}"
        local next_item="${items[$((i+1))]:-}"
        
        # 解析菜单项格式: "key|text|color"
        IFS='|' read -r key text color <<< "$item"
        color="${color:-$YELLOW}"
        
        # 创建菜单项
        local menu_item=$(create_menu_item "$key" "$text" "$color")
        
        # 检查是否需要并排显示
        if [ -n "$next_item" ] && [ ${#menu_item} -lt 35 ]; then
            # 并排显示两个菜单项
            IFS='|' read -r next_key next_text next_color <<< "$next_item"
            next_color="${next_color:-$YELLOW}"
            local next_menu_item=$(create_menu_item "$next_key" "$next_text" "$next_color")
            
            printf "%-35s %s\n" "$menu_item" "$next_menu_item"
            i=$((i + 2))
        else
            # 单独显示
            echo "$menu_item"
            i=$((i + 1))
        fi
    done
    
    # 添加返回选项
    if [ ${#MENU_HISTORY[@]} -gt 0 ]; then
        echo ""
        create_menu_item "$MENU_BACK_OPTION" "$MENU_BACK_TEXT"
        echo ""
    fi
    
    # 绘制底部边框
    draw_menu_border ""
}

# 读取用户选择
read_menu_choice() {
    local prompt="${1:-$MENU_PROMPT}"
    local valid_choices=("${@:2}")
    local choice
    
    while true; do
        read -p "$prompt: " choice
        
        # 检查是否为空
        if [ -z "$choice" ]; then
            echo -e "${RED}$MENU_INVALID_MSG${NC}"
            continue
        fi
        
        # 检查是否为返回选项
        if [ "$choice" = "$MENU_BACK_OPTION" ] && [ ${#MENU_HISTORY[@]} -gt 0 ]; then
            return 0
        fi
        
        # 检查是否为有效选择
        if [ ${#valid_choices[@]} -eq 0 ]; then
            # 没有指定有效选择，接受任何输入
            break
        else
            local valid=false
            for valid_choice in "${valid_choices[@]}"; do
                if [ "$choice" = "$valid_choice" ]; then
                    valid=true
                    break
                fi
            done
            
            if [ "$valid" = true ]; then
                break
            else
                echo -e "${RED}$MENU_INVALID_MSG${NC}"
            fi
        fi
    done
    
    echo "$choice"
}

# 菜单导航
navigate_menu() {
    local menu_id="$1"
    
    # 添加到历史
    MENU_HISTORY+=("$menu_id")
    
    # 导出当前菜单ID
    export CURRENT_MENU_ID="$menu_id"
}

# 返回上级菜单
go_back_menu() {
    if [ ${#MENU_HISTORY[@]} -gt 1 ]; then
        # 移除当前菜单
        unset MENU_HISTORY[-1]
        # 获取上级菜单
        CURRENT_MENU_ID="${MENU_HISTORY[-1]}"
        return 0
    else
        return 1
    fi
}

# 清除菜单历史
clear_menu_history() {
    MENU_HISTORY=()
    CURRENT_MENU_ID=""
}

# 创建确认对话框
show_confirm_dialog() {
    local message="$1"
    local default="${2:-n}"
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━ 确认 ━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}$message${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    confirm "$message" "$default"
}

# 显示信息框
show_info_box() {
    local title="$1"
    local message="$2"
    local wait="${3:-true}"
    
    echo ""
    draw_menu_border "$title"
    echo -e "${WHITE}$message${NC}"
    draw_menu_border ""
    
    if [ "$wait" = true ]; then
        echo ""
        read -n 1 -s -r -p "按任意键继续..."
    fi
}

# 显示错误框
show_error_box() {
    local title="${1:-错误}"
    local message="$2"
    
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━ $title ━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}$message${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
}

# 显示进度框
show_progress_box() {
    local title="$1"
    local total="$2"
    local current=0
    
    # 创建命名管道
    local pipe=$(mktemp -u)
    mkfifo "$pipe"
    
    # 后台显示进度
    (
        while IFS= read -r line; do
            current=$line
            clear
            draw_menu_border "$title"
            show_progress "$current" "$total" 50 "进度"
            draw_menu_border ""
            
            if [ "$current" -ge "$total" ]; then
                break
            fi
        done < "$pipe"
        
        rm -f "$pipe"
    ) &
    
    local progress_pid=$!
    
    # 返回管道路径和进程ID
    echo "$pipe:$progress_pid"
}

# 更新进度框
update_progress_box() {
    local pipe_info="$1"
    local value="$2"
    
    local pipe="${pipe_info%:*}"
    
    if [ -p "$pipe" ]; then
        echo "$value" > "$pipe"
    fi
}

# 关闭进度框
close_progress_box() {
    local pipe_info="$1"
    
    local pipe="${pipe_info%:*}"
    local pid="${pipe_info#*:}"
    
    if [ -p "$pipe" ]; then
        # 发送最大值以关闭进度框
        echo "999999" > "$pipe"
        rm -f "$pipe"
    fi
    
    # 等待进程结束
    wait "$pid" 2>/dev/null || true
}

# 创建列表选择菜单
show_list_menu() {
    local title="$1"
    shift
    local items=("$@")
    local selected=0
    local key
    
    while true; do
        clear
        draw_menu_border "$title"
        
        # 显示列表项
        for i in "${!items[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "${GREEN}▶ ${items[$i]}${NC}"
            else
                echo -e "  ${items[$i]}"
            fi
        done
        
        draw_menu_border ""
        echo "使用 ↑/↓ 或 j/k 移动，Enter 确认，q 退出"
        
        # 读取键盘输入
        read -rsn1 key
        
        case "$key" in
            A|k) # 上
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#items[@]} - 1))
                ;;
            B|j) # 下
                ((selected++))
                [ $selected -ge ${#items[@]} ] && selected=0
                ;;
            ''|' ') # Enter
                echo "$selected"
                return 0
                ;;
            q|Q) # 退出
                return 1
                ;;
        esac
    done
}

# 创建多选菜单
show_checkbox_menu() {
    local title="$1"
    shift
    local items=("$@")
    local selected=()
    local cursor=0
    local key
    
    # 初始化选中状态
    for i in "${!items[@]}"; do
        selected[$i]=false
    done
    
    while true; do
        clear
        draw_menu_border "$title"
        
        # 显示选项
        for i in "${!items[@]}"; do
            local checkbox="[ ]"
            [ "${selected[$i]}" = true ] && checkbox="[x]"
            
            if [ $i -eq $cursor ]; then
                echo -e "${GREEN}▶ $checkbox ${items[$i]}${NC}"
            else
                echo -e "  $checkbox ${items[$i]}"
            fi
        done
        
        draw_menu_border ""
        echo "使用 ↑/↓ 移动，空格 选择/取消，Enter 确认，q 退出"
        
        # 读取键盘输入
        read -rsn1 key
        
        case "$key" in
            A|k) # 上
                ((cursor--))
                [ $cursor -lt 0 ] && cursor=$((${#items[@]} - 1))
                ;;
            B|j) # 下
                ((cursor++))
                [ $cursor -ge ${#items[@]} ] && cursor=0
                ;;
            ' ') # 空格 - 切换选择
                if [ "${selected[$cursor]}" = true ]; then
                    selected[$cursor]=false
                else
                    selected[$cursor]=true
                fi
                ;;
            ''|$'\n') # Enter - 确认
                # 返回选中的索引
                local result=""
                for i in "${!selected[@]}"; do
                    if [ "${selected[$i]}" = true ]; then
                        result="$result $i"
                    fi
                done
                echo "$result"
                return 0
                ;;
            q|Q) # 退出
                return 1
                ;;
        esac
    done
}

# 创建输入框
show_input_box() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local validation_func="$4"
    
    local input
    
    while true; do
        clear
        draw_menu_border "$title"
        echo -e "${WHITE}$prompt${NC}"
        if [ -n "$default" ]; then
            echo -e "${CYAN}默认值: $default${NC}"
        fi
        draw_menu_border ""
        
        read -p "> " input
        
        # 使用默认值
        if [ -z "$input" ] && [ -n "$default" ]; then
            input="$default"
        fi
        
        # 验证输入
        if [ -n "$validation_func" ]; then
            if ! $validation_func "$input"; then
                show_error_box "输入无效" "请重新输入"
                continue
            fi
        fi
        
        echo "$input"
        return 0
    done
}

# 验证函数示例
validate_number() {
    local input="$1"
    [[ "$input" =~ ^[0-9]+$ ]]
}

validate_ip() {
    local input="$1"
    local regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    
    if [[ "$input" =~ $regex ]]; then
        # 检查每个段是否在有效范围内
        IFS='.' read -ra ADDR <<< "$input"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

validate_email() {
    local input="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    [[ "$input" =~ $regex ]]
}

validate_url() {
    local input="$1"
    local regex="^(https?|ftp)://[^\s/$.?#].[^\s]*$"
    [[ "$input" =~ $regex ]]
}

validate_port() {
    local input="$1"
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        [ "$input" -ge 1 ] && [ "$input" -le 65535 ]
    else
        return 1
    fi
}

# 创建表格显示
show_table() {
    local title="$1"
    shift
    local headers=("$@")
    
    # 计算列宽
    local col_widths=()
    for header in "${headers[@]}"; do
        col_widths+=(${#header})
    done
    
    # 绘制标题
    draw_menu_border "$title"
    
    # 绘制表头
    local header_line=""
    for i in "${!headers[@]}"; do
        header_line+=$(printf "%-${col_widths[$i]}s  " "${headers[$i]}")
    done
    echo -e "${CYAN}$header_line${NC}"
    
    # 绘制分隔线
    local separator=""
    for width in "${col_widths[@]}"; do
        separator+=$(printf '%*s' "$width" | tr ' ' '-')
        separator+="  "
    done
    echo "$separator"
}

# 添加表格行
add_table_row() {
    local values=("$@")
    local row=""
    
    for i in "${!values[@]}"; do
        row+=$(printf "%-${col_widths[$i]:-15}s  " "${values[$i]}")
    done
    echo "$row"
}

# 分页显示
show_paged_output() {
    local title="$1"
    local content="$2"
    local lines_per_page="${3:-20}"
    
    local total_lines=$(echo "$content" | wc -l)
    local current_page=1
    local total_pages=$(( (total_lines + lines_per_page - 1) / lines_per_page ))
    
    while true; do
        clear
        draw_menu_border "$title (页 $current_page/$total_pages)"
        
        # 显示当前页内容
        local start_line=$(( (current_page - 1) * lines_per_page + 1 ))
        local end_line=$(( start_line + lines_per_page - 1 ))
        echo "$content" | sed -n "${start_line},${end_line}p"
        
        draw_menu_border ""
        echo "使用 n(下一页) p(上一页) q(退出)"
        
        read -rsn1 key
        case "$key" in
            n|N)
                [ $current_page -lt $total_pages ] && ((current_page++))
                ;;
            p|P)
                [ $current_page -gt 1 ] && ((current_page--))
                ;;
            q|Q)
                break
                ;;
        esac
    done
}

# 导出所有函数
export -f draw_menu_border create_menu_item show_menu read_menu_choice
export -f navigate_menu go_back_menu clear_menu_history
export -f show_confirm_dialog show_info_box show_error_box
export -f show_progress_box update_progress_box close_progress_box
export -f show_list_menu show_checkbox_menu show_input_box
export -f validate_number validate_ip validate_email validate_url validate_port
export -f show_table add_table_row show_paged_output
