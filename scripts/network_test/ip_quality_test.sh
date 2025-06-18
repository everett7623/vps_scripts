#!/bin/bash

#==============================================================================
# 脚本名称: ip_quality_test.sh
# 描述: VPS IP质量测试脚本 - 检测IP黑名单、声誉、类型、风险等级
# 作者: Jensfrank
# 路径: vps_scripts/scripts/network_test/ip_quality_test.sh
# 使用方法: bash ip_quality_test.sh [IP地址]
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
LOG_FILE="$LOG_DIR/ip_quality_$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/var/log/vps_scripts/reports"
REPORT_FILE="$REPORT_DIR/ip_quality_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/ip_quality_$$"

# 测试IP（默认使用本机公网IP）
TARGET_IP=""
CHECK_BLACKLIST=true
CHECK_REPUTATION=true
CHECK_ABUSE=true
CHECK_RISK=true

# 黑名单服务器列表
declare -A BLACKLIST_SERVERS
BLACKLIST_SERVERS[spamhaus]="zen.spamhaus.org"
BLACKLIST_SERVERS[barracuda]="b.barracudacentral.org"
BLACKLIST_SERVERS[spamcop]="bl.spamcop.net"
BLACKLIST_SERVERS[sorbs]="dnsbl.sorbs.net"
BLACKLIST_SERVERS[uceprotect1]="dnsbl-1.uceprotect.net"
BLACKLIST_SERVERS[uceprotect2]="dnsbl-2.uceprotect.net"
BLACKLIST_SERVERS[cbl]="cbl.abuseat.org"
BLACKLIST_SERVERS[psbl]="psbl.surriel.com"
BLACKLIST_SERVERS[mailspike]="bl.mailspike.net"
BLACKLIST_SERVERS[truncate]="truncate.gbudb.net"

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
get_ip_info() {
    local ip=$1
    
    print_msg "$BLUE" "========== IP基本信息 =========="
    echo -e "${CYAN}IP地址:${NC} $ip"
    
    # 使用多个API获取IP信息
    local apis=(
        "http://ip-api.com/json/$ip?fields=status,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,mobile,proxy,hosting"
        "https://ipapi.co/$ip/json/"
        "http://ipinfo.io/$ip/json"
    )
    
    local ip_info=""
    for api in "${apis[@]}"; do
        ip_info=$(curl -s --max-time 5 "$api" 2>/dev/null)
        if [ -n "$ip_info" ] && echo "$ip_info" | grep -q "country"; then
            break
        fi
    done
    
    if [ -n "$ip_info" ]; then
        # 解析信息
        local country=$(echo "$ip_info" | grep -oP '"country":\s*"\K[^"]+' | head -1)
        local region=$(echo "$ip_info" | grep -oP '"regionName":\s*"\K[^"]+' | head -1)
        local city=$(echo "$ip_info" | grep -oP '"city":\s*"\K[^"]+' | head -1)
        local isp=$(echo "$ip_info" | grep -oP '"isp":\s*"\K[^"]+' | head -1)
        local org=$(echo "$ip_info" | grep -oP '"org":\s*"\K[^"]+' | head -1)
        local as_info=$(echo "$ip_info" | grep -oP '"as":\s*"\K[^"]+' | head -1)
        local proxy=$(echo "$ip_info" | grep -oP '"proxy":\s*\K(true|false)' | head -1)
        local hosting=$(echo "$ip_info" | grep -oP '"hosting":\s*\K(true|false)' | head -1)
        local mobile=$(echo "$ip_info" | grep -oP '"mobile":\s*\K(true|false)' | head -1)
        
        echo -e "${CYAN}位置信息:${NC}"
        echo -e "  国家: ${country:-未知}"
        echo -e "  地区: ${region:-未知}"
        echo -e "  城市: ${city:-未知}"
        
        echo -e "\n${CYAN}网络信息:${NC}"
        echo -e "  ISP: ${isp:-未知}"
        echo -e "  组织: ${org:-未知}"
        echo -e "  AS: ${as_info:-未知}"
        
        echo -e "\n${CYAN}IP类型:${NC}"
        
        # 判断IP类型
        local ip_type="住宅IP"
        local type_color=$GREEN
        
        if [ "$hosting" = "true" ]; then
            ip_type="数据中心IP"
            type_color=$YELLOW
        elif [ "$mobile" = "true" ]; then
            ip_type="移动网络IP"
            type_color=$CYAN
        elif [ "$proxy" = "true" ]; then
            ip_type="代理IP"
            type_color=$RED
        elif [[ "$org" =~ (hosting|vps|server|cloud|datacenter|colocation) ]]; then
            ip_type="数据中心IP"
            type_color=$YELLOW
        fi
        
        echo -e "  类型: ${type_color}${ip_type}${NC}"
        [ "$proxy" = "true" ] && echo -e "  ${RED}检测到代理${NC}"
        [ "$hosting" = "true" ] && echo -e "  ${YELLOW}托管服务器IP${NC}"
        
        # 保存到报告
        {
            echo "========== IP基本信息 =========="
            echo "IP地址: $ip"
            echo "国家: ${country:-未知}"
            echo "ISP: ${isp:-未知}"
            echo "组织: ${org:-未知}"
            echo "IP类型: $ip_type"
            echo ""
        } >> "$REPORT_FILE"
    else
        print_msg "$RED" "无法获取IP信息"
    fi
}

# 反向DNS查询
check_rdns() {
    local ip=$1
    
    print_msg "$BLUE" "\n========== 反向DNS检查 =========="
    
    local rdns=$(dig +short -x "$ip" 2>/dev/null | sed 's/\.$//')
    
    if [ -n "$rdns" ]; then
        echo -e "${GREEN}反向DNS记录: $rdns${NC}"
        
        # 检查正向解析是否匹配
        local forward_ip=$(dig +short "$rdns" 2>/dev/null | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' | head -1)
        
        if [ "$forward_ip" = "$ip" ]; then
            echo -e "${GREEN}正反向DNS匹配 ✓${NC}"
        else
            echo -e "${YELLOW}正反向DNS不匹配${NC}"
            echo -e "  正向解析: $forward_ip"
        fi
        
        # 分析主机名模式
        if [[ "$rdns" =~ (static|business|dedicated) ]]; then
            echo -e "${GREEN}看起来是静态分配的IP${NC}"
        elif [[ "$rdns" =~ (dynamic|dhcp|pool|ppp) ]]; then
            echo -e "${YELLOW}看起来是动态分配的IP${NC}"
        fi
        
        echo "反向DNS: $rdns" >> "$REPORT_FILE"
    else
        echo -e "${YELLOW}无反向DNS记录${NC}"
        echo "反向DNS: 无" >> "$REPORT_FILE"
    fi
}

# 黑名单检查
check_blacklists() {
    if [ "$CHECK_BLACKLIST" = false ]; then
        return
    fi
    
    local ip=$1
    print_msg "$BLUE" "\n========== 黑名单检查 =========="
    
    # 反转IP地址
    local reversed_ip=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')
    
    local blacklisted=0
    local total=${#BLACKLIST_SERVERS[@]}
    local clean=0
    
    echo -e "${CYAN}检查 $total 个黑名单数据库...${NC}\n"
    
    for bl_name in "${!BLACKLIST_SERVERS[@]}"; do
        local bl_server=${BLACKLIST_SERVERS[$bl_name]}
        local query="${reversed_ip}.${bl_server}"
        
        # 执行DNS查询
        local result=$(dig +short "$query" 2>/dev/null)
        
        if [ -n "$result" ] && [[ "$result" =~ ^127\. ]]; then
            echo -e "  ${RED}✗ $bl_name${NC} - 已列入黑名单"
            ((blacklisted++))
            
            # 获取黑名单原因（如果有TXT记录）
            local reason=$(dig +short TXT "$query" 2>/dev/null | sed 's/"//g')
            [ -n "$reason" ] && echo "    原因: $reason"
        else
            echo -e "  ${GREEN}✓ $bl_name${NC} - 清洁"
            ((clean++))
        fi
    done
    
    echo -e "\n${CYAN}黑名单检查结果:${NC}"
    echo -e "  总检查: $total"
    echo -e "  ${GREEN}清洁: $clean${NC}"
    echo -e "  ${RED}黑名单: $blacklisted${NC}"
    
    # 评估
    local reputation="良好"
    local rep_color=$GREEN
    
    if [ $blacklisted -eq 0 ]; then
        reputation="优秀"
        rep_color=$GREEN
    elif [ $blacklisted -le 2 ]; then
        reputation="一般"
        rep_color=$YELLOW
    else
        reputation="较差"
        rep_color=$RED
    fi
    
    echo -e "\n${CYAN}IP声誉评级: ${rep_color}${reputation}${NC}"
    
    # 保存结果
    {
        echo "========== 黑名单检查 =========="
        echo "检查数量: $total"
        echo "清洁: $clean"
        echo "黑名单: $blacklisted"
        echo "声誉评级: $reputation"
        echo ""
    } >> "$REPORT_FILE"
}

# 端口扫描（检测开放服务）
check_open_ports() {
    local ip=$1
    
    print_msg "$BLUE" "\n========== 开放端口检查 =========="
    echo -e "${CYAN}扫描常见端口...${NC}"
    
    # 常见高风险端口
    local risky_ports=(
        "22:SSH"
        "23:Telnet"
        "25:SMTP"
        "110:POP3"
        "135:RPC"
        "139:NetBIOS"
        "445:SMB"
        "1433:MSSQL"
        "3306:MySQL"
        "3389:RDP"
        "5432:PostgreSQL"
        "6379:Redis"
        "27017:MongoDB"
    )
    
    local open_ports=0
    local risky_services=""
    
    for port_info in "${risky_ports[@]}"; do
        IFS=':' read -r port service <<< "$port_info"
        
        if timeout 2 bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null; then
            echo -e "  ${YELLOW}$service (端口 $port) - 开放${NC}"
            ((open_ports++))
            
            # 评估风险
            case $port in
                23|135|139|445)
                    risky_services+="$service(高风险) "
                    ;;
                22|3389)
                    risky_services+="$service(中风险) "
                    ;;
            esac
        fi
    done
    
    if [ $open_ports -eq 0 ]; then
        echo -e "${GREEN}未发现开放的高风险端口${NC}"
    else
        echo -e "\n${YELLOW}发现 $open_ports 个开放端口${NC}"
        [ -n "$risky_services" ] && echo -e "${RED}高风险服务: $risky_services${NC}"
    fi
    
    echo "开放端口数: $open_ports" >> "$REPORT_FILE"
}

# 检查IP是否在云服务提供商范围
check_cloud_provider() {
    local ip=$1
    
    print_msg "$BLUE" "\n========== 云服务商检测 =========="
    
    # 检查AS信息
    local as_info=$(whois "$ip" 2>/dev/null | grep -i "org-name\|orgname\|netname" | head -1)
    
    # 云服务商关键词
    local providers=(
        "amazon:AWS"
        "google:Google Cloud"
        "microsoft:Azure"
        "alibaba:阿里云"
        "tencent:腾讯云"
        "huawei:华为云"
        "digitalocean:DigitalOcean"
        "linode:Linode"
        "vultr:Vultr"
        "ovh:OVH"
        "hetzner:Hetzner"
    )
    
    local detected_provider=""
    
    for provider_info in "${providers[@]}"; do
        IFS=':' read -r keyword name <<< "$provider_info"
        
        if echo "$as_info" | grep -iq "$keyword"; then
            detected_provider=$name
            break
        fi
    done
    
    if [ -n "$detected_provider" ]; then
        echo -e "${CYAN}检测到云服务商: ${detected_provider}${NC}"
        echo "云服务商: $detected_provider" >> "$REPORT_FILE"
    else
        echo -e "${GREEN}非主流云服务商IP${NC}"
        echo "云服务商: 未知/独立" >> "$REPORT_FILE"
    fi
}

# 滥用数据库检查
check_abuse_db() {
    if [ "$CHECK_ABUSE" = false ]; then
        return
    fi
    
    local ip=$1
    
    print_msg "$BLUE" "\n========== 滥用行为检查 =========="
    
    # 检查AbuseIPDB（需要API密钥，这里仅作示例）
    echo -e "${CYAN}检查滥用举报记录...${NC}"
    
    # 使用公开的威胁情报源
    local threat_check=$(curl -s "https://www.abuseipdb.com/check/$ip" 2>/dev/null | grep -c "was found in our database")
    
    if [ "$threat_check" -gt 0 ]; then
        echo -e "${RED}在滥用数据库中发现记录${NC}"
        echo "滥用记录: 是" >> "$REPORT_FILE"
    else
        echo -e "${GREEN}未发现滥用记录${NC}"
        echo "滥用记录: 否" >> "$REPORT_FILE"
    fi
    
    # 检查是否为Tor出口节点
    local tor_check=$(curl -s "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$ip" 2>/dev/null)
    
    if echo "$tor_check" | grep -q "$ip"; then
        echo -e "${RED}检测到Tor出口节点${NC}"
        echo "Tor节点: 是" >> "$REPORT_FILE"
    else
        echo -e "${GREEN}非Tor出口节点${NC}"
        echo "Tor节点: 否" >> "$REPORT_FILE"
    fi
}

# 风险评分
calculate_risk_score() {
    local ip=$1
    
    print_msg "$BLUE" "\n========== IP风险评估 =========="
    
    local risk_score=0
    local risk_factors=""
    
    # 分析报告中的数据
    if grep -q "数据中心IP" "$REPORT_FILE"; then
        risk_score=$((risk_score + 20))
        risk_factors+="\n  - 数据中心IP (+20)"
    fi
    
    if grep -q "代理IP" "$REPORT_FILE"; then
        risk_score=$((risk_score + 40))
        risk_factors+="\n  - 检测到代理 (+40)"
    fi
    
    local blacklist_count=$(grep "黑名单:" "$REPORT_FILE" | awk '{print $2}')
    if [ "$blacklist_count" -gt 0 ] 2>/dev/null; then
        risk_score=$((risk_score + blacklist_count * 15))
        risk_factors+="\n  - 黑名单记录 (+$((blacklist_count * 15)))"
    fi
    
    if grep -q "反向DNS: 无" "$REPORT_FILE"; then
        risk_score=$((risk_score + 10))
        risk_factors+="\n  - 无反向DNS (+10)"
    fi
    
    if grep -q "滥用记录: 是" "$REPORT_FILE"; then
        risk_score=$((risk_score + 30))
        risk_factors+="\n  - 滥用记录 (+30)"
    fi
    
    if grep -q "Tor节点: 是" "$REPORT_FILE"; then
        risk_score=$((risk_score + 25))
        risk_factors+="\n  - Tor出口节点 (+25)"
    fi
    
    # 确定风险等级
    local risk_level=""
    local risk_color=""
    
    if [ $risk_score -eq 0 ]; then
        risk_level="极低"
        risk_color=$GREEN
    elif [ $risk_score -le 20 ]; then
        risk_level="低"
        risk_color=$GREEN
    elif [ $risk_score -le 40 ]; then
        risk_level="中等"
        risk_color=$YELLOW
    elif [ $risk_score -le 70 ]; then
        risk_level="高"
        risk_color=$RED
    else
        risk_level="极高"
        risk_color=$RED
    fi
    
    echo -e "${CYAN}风险评分: ${risk_score}/100${NC}"
    echo -e "${CYAN}风险等级: ${risk_color}${risk_level}${NC}"
    
    if [ -n "$risk_factors" ]; then
        echo -e "\n风险因素:$risk_factors"
    fi
    
    # 建议
    echo -e "\n${CYAN}建议:${NC}"
    
    if [ $risk_score -le 20 ]; then
        echo -e "${GREEN}  - IP质量良好，适合各类用途${NC}"
    elif [ $risk_score -le 40 ]; then
        echo -e "${YELLOW}  - IP质量一般，可能影响邮件发送${NC}"
        echo -e "${YELLOW}  - 建议配置反向DNS和SPF记录${NC}"
    else
        echo -e "${RED}  - IP质量较差，不适合邮件服务器${NC}"
        echo -e "${RED}  - 可能被某些服务拒绝访问${NC}"
        echo -e "${RED}  - 建议联系ISP清理黑名单记录${NC}"
    fi
    
    # 保存评估结果
    {
        echo ""
        echo "========== 风险评估 =========="
        echo "风险评分: ${risk_score}/100"
        echo "风险等级: $risk_level"
    } >> "$REPORT_FILE"
}

# 生成综合报告
generate_comprehensive_report() {
    print_msg "$BLUE" "\n生成综合报告..."
    
    local summary_file="$REPORT_DIR/ip_quality_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "         IP质量检测报告"
        echo "=========================================="
        echo "检测时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "检测IP: $TARGET_IP"
        echo ""
        
        cat "$REPORT_FILE"
        
        echo ""
        echo "=========================================="
        echo "使用建议:"
        echo ""
        
        local risk_score=$(grep "风险评分:" "$REPORT_FILE" | awk '{print $2}' | cut -d'/' -f1)
        
        if [ "$risk_score" -le 20 ]; then
            echo "1. 网站托管: ✓ 推荐"
            echo "2. 邮件服务: ✓ 推荐"
            echo "3. API服务: ✓ 推荐"
            echo "4. 游戏服务: ✓ 推荐"
        elif [ "$risk_score" -le 40 ]; then
            echo "1. 网站托管: ✓ 可用"
            echo "2. 邮件服务: ⚠ 需要配置"
            echo "3. API服务: ✓ 可用"
            echo "4. 游戏服务: ✓ 可用"
        else
            echo "1. 网站托管: ⚠ 可能受限"
            echo "2. 邮件服务: ✗ 不推荐"
            echo "3. API服务: ⚠ 可能受限"
            echo "4. 游戏服务: ⚠ 可能受限"
        fi
        
        echo ""
        echo "详细日志: $LOG_FILE"
        echo "=========================================="
    } | tee "$summary_file"
    
    print_msg "$GREEN" "\n检测报告已保存到: $summary_file"
}

# 交互式菜单
interactive_menu() {
    clear
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                          VPS IP质量检测工具 v1.0                           ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 获取本机IP
    if [ -z "$TARGET_IP" ]; then
        TARGET_IP=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null || curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)
    fi
    
    echo -e "${CYAN}当前检测IP: $TARGET_IP${NC}"
    echo ""
    echo -e "${CYAN}请选择检测项目:${NC}"
    echo -e "${GREEN}1)${NC} 完整检测 (推荐)"
    echo -e "${GREEN}2)${NC} 基础信息"
    echo -e "${GREEN}3)${NC} 黑名单检查"
    echo -e "${GREEN}4)${NC} 滥用记录检查"
    echo -e "${GREEN}5)${NC} 风险评估"
    echo -e "${GREEN}6)${NC} 更换检测IP"
    echo -e "${GREEN}0)${NC} 退出"
    echo ""
    
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1)
            # 完整检测
            get_ip_info "$TARGET_IP"
            check_rdns "$TARGET_IP"
            check_blacklists "$TARGET_IP"
            check_open_ports "$TARGET_IP"
            check_cloud_provider "$TARGET_IP"
            check_abuse_db "$TARGET_IP"
            calculate_risk_score "$TARGET_IP"
            generate_comprehensive_report
            ;;
        2)
            get_ip_info "$TARGET_IP"
            check_rdns "$TARGET_IP"
            check_cloud_provider "$TARGET_IP"
            ;;
        3)
            check_blacklists "$TARGET_IP"
            ;;
        4)
            check_abuse_db "$TARGET_IP"
            ;;
        5)
            # 需要先收集数据
            get_ip_info "$TARGET_IP" > /dev/null 2>&1
            check_rdns "$TARGET_IP" > /dev/null 2>&1
            check_blacklists "$TARGET_IP" > /dev/null 2>&1
            check_abuse_db "$TARGET_IP" > /dev/null 2>&1
            calculate_risk_score "$TARGET_IP"
            ;;
        6)
            echo ""
            read -p "请输入要检测的IP地址: " new_ip
            if [[ "$new_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                TARGET_IP=$new_ip
                # 清空报告文件
                > "$REPORT_FILE"
            else
                print_msg "$RED" "无效的IP地址格式"
            fi
            sleep 2
            interactive_menu
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

# 显示帮助
show_help() {
    cat << EOF
使用方法: $0 [IP地址]

说明:
  检测指定IP地址的质量，包括黑名单、声誉、风险等级等。
  如果不指定IP，将检测本机公网IP。

选项:
  IP地址      要检测的IP地址
  --help, -h  显示此帮助信息

示例:
  $0                  # 检测本机IP
  $0 8.8.8.8          # 检测指定IP
  $0 --help           # 显示帮助

检测项目:
  - IP基本信息（位置、ISP、类型）
  - 反向DNS记录
  - 黑名单数据库检查
  - 开放端口扫描
  - 云服务商识别
  - 滥用记录检查
  - 综合风险评估

注意:
  - 检测可能需要几分钟时间
  - 某些检测需要网络连接
  - 结果仅供参考
EOF
}

# 主函数
main() {
    # 初始化
    create_directories
    
    # 解析参数
    if [ $# -eq 0 ]; then
        # 无参数，使用本机IP
        TARGET_IP=$(curl -s -4 --max-time 5 ip.sb 2>/dev/null || curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)
        
        if [ -z "$TARGET_IP" ]; then
            print_msg "$RED" "无法获取本机公网IP"
            exit 1
        fi
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    else
        # 验证IP格式
        if [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            TARGET_IP=$1
        else
            print_msg "$RED" "无效的IP地址格式: $1"
            exit 1
        fi
    fi
    
    # 开始检测
    log "开始IP质量检测: $TARGET_IP"
    
    {
        echo "========== IP质量检测 =========="
        echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$REPORT_FILE"
    
    # 如果有参数，执行完整检测
    if [ $# -gt 0 ] && [ "$1" != "--help" ] && [ "$1" != "-h" ]; then
        get_ip_info "$TARGET_IP"
        check_rdns "$TARGET_IP"
        check_blacklists "$TARGET_IP"
        check_open_ports "$TARGET_IP"
        check_cloud_provider "$TARGET_IP"
        check_abuse_db "$TARGET_IP"
        calculate_risk_score "$TARGET_IP"
        generate_comprehensive_report
    else
        # 否则显示交互菜单
        interactive_menu
    fi
    
    print_msg "$GREEN" "\nIP质量检测完成！"
}

# 运行主函数
main "$@"
