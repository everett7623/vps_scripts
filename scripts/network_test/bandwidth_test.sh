#!/bin/bash
# ==============================================================================
# 脚本名称: bandwidth_test_overseas.sh
# 描述: 海外 VPS 专用带宽性能测试工具 (v2.0.0)
#       【核心优化】
#       1. 自动检测 VPS 地理位置，智能切换测试策略
#       2. 针对海外 VPS 使用全球高可用节点（避开中国三网被墙问题）
#       3. 增加回国路由质量测试（香港/日本/新加坡中转）
#       4. 支持 iperf3 和 Speedtest 双模式
#       5. 优化 CDN 节点选择，使用全球分布式测试点
# 作者: AI Optimized for Overseas VPS
# 更新日期: 2026-01-21
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. 环境初始化
# ------------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT_DIR")")"

LOG_DIR="/var/log/vps_scripts"
LOG_FILE="$LOG_DIR/bandwidth_test.log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/bandwidth_report_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/bandwidth_test_$$"

# 颜色定义
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

print_info() { echo -e "${CYAN}[信息] $1${NC}"; }
print_success() { echo -e "${GREEN}[成功] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[警告] $1${NC}"; }
print_error() { echo -e "${RED}[错误] $1${NC}"; }
print_header() { echo -e "\n${PURPLE}=== $1 ===${NC}\n"; }

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$TEMP_DIR"
trap 'rm -rf "$TEMP_DIR"' EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

# ------------------------------------------------------------------------------
# 2. 地理位置检测
# ------------------------------------------------------------------------------

detect_vps_location() {
    print_header "检测 VPS 地理位置"
    
    # 方法1: 测试到中国 DNS 的连通性
    local cn_dns="114.114.114.114"
    local ping_cn=$(ping -c 2 -W 2 "$cn_dns" 2>/dev/null | grep "time=" | wc -l)
    
    # 方法2: 获取公网 IP 地理信息
    local public_ip=$(curl -s4m5 ifconfig.me 2>/dev/null || echo "未知")
    local geo_info=$(curl -s "http://ip-api.com/json/$public_ip?fields=country,regionName,city,isp" 2>/dev/null)
    
    local country=$(echo "$geo_info" | grep -oP '"country":"\K[^"]+' || echo "Unknown")
    local region=$(echo "$geo_info" | grep -oP '"regionName":"\K[^"]+' || echo "Unknown")
    local city=$(echo "$geo_info" | grep -oP '"city":"\K[^"]+' || echo "Unknown")
    local isp=$(echo "$geo_info" | grep -oP '"isp":"\K[^"]+' || echo "Unknown")
    
    echo -e "  公网IP: ${CYAN}$public_ip${NC}"
    echo -e "  位置: ${GREEN}$country / $region / $city${NC}"
    echo -e "  ISP: ${BLUE}$isp${NC}"
    
    # 判断是否在中国大陆
    if [ "$ping_cn" -ge 1 ] && [[ "$country" =~ (China|中国) ]]; then
        print_success "检测到 VPS 位于中国大陆，使用国内测试模式"
        export VPS_LOCATION="CN"
        export TEST_MODE="domestic"
    else
        print_warn "检测到 VPS 位于海外，使用国际测试模式"
        export VPS_LOCATION="OVERSEAS"
        export TEST_MODE="international"
    fi
    
    log "VPS Location: $country/$city, Mode: $TEST_MODE"
    sleep 2
}

# ------------------------------------------------------------------------------
# 3. Speedtest 节点配置（按地理位置分类）
# ------------------------------------------------------------------------------

declare -A SPEEDTEST_SERVERS

init_speedtest_servers() {
    if [ "$TEST_MODE" = "domestic" ]; then
        # 国内模式：使用中国三网节点
        SPEEDTEST_SERVERS=(
            [ct_js]="5396|江苏电信(苏州)"
            [ct_sh]="24012|上海电信"
            [cu_sh]="24447|上海联通"
            [cu_hn]="4870|湖南联通"
            [cm_js]="27249|江苏移动"
            [cm_bj]="25858|北京移动"
        )
    else
        # 海外模式：使用全球高可用节点
        SPEEDTEST_SERVERS=(
            # 亚太区域（回国路由测试）
            [hk_hgc]="32155|香港 HGC"
            [hk_hkt]="13538|香港 HKT"
            [tw_cht]="3417|台湾中华电信"
            [jp_tokyo]="48463|日本东京 IPA"
            [jp_osaka]="48516|日本大阪 GLBB"
            [sg_singtel]="18458|新加坡 Singtel"
            [sg_myrepublic]="7292|新加坡 MyRepublic"
            [kr_seoul]="6527|韩国首尔 KISTI"
            
            # 北美区域
            [us_la_wave]="18531|美国洛杉矶 Wave"
            [us_sj_gsl]="35055|美国圣何塞 GSL"
            [us_seattle]="16625|美国西雅图 Ziply"
            [us_dallas]="12190|美国达拉斯 Windstream"
            [us_nyc]="21541|美国纽约 Verizon"
            [ca_toronto]="17394|加拿大多伦多 Bell"
            
            # 欧洲区域
            [uk_london]="51838|英国伦敦 Community Fibre"
            [de_frankfurt]="31622|德国法兰克福 23M"
            [fr_paris]="24215|法国巴黎 Bouygues"
            [nl_amsterdam]="12372|荷兰阿姆斯特丹 KPN"
            
            # 其他区域
            [au_sydney]="2225|澳洲悉尼 Telstra"
            [ru_moscow]="11603|俄罗斯莫斯科 MTS"
        )
    fi
}

# ------------------------------------------------------------------------------
# 4. 工具安装
# ------------------------------------------------------------------------------

install_speedtest() {
    if command -v speedtest &>/dev/null; then 
        log "Speedtest CLI already installed"
        return 0
    fi
    
    print_info "正在安装 Speedtest CLI..."
    
    if command -v apt-get &>/dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash &>> "$LOG_FILE"
        apt-get install -y speedtest &>> "$LOG_FILE"
    elif command -v yum &>/dev/null; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash &>> "$LOG_FILE"
        yum install -y speedtest &>> "$LOG_FILE"
    else
        # 二进制安装
        local arch=$(uname -m)
        [[ "$arch" = "x86_64" ]] && arch="x86_64" || arch="aarch64"
        wget -qO "$TEMP_DIR/speedtest.tgz" "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${arch}.tgz"
        tar -xzf "$TEMP_DIR/speedtest.tgz" -C "$TEMP_DIR"
        mv "$TEMP_DIR/speedtest" /usr/local/bin/
        chmod +x /usr/local/bin/speedtest
    fi
    
    speedtest --accept-license --accept-gdpr &>> "$LOG_FILE"
    print_success "Speedtest CLI 安装完成"
}

install_iperf3() {
    if command -v iperf3 &>/dev/null; then return 0; fi
    
    print_info "正在安装 iperf3..."
    if command -v apt-get &>/dev/null; then
        apt-get install -y iperf3 &>> "$LOG_FILE"
    elif command -v yum &>/dev/null; then
        yum install -y iperf3 &>> "$LOG_FILE"
    else
        print_warn "无法自动安装 iperf3，请手动安装"
        return 1
    fi
    print_success "iperf3 安装完成"
}

# ------------------------------------------------------------------------------
# 5. 核心测试函数
# ------------------------------------------------------------------------------

run_speedtest_single() {
    local server_id=$1
    local server_name=$2
    
    echo -ne "  测试: ${CYAN}$server_name${NC} (ID:$server_id) ... "
    
    local result=$(timeout 30 speedtest --server-id="$server_id" --format=json 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        local dl=$(echo "$result" | grep -oP '"download":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ul=$(echo "$result" | grep -oP '"upload":{"bandwidth":\K[0-9]+' | awk '{printf "%.2f", $1 * 8 / 1000000}')
        local ping=$(echo "$result" | grep -oP '"latency":\K[0-9.]+' | head -1)
        
        if [ -n "$ping" ]; then
            echo -ne "\r"
            printf "  %-30s | 延迟: ${CYAN}%-7s${NC} | ↓ ${GREEN}%-10s${NC} | ↑ ${BLUE}%-10s${NC}\n" \
                "${server_name:0:30}" "${ping}ms" "${dl} Mbps" "${ul} Mbps"
            echo "$server_name | Ping: ${ping}ms | Download: ${dl} Mbps | Upload: ${ul} Mbps" >> "$REPORT_FILE"
            return 0
        fi
    fi
    
    echo -e "\r  ${RED}[超时]${NC} $server_name - 节点不可达或网络限制"
    log "Speedtest timeout: $server_name (ID:$server_id)"
    return 1
}

test_speedtest_batch() {
    print_header "Speedtest 全球节点测速"
    install_speedtest
    init_speedtest_servers
    
    local success=0
    local total=0
    
    for key in "${!SPEEDTEST_SERVERS[@]}"; do
        IFS='|' read -r id name <<< "${SPEEDTEST_SERVERS[$key]}"
        ((total++))
        if run_speedtest_single "$id" "$name"; then
            ((success++))
        fi
    done
    
    echo ""
    print_info "测试完成: ${GREEN}${success}${NC}/${total} 节点成功"
}

# ------------------------------------------------------------------------------
# 6. iperf3 测试（备用方案）
# ------------------------------------------------------------------------------

test_iperf3_batch() {
    print_header "iperf3 带宽测试（公共服务器）"
    
    if ! install_iperf3; then
        print_error "iperf3 未安装，跳过此测试"
        return 1
    fi
    
    # 公共 iperf3 服务器列表
    declare -A IPERF_SERVERS=(
        [fr_online]="ping.online.net:5200:法国 Online.net"
        [us_he]="iperf.he.net:5201:美国 HE.net"
        [fr_bouygues]="bouygues.iperf.fr:5206:法国 Bouygues"
        [de_informatik]="iperf.informatik.hs-augsburg.de:5201:德国 HS Augsburg"
    )
    
    for key in "${!IPERF_SERVERS[@]}"; do
        IFS=':' read -r host port name <<< "${IPERF_SERVERS[$key]}"
        echo -ne "  测试: ${CYAN}$name${NC} ... "
        
        local result=$(timeout 15 iperf3 -c "$host" -p "$port" -t 5 -J 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$result" ]; then
            local bps=$(echo "$result" | grep -oP '"bits_per_second":\K[0-9.]+' | tail -1)
            if [ -n "$bps" ]; then
                local mbps=$(echo "scale=2; $bps / 1000000" | bc)
                echo -e "${GREEN}${mbps} Mbps${NC}"
                echo "$name: ${mbps} Mbps" >> "$REPORT_FILE"
                continue
            fi
        fi
        
        echo -e "${RED}超时${NC}"
    done
}

# ------------------------------------------------------------------------------
# 7. CDN 节点测速（全球分布）
# ------------------------------------------------------------------------------

test_cdn_global() {
    print_header "全球 CDN 节点下载测速"
    
    declare -A CDN_NODES=(
        # Cloudflare (全球)
        [cf_global]="https://speed.cloudflare.com/__down?bytes=25000000:Cloudflare 全球"
        
        # AWS 各区域
        [aws_us_east]="http://s3.us-east-1.amazonaws.com/speedtest.us-east-1/10MB.bin:AWS 美东"
        [aws_us_west]="http://s3-us-west-1.amazonaws.com/speedtest/10MB.zip:AWS 美西"
        [aws_eu_west]="http://s3.eu-west-1.amazonaws.com/speedtest.eu-west-1/10MB.bin:AWS 欧洲"
        [aws_ap_se]="http://s3-ap-southeast-1.amazonaws.com/speedtest/10MB.zip:AWS 新加坡"
        [aws_ap_ne]="http://s3-ap-northeast-1.amazonaws.com/speedtest/10MB.zip:AWS 日本"
        
        # 其他 CDN
        [linode_sg]="http://speedtest.singapore.linode.com/100MB-singapore.bin:Linode 新加坡"
        [linode_jp]="http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin:Linode 东京"
        [do_sf]="http://speedtest-sfo3.digitalocean.com/100mb.test:DigitalOcean 旧金山"
        [do_nyc]="http://speedtest-nyc3.digitalocean.com/100mb.test:DigitalOcean 纽约"
        [vultr_tokyo]="http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin:Vultr 东京"
    )
    
    for key in "${!CDN_NODES[@]}"; do
        IFS=':' read -r url name <<< "${CDN_NODES[$key]}"
        echo -ne "  ${CYAN}$name${NC} ... "
        
        local temp_file="$TEMP_DIR/cdn_test"
        local speed=$(timeout 20 wget -O "$temp_file" --no-check-certificate "$url" 2>&1 | \
                     grep -o "[0-9.]\+ [KMG]B/s" | tail -1)
        rm -f "$temp_file"
        
        if [ -n "$speed" ]; then
            # 转换为 Mbps
            if [[ "$speed" =~ MB/s ]]; then
                local val=$(echo "$speed" | awk '{print $1}')
                local mbps=$(echo "$val * 8" | bc)
                echo -e "${GREEN}${mbps} Mbps${NC}"
                echo "$name: ${mbps} Mbps" >> "$REPORT_FILE"
            elif [[ "$speed" =~ KB/s ]]; then
                local val=$(echo "$speed" | awk '{print $1}')
                local mbps=$(echo "scale=2; $val * 8 / 1024" | bc)
                echo -e "${YELLOW}${mbps} Mbps${NC}"
            else
                echo -e "${YELLOW}${speed}${NC}"
            fi
        else
            echo -e "${RED}超时${NC}"
        fi
    done
}

# ------------------------------------------------------------------------------
# 8. 回国路由质量测试（海外VPS专用）
# ------------------------------------------------------------------------------

test_china_route_quality() {
    if [ "$TEST_MODE" != "international" ]; then
        return 0
    fi
    
    print_header "回国路由质量测试（延迟 + 丢包）"
    
    declare -A CN_TEST_IPS=(
        [ct_sh]="202.101.172.35:上海电信 DNS"
        [cu_bj]="123.123.123.123:北京联通 DNS"
        [cm_gd]="120.196.165.24:广东移动 DNS"
        [ali_hk]="47.52.0.1:阿里云香港"
        [tencent_hk]="119.28.0.1:腾讯云香港"
    )
    
    for key in "${!CN_TEST_IPS[@]}"; do
        IFS=':' read -r ip name <<< "${CN_TEST_IPS[$key]}"
        echo -ne "  测试: ${CYAN}$name${NC} ... "
        
        local result=$(ping -c 10 -W 2 "$ip" 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            local avg=$(echo "$result" | grep "rtt min/avg/max" | awk -F'/' '{print $5}')
            local loss=$(echo "$result" | grep "packet loss" | grep -oP '[0-9]+(?=% packet loss)')
            
            if [ -n "$avg" ]; then
                if [ "$loss" -eq 0 ]; then
                    echo -e "延迟: ${GREEN}${avg}ms${NC} | 丢包: ${GREEN}0%${NC}"
                elif [ "$loss" -lt 5 ]; then
                    echo -e "延迟: ${YELLOW}${avg}ms${NC} | 丢包: ${YELLOW}${loss}%${NC}"
                else
                    echo -e "延迟: ${RED}${avg}ms${NC} | 丢包: ${RED}${loss}%${NC}"
                fi
                echo "$name | Latency: ${avg}ms | Loss: ${loss}%" >> "$REPORT_FILE"
                continue
            fi
        fi
        
        echo -e "${RED}不可达${NC}"
    done
}

# ------------------------------------------------------------------------------
# 9. 综合报告生成
# ------------------------------------------------------------------------------

generate_summary() {
    print_header "测试报告总结"
    
    echo -e "${CYAN}报告路径:${NC} $REPORT_FILE"
    echo ""
    
    if [ -f "$REPORT_FILE" ]; then
        local total_lines=$(wc -l < "$REPORT_FILE")
        local success_lines=$(grep -c "Mbps\|ms" "$REPORT_FILE" || echo 0)
        
        echo -e "  测试项数: ${CYAN}$total_lines${NC}"
        echo -e "  成功项数: ${GREEN}$success_lines${NC}"
        echo -e "  成功率: $(awk "BEGIN {printf \"%.1f%%\", $success_lines/$total_lines*100}")"
        echo ""
        
        # 显示最快/最慢节点
        print_info "性能排名 (Top 3 最快节点):"
        grep "Download:" "$REPORT_FILE" | \
            awk -F'|' '{gsub(/Download: | Mbps/, "", $3); print $1, $3}' | \
            sort -k2 -nr | head -3 | \
            awk '{printf "  %d. %-30s %s Mbps\n", NR, $1, $2}'
    fi
    
    echo ""
    print_success "所有测试已完成！"
}

# ------------------------------------------------------------------------------
# 10. 交互菜单
# ------------------------------------------------------------------------------

show_menu() {
    clear
    print_header "VPS 全球带宽测试工具 (海外优化版 v2.0)"
    
    echo -e "${CYAN}当前模式: ${GREEN}$TEST_MODE${NC}"
    echo -e "${CYAN}VPS 位置: ${GREEN}${VPS_LOCATION:-检测中...}${NC}"
    echo ""
    echo -e "请选择测试类型:"
    echo -e " ${GREEN}1.${NC} 快速测试 (Speedtest 自动节点 + Cloudflare CDN)"
    echo -e " ${GREEN}2.${NC} 标准测试 (Speedtest 核心节点 + CDN + 回国路由)"
    echo -e " ${GREEN}3.${NC} 完整测试 (Speedtest 全节点 + iperf3 + CDN)"
    echo -e " ${GREEN}4.${NC} 仅 Speedtest 测试"
    echo -e " ${GREEN}5.${NC} 仅 CDN 下载测速"
    echo -e " ${GREEN}6.${NC} 仅 iperf3 测试"
    echo -e " ${GREEN}7.${NC} 回国路由质量测试 (海外VPS专用)"
    echo -e " ${GREEN}0.${NC} 退出"
    echo ""
    read -p "请输入选项 [0-7]: " choice
    
    echo "" > "$REPORT_FILE"
    echo "===== VPS 带宽测试报告 =====" >> "$REPORT_FILE"
    echo "测试时间: $(date)" >> "$REPORT_FILE"
    echo "测试模式: $TEST_MODE" >> "$REPORT_FILE"
    echo "============================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    case $choice in
        1)
            install_speedtest
            speedtest --format=json 2>/dev/null | grep -oP '"download":{"bandwidth":\K[0-9]+' | \
                awk '{printf "自动最优节点: %.2f Mbps\n", $1*8/1000000}'
            test_cdn_global
            ;;
        2)
            test_speedtest_batch
            test_cdn_global
            test_china_route_quality
            ;;
        3)
            test_speedtest_batch
            test_iperf3_batch
            test_cdn_global
            test_china_route_quality
            ;;
        4) test_speedtest_batch ;;
        5) test_cdn_global ;;
        6) test_iperf3_batch ;;
        7) test_china_route_quality ;;
        0) exit 0 ;;
        *) 
            print_error "无效选项"
            sleep 2
            show_menu
            return
            ;;
    esac
    
    generate_summary
    echo ""
    read -n 1 -s -r -p "按任意键返回菜单..."
    show_menu
}

# ------------------------------------------------------------------------------
# 11. 主函数
# ------------------------------------------------------------------------------

main() {
    # 检查依赖
    for cmd in curl wget bc grep awk; do
        if ! command -v "$cmd" &>/dev/null; then
            print_error "缺少依赖: $cmd"
            exit 1
        fi
    done
    
    # 检测地理位置
    detect_vps_location
    
    # 命令行参数支持
    if [ -n "$1" ]; then
        case "$1" in
            --quick)
                install_speedtest
                speedtest
                exit 0
                ;;
            --full)
                test_speedtest_batch
                test_iperf3_batch
                test_cdn_global
                test_china_route_quality
                generate_summary
                exit 0
                ;;
            --help|-h)
                echo "用法: bash $0 [选项]"
                echo "选项:"
                echo "  --quick    快速测试"
                echo "  --full     完整测试"
                echo "  --help     显示帮助"
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                exit 1
                ;;
        esac
    else
        show_menu
    fi
}

main "$@"
