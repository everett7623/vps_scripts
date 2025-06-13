
#!/bin/bash
#/scripts/network_test/network_security_scan.sh - VPS Scripts 网络测试工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 安装必要工具
install_tools() {
    echo -e "${BLUE}正在安装必要的工具...${NC}"
    
    if command -v apt &>/dev/null; then
        sudo apt install -y nmap lynis
    elif command -v yum &>/dev/null; then
        sudo yum install -y nmap lynis
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm nmap lynis
    else
        echo -e "${RED}无法安装必要的工具，请手动安装。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}工具安装完成。${NC}"
}

# 端口扫描
port_scan() {
    echo -e "${BLUE}正在进行端口扫描...${NC}"
    
    # 获取本机IP
    local_ip=$(hostname -I | awk '{print $1}')
    echo -e "${YELLOW}本机IP: ${GREEN}$local_ip${NC}"
    
    # 创建结果文件
    result_file="/tmp/port_scan_$(date +%Y%m%d%H%M%S).txt"
    echo "端口扫描结果 - $(date)" > $result_file
    echo "扫描IP: $local_ip" >> $result_file
    echo "==============================================" >> $result_file
    
    # 使用nmap扫描常用端口
    echo -e "${YELLOW}正在扫描常用端口...${NC}"
    nmap_result=$(nmap -sV --version-light -p- $local_ip)
    
    # 显示开放端口
    open_ports=$(echo "$nmap_result" | grep "open" | awk '{print $1 " " $3 " " $4 " " $5 " " $6}')
    
    if [ -z "$open_ports" ]; then
        echo -e "${GREEN}✓ 没有发现开放端口${NC}"
        echo "没有发现开放端口" >> $result_file
    else
        echo -e "${YELLOW}发现以下开放端口:${NC}"
        echo "$open_ports" | while read line; do
            port=$(echo $line | awk '{print $1}')
            service=$(echo $line | awk '{$1=""; print $0}' | sed 's/^ //')
            echo -e "${RED}✗ 端口 $port 开放: $service${NC}"
            echo "端口 $port 开放: $service" >> $result_file
        done
    fi
    
    echo -e "${GREEN}端口扫描完成。${NC}"
    echo ""
    echo -e "${YELLOW}扫描结果已保存到: $result_file${NC}"
    echo ""
}

# 安全漏洞扫描
vulnerability_scan() {
    echo -e "${BLUE}正在进行安全漏洞扫描...${NC}"
    
    # 创建结果文件
    result_file="/tmp/vulnerability_scan_$(date +%Y%m%d%H%M%S).txt"
    echo "安全漏洞扫描结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 使用lynis进行安全审计
    echo -e "${YELLOW}正在进行安全审计...${NC}"
    lynis_result=$(lynis audit system --quiet)
    
    # 提取警告和建议
    warnings=$(echo "$lynis_result" | grep "warning" | sed 's/\[warning\] //')
    suggestions=$(echo "$lynis_result" | grep "suggestion" | sed 's/\[suggestion\] //')
    
    # 显示警告
    if [ -n "$warnings" ]; then
        echo -e "${RED}发现以下安全警告:${NC}"
        echo "$warnings" | while read line; do
            echo -e "${RED}✗ $line${NC}"
            echo "警告: $line" >> $result_file
        done
    else
        echo -e "${GREEN}✓ 没有发现安全警告${NC}"
        echo "没有发现安全警告" >> $result_file
    fi
    
    # 显示建议
    if [ -n "$suggestions" ]; then
        echo -e "${YELLOW}安全建议:${NC}"
        echo "$suggestions" | while read line; do
            echo -e "${YELLOW}⚠ $line${NC}"
            echo "建议: $line" >> $result_file
        done
    else
        echo -e "${GREEN}✓ 没有安全建议${NC}"
        echo "没有安全建议" >> $result_file
    fi
    
    echo -e "${GREEN}安全漏洞扫描完成。${NC}"
    echo ""
    echo -e "${YELLOW}扫描结果已保存到: $result_file${NC}"
    echo ""
}

# 防火墙配置检查
firewall_check() {
    echo -e "${BLUE}正在检查防火墙配置...${NC}"
    
    # 创建结果文件
    result_file="/tmp/firewall_check_$(date +%Y%m%d%H%M%S).txt"
    echo "防火墙配置检查结果 - $(date)" > $result_file
    echo "==============================================" >> $result_file
    
    # 检查防火墙状态
    if command -v ufw &>/dev/null; then
        firewall="ufw"
        status=$(sudo ufw status)
    elif command -v firewalld &>/dev/null; then
        firewall="firewalld"
        status=$(sudo firewall-cmd --state)
    elif command -v iptables &>/dev/null; then
        firewall="iptables"
        status=$(sudo iptables -L)
    else
        firewall="未安装"
        status="未安装防火墙"
    fi
    
    # 显示防火墙状态
    echo -e "${YELLOW}防火墙类型: ${GREEN}$firewall${NC}"
    echo "防火墙类型: $firewall" >> $result_file
    
    if [ "$firewall" = "未安装" ]; then
        echo -e "${RED}✗ 未安装防火墙，系统存在安全风险${NC}"
        echo "未安装防火墙，系统存在安全风险" >> $result_file
    else
        echo -e "${YELLOW}防火墙状态:${NC}"
        echo "$status" >> $result_file
        
        # 检查防火墙是否启用
        if [ "$firewall" = "ufw" ]; then
            if echo "$status" | grep -q "Status: active"; then
                echo -e "${GREEN}✓ 防火墙已启用${NC}"
                echo "防火墙已启用" >> $result_file
            else
                echo -e "${RED}✗ 防火墙未启用，系统存在安全风险${NC}"
                echo "防火墙未启用，系统存在安全风险" >> $result_file
            fi
        elif [ "$firewall" = "firewalld" ]; then
            if [ "$status" = "running" ]; then
                echo -e "${GREEN}✓ 防火墙已启用${NC}"
                echo "防火墙已启用" >> $result_file
            else
                echo -e "${RED}✗ 防火墙未启用，系统存在安全风险${NC}"
                echo "防火墙未启用，系统存在安全风险" >> $result_file
            fi
        fi
    fi
    
    echo -e "${GREEN}防火墙配置检查完成。${NC}"
    echo ""
    echo -e "${YELLOW}检查结果已保存到: $result_file${NC}"
    echo ""
}

# 主函数
main() {
    echo -e "${WHITE}=============================================${NC}"
    echo -e "${WHITE}           网络安全扫描工具                   ${NC}"
    echo -e "${WHITE}=============================================${NC}"
    echo ""
    
    # 检查是否已安装必要工具
    if ! command -v nmap &>/dev/null || ! command -v lynis &>/dev/null; then
        install_tools
    fi
    
    # 显示测试选项菜单
    echo "请选择要执行的安全扫描项目:"
    echo "1. 全部扫描"
    echo "2. 仅端口扫描"
    echo "3. 仅安全漏洞扫描"
    echo "4. 仅防火墙配置检查"
    echo ""
    
    read -p "请输入选项 (1-4): " option
    
    case $option in
        1)
            port_scan
            vulnerability_scan
            firewall_check
            ;;
        2) port_scan ;;
        3) vulnerability_scan ;;
        4) firewall_check ;;
        *)
            echo -e "${RED}无效选项，操作已取消。${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}网络安全扫描完成!${NC}"
}

# 执行主函数
main
