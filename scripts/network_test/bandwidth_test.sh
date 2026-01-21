#!/bin/bash

#==============================================================================
# 脚本名称: bandwidth_test.sh
# 描述: VPS带宽测试脚本 - 测试上传下载速度、多线程速度、全球节点速度
# 作者: Jensfrank
# 路径: vps_scripts/scripts/network_test/bandwidth_test.sh
# 使用方法: bash bandwidth_test.sh [选项]
# 选项: --simple (简单测试) --full (完整测试) --share (生成分享链接)
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
LOG_FILE="$LOG_DIR/bandwidth_test_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/bandwidth_test_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/bandwidth_test_$$"

# 测试模式
SIMPLE_MODE=false
FULL_MODE=false
SHARE_RESULT=false
TEST_DURATION=10  # 默认测试时长(秒)

# Speedtest服务器列表
declare -A SPEEDTEST_SERVERS
SPEEDTEST_SERVERS[cn_telecom_sh]="3633:上海电信"
SPEEDTEST_SERVERS[cn_telecom_bj]="35722:北京电信"
SPEEDTEST_SERVERS[cn_telecom_gz]="27594:广州电信"
SPEEDTEST_SERVERS[cn_unicom_sh]="24447:上海联通"
SPEEDTEST_SERVERS[cn_unicom_bj]="5145:北京联通"
SPEEDTEST_SERVERS[cn_mobile_sh]="25637:上海移动"
SPEEDTEST_SERVERS[cn_mobile_bj]="25858:北京移动"
SPEEDTEST_SERVERS[hk]="22126:香港宽频"
SPEEDTEST_SERVERS[jp_tokyo]="48463:日本东京"
SPEEDTEST_SERVERS[sg]="18458:新加坡Singtel"
SPEEDTEST_SERVERS[us_la]="18531:美国洛杉矶"
SPEEDTEST_SERVERS[uk_london]="51838:英国伦敦"

# 创建必要目录
create_directories() {
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    [ ! -d "$REPORT_DIR" ] && mkdir -p "$REPORT_DIR"
    [ ! -d "$TEMP_DIR" ] && mkdir -p "$TEMP_DIR"
}

# 清理临时文件
cleanup() {
    [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR"
}

# 设置清理钩子
trap cleanup EXIT

# 日志记录函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
    log "$msg"
}

# 打印进度条
print_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width - filled))s" | tr ' ' ' '
    printf "] %d%%" $percentage
}

# 检查并安装speedtest-cli
install_speedtest() {
    print_msg "$BLUE" "检查测速工具..."
    
    # 检查是否已安装官方speedtest
    if command -v speedtest &> /dev/null; then
        print_msg "$GREEN" "Speedtest CLI已安装"
        return 0
    fi
    
    print_msg "$YELLOW" "正在安装Speedtest CLI..."
    
    # 安装官方speedtest
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash &>> "$LOG_FILE"
        apt-get install -y speedtest &>> "$LOG_FILE"
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash &>> "$LOG_FILE"
        yum install -y speedtest &>> "$LOG_FILE"
    else
        # 通用安装方法
        wget -O "$TEMP_DIR/speedtest.tgz" "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-$(uname -m).tgz" &>> "$LOG_FILE"
        tar -xzf "$TEMP_DIR/speedtest.tgz" -C "$TEMP_DIR"
        cp "$TEMP_DIR/speedtest" /usr/local/bin/
        chmod +x /usr/local/bin/speedtest
    fi
    
    # 接受许可
    speedtest --accept-license --accept-gdpr &>> "$LOG_FILE"
    
    if command -v speedtest &> /dev/null; then
        print_msg "$GREEN" "Speedtest CLI安装成功"
    else
        print_msg "$RED" "Speedtest CLI安装失败"
        return 1
    fi
}

# 测试下载速度（使用wget）
test_download_speed() {
    local url=$1
    local name=$2
    local size=$3  # MB
    
    print_msg "$CYAN" "测试下载速度: $name"
    
    local temp_file="$TEMP_DIR/download_test_$$"
    local start_time=$(date +%s.%N)
    
    # 使用wget下载，限制时间
    timeout 30 wget -O "$temp_file" --no-check-certificate "$url" 2>&1 | \
        grep -o "[0-9.]\+ [KM]B/s" | tail -1 > "$TEMP_DIR/wget_speed"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # 获取速度
    local speed_str=$(cat "$TEMP_DIR/wget_speed" 2>/dev/null)
    local speed_mbps=0
    
    if [[ "$speed_str" =~ ([0-9.]+)[[:space:]]KB/s ]]; then
        speed_mbps=$(echo "scale=2; ${BASH_REMATCH[1]} * 8 / 1024" | bc)
    elif [[ "$speed_str" =~ ([0-9.]+)[[:space:]]MB/s ]]; then
        speed_mbps=$(echo "scale=2; ${BASH_REMATCH[1]} * 8" | bc)
    fi
    
    # 清理临时文件
    rm -f "$temp_file" "$TEMP_DIR/wget_speed"
    
    echo -e "${GREEN}  下载速度: ${speed_mbps} Mbps${NC}"
    echo "$name: ${speed_mbps} Mbps" >> "$REPORT_FILE"
    
    return 0
}

# 测试上传速度（使用dd和curl）
test_upload_speed() {
    local url=$1
    local name=$2
    local size_mb=${3:-10}  # 默认10MB
    
    print_msg "$CYAN" "测试上传速度: $name"
    
    # 生成测试文件
    local test_file="$TEMP_DIR/upload_test_$$"
    dd if=/dev/zero of="$test_file" bs=1M count=$size_mb 2>/dev/null
    
    local start_time=$(date +%s.%N)
    
    # 使用curl上传
    local upload_result=$(curl -s -w "%{speed_upload}" -X POST -F "file=@$test_file" \
                         --max-time 30 -o /dev/null "$url" 2>/dev/null)
    
    local end_time=$(date +%s.%N)
    
    # 计算速度（bytes/s转Mbps）
    local speed_mbps=0
    if [[ "$upload_result" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        speed_mbps=$(echo "scale=2; $upload_result * 8 / 1024 / 1024" | bc)
    fi
    
    # 清理临时文件
    rm -f "$test_file"
    
    echo -e "${GREEN}  上传速度: ${speed_mbps} Mbps${NC}"
    echo "$name 上传: ${speed_mbps} Mbps" >> "$REPORT_FILE"
}

# 使用Speedtest测试
run_speedtest() {
    local server_id=$1
    local server_name=$2
    
    print_msg "$CYAN" "Speedtest测试: $server_name"
    
    local cmd="speedtest --format=json"
    [ -n "$server_id" ] && cmd="$cmd --server-id=$server_id"
    
    # 执行测试
    local result=$($cmd 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        # 解析JSON结果
        local download=$(echo "$result" | grep -oP '"download":\s*\{"bandwidth":\s*\K[0-9]+' | head -1)
        local upload=$(echo "$result" | grep -oP '"upload":\s*\{"bandwidth":\s*\K[0-9]+' | head -1)
        local ping=$(echo "$result" | grep -oP '"ping":\s*\{"latency":\s*\K[0-9.]+' | head -1)
        local server_info=$(echo "$result" | grep -oP '"name":\s*"\K[^"]+' | head -1)
        
        # 转换为Mbps
        [ -n "$download" ] && download=$(echo "scale=2; $download * 8 / 1024 / 1024" | bc)
        [ -n "$upload" ] && upload=$(echo "scale=2; $upload * 8 / 1024 / 1024" | bc)
        
        echo -e "${GREEN}  服务器: $server_info${NC}"
        echo -e "${GREEN}  延迟: ${ping}ms${NC}"
        echo -e "${GREEN}  下载: ${download} Mbps${NC}"
        echo -e "${GREEN}  上传: ${upload} Mbps${NC}"
        
        # 保存结果
        {
            echo "Speedtest - $server_name"
            echo "  服务器: $server_info"
            echo "  延迟: ${ping}ms"
            echo "  下载: ${download} Mbps"
            echo "  上传: ${upload} Mbps"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "  测试失败"
    fi
}

# 多线程速度测试
multi_thread_test() {
    print_msg "$PURPLE" "\n========== 多线程速度测试 =========="
    
    local test_urls=(
        "http://speedtest.tele2.net/10MB.zip"
        "http://cachefly.cachefly.net/10mb.test"
        "http://speed.cloudflare.com/__down?bytes=10485760"
    )
    
    local threads=(1 2 4 8)
    
    for thread in "${threads[@]}"; do
        print_msg "$CYAN" "\n使用 $thread 线程测试..."
        
        local total_speed=0
        local count=0
        
        # 并发下载
        for ((i=0; i<thread; i++)); do
            {
                local url=${test_urls[$((i % ${#test_urls[@]}))]}
                local temp_file="$TEMP_DIR/thread_${thread}_${i}"
                local start=$(date +%s.%N)
                
                wget -O "$temp_file" --no-check-certificate "$url" 2>&1 | \
                    grep -o "[0-9.]\+ [KM]B/s" | tail -1 > "$TEMP_DIR/speed_${thread}_${i}"
                
                local end=$(date +%s.%N)
                rm -f "$temp_file"
            } &
        done
        
        # 等待所有线程完成
        wait
        
        # 计算总速度
        for ((i=0; i<thread; i++)); do
            local speed_str=$(cat "$TEMP_DIR/speed_${thread}_${i}" 2>/dev/null)
            local speed=0
            
            if [[ "$speed_str" =~ ([0-9.]+)[[:space:]]KB/s ]]; then
                speed=$(echo "scale=2; ${BASH_REMATCH[1]} * 8 / 1024" | bc)
            elif [[ "$speed_str" =~ ([0-9.]+)[[:space:]]MB/s ]]; then
                speed=$(echo "scale=2; ${BASH_REMATCH[1]} * 8" | bc)
            fi
            
            total_speed=$(echo "scale=2; $total_speed + $speed" | bc)
            ((count++))
            
            rm -f "$TEMP_DIR/speed_${thread}_${i}"
        done
        
        if [ $count -gt 0 ]; then
            echo -e "${GREEN}  总速度: ${total_speed} Mbps${NC}"
            echo "$thread 线程: ${total_speed} Mbps" >> "$REPORT_FILE"
        fi
    done
}

# 测试到各地CDN的速度
cdn_speed_test() {
    print_msg "$PURPLE" "\n========== CDN节点速度测试 =========="
    
    declare -A cdn_urls
    cdn_urls[cloudflare_global]="https://speed.cloudflare.com/__down?bytes=25000000:Cloudflare全球"
    cdn_urls[aws_singapore]="http://s3-ap-southeast-1.amazonaws.com/speedtest/10MB.zip:AWS新加坡"
    cdn_urls[aws_tokyo]="http://s3-ap-northeast-1.amazonaws.com/speedtest/10MB.zip:AWS东京"
    cdn_urls[aws_us_west]="http://s3-us-west-1.amazonaws.com/speedtest/10MB.zip:AWS美西"
    cdn_urls[vultr_tokyo]="https://hnd-jp-ping.vultr.com/vultr.com.100MB.bin:Vultr东京"
    cdn_urls[vultr_singapore]="https://sgp-ping.vultr.com/vultr.com.100MB.bin:Vultr新加坡"
    cdn_urls[linode_singapore]="http://speedtest.singapore.linode.com/100MB-singapore.bin:Linode新加坡"
    cdn_urls[do_singapore]="http://speedtest-sgp1.digitalocean.com/10mb.test:DigitalOcean新加坡"
    
    for key in "${!cdn_urls[@]}"; do
        IFS=':' read -r url name <<< "${cdn_urls[$key]}"
        test_download_speed "$url" "$name" 10
        sleep 1
    done
}

# 带宽稳定性测试
bandwidth_stability_test() {
    print_msg "$PURPLE" "\n========== 带宽稳定性测试 =========="
    print_msg "$CYAN" "连续测试5次，检测带宽波动..."
    
    local test_url="https://speed.cloudflare.com/__down?bytes=10485760"
    local speeds=()
    
    for i in {1..5}; do
        echo -ne "\r测试进度: $i/5"
        
        local temp_file="$TEMP_DIR/stability_test_$i"
        local speed_str=$(timeout 20 wget -O "$temp_file" --no-check-certificate "$test_url" 2>&1 | \
                         grep -o "[0-9.]\+ [KM]B/s" | tail -1)
        
        local speed=0
        if [[ "$speed_str" =~ ([0-9.]+)[[:space:]]KB/s ]]; then
            speed=$(echo "scale=2; ${BASH_REMATCH[1]} * 8 / 1024" | bc)
        elif [[ "$speed_str" =~ ([0-9.]+)[[:space:]]MB/s ]]; then
            speed=$(echo "scale=2; ${BASH_REMATCH[1]} * 8" | bc)
        fi
        
        speeds+=($speed)
        rm -f "$temp_file"
        
        sleep 2
    done
    
    echo ""
    
    # 计算平均值和标准差
    local sum=0
    local min=999999
    local max=0
    
    for speed in "${speeds[@]}"; do
        sum=$(echo "scale=2; $sum + $speed" | bc)
        
        if (( $(echo "$speed < $min" | bc -l) )); then
            min=$speed
        fi
        
        if (( $(echo "$speed > $max" | bc -l) )); then
            max=$speed
        fi
    done
    
    local avg=$(echo "scale=2; $sum / ${#speeds[@]}" | bc)
    local variance=0
    
    for speed in "${speeds[@]}"; do
        local diff=$(echo "scale=2; $speed - $avg" | bc)
        variance=$(echo "scale=2; $variance + ($diff * $diff)" | bc)
    done
    
    variance=$(echo "scale=2; $variance / ${#speeds[@]}" | bc)
    local std_dev=$(echo "scale=2; sqrt($variance)" | bc)
    
    echo -e "${GREEN}测试结果:${NC}"
    echo -e "  测试次数: ${#speeds[@]}"
    echo -e "  平均速度: ${avg} Mbps"
    echo -e "  最小速度: ${min} Mbps"
    echo -e "  最大速度: ${max} Mbps"
    echo -e "  标准差: ${std_dev} Mbps"
    
    # 判断稳定性
    local stability_ratio=$(echo "scale=2; $std_dev / $avg * 100" | bc)
    if (( $(echo "$stability_ratio < 10" | bc -l) )); then
        echo -e "  稳定性: ${GREEN}优秀${NC} (波动 <10%)"
    elif (( $(echo "$stability_ratio < 20" | bc -l) )); then
        echo -e "  稳定性: ${YELLOW}良好${NC} (波动 10-20%)"
    else
        echo -e "  稳定性: ${RED}较差${NC} (波动 >20%)"
    fi
    
    # 保存到报告
    {
        echo "带宽稳定性测试:"
        echo "  平均: ${avg} Mbps, 最小: ${min} Mbps, 最大: ${max} Mbps"
        echo "  标准差: ${std_dev} Mbps, 波动率: ${stability_ratio}%"
        echo ""
    } >> "$REPORT_FILE"
}

# 生成测试报告
generate_report() {
    print_msg "$BLUE" "\n生成测试报告..."
    
    local summary_file="$REPORT_DIR/bandwidth_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "       VPS带宽测试报告"
        echo "=========================================="
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "测试模式: $([ "$SIMPLE_MODE" = true ] && echo "简单模式" || echo "完整模式")"
        echo ""
        
        # 系统信息
        echo "系统信息:"
        echo "  CPU: $(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)"
        echo "  内存: $(free -h | awk 'NR==2{print $2}')"
        echo "  系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
        echo ""
        
        # 测试结果摘要
        echo "测试结果摘要:"
        cat "$REPORT_FILE"
        
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n测试报告已保存到: $summary_file"
}

# 简单测试模式
simple_test() {
    print_msg "$PURPLE" "========== 简单带宽测试 =========="
    
    # 安装测速工具
    install_speedtest
    
    # 默认节点测试
    print_msg "$CYAN" "\n测试到最近的服务器..."
    run_speedtest "" "自动选择"
    
    # 测试到主要地区
    if command -v speedtest &> /dev/null; then
        print_msg "$CYAN" "\n测试到中国电信..."
        run_speedtest "3633" "上海电信"
        
        print_msg "$CYAN" "\n测试到中国联通..."
        run_speedtest "24447" "上海联通"
        
        print_msg "$CYAN" "\n测试到国际线路..."
        run_speedtest "22126" "香港"
    fi
    
    # CDN测试
    print_msg "$CYAN" "\n测试到Cloudflare CDN..."
    test_download_speed "https://speed.cloudflare.com/__down?bytes=25000000" "Cloudflare" 25
}

# 完整测试模式
full_test() {
    print_msg "$PURPLE" "========== 完整带宽测试 =========="
    
    # 安装测速工具
    install_speedtest
    
    # Speedtest测试
    print_msg "$BLUE" "\n=== Speedtest.net测试 ==="
    
    for key in "${!SPEEDTEST_SERVERS[@]}"; do
        IFS=':' read -r id name <<< "${SPEEDTEST_SERVERS[$key]}"
        run_speedtest "$id" "$name"
        sleep 2
    done
    
    # 多线程测试
    multi_thread_test
    
    # CDN速度测试
    cdn_speed_test
    
    # 稳定性测试
    bandwidth_stability_test
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                          VPS 带宽测试工具 v1.0                             ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}请选择测试模式:${NC}"
    echo -e "${GREEN}1)${NC} 简单测试 (快速)"
    echo -e "${GREEN}2)${NC} 标准测试 (推荐)"
    echo -e "${GREEN}3)${NC} 完整测试 (详细)"
    echo -e "${GREEN}4)${NC} 多线程测试"
    echo -e "${GREEN}5)${NC} CDN速度测试"
    echo -e "${GREEN}6)${NC} 带宽稳定性测试"
    echo -e "${GREEN}7)${NC} 自定义Speedtest服务器"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            SIMPLE_MODE=true
            simple_test
            generate_report
            ;;
        2)
            install_speedtest
            print_msg "$BLUE" "开始标准带宽测试..."
            run_speedtest "" "自动选择"
            
            # 测试主要节点
            for key in cn_telecom_sh cn_unicom_sh cn_mobile_sh hk jp_tokyo sg us_la; do
                IFS=':' read -r id name <<< "${SPEEDTEST_SERVERS[$key]}"
                run_speedtest "$id" "$name"
                sleep 2
            done
            
            generate_report
            ;;
        3)
            FULL_MODE=true
            full_test
            generate_report
            ;;
        4)
            multi_thread_test
            ;;
        5)
            cdn_speed_test
            ;;
        6)
            bandwidth_stability_test
            ;;
        7)
            custom_speedtest
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

# 自定义Speedtest服务器
custom_speedtest() {
    echo ""
    echo -e "${CYAN}查找可用的Speedtest服务器...${NC}"
    
    # 列出附近的服务器
    speedtest --list 2>/dev/null | head -20
    
    echo ""
    read -p "请输入服务器ID (或直接回车使用自动选择): " server_id
    
    if [ -n "$server_id" ]; then
        run_speedtest "$server_id" "自定义服务器 #$server_id"
    else
        run_speedtest "" "自动选择"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
使用方法: $0 [选项]

选项:
  --simple    简单测试模式
  --full      完整测试模式
  --share     生成分享链接
  --help, -h  显示此帮助信息

示例:
  $0              # 交互式菜单
  $0 --simple     # 快速简单测试
  $0 --full       # 完整详细测试

注意:
  - 首次运行会自动安装测速工具
  - 完整测试可能需要较长时间
  - 测试结果保存在 $REPORT_DIR
EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --simple)
                SIMPLE_MODE=true
                shift
                ;;
            --full)
                FULL_MODE=true
                shift
                ;;
            --share)
                SHARE_RESULT=true
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
    log "开始带宽测试"
    
    {
        echo "========== VPS带宽测试 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    if [ "$SIMPLE_MODE" = true ]; then
        simple_test
        generate_report
    elif [ "$FULL_MODE" = true ]; then
        full_test
        generate_report
    else
        interactive_menu
    fi
    
    print_msg "$GREEN" "\n带宽测试完成！"
    [ -f "$REPORT_FILE" ] && print_msg "$CYAN" "测试报告: $REPORT_FILE"
}

# 运行主函数
main "$@"
