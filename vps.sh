#!/bin/bash

# ==============================================================================
#                              VPS Management Scripts
#
#      Project: https://github.com/everett7623/vps_scripts/
#      Author: Jensfrank
#      Version: 2.2.0 (Enterprise Enhanced)
#
#      New Features in 2.2.0:
#      - Automatic version checking and update notifications
#      - Multi-language support (English/Chinese)
#      - Script signature verification (SHA256)
#      - Concurrent instance control (flock)
#      - Enhanced security and reliability
# ==============================================================================

# --- Configuration ---
GITHUB_RAW_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main"
SCRIPT_VERSION="2.2.0"
VERSION_CHECK_URL="${GITHUB_RAW_URL}/version.json"
CHANGELOG_URL="${GITHUB_RAW_URL}/CHANGELOG.md"
NETWORK_TIMEOUT=30
MAX_RETRIES=3
LOG_FILE="/tmp/vps_scripts.log"
LOCK_FILE="/tmp/vps_scripts.lock"
LOCK_FD=200

# Language settings
DEFAULT_LANG="zh_CN"
LANG_FILE="/tmp/vps_scripts_lang"

# --- Colors for Terminal Output ---
RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'

# ==============================================================================
#                              MULTI-LANGUAGE SUPPORT
# ==============================================================================

# Language strings
declare -A LANG_ZH_CN=(
    [menu_title]="VPS 综合管理脚本"
    [menu_subtitle]="作者: Jensfrank"
    [menu_exit]="退出脚本"
    [menu_return]="返回上级菜单"
    [menu_prompt]="请输入选项"
    [press_enter]="按回车键继续..."
    [invalid_input]="无效输入"
    [input_number]="请输入数字"
    [input_range]="请输入 %s-%s 之间的数字"
    [error]="错误"
    [warning]="警告"
    [info]="信息"
    [success]="成功"
    [network_fail]="网络连接失败"
    [download_fail]="下载失败"
    [executing]="正在执行"
    [completed]="执行完成"
    [checking_deps]="检查依赖"
    [checking_network]="检查网络连接"
    [checking_update]="检查更新"
    [new_version_available]="发现新版本"
    [current_version]="当前版本"
    [latest_version]="最新版本"
    [update_prompt]="是否查看更新日志? (y/n)"
    [script_locked]="脚本已在运行，请勿重复启动"
    [signature_verify]="验证脚本签名"
    [signature_fail]="签名验证失败"
    [thanks]="感谢使用 VPS 综合管理脚本!"
    [goodbye]="再见!"
)

declare -A LANG_EN_US=(
    [menu_title]="VPS Management Script"
    [menu_subtitle]="Author: Jensfrank"
    [menu_exit]="Exit Script"
    [menu_return]="Return to Previous Menu"
    [menu_prompt]="Enter your choice"
    [press_enter]="Press Enter to continue..."
    [invalid_input]="Invalid input"
    [input_number]="Please enter a number"
    [input_range]="Please enter a number between %s-%s"
    [error]="ERROR"
    [warning]="WARNING"
    [info]="INFO"
    [success]="SUCCESS"
    [network_fail]="Network connection failed"
    [download_fail]="Download failed"
    [executing]="Executing"
    [completed]="Completed"
    [checking_deps]="Checking dependencies"
    [checking_network]="Checking network"
    [checking_update]="Checking for updates"
    [new_version_available]="New version available"
    [current_version]="Current version"
    [latest_version]="Latest version"
    [update_prompt]="View changelog? (y/n)"
    [script_locked]="Script is already running"
    [signature_verify]="Verifying signature"
    [signature_fail]="Signature verification failed"
    [thanks]="Thanks for using VPS Management Script!"
    [goodbye]="Goodbye!"
)

# Get current language
get_lang() {
    if [ -f "$LANG_FILE" ]; then
        cat "$LANG_FILE"
    else
        echo "$DEFAULT_LANG"
    fi
}

# Set language
set_lang() {
    local lang="$1"
    echo "$lang" > "$LANG_FILE"
}

# Get translated text
t() {
    local key="$1"
    shift
    local current_lang=$(get_lang)
    local text=""
    
    if [ "$current_lang" = "en_US" ]; then
        text="${LANG_EN_US[$key]}"
    else
        text="${LANG_ZH_CN[$key]}"
    fi
    
    # Handle printf-style formatting
    if [ $# -gt 0 ]; then
        printf "$text" "$@"
    else
        echo "$text"
    fi
}

# Language selection menu
select_language() {
    clear
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${CYAN}Select Language / 选择语言${RESET}"
    echo -e "${GREEN}========================================${RESET}"
    echo ""
    echo -e "${CYAN}[1]${RESET} 简体中文"
    echo -e "${CYAN}[2]${RESET} English"
    echo ""
    read -p "Choice / 选择 [1-2]: " lang_choice
    
    case $lang_choice in
        1) set_lang "zh_CN" ;;
        2) set_lang "en_US" ;;
        *) set_lang "zh_CN" ;;
    esac
}

# ==============================================================================
#                              UTILITY FUNCTIONS
# ==============================================================================

# Logging functions
log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(t info)]${RESET} $*"
    log_message "INFO" "$*"
}

log_success() {
    echo -e "${GREEN}[$(t success)]${RESET} $*"
    log_message "SUCCESS" "$*"
}

log_warning() {
    echo -e "${YELLOW}[$(t warning)]${RESET} $*"
    log_message "WARNING" "$*"
}

log_error() {
    echo -e "${RED}[$(t error)]${RESET} $*" >&2
    log_message "ERROR" "$*"
}

# Header display
print_header() {
    clear
    echo -e "${GREEN}==========================================================${RESET}"
    echo -e "${CYAN}${BOLD}         $(t menu_title) v${SCRIPT_VERSION}              ${RESET}"
    echo -e "${CYAN}              $(t menu_subtitle)                          ${RESET}"
    echo -e "${YELLOW}   Project: https://github.com/everett7623/vps_scripts/  ${RESET}"
    echo -e "${GREEN}==========================================================${RESET}"
    echo ""
}

# ==============================================================================
#                              CONCURRENT CONTROL
# ==============================================================================

# Acquire lock to prevent concurrent execution
acquire_lock() {
    eval "exec $LOCK_FD>$LOCK_FILE"
    
    if ! flock -n $LOCK_FD 2>/dev/null; then
        log_error "$(t script_locked)"
        echo ""
        echo -e "${YELLOW}$(t info):${RESET}"
        if [ "$(get_lang)" = "zh_CN" ]; then
            echo "  - 如果确认没有其他实例运行，请删除锁文件:"
            echo "    ${WHITE}rm -f $LOCK_FILE${RESET}"
            echo "  - 或等待其他实例完成"
        else
            echo "  - If no other instance is running, remove lock file:"
            echo "    ${WHITE}rm -f $LOCK_FILE${RESET}"
            echo "  - Or wait for other instance to finish"
        fi
        echo ""
        exit 1
    fi
    
    # Write PID to lock file
    echo $$ >&$LOCK_FD
    return 0
}

# Release lock
release_lock() {
    if [ -n "$LOCK_FD" ]; then
        flock -u $LOCK_FD 2>/dev/null
        eval "exec $LOCK_FD>&-"
    fi
    rm -f "$LOCK_FILE" 2>/dev/null
}

# ==============================================================================
#                              VERSION CHECKING
# ==============================================================================

# Compare version numbers (returns 0 if v1 < v2, 1 if v1 >= v2)
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if exists
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Split by dots and compare
    IFS='.' read -ra V1 <<< "$v1"
    IFS='.' read -ra V2 <<< "$v2"
    
    for i in 0 1 2; do
        local num1=${V1[$i]:-0}
        local num2=${V2[$i]:-0}
        
        if [ "$num1" -lt "$num2" ]; then
            return 0
        elif [ "$num1" -gt "$num2" ]; then
            return 1
        fi
    done
    
    return 1
}

# Check for updates
check_for_updates() {
    log_info "$(t checking_update)..."
    
    local version_data=""
    local attempt=1
    
    while [ $attempt -le 2 ]; do
        if command -v curl &>/dev/null; then
            version_data=$(curl -fsSL --max-time 10 "${VERSION_CHECK_URL}" 2>/dev/null)
        elif command -v wget &>/dev/null; then
            version_data=$(wget -qO- --timeout=10 "${VERSION_CHECK_URL}" 2>/dev/null)
        fi
        
        if [ -n "$version_data" ]; then
            break
        fi
        ((attempt++))
    done
    
    if [ -z "$version_data" ]; then
        log_warning "$(t checking_update) - $(t network_fail)"
        return 1
    fi
    
    # Parse JSON (simple extraction)
    local latest_version=$(echo "$version_data" | grep -oP '"version":\s*"\K[^"]+' | head -1)
    local release_date=$(echo "$version_data" | grep -oP '"date":\s*"\K[^"]+' | head -1)
    local download_url=$(echo "$version_data" | grep -oP '"url":\s*"\K[^"]+' | head -1)
    
    if [ -z "$latest_version" ]; then
        return 1
    fi
    
    # Compare versions
    if version_compare "$SCRIPT_VERSION" "$latest_version"; then
        echo ""
        echo -e "${YELLOW}┌────────────────────────────────────────────────┐${RESET}"
        echo -e "${YELLOW}│  🎉 $(t new_version_available)!${RESET}"
        echo -e "${YELLOW}├────────────────────────────────────────────────┤${RESET}"
        echo -e "   $(t current_version): ${RED}v${SCRIPT_VERSION}${RESET}"
        echo -e "   $(t latest_version):  ${GREEN}v${latest_version}${RESET}"
        [ -n "$release_date" ] && echo -e "   Release Date: ${CYAN}${release_date}${RESET}"
        echo -e "${YELLOW}└────────────────────────────────────────────────┘${RESET}"
        echo ""
        
        read -p "$(t update_prompt) " show_changelog
        if [[ "$show_changelog" =~ ^[Yy]$ ]]; then
            show_changelog_func
        fi
        
        echo ""
        if [ "$(get_lang)" = "zh_CN" ]; then
            echo -e "${WHITE}更新命令:${RESET}"
        else
            echo -e "${WHITE}Update command:${RESET}"
        fi
        echo -e "${GREEN}bash <(curl -sL ${download_url:-${GITHUB_RAW_URL}/vps.sh})${RESET}"
        echo ""
        sleep 2
    fi
    
    return 0
}

# Show changelog
show_changelog_func() {
    local changelog=""
    
    if command -v curl &>/dev/null; then
        changelog=$(curl -fsSL --max-time 10 "${CHANGELOG_URL}" 2>/dev/null | head -50)
    elif command -v wget &>/dev/null; then
        changelog=$(wget -qO- --timeout=10 "${CHANGELOG_URL}" 2>/dev/null | head -50)
    fi
    
    if [ -n "$changelog" ]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━ CHANGELOG ━━━━━━━━━━━━━━━${RESET}"
        echo "$changelog"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    fi
}

# ==============================================================================
#                              SCRIPT SIGNATURE VERIFICATION
# ==============================================================================

# Verify script integrity using SHA256
verify_script_signature() {
    local script_path="$1"
    local signature_url="${2}.sha256"
    
    if [ ! -f "$script_path" ]; then
        return 1
    fi
    
    # Try to download signature file
    local expected_hash=""
    if command -v curl &>/dev/null; then
        expected_hash=$(curl -fsSL --max-time 5 "${signature_url}" 2>/dev/null)
    elif command -v wget &>/dev/null; then
        expected_hash=$(wget -qO- --timeout=5 "${signature_url}" 2>/dev/null)
    fi
    
    # If no signature file, skip verification (optional security)
    if [ -z "$expected_hash" ]; then
        log_warning "$(t signature_verify) - No signature file found (skipped)"
        return 0
    fi
    
    # Calculate actual hash
    local actual_hash=""
    if command -v sha256sum &>/dev/null; then
        actual_hash=$(sha256sum "$script_path" | awk '{print $1}')
    elif command -v shasum &>/dev/null; then
        actual_hash=$(shasum -a 256 "$script_path" | awk '{print $1}')
    else
        log_warning "$(t signature_verify) - sha256sum not found (skipped)"
        return 0
    fi
    
    # Compare hashes
    expected_hash=$(echo "$expected_hash" | tr -d '[:space:]')
    actual_hash=$(echo "$actual_hash" | tr -d '[:space:]')
    
    if [ "$expected_hash" != "$actual_hash" ]; then
        log_error "$(t signature_fail)!"
        echo ""
        if [ "$(get_lang)" = "zh_CN" ]; then
            echo -e "${RED}警告: 脚本完整性验证失败!${RESET}"
            echo "  预期: $expected_hash"
            echo "  实际: $actual_hash"
            echo ""
            echo "可能原因:"
            echo "  1. 脚本在传输过程中被修改"
            echo "  2. 中间人攻击"
            echo "  3. 下载不完整"
            echo ""
            echo "建议: 停止执行并重新下载"
        else
            echo -e "${RED}WARNING: Script integrity verification failed!${RESET}"
            echo "  Expected: $expected_hash"
            echo "  Actual:   $actual_hash"
            echo ""
            echo "Possible reasons:"
            echo "  1. Script modified during transmission"
            echo "  2. Man-in-the-middle attack"
            echo "  3. Incomplete download"
            echo ""
            echo "Recommendation: Stop execution and re-download"
        fi
        echo ""
        return 1
    fi
    
    log_success "$(t signature_verify) - OK"
    return 0
}

# ==============================================================================
#                              DEPENDENCY & NETWORK CHECKS
# ==============================================================================

check_dependencies() {
    log_info "$(t checking_deps)..."
    
    local missing_tools=()
    
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        missing_tools+=("curl or wget")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        if [ "$(get_lang)" = "zh_CN" ]; then
            echo -e "${YELLOW}请先安装缺少的工具:${RESET}"
            echo -e "  ${WHITE}Debian/Ubuntu: apt-get update && apt-get install -y curl${RESET}"
            echo -e "  ${WHITE}CentOS/RHEL:   yum install -y curl${RESET}"
            echo -e "  ${WHITE}Alpine:        apk add curl${RESET}"
        else
            echo -e "${YELLOW}Please install missing tools:${RESET}"
            echo -e "  ${WHITE}Debian/Ubuntu: apt-get update && apt-get install -y curl${RESET}"
            echo -e "  ${WHITE}CentOS/RHEL:   yum install -y curl${RESET}"
            echo -e "  ${WHITE}Alpine:        apk add curl${RESET}"
        fi
        echo ""
        return 1
    fi
    
    log_success "$(t checking_deps) - OK"
    return 0
}

check_network() {
    log_info "$(t checking_network)..."
    
    if ping -c 1 -W 3 raw.githubusercontent.com &>/dev/null; then
        log_success "$(t checking_network) - OK"
        return 0
    fi
    
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        log_warning "Internet OK, but GitHub may be blocked"
        return 0
    fi
    
    log_error "$(t network_fail)"
    return 1
}

# ==============================================================================
#                              INPUT VALIDATION
# ==============================================================================

validate_input() {
    local input="$1"
    local min="${2:-0}"
    local max="$3"
    
    if [ -z "$input" ]; then
        log_error "$(t invalid_input): Empty input"
        return 1
    fi
    
    if ! [[ "$input" =~ ^[0-9]+$ ]]; then
        log_error "$(t invalid_input): $(t input_number)"
        return 1
    fi
    
    if [ "$input" -lt "$min" ] || [ "$input" -gt "$max" ]; then
        log_error "$(t invalid_input): $(t input_range $min $max)"
        return 1
    fi
    
    return 0
}

pause() {
    echo ""
    echo -e "${CYAN}$(t press_enter)${RESET}"
    read -r
}

# ==============================================================================
#                              SCRIPT EXECUTION
# ==============================================================================

run_repo_script() {
    local script_repo_path="${1}"
    local full_url="${GITHUB_RAW_URL}/${script_repo_path}"
    local temp_script="/tmp/vps_script_$$.sh"
    
    print_header
    log_info "$(t executing): ${script_repo_path}"
    echo -e "${WHITE}URL: ${full_url}${RESET}"
    echo ""
    
    # Download script
    local download_success=false
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        log_info "Download attempt ${attempt}/${MAX_RETRIES}..."
        
        if command -v curl &>/dev/null; then
            if curl -fsSL --connect-timeout 10 --max-time "$NETWORK_TIMEOUT" \
                    -o "$temp_script" "${full_url}" 2>/dev/null; then
                download_success=true
                break
            fi
        elif command -v wget &>/dev/null; then
            if wget -q --timeout="$NETWORK_TIMEOUT" --tries=1 \
                    -O "$temp_script" "${full_url}" 2>/dev/null; then
                download_success=true
                break
            fi
        fi
        
        ((attempt++))
        [ $attempt -le $MAX_RETRIES ] && sleep 2
    done
    
    if [ "$download_success" = false ]; then
        log_error "$(t download_fail): ${full_url}"
        rm -f "$temp_script"
        pause
        return 1
    fi
    
    if [ ! -s "$temp_script" ]; then
        log_error "Downloaded script is empty"
        rm -f "$temp_script"
        pause
        return 1
    fi
    
    log_success "Download completed"
    
    # Verify signature (optional but recommended)
    if ! verify_script_signature "$temp_script" "$full_url"; then
        read -p "Continue anyway? (y/n): " continue_exec
        if [[ ! "$continue_exec" =~ ^[Yy]$ ]]; then
            rm -f "$temp_script"
            pause
            return 1
        fi
    fi
    
    # Execute script
    echo ""
    log_info "$(t executing)..."
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    chmod +x "$temp_script"
    if bash "$temp_script"; then
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        log_success "$(t completed)"
    else
        local exit_code=$?
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        log_error "Failed with exit code: ${exit_code}"
    fi
    
    rm -f "$temp_script"
    pause
    return 0
}

run_remote_command() {
    local command_to_run="${1}"
    local description="${2:-$(t executing)}"
    
    print_header
    log_info "$description"
    echo ""
    echo -e "${YELLOW}Command:${RESET}"
    echo -e "${WHITE}${command_to_run}${RESET}"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    
    if eval "${command_to_run}"; then
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        log_success "$(t completed)"
    else
        local exit_code=$?
        echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        log_error "Failed with exit code: ${exit_code}"
    fi
    
    pause
}

# ==============================================================================
#                              MENU FUNCTIONS
# ==============================================================================

show_menu() {
    local menu_title="$1"
    local menu_max="$2"
    shift 2
    local menu_items=("$@")
    
    print_header
    echo -e "${PURPLE}${BOLD}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}${BOLD}║  ${menu_title}${RESET}"
    echo -e "${PURPLE}${BOLD}╚════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    
    for item in "${menu_items[@]}"; do
        echo -e "$item"
    done
    
    echo ""
    echo -e "${PURPLE}────────────────────────────────────────────────────────${RESET}"
    echo -e "${CYAN}[0]${RESET} $(t menu_return)"
    echo ""
}

# System Tools Menu
system_tools_menu() {
    while true; do
        if [ "$(get_lang)" = "zh_CN" ]; then
            show_menu "系统工具菜单" 7 \
                "${CYAN}[1]${RESET} 查看系统信息" \
                "${CYAN}[2]${RESET} 安装常用依赖" \
                "${CYAN}[3]${RESET} 更新系统" \
                "${CYAN}[4]${RESET} 清理系统" \
                "${CYAN}[5]${RESET} 系统优化" \
                "${CYAN}[6]${RESET} 修改主机名" \
                "${CYAN}[7]${RESET} 设置时区"
        else
            show_menu "System Tools Menu" 7 \
                "${CYAN}[1]${RESET} System Information" \
                "${CYAN}[2]${RESET} Install Dependencies" \
                "${CYAN}[3]${RESET} Update System" \
                "${CYAN}[4]${RESET} Clean System" \
                "${CYAN}[5]${RESET} Optimize System" \
                "${CYAN}[6]${RESET} Change Hostname" \
                "${CYAN}[7]${RESET} Set Timezone"
        fi
        
        read -p "$(echo -e ${YELLOW}$(t menu_prompt) [0-7]:${RESET} )" choice
        
        if ! validate_input "$choice" 0 7; then
            sleep 1.5
            continue
        fi
        
        case $choice in
            1) run_repo_script "scripts/system_tools/system_info.sh" ;;
            2) run_repo_script "scripts/system_tools/install_deps.sh" ;;
            3) run_repo_script "scripts/system_tools/update_system.sh" ;;
            4) run_repo_script "scripts/system_tools/clean_system.sh" ;;
            5) run_repo_script "scripts/system_tools/optimize_system.sh" ;;
            6) run_repo_script "scripts/system_tools/change_hostname.sh" ;;
            7) run_repo_script "scripts/system_tools/set_timezone.sh" ;;
            0) return 0 ;;
        esac
    done
}

# Settings Menu
settings_menu() {
    while true; do
        if [ "$(get_lang)" = "zh_CN" ]; then
            show_menu "设置菜单" 3 \
                "${CYAN}[1]${RESET} 切换语言 (当前: $(get_lang))" \
                "${CYAN}[2]${RESET} 检查更新" \
                "${CYAN}[3]${RESET} 查看更新日志"
        else
            show_menu "Settings Menu" 3 \
                "${CYAN}[1]${RESET} Switch Language (Current: $(get_lang))" \
                "${CYAN}[2]${RESET} Check for Updates" \
                "${CYAN}[3]${RESET} View Changelog"
        fi
        
        read -p "$(echo -e ${YELLOW}$(t menu_prompt) [0-3]:${RESET} )" choice
        
        if ! validate_input "$choice" 0 3; then
            sleep 1.5
            continue
        fi
        
        case $choice in
            1) select_language ;;
            2) check_for_updates; pause ;;
            3) show_changelog_func; pause ;;
            0) return 0 ;;
        esac
    done
}

# Main Menu
main_menu() {
    while true; do
        print_header
        
        if [ "$(get_lang)" = "zh_CN" ]; then
            echo -e "${YELLOW}${BOLD}请选择要执行的操作类别:${RESET}"
            echo ""
            echo -e " ${CYAN}[1]${RESET} 系统工具       - 系统信息、更新、清理、优化等"
            echo -e " ${CYAN}[2]${RESET} 设置           - 语言、更新检查等"
            echo ""
            echo -e "${PURPLE}────────────────────────────────────────────────────────${RESET}"
            echo -e " ${CYAN}[0]${RESET} 退出脚本"
        else
            echo -e "${YELLOW}${BOLD}Please select an operation category:${RESET}"
            echo ""
            echo -e " ${CYAN}[1]${RESET} System Tools   - Information, Update, Clean, Optimize"
            echo -e " ${CYAN}[2]${RESET} Settings       - Language, Update Check, etc."
            echo ""
            echo -e "${PURPLE}────────────────────────────────────────────────────────${RESET}"
            echo -e " ${CYAN}[0]${RESET} Exit Script"
        fi
        echo ""
        
        read -p "$(echo -e ${YELLOW}$(t menu_prompt) [0-2]:${RESET} )" choice
        
        if ! validate_input "$choice" 0 2; then
            sleep 1.5
            continue
        fi
        
        case $choice in
            1) system_tools_menu ;;
            2) settings_menu ;;
            0)
                echo ""
                log_success "$(t thanks)"
                echo -e "${CYAN}$(t goodbye)${RESET}"
                echo ""
                exit 0
                ;;
        esac
    done
}

# ==============================================================================
#                              MAIN EXECUTION
# ==============================================================================

main() {
    # Initialize log file
    : > "$LOG_FILE"
    log_message "INFO" "VPS Management Script v${SCRIPT_VERSION} starting"
    
    # Check if language is set, if not, prompt user
    if [ ! -f "$LANG_FILE" ]; then
        select_language
    fi
    
    # Acquire lock to prevent concurrent execution
    if ! acquire_lock; then
        exit 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        release_lock
        exit 1
    fi
    
    # Check network (non-blocking)
    check_network
    
    # Check for updates (non-blocking)
    check_for_updates
    
    # Start main menu
    main_menu
}

# Cleanup on exit
cleanup() {
    log_message "INFO" "Script exiting"
    rm -f /tmp/vps_script_*.sh
    release_lock
}

trap cleanup EXIT INT TERM

# Run main function
main
