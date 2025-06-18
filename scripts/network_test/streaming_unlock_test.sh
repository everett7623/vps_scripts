#!/bin/bash

#==============================================================================
# 脚本名称: streaming_unlock_test.sh
# 描述: VPS流媒体解锁测试脚本 - 测试Netflix、Disney+、YouTube等流媒体服务解锁情况
# 作者: Jensfrank
# 路径: vps_scripts/scripts/network_test/streaming_unlock_test.sh
# 使用方法: bash streaming_unlock_test.sh [选项]
# 选项: --basic (基础测试) --full (完整测试) --region (地区检测)
# 更新日期: 2024-06-17
#==============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# 配置变量
LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/streaming_unlock_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/streaming_unlock_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/streaming_test_$$"

# 测试模式
BASIC_MODE=false
FULL_MODE=false
REGION_CHECK=false

# User-Agent
UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
UA_MOBILE="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

# 创建目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
}

# 清理
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# 日志记录
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 获取IP信息
get_ip_location() {
    print_msg "$BLUE" "========== IP地理位置信息 =========="
    
    # 获取公网IP
    local public_ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null)
    
    if [ -z "$public_ip" ]; then
        print_msg "$RED" "无法获取公网IP"
        return 1
    fi
    
    # 获取IP信息
    local ip_info=$(curl -s --max-time 5 "http://ip-api.com/json/${public_ip}?fields=country,countryCode,regionName,city,isp,as" 2>/dev/null)
    
    if [ -n "$ip_info" ]; then
        local country=$(echo "$ip_info" | grep -oP '"country":\s*"\K[^"]+')
        local country_code=$(echo "$ip_info" | grep -oP '"countryCode":\s*"\K[^"]+')
        local region=$(echo "$ip_info" | grep -oP '"regionName":\s*"\K[^"]+')
        local city=$(echo "$ip_info" | grep -oP '"city":\s*"\K[^"]+')
        local isp=$(echo "$ip_info" | grep -oP '"isp":\s*"\K[^"]+')
        
        echo -e "${CYAN}IP地址:${NC} $public_ip"
        echo -e "${CYAN}位置:${NC} $country ($country_code) - $region - $city"
        echo -e "${CYAN}ISP:${NC} $isp"
        echo ""
        
        # 保存信息供后续使用
        echo "$country_code" > "$TEMP_DIR/country_code"
        
        {
            echo "========== IP信息 =========="
            echo "IP: $public_ip"
            echo "位置: $country - $region - $city"
            echo "ISP: $isp"
            echo ""
        } >> "$REPORT_FILE"
    fi
}

# Netflix测试
test_netflix() {
    print_msg "$BLUE" "\n========== Netflix 测试 =========="
    
    local result="不支持"
    local region=""
    local type=""
    
    # 测试是否能访问Netflix
    local response=$(curl -s --max-time 10 -H "User-Agent: $UA_BROWSER" \
                    "https://www.netflix.com/title/81215567" 2>&1)
    
    if echo "$response" | grep -q "Not Available\|不可用"; then
        result="不支持"
        print_msg "$RED" "Netflix: 不支持 ✗"
    elif echo "$response" | grep -q "page-404\|NSEZ-403"; then
        result="不支持"
        print_msg "$RED" "Netflix: 不支持 ✗"
    else
        # 进一步测试区域
        local nf_region=$(curl -s --max-time 10 -H "User-Agent: $UA_BROWSER" \
                         "https://www.netflix.com/" | grep -oP '"geolocation":{"country":"\K[^"]+')
        
        if [ -n "$nf_region" ]; then
            # 测试是否支持自制剧
            local originals_test=$(curl -s --max-time 10 -H "User-Agent: $UA_BROWSER" \
                                  "https://www.netflix.com/title/80018499" 2>&1)
            
            if echo "$originals_test" | grep -q "Not Available\|不可用"; then
                result="仅解锁自制剧"
                type="自制剧"
                print_msg "$YELLOW" "Netflix: 仅解锁自制剧 (地区: $nf_region)"
            else
                result="完全解锁"
                type="完整"
                print_msg "$GREEN" "Netflix: 完全解锁 ✓ (地区: $nf_region)"
            fi
            region=$nf_region
        else
            # 基础解锁测试
            result="部分解锁"
            print_msg "$YELLOW" "Netflix: 部分解锁"
        fi
    fi
    
    # 保存结果
    {
        echo "Netflix:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        [ -n "$type" ] && echo "  类型: $type"
        echo ""
    } >> "$REPORT_FILE"
}

# Disney+测试
test_disney_plus() {
    print_msg "$BLUE" "\n========== Disney+ 测试 =========="
    
    local result="不支持"
    local region=""
    
    # 获取Disney+ token
    local token_response=$(curl -s --max-time 10 \
                          -H "User-Agent: $UA_BROWSER" \
                          -H "Accept-Language: en-US,en;q=0.9" \
                          "https://global.edge.bamgrid.com/token" \
                          -d "grant_type=urn:ietf:params:oauth:grant-type:token-exchange" 2>&1)
    
    if echo "$token_response" | grep -q "accessToken"; then
        # 检查区域
        local region_response=$(curl -s --max-time 10 \
                               -H "User-Agent: $UA_BROWSER" \
                               "https://disney.api.edge.bamgrid.com/v1/public/graphql" \
                               -H "content-type: application/json" \
                               -d '{"query":"query{me{account{activeProfile{maturityRating{ratingSystem}}}}}"}' 2>&1)
        
        if echo "$region_response" | grep -q "ratingSystem"; then
            region=$(echo "$region_response" | grep -oP '"ratingSystem":"\K[^"]+' | head -1)
            result="解锁"
            print_msg "$GREEN" "Disney+: 解锁 ✓ (地区: ${region:-未知})"
        else
            result="部分解锁"
            print_msg "$YELLOW" "Disney+: 部分解锁"
        fi
    else
        result="不支持"
        print_msg "$RED" "Disney+: 不支持 ✗"
    fi
    
    # 保存结果
    {
        echo "Disney+:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        echo ""
    } >> "$REPORT_FILE"
}

# YouTube Premium测试
test_youtube() {
    print_msg "$BLUE" "\n========== YouTube Premium 测试 =========="
    
    local result="不支持"
    local region=""
    
    # 测试YouTube地区
    local yt_response=$(curl -s --max-time 10 \
                       -H "User-Agent: $UA_BROWSER" \
                       -H "Accept-Language: en-US,en;q=0.9" \
                       "https://www.youtube.com/premium" 2>&1)
    
    if echo "$yt_response" | grep -q "www.google.cn"; then
        result="不支持(中国大陆)"
        print_msg "$RED" "YouTube Premium: 不支持 (中国大陆) ✗"
    else
        # 获取实际地区
        local yt_region=$(echo "$yt_response" | grep -oP '"GL":"\K[^"]+' | head -1)
        
        if [ -n "$yt_region" ]; then
            # 检查是否支持Premium
            if echo "$yt_response" | grep -q "premium_membership"; then
                result="支持"
                region=$yt_region
                print_msg "$GREEN" "YouTube Premium: 支持 ✓ (地区: $yt_region)"
            else
                result="YouTube可用但不支持Premium"
                region=$yt_region
                print_msg "$YELLOW" "YouTube Premium: 不支持Premium (地区: $yt_region)"
            fi
        else
            result="未知"
            print_msg "$YELLOW" "YouTube Premium: 状态未知"
        fi
    fi
    
    # 保存结果
    {
        echo "YouTube Premium:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        echo ""
    } >> "$REPORT_FILE"
}

# Amazon Prime Video测试
test_prime_video() {
    print_msg "$BLUE" "\n========== Amazon Prime Video 测试 =========="
    
    local result="不支持"
    local region=""
    
    # 测试Prime Video
    local pv_response=$(curl -s --max-time 10 \
                       -H "User-Agent: $UA_BROWSER" \
                       "https://www.primevideo.com" 2>&1)
    
    if echo "$pv_response" | grep -q "currentTerritory"; then
        region=$(echo "$pv_response" | grep -oP '"currentTerritory":"\K[^"]+' | head -1)
        
        if [ -n "$region" ]; then
            result="解锁"
            print_msg "$GREEN" "Prime Video: 解锁 ✓ (地区: $region)"
        else
            result="部分解锁"
            print_msg "$YELLOW" "Prime Video: 部分解锁"
        fi
    else
        result="不支持"
        print_msg "$RED" "Prime Video: 不支持 ✗"
    fi
    
    # 保存结果
    {
        echo "Amazon Prime Video:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        echo ""
    } >> "$REPORT_FILE"
}

# HBO Max测试
test_hbo_max() {
    print_msg "$BLUE" "\n========== HBO Max 测试 =========="
    
    local result="不支持"
    local region=""
    
    # 测试HBO Max
    local hbo_response=$(curl -s --max-time 10 \
                        -H "User-Agent: $UA_BROWSER" \
                        "https://www.hbomax.com/" 2>&1)
    
    if echo "$hbo_response" | grep -qE "geo-availability|territorio|country"; then
        # 尝试获取地区信息
        local api_response=$(curl -s --max-time 10 \
                            "https://api-global.hbomax.com/v1/geo" 2>&1)
        
        if echo "$api_response" | grep -q "country"; then
            region=$(echo "$api_response" | grep -oP '"country":"\K[^"]+' | head -1)
            result="解锁"
            print_msg "$GREEN" "HBO Max: 解锁 ✓ (地区: ${region:-未知})"
        else
            result="部分解锁"
            print_msg "$YELLOW" "HBO Max: 部分解锁"
        fi
    else
        result="不支持"
        print_msg "$RED" "HBO Max: 不支持 ✗"
    fi
    
    # 保存结果
    {
        echo "HBO Max:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        echo ""
    } >> "$REPORT_FILE"
}

# Spotify测试
test_spotify() {
    print_msg "$BLUE" "\n========== Spotify 测试 =========="
    
    local result="不支持"
    local region=""
    
    # 测试Spotify
    local spotify_response=$(curl -s --max-time 10 \
                            -H "User-Agent: $UA_BROWSER" \
                            "https://accounts.spotify.com/en/login" 2>&1)
    
    if echo "$spotify_response" | grep -q "errorInvalidCountry"; then
        result="不支持"
        print_msg "$RED" "Spotify: 不支持 ✗"
    else
        # 获取地区
        local api_response=$(curl -s --max-time 10 \
                            "https://spclient.wg.spotify.com/signup/public/v1/account" \
                            -d "birth_day=1&birth_month=1&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https://www.spotify.com/&displayname=test&email=test@test.com&gender=neutral&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&password=test1234&password_repeat=test1234&platform=www&referrer=&send-email=0&thirdpartyemail=0&fb=0" 2>&1)
        
        if echo "$api_response" | grep -q "country"; then
            region=$(echo "$api_response" | grep -oP '"country":"\K[^"]+' | head -1)
            result="解锁"
            print_msg "$GREEN" "Spotify: 解锁 ✓ (地区: ${region:-未知})"
        elif echo "$api_response" | grep -q "geo_blocking"; then
            result="受限"
            print_msg "$YELLOW" "Spotify: 受地理限制"
        else
            result="可能支持"
            print_msg "$YELLOW" "Spotify: 可能支持"
        fi
    fi
    
    # 保存结果
    {
        echo "Spotify:"
        echo "  状态: $result"
        [ -n "$region" ] && echo "  地区: $region"
        echo ""
    } >> "$REPORT_FILE"
}

# BBC iPlayer测试
test_bbc_iplayer() {
    print_msg "$BLUE" "\n========== BBC iPlayer 测试 =========="
    
    local result="不支持"
    
    # 测试BBC iPlayer
    local bbc_response=$(curl -s --max-time 10 \
                        -H "User-Agent: $UA_BROWSER" \
                        "https://www.bbc.co.uk/iplayer" 2>&1)
    
    if echo "$bbc_response" | grep -q "available in the UK"; then
        result="不支持(仅限英国)"
        print_msg "$RED" "BBC iPlayer: 不支持 (仅限英国) ✗"
    elif echo "$bbc_response" | grep -q "bbcAccount"; then
        result="解锁"
        print_msg "$GREEN" "BBC iPlayer: 解锁 ✓ (英国)"
    else
        result="未知"
        print_msg "$YELLOW" "BBC iPlayer: 状态未知"
    fi
    
    # 保存结果
    {
        echo "BBC iPlayer:"
        echo "  状态: $result"
        echo ""
    } >> "$REPORT_FILE"
}

# 亚洲流媒体测试
test_asian_streaming() {
    print_msg "$BLUE" "\n========== 亚洲流媒体 测试 =========="
    
    # Bilibili测试
    echo -e "${CYAN}测试 Bilibili...${NC}"
    local bili_response=$(curl -s --max-time 10 \
                         -H "User-Agent: $UA_BROWSER" \
                         "https://api.bilibili.com/x/web-interface/zone" 2>&1)
    
    if echo "$bili_response" | grep -q "country_code"; then
        local bili_region=$(echo "$bili_response" | grep -oP '"country_code":"\K[^"]+')
        if [ "$bili_region" = "86" ]; then
            echo -e "${GREEN}  Bilibili: 中国大陆解锁 ✓${NC}"
            echo "Bilibili: 中国大陆解锁" >> "$REPORT_FILE"
        else
            echo -e "${YELLOW}  Bilibili: 港澳台解锁${NC}"
            echo "Bilibili: 港澳台解锁" >> "$REPORT_FILE"
        fi
    else
        echo -e "${RED}  Bilibili: 不支持 ✗${NC}"
        echo "Bilibili: 不支持" >> "$REPORT_FILE"
    fi
    
    # 爱奇艺测试
    echo -e "${CYAN}测试 爱奇艺...${NC}"
    local iqiyi_response=$(curl -s --max-time 10 \
                          -H "User-Agent: $UA_BROWSER" \
                          "https://www.iqiyi.com/" 2>&1)
    
    if echo "$iqiyi_response" | grep -q "territory"; then
        echo -e "${GREEN}  爱奇艺: 解锁 ✓${NC}"
        echo "爱奇艺: 解锁" >> "$REPORT_FILE"
    else
        echo -e "${RED}  爱奇艺: 不支持 ✗${NC}"
        echo "爱奇艺: 不支持" >> "$REPORT_FILE"
    fi
    
    # 腾讯视频测试
    echo -e "${CYAN}测试 腾讯视频...${NC}"
    local qq_response=$(curl -s --max-time 10 \
                       -H "User-Agent: $UA_BROWSER" \
                       "https://v.qq.com/" 2>&1)
    
    if ! echo "$qq_response" | grep -q "地区限制\|geo_block"; then
        echo -e "${GREEN}  腾讯视频: 解锁 ✓${NC}"
        echo "腾讯视频: 解锁" >> "$REPORT_FILE"
    else
        echo -e "${RED}  腾讯视频: 不支持 ✗${NC}"
        echo "腾讯视频: 不支持" >> "$REPORT_FILE"
    fi
}

# 游戏平台测试
test_gaming_platforms() {
    print_msg "$BLUE" "\n========== 游戏平台 测试 =========="
    
    # Steam测试
    echo -e "${CYAN}测试 Steam...${NC}"
    local steam_response=$(curl -s --max-time 10 \
                          -H "User-Agent: $UA_BROWSER" \
                          "https://store.steampowered.com/api/v1/country" 2>&1)
    
    if echo "$steam_response" | grep -q "country_code"; then
        local steam_region=$(echo "$steam_response" | grep -oP '"country_code":"\K[^"]+')
        echo -e "${GREEN}  Steam: 可用 ✓ (地区: $steam_region)${NC}"
        echo "Steam: 可用 (地区: $steam_region)" >> "$REPORT_FILE"
    else
        echo -e "${RED}  Steam: 受限 ✗${NC}"
        echo "Steam: 受限" >> "$REPORT_FILE"
    fi
}

# 生成测试总结
generate_summary() {
    print_msg "$BLUE" "\n========== 流媒体解锁总结 =========="
    
    # 统计解锁数量
    local total_services=0
    local unlocked_services=0
    local partial_services=0
    local blocked_services=0
    
    # 读取报告统计
    while IFS= read -r line; do
        if echo "$line" | grep -qE "(Netflix|Disney\+|YouTube|Prime Video|HBO Max|Spotify|BBC iPlayer|Bilibili|爱奇艺|腾讯视频|Steam):"; then
            ((total_services++))
            
            if echo "$line" | grep -qE "(解锁|支持|可用)"; then
                ((unlocked_services++))
            elif echo "$line" | grep -qE "(部分|仅限|受限)"; then
                ((partial_services++))
            else
                ((blocked_services++))
            fi
        fi
    done < "$REPORT_FILE"
    
    echo -e "${CYAN}测试统计:${NC}"
    echo -e "  测试服务总数: $total_services"
    echo -e "  ${GREEN}完全解锁: $unlocked_services${NC}"
    echo -e "  ${YELLOW}部分解锁: $partial_services${NC}"
    echo -e "  ${RED}不支持: $blocked_services${NC}"
    
    # 地区推荐
    echo -e "\n${CYAN}推荐用途:${NC}"
    
    local unlock_rate=$((unlocked_services * 100 / total_services))
    
    if [ $unlock_rate -ge 80 ]; then
        echo -e "${GREEN}  ✓ 非常适合作为流媒体服务器${NC}"
        echo -e "${GREEN}  ✓ 支持大部分主流流媒体平台${NC}"
    elif [ $unlock_rate -ge 50 ]; then
        echo -e "${YELLOW}  ⚡ 适合部分流媒体服务${NC}"
        echo -e "${YELLOW}  ⚡ 可能需要配合其他工具使用${NC}"
    else
        echo -e "${RED}  ✗ 不适合作为流媒体服务器${NC}"
        echo -e "${RED}  ✗ 大部分服务受地理限制${NC}"
    fi
    
    # 保存总结
    {
        echo ""
        echo "========== 测试总结 =========="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试服务: $total_services"
        echo "完全解锁: $unlocked_services"
        echo "部分解锁: $partial_services"
        echo "不支持: $blocked_services"
        echo "解锁率: ${unlock_rate}%"
    } >> "$REPORT_FILE"
}

# 生成详细报告
generate_detailed_report() {
    print_msg "$BLUE" "\n生成详细报告..."
    
    local report_file="$REPORT_DIR/streaming_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "       流媒体解锁测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试主机: $(hostname)"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "说明:"
        echo "1. 测试结果仅供参考，实际可用性可能因时间和地区而异"
        echo "2. 部分服务可能需要有效账户才能完全测试"
        echo "3. 解锁不代表可以观看所有内容，部分内容可能有额外限制"
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$report_file"
    
    print_msg "$GREEN" "\n详细报告已保存到: $report_file"
}

# 基础测试
basic_test() {
    get_ip_location
    test_netflix
    test_youtube
    test_disney_plus
    test_spotify
}

# 完整测试
full_test() {
    get_ip_location
    test_netflix
    test_disney_plus
    test_youtube
    test_prime_video
    test_hbo_max
    test_spotify
    test_bbc_iplayer
    test_asian_streaming
    test_gaming_platforms
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                       VPS 流媒体解锁测试工具 v1.0                          ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示当前IP位置
    local ip=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null)
    echo -e "${CYAN}当前IP: $ip${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 基础测试 (Netflix/YouTube/Disney+/Spotify)"
    echo -e "${GREEN}2)${NC} 标准测试 (主流欧美流媒体)"
    echo -e "${GREEN}3)${NC} 完整测试 (所有流媒体平台)"
    echo -e "${GREEN}4)${NC} 亚洲流媒体测试"
    echo -e "${GREEN}5)${NC} 单项测试"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-5]: " choice
    
    case $choice in
        1)
            BASIC_MODE=true
            basic_test
            generate_summary
            generate_detailed_report
            ;;
        2)
            get_ip_location
            test_netflix
            test_disney_plus
            test_youtube
            test_prime_video
            test_hbo_max
            test_spotify
            generate_summary
            generate_detailed_report
            ;;
        3)
            FULL_MODE=true
            full_test
            generate_summary
            generate_detailed_report
            ;;
        4)
            get_ip_location
            test_asian_streaming
            ;;
        5)
            single_service_menu
            ;;
        0)
            print_msg "$YELLOW" "退出程序"
            exit 0
            ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            interactive_menu
            ;;
    esac
}

# 单项测试菜单
single_service_menu() {
    clear
    echo -e "${CYAN}选择要测试的流媒体服务:${NC}"
    echo -e "${GREEN}1)${NC} Netflix"
    echo -e "${GREEN}2)${NC} Disney+"
    echo -e "${GREEN}3)${NC} YouTube Premium"
    echo -e "${GREEN}4)${NC} Amazon Prime Video"
    echo -e "${GREEN}5)${NC} HBO Max"
    echo -e "${GREEN}6)${NC} Spotify"
    echo -e "${GREEN}7)${NC} BBC iPlayer"
    echo -e "${GREEN}8)${NC} Bilibili"
    echo -e "${GREEN}0)${NC} 返回主菜单"
    echo ""
    
    read -p "请输入选项 [0-8]: " service_choice
    
    case $service_choice in
        1) test_netflix ;;
        2) test_disney_plus ;;
        3) test_youtube ;;
        4) test_prime_video ;;
        5) test_hbo_max ;;
        6) test_spotify ;;
        7) test_bbc_iplayer ;;
        8) test_asian_streaming ;;
        0) interactive_menu ;;
        *)
            print_msg "$RED" "无效选项"
            sleep 2
            single_service_menu
            ;;
    esac
}

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --basic     基础测试模式
  --full      完整测试模式
  --region    包含地区检测
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --basic      # 运行基础测试
  $0 --full       # 运行完整测试

测试服务:
  欧美流媒体:
    - Netflix
    - Disney+
    - YouTube Premium
    - Amazon Prime Video
    - HBO Max
    - Spotify
    - BBC iPlayer
    
  亚洲流媒体:
    - Bilibili
    - 爱奇艺
    - 腾讯视频
    
  游戏平台:
    - Steam

注意:
  - 测试需要网络连接
  - 结果可能因时间和地区而异
  - 仅测试解锁状态，不测试播放质量
EOF
}

# 解析参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --basic)
                BASIC_MODE=true
                shift
                ;;
            --full)
                FULL_MODE=true
                shift
                ;;
            --region)
                REGION_CHECK=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_msg "$RED" "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 初始化
    create_directories
    
    # 解析参数
    parse_arguments "$@"
    
    # 开始测试
    log "开始流媒体解锁测试"
    
    {
        echo "========== 流媒体解锁测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$BASIC_MODE" = true ]; then
        basic_test
        generate_summary
        generate_detailed_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        generate_summary
        generate_detailed_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n流媒体解锁测试完成！"
}

# 运行主函数
main "$@"
