#!/bin/bash
#/scripts/system_tools/system_info.sh - VPS Scripts 系统工具库

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # 恢复默认颜色

# 获取公网IP地址
ipv4_address=$(curl -s https://api.ipify.org)
ipv6_address=$(curl -s https://api64.ipify.org 2>/dev/null || echo "未检测到IPv6")

# 获取CPU信息
if [ "$(uname -m)" == "x86_64" ]; then
  cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
else
  cpu_info=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
fi

cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
cpu_usage_percent=$(printf "%.2f" "$cpu_usage")%

cpu_cores=$(nproc)

# 获取内存信息
mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

# 获取磁盘信息
disk_info=$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)", $3,$2,$5}')

# 获取地理位置信息
country=$(curl -s ipinfo.io/country)
city=$(curl -s ipinfo.io/city)

# 获取ISP信息
isp_info=$(curl -s ipinfo.io/org)

# 获取系统架构信息
cpu_arch=$(uname -m)

# 获取主机名
hostname=$(hostname)

# 获取内核版本
kernel_version=$(uname -r)

# 获取网络拥塞算法
congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
queue_algorithm=$(sysctl -n net.core.default_qdisc)

# 获取操作系统信息
# 尝试使用 lsb_release 获取系统信息
os_info=$(lsb_release -ds 2>/dev/null)

# 如果 lsb_release 命令失败，则尝试其他方法
if [ -z "$os_info" ]; then
  # 检查常见的发行文件
  if [ -f "/etc/os-release" ]; then
    os_info=$(source /etc/os-release && echo "$PRETTY_NAME")
  elif [ -f "/etc/debian_version" ]; then
    os_info="Debian $(cat /etc/debian_version)"
  elif [ -f "/etc/redhat-release" ]; then
    os_info=$(cat /etc/redhat-release)
  else
    os_info="Unknown"
  fi
fi

# 计算网络流量
clear
output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
  NR > 2 { rx_total += $2; tx_total += $10 }
  END {
      rx_units = "Bytes";
      tx_units = "Bytes";
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "KB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "MB"; }
      if (rx_total > 1024) { rx_total /= 1024; rx_units = "GB"; }

      if (tx_total > 1024) { tx_total /= 1024; tx_units = "KB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "MB"; }
      if (tx_total > 1024) { tx_total /= 1024; tx_units = "GB"; }

      printf("总接收: %.2f %s\n总发送: %.2f %s\n", rx_total, rx_units, tx_total, tx_units);
  }' /proc/net/dev)

# 获取当前时间
current_time=$(date "+%Y-%m-%d %I:%M %p")

# 获取交换空间信息
swap_used=$(free -m | awk 'NR==3{print $3}')
swap_total=$(free -m | awk 'NR==3{print $2}')

if [ "$swap_total" -eq 0 ]; then
  swap_percentage=0
else
  swap_percentage=$((swap_used * 100 / swap_total))
fi

swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

# 获取系统运行时间
runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

# 显示系统信息
echo ""
echo -e "${WHITE}系统信息详情${NC}"
echo "------------------------"
echo -e "${WHITE}主机名: ${YELLOW}${hostname}${NC}"
echo -e "${WHITE}运营商: ${YELLOW}${isp_info}${NC}"
echo "------------------------"
echo -e "${WHITE}系统版本: ${YELLOW}${os_info}${NC}"
echo -e "${WHITE}Linux版本: ${YELLOW}${kernel_version}${NC}"
echo "------------------------"
echo -e "${WHITE}CPU架构: ${YELLOW}${cpu_arch}${NC}"
echo -e "${WHITE}CPU型号: ${YELLOW}${cpu_info}${NC}"
echo -e "${WHITE}CPU核心数: ${YELLOW}${cpu_cores}${NC}"
echo "------------------------"
echo -e "${WHITE}CPU占用: ${YELLOW}${cpu_usage_percent}${NC}"
echo -e "${WHITE}物理内存: ${YELLOW}${mem_info}${NC}"
echo -e "${WHITE}虚拟内存: ${YELLOW}${swap_info}${NC}"
echo -e "${WHITE}硬盘占用: ${YELLOW}${disk_info}${NC}"
echo "------------------------"
echo -e "${PURPLE}$output${NC}"
echo "------------------------"
echo -e "${WHITE}网络拥堵算法: ${YELLOW}${congestion_algorithm} ${queue_algorithm}${NC}"
echo "------------------------"
echo -e "${WHITE}公网IPv4地址: ${YELLOW}${ipv4_address}${NC}"
echo -e "${WHITE}公网IPv6地址: ${YELLOW}${ipv6_address}${NC}"
echo "------------------------"
echo -e "${WHITE}地理位置: ${YELLOW}${country} ${city}${NC}"
echo -e "${WHITE}系统时间: ${YELLOW}${current_time}${NC}"
echo "------------------------"
echo -e "${WHITE}系统运行时长: ${YELLOW}${runtime}${NC}"
echo ""
