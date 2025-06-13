#!/bin/bash

# ===================================================================
# 文件名: lib/menu.sh
# 描述: 菜单渲染与交互逻辑
# 作者: everett7623
# 版本: 1.0.0
# 更新日期: 2025-01-10
# ===================================================================

# 加载公共函数库
source "${LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/common.sh"

# 定义菜单样式
export MENU_STYLE_SIMPLE="simple"
export MENU_STYLE_FANCY="fancy"
export MENU_STYLE_COMPACT="compact"

# 默认菜单样式
MENU_CURRENT_STYLE="${MENU_STYLE_FANCY}"

# ===================================================================
# 菜单渲染函数
# ===================================================================

# 设置菜单样式
set_menu_style() {
    local style="$1"
    
    case "$style" in
        "$MENU_STYLE_SIMPLE"|"$MENU_STYLE_FANCY"|"$MENU_STYLE_COMPACT")
            MENU_CURRENT_STYLE="$style"
            ;;
        *)
            log_warn "未知的菜单样式: $style，使用默认样式"
            ;;
    esac
}

# 显示菜单头部
show_menu_header() {
    local title="$1"
    local subtitle="$2"
    
    clear
    
    case "$MENU_CURRENT_STYLE" in
        "$MENU_STYLE_SIMPLE")
            echo -e "${YELLOW}$title${NC}"
            [[ -n "$subtitle" ]] && echo -e "${CYAN}$subtitle${NC}"
            echo ""
            ;;
        "$MENU_STYLE_FANCY")
            local width=78
            echo -e "${YELLOW}$(printf '═%.0s' $(seq 1 $width))${NC}"
            printf "${YELLOW}║${NC} %-*s ${YELLOW}║${NC}\n" $((width-4)) "$title"
            [[ -n "$subtitle" ]] && printf "${YELLOW}║${NC} ${CYAN}%-*s${NC} ${YELLOW}║${NC}\n" $((width-4)) "$subtitle"
            echo -e "${YELLOW}$(printf '═%.0s' $(seq 1 $width))${NC}"
            echo ""
            ;;
        "$MENU_STYLE_COMPACT")
            echo -e "${YELLOW}=== $title ===${NC}"
            [[ -n "$subtitle" ]] && echo -e "${CYAN}$subtitle${NC}"
            ;;
    esac
}

# 显示菜单项
show_menu_item() {
    local number="$1"
    local text="$2"
    local status="${3:-}"
    
    case "$MENU_CURRENT_STYLE" in
        "$MENU_STYLE_SIMPLE")
            if [[ -n "$status" ]]; then
                printf "  %-3s %-40s [%s]\n" "$number)" "$text" "$status"
            else
                printf "  %-3s %s\n" "$number)" "$text"
            fi
            ;;
        "$MENU_STYLE_FANCY")
            if [[ -n "$status" ]]; then
                printf "${YELLOW}║${NC}  ${BLUE}%-3s${NC} %-40s ${GREEN}[%s]${NC}\n" "$number)" "$text" "$status"
            else
                printf "${YELLOW}║${NC}  ${BLUE}%-3s${NC} %s\n" "$number)" "$text"
            fi
            ;;
        "$MENU_STYLE_COMPACT")
            if [[ -n "$status" ]]; then
                printf "%3s) %-30s [%s]\n" "$number" "$text" "$status"
            else
                printf "%3s) %s\n" "$number" "$text"
            fi
            ;;
    esac
}

# 显示菜单分隔线
show_menu_separator() {
    local text="${1:-}"
    
    case "$MENU_CURRENT_STYLE" in
        "$MENU_STYLE_SIMPLE")
            if [[ -n "$text" ]]; then
                echo -e "\n${CYAN}--- $text ---${NC}"
            else
                echo ""
            fi
            ;;
        "$MENU_STYLE_FANCY")
            if [[ -n "$text" ]]; then
                local width=78
                local text_len=${#text}
                local padding=$(( (width - text_len - 4) / 2 ))
                echo -e "${YELLOW}├$(printf '─%.0s' $(seq 1 $padding))┤${NC} ${CYAN}$text${NC} ${YELLOW}├$(printf '─%.0s' $(seq 1 $padding))┤${NC}"
            else
                echo -e "${YELLOW}├$(printf '─%.0s' $(seq 1 76))┤${NC}"
            fi
            ;;
        "$MENU_STYLE_COMPACT")
            if [[ -n "$text" ]]; then
                echo -e "${CYAN}-- $text --${NC}"
            else
                echo "---"
            fi
            ;;
    esac
}

# 显示菜单底部
show_menu_footer() {
    case "$MENU_CURRENT_STYLE" in
        "$MENU_STYLE_SIMPLE")
            echo ""
            ;;
        "$MENU_STYLE_FANCY")
            echo -e "${YELLOW}$(printf '═%.0s' $(seq 1 78))${NC}"
            ;;
        "$MENU_STYLE_COMPACT")
            echo ""
            ;;
    esac
}

# ===================================================================
# 菜单交互函数
# ===================================================================

# 读取用户选择
read_menu_choice() {
    local prompt="${1:-请选择}"
    local default="${2:-}"
    local timeout="${3:-0}"
    
    local choice
    
    if [[ $timeout -gt 0 ]]; then
        if [[ -n "$default" ]]; then
            read -t "$timeout" -p "$prompt [$default]: " choice || choice="$default"
        else
            read -t "$timeout" -p "$prompt: " choice
        fi
    else
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " choice
            [[ -z "$choice" ]] && choice="$default"
        else
            read -p "$prompt: " choice
        fi
    fi
    
    echo "$choice"
}

# 验证菜单选择
validate_menu_choice() {
    local choice="$1"
    local min="$2"
    local max="$3"
    
    # 检查是否为数字
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # 检查范围
    if (( choice < min || choice > max )); then
        return 1
    fi
    
    return 0
}

# 显示错误信息
show_menu_error() {
    local message="$1"
    echo -e "${RED}错误: $message${NC}"
    sleep 2
}

# 显示成功信息
show_menu_success() {
    local message="$1"
    echo -e "${GREEN}成功: $message${NC}"
    sleep 2
}

# 暂停等待
pause_menu() {
    local message="${1:-按任意键继续...}"
    read -n 1 -s -r -p "$message"
    echo ""
}

# ===================================================================
# 高级菜单功能
# ===================================================================

# 创建动态菜单
create_dynamic_menu() {
    local -n menu_items=$1  # 使用名称引用
    local title="$2"
    local subtitle="${3:-}"
    
    show_menu_header "$title" "$subtitle"
    
    local i=1
    for item in "${menu_items[@]}"; do
        # 如果item包含|分隔符，则分割为文本和状态
        if [[ "$item" == *"|"* ]]; then
            local text="${item%|*}"
            local status="${item#*|}"
            show_menu_item "$i" "$text" "$status"
        else
            show_menu_item "$i" "$item"
        fi
        ((i++))
    done
    
    show_menu_separator
    show_menu_item "0" "返回上级菜单"
    show_menu_footer
    
    local choice=$(read_menu_choice "请选择" "" 0)
    
    if validate_menu_choice "$choice" 0 ${#menu_items[@]}; then
        echo "$choice"
    else
        show_menu_error "无效的选择"
        echo "-1"
    fi
}

# 创建复选菜单
create_checkbox_menu() {
    local -n options=$1  # 选项数组
    local -n selected=$2  # 已选中数组
    local title="$3"
    
    while true; do
        show_menu_header "$title" "使用空格选择/取消选择，回车确认"
        
        local i=1
        for option in "${options[@]}"; do
            local mark=" "
            for sel in "${selected[@]}"; do
                if [[ "$sel" == "$option" ]]; then
                    mark="✓"
                    break
                fi
            done
            printf "  [${GREEN}%s${NC}] %2d) %s\n" "$mark" "$i" "$option"
            ((i++))
        done
        
        show_menu_separator
        show_menu_item "0" "确认选择"
        show_menu_footer
        
        local choice=$(read_menu_choice "请选择" "" 0)
        
        if [[ "$choice" == "0" ]]; then
            break
        elif validate_menu_choice "$choice" 1 ${#options[@]}; then
            local index=$((choice - 1))
            local option="${options[$index]}"
            
            # 切换选中状态
            local found=0
            for i in "${!selected[@]}"; do
                if [[ "${selected[$i]}" == "$option" ]]; then
                    unset 'selected[$i]'
                    selected=("${selected[@]}")  # 重建数组
                    found=1
                    break
                fi
            done
            
            if [[ $found -eq 0 ]]; then
                selected+=("$option")
            fi
        fi
    done
}

# 创建输入菜单
create_input_menu() {
    local title="$1"
    local prompt="$2"
    local default="${3:-}"
    local validation_func="${4:-}"
    
    show_menu_header "$title"
    
    while true; do
        local input=$(read_menu_choice "$prompt" "$default" 0)
        
        # 如果提供了验证函数，则验证输入
        if [[ -n "$validation_func" ]]; then
            if $validation_func "$input"; then
                echo "$input"
                break
            else
                show_menu_error "输入无效，请重试"
            fi
        else
            echo "$input"
            break
        fi
    done
}

# 创建确认菜单
create_confirm_menu() {
    local title="$1"
    local message="$2"
    local default="${3:-n}"
    
    show_menu_header "$title"
    echo -e "$message"
    echo ""
    
    local choice
    if [[ "$default" == "y" ]]; then
        choice=$(read_menu_choice "确定要继续吗? [Y/n]" "y" 0)
    else
        choice=$(read_menu_choice "确定要继续吗? [y/N]" "n" 0)
    fi
    
    [[ "$choice" =~ ^[Yy]$ ]]
}

# ===================================================================
# 进度条功能
# ===================================================================

# 显示进度条菜单
show_progress_menu() {
    local title="$1"
    local total="$2"
    local current=0
    
    show_menu_header "$title"
    
    while read -r line; do
        ((current++))
        
        local percent=$((current * 100 / total))
        local bar_length=50
        local filled_length=$((bar_length * current / total))
        
        printf "\r["
        printf "%${filled_length}s" | tr ' ' '='
        printf "%$((bar_length - filled_length))s" | tr ' ' '-'
        printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
        
        # 处理输入行
        if [[ -n "$line" ]]; then
            echo ""
            echo "$line"
        fi
        
        if [[ $current -ge $total ]]; then
            echo ""
            break
        fi
    done
}

# ===================================================================
# 导出所有函数
# ===================================================================

export -f set_menu_style show_menu_header show_menu_item
export -f show_menu_separator show_menu_footer
export -f read_menu_choice validate_menu_choice
export -f show_menu_error show_menu_success pause_menu
export -f create_dynamic_menu create_checkbox_menu
export -f create_input_menu create_confirm_menu
export -f show_progress_menu
