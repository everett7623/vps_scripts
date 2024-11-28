#!/bin/bash
VERSION="2024-10-30 v1.1.20"  # 最新版本号

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 定义渐变颜色数组
colors=(
    '\033[38;2;0;255;0m'    # 绿色
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # 黄色
)

# 检查 root 权限并获取 sudo 权限
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限运行。"
    if ! sudo -v; then
        echo "无法获取 sudo 权限，退出脚本。"
        exit 1
    fi
    echo "已获取 sudo 权限。"
fi

# 更新脚本
update_scripts() {
    local VERSION="2024-10-30 v1.1.20"  # 最新版本号
    local SCRIPT_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh"
    local VERSION_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/update_log.sh"
    
    echo -e "${YELLOW}正在检查更新...${NC}"
    
    local REMOTE_VERSION=$(curl -s -m 10 $VERSION_URL)
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}无法获取远程版本信息。请检查您的网络连接。${NC}"
        sleep 2
        return 1
    fi
    
    if [ "$REMOTE_VERSION" != "$VERSION" ]; then
        echo -e "${BLUE}发现新版本 $REMOTE_VERSION，当前版本 $VERSION${NC}"
        echo -e "${BLUE}正在更新...${NC}"
        
        if curl -s -m 30 -o /tmp/vps_scripts.sh $SCRIPT_URL; then
            if [ ! -s /tmp/vps_scripts.sh ]; then
                echo -e "${RED}下载的脚本文件为空。更新失败。${NC}"
                sleep 2
                return 1
            fi
            
            local NEW_VERSION=$(grep '^VERSION=' /tmp/vps_scripts.sh | cut -d'"' -f2)
            if [ -z "$NEW_VERSION" ]; then
                echo -e "${RED}无法从下载的脚本中获取版本信息。更新失败。${NC}"
                sleep 2
                return 1
            fi
            
            if ! sed -i "s/^VERSION=.*/VERSION=\"$NEW_VERSION\"/" "$0"; then
                echo -e "${RED}无法更新脚本中的版本号。请检查文件权限。${NC}"
                sleep 2
                return 1
            fi
            
            if mv /tmp/vps_scripts.sh "$0"; then
                chmod +x "$0"
                echo -e "${GREEN}脚本更新成功！新版本: $NEW_VERSION${NC}"
                echo -e "${YELLOW}请等待 3 秒...${NC}"
                sleep 3
                echo -e "${YELLOW}是否重新启动脚本以应用更新？(Y/n)${NC}"
                read -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                    exec bash "$0"
                else
                    echo -e "${YELLOW}请手动重启脚本以应用更新。${NC}"
                    sleep 2
                fi
            else
                echo -e "${RED}无法替换脚本文件。请检查权限。${NC}"
                sleep 2
                return 1
            fi
        else
            echo -e "${RED}下载新版本失败。请稍后重试。${NC}"
            sleep 2
            return 1
        fi
    else
        echo -e "${GREEN}脚本已是最新版本 $VERSION。${NC}"
        sleep 2
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_type=$ID
    elif type lsb_release >/dev/null 2>&1; then
        os_type=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        os_type=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        os_type="debian"
    elif [ -f /etc/fedora-release ]; then
        os_type="fedora"
    elif [ -f /etc/centos-release ]; then
        os_type="centos"
    else
        os_type=$(uname -s)
    fi
    os_type=$(echo $os_type | tr '[:upper:]' '[:lower:]')
    echo "检测到的操作系统: $os_type"
}

# 更新系统
update_system() {
    detect_os
    if [ $? -ne 0 ]; then
        echo -e "${RED}无法检测操作系统。${NC}"
        return 1
    fi
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            update_cmd="apt-get update"
            upgrade_cmd="apt-get upgrade -y"
            clean_cmd="apt-get autoremove -y"
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            if command -v dnf &>/dev/null; then
                update_cmd="dnf check-update"
                upgrade_cmd="dnf upgrade -y"
                clean_cmd="dnf autoremove -y"
            else
                update_cmd="yum check-update"
                upgrade_cmd="yum upgrade -y"
                clean_cmd="yum autoremove -y"
            fi
            ;;
        opensuse*|sles)
            update_cmd="zypper refresh"
            upgrade_cmd="zypper dup -y"
            clean_cmd="zypper clean -a"
            ;;
        arch|manjaro)
            update_cmd="pacman -Sy"
            upgrade_cmd="pacman -Syu --noconfirm"
            clean_cmd="pacman -Sc --noconfirm"
            ;;
        alpine)
            update_cmd="apk update"
            upgrade_cmd="apk upgrade"
            clean_cmd="apk cache clean"
            ;;
        gentoo)
            update_cmd="emerge --sync"
            upgrade_cmd="emerge -uDN @world"
            clean_cmd="emerge --depclean"
            ;;
        cloudlinux)
            update_cmd="yum check-update"
            upgrade_cmd="yum upgrade -y"
            clean_cmd="yum clean all"
            ;;
        *)
            echo -e "${RED}不支持的 Linux 发行版: $os_type${NC}"
            return 1
            ;;
    esac
    
    echo -e "${YELLOW}正在更新系统...${NC}"
    sudo $update_cmd
    if [ $? -eq 0 ]; then
        sudo $upgrade_cmd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}系统更新完成。${NC}"
            echo -e "${YELLOW}正在清理系统...${NC}"
            sudo $clean_cmd
            echo -e "${GREEN}系统清理完成。${NC}"
            # 检查是否需要重启
            if [ -f /var/run/reboot-required ]; then
                echo -e "${YELLOW}系统更新需要重启才能完成。请在方便时重启系统。${NC}"
            fi
            return 0
        fi
    fi
    echo -e "${RED}系统更新失败。${NC}"
    return 1
}


# 定义支持的操作系统类型
SUPPORTED_OS=("ubuntu" "debian" "linuxmint" "elementary" "pop" "centos" "rhel" "fedora" "rocky" "almalinux" "openeuler" "opensuse" "sles" "arch" "manjaro" "alpine" "gentoo" "cloudlinux")

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}正在检查并安装必要的依赖项...${NC}"
    
    # 确保 os_type 已定义
    if [ -z "$os_type" ]; then
        detect_os
    fi

    # 定义安装命令
    case "${os_type,,}" in
        ubuntu|debian|linuxmint|elementary|pop)
            install_cmd="apt-get install -y"
            ;;
        centos|rhel|fedora|rocky|almalinux|openeuler)
            install_cmd="yum install -y"
            ;;
        opensuse*|sles)
            install_cmd="zypper install -y"
            ;;
        arch|manjaro)
            install_cmd="pacman -S --noconfirm"
            ;;
        alpine)
            install_cmd="apk add"
            ;;
        gentoo)
            install_cmd="emerge"
            ;;
        cloudlinux)
            install_cmd="yum install -y"
            ;;
        *)
            echo -e "${RED}不支持的 Linux 发行版: $os_type${NC}"
            return 1
            ;;
    esac
    
    # 安装 curl
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}正在安装 curl...${NC}"
        if ! sudo $install_cmd curl; then
            echo -e "${RED}无法安装 curl。请手动安装此依赖项。${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}curl 已安装。${NC}"
    fi
    
    echo -e "${GREEN}依赖项检查和安装完成。${NC}"
}

# 检查并安装依赖
install_dependencies

# 获取IP地址
ip_address() {
    ipv4_address=$(curl -s --max-time 5 ipv4.ip.sb)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi

    ipv6_address=$(curl -s --max-time 5 ipv6.ip.sb)
    if [ -z "$ipv6_address" ]; then
        ipv6_address=$(ip -6 addr show | grep -oP '(?<=inet6\s)[\da-f:]+' | grep -v '^::1' | grep -v '^fe80' | head -n1)
    fi
}

# 创建快捷指令
add_alias() {
    local alias_file="/root/.vps_aliases"
    echo "# VPS script aliases" > "$alias_file"
    echo "alias v='bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh)'" >> "$alias_file"
    echo "alias vps='bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh)'" >> "$alias_file"

    # 在shell配置文件中添加对别名文件的引用
    local config_files=("/root/.bashrc" "/root/.profile" "/root/.bash_profile")
    local updated=false

    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            if ! grep -q "source $alias_file" "$config_file"; then
                echo "source $alias_file" >> "$config_file"
                updated=true
            fi
        fi
    done

    if $updated; then
        echo "别名已添加到配置文件。"
        # 自动执行source命令
        for config_file in "${config_files[@]}"; do
            if [ -f "$config_file" ]; then
                source "$config_file"
                echo "已执行 source $config_file"
                break  # 只需执行一次
            fi
        done
        echo "别名现在应该可以使用了。"
    else
        echo "别名已经存在，无需更新。"
    fi

    # 确保在重启后别名仍然可用
    if [ ! -f "/etc/profile.d/vps_aliases.sh" ]; then
        echo "source $alias_file" | sudo tee /etc/profile.d/vps_aliases.sh > /dev/null
        echo "已创建 /etc/profile.d/vps_aliases.sh 以确保重启后别名仍然可用。"
    fi
}

# 统计使用次数
sum_run_times() {
    local COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Feverett7623%2Fvps_scripts%2Fblob%2Fmain%2Fvps_scripts.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+")
    if [[ -n "$COUNT" ]]; then
        daily_count=$(cut -d " " -f1 <<< "$COUNT")
        total_count=$(cut -d " " -f3 <<< "$COUNT")
    else
        echo "Failed to fetch usage counts."
        daily_count=0
        total_count=0
    fi
}

# 调用函数获取统计数据
sum_run_times
      
#清理系统
clean_system() {
        if command -v apt &>/dev/null; then
          apt autoremove --purge -y && apt clean -y && apt autoclean -y
          apt remove --purge $(dpkg -l | awk '/^rc/ {print $2}') -y
          journalctl --vacuum-time=1s
          journalctl --vacuum-size=50M
          apt remove --purge $(dpkg -l | awk '/^ii linux-(image|headers)-[^ ]+/{print $2}' | grep -v $(uname -r | sed 's/-.*//')) -y
        elif command -v yum &>/dev/null; then
          yum autoremove -y && yum clean all
          journalctl --vacuum-time=1s
          journalctl --vacuum-size=50M
          yum remove $(rpm -q kernel | grep -v $(uname -r)) -y
        elif command -v dnf &>/dev/null; then
          dnf autoremove -y && dnf clean all
          journalctl --vacuum-time=1s
          journalctl --vacuum-size=50M
          dnf remove $(rpm -q kernel | grep -v $(uname -r)) -y
        elif command -v apk &>/dev/null; then
          apk autoremove -y
          apk clean
          journalctl --vacuum-time=1s
          journalctl --vacuum-size=50M
          apk del $(apk info -e | grep '^r' | awk '{print $1}') -y
        else
          echo -e "${RED}暂不支持你的系统！${NC}"
          exit 1
        fi
}

# 显示菜单
show_menu() {
  echo ""
  echo "请选择要执行的脚本："
  echo "------------------------------------------------------------------------------"
  echo -e "${YELLOW}1) 本机信息${NC}                        ${YELLOW}13) VPS一键脚本工具箱${NC}"
  echo -e "${YELLOW}2) 更新系统${NC}                        ${YELLOW}14) jcnf 常用脚本工具包${NC}"
  echo -e "${YELLOW}3) 清理系统${NC}                        ${YELLOW}15) 科技Lion脚本${NC}"
  echo -e "${YELLOW}4) Yabs${NC}                            ${YELLOW}16) BlueSkyXN脚本${NC}"
  echo -e "${YELLOW}5) 融合怪${NC}                          ${YELLOW}17) 勇哥Singbox${NC}"
  echo -e "${YELLOW}6) IP质量${NC}                          ${YELLOW}18) 勇哥X-UI${NC}"
  echo -e "${YELLOW}7) 流媒体解锁${NC}                      ${YELLOW}19) Fscarmen-Singbox${NC}"
  echo -e "${YELLOW}8) 响应测试${NC}                        ${YELLOW}20) 3X-UI${NC}"
  echo -e "${YELLOW}9) 三网测速（多/单线程）${NC}           ${YELLOW}21) 3X-UI优化版${NC}"
  echo -e "${YELLOW}10) AutoTrace三网回程路由${NC}          ${YELLOW}22) 安装Docker${NC}"
  echo -e "${YELLOW}11) 安装并启动iperf3服务端${NC}"
  echo -e "${YELLOW}12) 超售测试${NC}"
  echo "------------------------------------------------------------------------------"
  echo -e "${GREEN}66) NodeLoc聚合测试脚本${NC}"
  echo -e "${YELLOW}88) 更新脚本${NC}"
  echo -e "${YELLOW}99) 卸载脚本${NC}"
  echo -e "${YELLOW}0) 退出${NC}"
  echo "------------------------------------------------------------------------------"
}

# 处理用户选择
handle_choice() {
    local choice=$1
    case $choice in
    1)
      clear
      echo -e "${PURPLE}执行本机信息...${NC}"

      ip_address

      if [ "$(uname -m)" == "x86_64" ]; then
        cpu_info=$(cat /proc/cpuinfo | grep 'model name' | uniq | sed -e 's/model name[[:space:]]*: //')
      else
        cpu_info=$(lscpu | grep 'Model name' | sed -e 's/Model name[[:space:]]*: //')
      fi

      cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}')
      cpu_usage_percent=$(printf "%.2f" "$cpu_usage")%

      cpu_cores=$(nproc)

      mem_info=$(free -b | awk 'NR==2{printf "%.2f/%.2f MB (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')

      disk_info=$(df -h | awk '$NF=="/"{printf "%d/%dGB (%s)", $3,$2,$5}')

      country=$(curl -s ipinfo.io/country)
      city=$(curl -s ipinfo.io/city)

      isp_info=$(curl -s ipinfo.io/org)

      cpu_arch=$(uname -m)

      hostname=$(hostname)

      kernel_version=$(uname -r)

      congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
      queue_algorithm=$(sysctl -n net.core.default_qdisc)

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

      current_time=$(date "+%Y-%m-%d %I:%M %p")

      swap_used=$(free -m | awk 'NR==3{print $3}')
      swap_total=$(free -m | awk 'NR==3{print $2}')

      if [ "$swap_total" -eq 0 ]; then
        swap_percentage=0
      else
        swap_percentage=$((swap_used * 100 / swap_total))
      fi

      swap_info="${swap_used}MB/${swap_total}MB (${swap_percentage}%)"

      runtime=$(cat /proc/uptime | awk -F. '{run_days=int($1 / 86400);run_hours=int(($1 % 86400) / 3600);run_minutes=int(($1 % 3600) / 60); if (run_days > 0) printf("%d天 ", run_days); if (run_hours > 0) printf("%d时 ", run_hours); printf("%d分\n", run_minutes)}')

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
      ;;
    2)
      clear
      echo -e "${PURPLE}执行更新系统...${NC}"
      update_system
      echo "系统更新完成"
      ;;
    3)
      clear
      echo -e "${PURPLE}执行 清理系统...${NC}"
      clean_system
      echo "系统清理完成"
      ;;
    4)
      clear
      echo -e "${PURPLE}执行 Yabs测试...${NC}"
      wget -qO- yabs.sh | bash
      ;;
    5)
      clear
      echo -e "${PURPLE}执行 融合怪测试...${NC}"
      curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
      ;;
    6)
      clear
      echo -e "${PURPLE}执行 IP质量测试...${NC}"
      bash <(curl -Ls IP.Check.Place)
      ;;
    7)
      clear
      echo -e "${PURPLE}执行 流媒体解锁...${NC}"
      bash <(curl -L -s media.ispvps.com)
      ;;
    8)
      clear
      echo -e "${PURPLE}执行 响应测试脚本...${NC}"
      bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
      ;;
    9)
      clear
      echo -e "${PURPLE}执行 三网测速（多/单线程）...${NC}"
      bash <(curl -sL https://raw.githubusercontent.com/i-abc/Speedtest/main/speedtest.sh)
      ;;
    10)
      clear
      echo -e "${PURPLE}执行 AutoTrace三网回程路由...${NC}"
      wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
      ;;
    11)
      clear
      echo -e "${PURPLE}执行 安装并启动iperf3服务端...${NC}"
      apt-get install -y iperf3

      # 检查iperf3是否已经在运行
      if pgrep -x "iperf3" > /dev/null
      then
          echo "iperf3 服务已经在运行。"
      else
          echo "启动iperf3服务..."
          iperf3 -s &
          sleep 2
          if pgrep -x "iperf3" > /dev/null
          then
              echo "iperf3服务启动成功，正在监听端口5201。"
          else
              echo "iperf3服务启动失败，请检查是否有其他程序占用了5201端口。"
          fi
      fi

      echo ""
      echo -e "${PURPLE}服务端操作完成。现在您可以在客户端进行测试。${NC}"
      echo ""
      echo "客户端操作，比如Windows："
      echo -e "${RED}iperf3客户端下载地址(https://iperf.fr/iperf-download.php)${NC}"
      echo "在Windows电脑上，下载iperf3 Windows版本，解压到任意目录，例如D:\iperf3"
      echo "打开命令提示符窗口，切换到iperf3目录:"
      echo "cd D:\iperf3"
      
      echo ""
      echo -e "${BLUE}执行客户端命令，连接到VPS的IP:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC}"
      echo "它会进行10秒的默认TCP下载测试。"
      echo "案例：.\iperf3.exe -c 104.234.111.111"
      echo ""
      echo -e "${BLUE}单线程上传测试:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC} -R"
      echo "该命令会测试从客户端到服务端VPS的上传带宽。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -R"
      echo ""
      echo -e "${BLUE}多线程下载测试:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC}  -P 4"
      echo "这会运行一个4个流并行下载测试。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -P 4"
      echo ""
      echo -e "${BLUE}多线程上传测试:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC}  -R -P 4"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -R -P 4"
      echo ""
      echo -e "${BLUE}长时间下载测试:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC}  -t 60"
      echo "该命令会测试60秒的长时间下载，观察带宽变化。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -t 60"
      echo ""
      echo -e "${BLUE}UDP模拟视频流测试:${NC}"
      echo -e "iperf3.exe -c ${RED}vps_ip${NC}  -u -b 200m"
      echo "以200mbps的码率，测试UDP下载/模拟视频流。"
      echo "您也可以根据实际需求调整目标带宽-b值。"
      echo "案例：.\iperf3.exe -c 104.234.111.11 -u -b 200m"
      echo ""
      echo -e "${BLUE}其他参数示例:${NC}"
      echo -e ".\iperf3.exe -c ${RED}vps_ip${NC}  -i 1       # 每1秒输出带宽报告"
      echo -e ".\iperf3.exe -c ${RED}vps_ip${NC}  -p 5201    # 指定服务端端口为5201"
      ;;
    12)
      clear
      echo -e "${PURPLE}执行 超售测试...${NC}"
      wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh
      ;;
    13)
      clear
      echo -e "${PURPLE}执行 VPS一键脚本工具箱 ...${NC}"
      curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
      ;;
    14)
      clear
      echo -e "${PURPLE}执行 Jcnf 常用脚本工具包 ...${NC}"
      wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh
      ;;
    15)
      clear
      echo -e "${PURPLE}执行 科技Lion脚本...${NC}"
      bash <(curl -sL kejilion.sh)
      ;;
    16)
      clear
      echo -e "${PURPLE}执行 BlueSkyXN脚本 ...${NC}"
      wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
      ;;
    17)
      clear
      echo -e "${PURPLE}执行 勇哥Singbox ...${NC}"
      bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)
      ;;
    18)
      clear
      echo -e "${PURPLE}执行 勇哥X-UI ...${NC}"
      bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh)
      ;;
    19)
      clear
      echo -e "${PURPLE}执行 Fscarmen-Singbox ...${NC}"
      bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
      ;;
    20)
      clear
      echo -e "${PURPLE}执行 3X-UI ...${NC}"
      bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
      ;;
    21)
      clear
      echo -e "${PURPLE}执行 3X-UI优化版...${NC}"
      bash <(curl -Ls https://raw.githubusercontent.com/xeefei/3x-ui/master/install.sh)
      ;;
    22)
      clear
      echo -e "${PURPLE}执行 安装Docker...${NC}"
      curl -fsSL https://get.docker.com | bash -s docker
      ;;
    66)
      clear
      echo -e "${PURPLE}执行 NodeLoc聚合测试脚本...${NC}"
      wget -O Nlbench.sh https://raw.githubusercontent.com/everett7623/nodeloc_vps_test/main/Nlbench.sh && chmod +x Nlbench.sh && ./Nlbench.sh
      ;;
    88)
      clear
      echo -e "${PURPLE}执行更新脚本...${NC}"
      update_scripts
      echo "脚本更新完成"
      ;;
    99)
      clear
      echo -e "${PURPLE}执行 卸载脚本...${NC}"
      
      # 删除之前可能运行过的脚本
      echo -e "${BLUE}删除之前可能运行过的脚本...${NC}"
      [ -f /root/yabs.sh ] && rm -f /root/yabs.sh
      [ -f /root/ecs.sh ] && rm -f /root/ecs.sh
      [ -f /root/memoryCheck.sh ] && rm -f /root/memoryCheck.sh
      [ -f /root/ssh_tool.sh ] && rm -f /root/ssh_tool.sh
      [ -f /root/kejilion.sh ] && rm -f /root/kejilion.sh
      [ -f /root/box.sh ] && rm -f /root/box.sh
      [ -f /root/AutoTrace.sh ] && rm -f /root/AutoTrace.sh

      # 清理可能的残留文件和目录
      echo -e "${BLUE}清理可能的残留文件和目录...${NC}"
      [ -d /tmp/yabs* ] && rm -rf /tmp/yabs*
      [ -f /tmp/bench.sh* ] && rm -rf /tmp/bench.sh*
      [ -f /root/.ssh_tool_cache ] && rm -f /root/.ssh_tool_cache
      [ -f /root/.ssh_tool_backup ] && rm -f /root/.ssh_tool_backup

      # 尝试卸载Docker(如果是通过脚本安装的)
      echo -e "${BLUE}尝试卸载Docker...${NC}"
      if command -v docker &> /dev/null; then
        echo "正在卸载Docker..."
        sudo apt-get remove docker docker-engine docker.io containerd runc -y
        sudo apt-get purge docker-ce docker-ce-cli containerd.io -y
        sudo rm -rf /var/lib/docker /etc/docker
        sudo groupdel docker 2>/dev/null
        sudo rm -rf /var/run/docker.sock
      fi

      # 删除主脚本及其相关文件
      echo -e "${BLUE}删除主脚本及其相关文件...${NC}"
      [ -f /root/vps_scripts.sh ] && rm -f /root/vps_scripts.sh
      [ -f /root/.vps_script_count ] && rm -f /root/.vps_script_count
      [ -f /root/.vps_script_daily_count ] && rm -f /root/.vps_script_daily_count
      [ -f /tmp/vps_scripts_updated.flag ] && rm -f /tmp/vps_scripts_updated.flag
      
      echo "脚本卸载完成"
      ;;
    0)
    clear
    exit
      ;;
    *)
      echo -e "${PURPLE}无效选择，请重新输入。${NC}"
      ;;
    esac

      # 等待用户按回车返回主菜单
      read -p "按回车键返回主菜单..."
}

# 调用函数创建别名
add_alias

clear
# 输出欢迎信息
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""
echo "VPS脚本集合 $VERSION"
echo "GitHub地址: https://github.com/everett7623/vps_scripts"
echo "VPS选购: https://www.nodeloc.com/vps"
echo ""
echo -e "${colors[0]} #     # #####   #####       #####   #####  #####   ### #####  #####  #####  ${NC}"
echo -e "${colors[1]} #     # #    # #     #     #     # #     # #    #   #  #    #   #   #     # ${NC}"
echo -e "${colors[2]} #     # #    # #           #       #       #    #   #  #    #   #   #       ${NC}"
echo -e "${colors[3]} #     # #####   #####       #####  #       #####    #  #####    #    #####  ${NC}"
echo -e "${colors[4]}  #   #  #            #           # #       #   #    #  #        #         # ${NC}"
echo -e "${colors[3]}   # #   #      #     #     #     # #     # #    #   #  #        #   #     # ${NC}"
echo -e "${colors[2]}    #    #       #####       #####   #####  #     # ### #        #    #####  ${NC}"
echo ""
echo "支持Ubuntu/Debian"
echo ""
echo -e "快捷键已设置为${RED}v${NC}或${RED}vps${NC},下次运行输入${RED}v${NC}或${RED}vps${NC}可快速启动此脚本"
echo ""
echo -e "今日运行次数: ${PURPLE}$daily_count${NC} 次，累计运行次数: ${PURPLE}$total_count${NC} 次"
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""

# 主循坏
while true; do
    show_menu
    read -p "输入数字选择对应的脚本: " choice
    handle_choice "$choice"
done
