#!/bin/bash
# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
# 定义渐变颜色数组
colors=(
    '\033[38;2;0;255;0m'    # 绿色
    '\033[38;2;64;255;0m'
    '\033[38;2;128;255;0m'
    '\033[38;2;192;255;0m'
    '\033[38;2;255;255;0m'  # 黄色
)

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限运行。"
    exit 1
fi

# 定义脚本URL和版本URL
SCRIPT_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh"
VERSION_URL="https://raw.githubusercontent.com/everett7623/vps_scripts/main/version.txt"
UPDATE_FLAG="/tmp/vps_scripts_updated.flag"

# 检查脚本更新
check_update() {
    local current_version=$(grep "VPS脚本集合 v" "$0" | cut -d'v' -f2)
    local version_url="https://raw.githubusercontent.com/everett7623/vps_scripts/main/version.txt"
    local script_url="https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh"

    echo "检查更新..."
    local latest_version=$(curl -s "$version_url")
    
    if [[ "$latest_version" != "$current_version" ]]; then
        echo "发现新版本: $latest_version"
        echo "正在更新..."
        if curl -o "$0" "$script_url"; then
            echo "更新成功，请重新运行脚本"
            exit 0
        else
            echo "更新失败，继续使用当前版本"
        fi
    else
        echo "已是最新版本"
    fi
}

# 统计使用次数
sum_run_times() {
    local COUNT
    COUNT=$(wget --no-check-certificate -qO- --tries=2 --timeout=2 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Feverett7623%2Fvps_scripts%2Fblob%2Fmain%2Fvps_scripts.sh" 2>&1 | grep -m1 -oE "[0-9]+[ ]+/[ ]+[0-9]+")
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

clear
# 输出欢迎信息
echo "今日运行次数: $daily_count，累计运行次数: $total_count"
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""
echo "VPS脚本集合 v2024.06.24"
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
echo -e "快捷键已设置为${RED}v${NC},下次运行输入${RED}v${NC}可快速启动此脚本"
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""

# 检查当前用户是否具有 sudo 权限
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要 root 权限运行。"
    echo "请使用具有 sudo 权限的用户运行此脚本。"
    exit 1
fi

# 在需要时获取 sudo 权限
sudo -v >/dev/null 2>&1 || { echo "无法获取 sudo 权限，退出脚本。"; exit 1; }

# 检查并安装依赖
echo "检查并安装必要的依赖项..."

# 检查和安装 curl
if ! command -v curl &> /dev/null; then
    echo "curl 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y curl
else
    echo "curl 已安装"
fi

# 检查和安装 wget
if ! command -v wget &> /dev/null; then
    echo "wget 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y wget
else
    echo "wget 已安装"
fi

# 检查 bash（一般来说不需要安装，因为通常是系统默认的 shell）
if ! command -v bash &> /dev/null; then
    echo "bash 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y bash
else
    echo "bash 已安装"
fi

echo "依赖项安装完成。"

# 主菜单
while true; do
  echo ""
  echo "请选择要执行的脚本："
  echo -e "${YELLOW}1) 更新系统${NC}"
  echo -e "${YELLOW}2) Yabs${NC}"
  echo -e "${YELLOW}3) 融合怪${NC}"
  echo -e "${YELLOW}4) IP质量${NC}"
  echo -e "${YELLOW}5) 流媒体解锁${NC}"
  echo -e "${YELLOW}6) 响应测试${NC}"
  echo -e "${YELLOW}7) 三网测速（多/单线程）${NC}"
  echo -e "${YELLOW}8) 安装并启动iperf3服务端 ${NC}"
  echo -e "${YELLOW}9) AutoTrace三网回程路由${NC}"
  echo -e "${YELLOW}10) 超售测试${NC}"
  echo -e "${YELLOW}11) VPS一键脚本工具箱${NC}"
  echo -e "${YELLOW}12) jcnf 常用脚本工具包${NC}"
  echo -e "${YELLOW}13) 科技lion脚本${NC}"
  echo -e "${YELLOW}14) BlueSkyXN脚本${NC}"
  echo -e "${YELLOW}15) 勇哥Singbox${NC}"
  echo -e "${YELLOW}16) 勇哥x-ui${NC}"
  echo -e "${YELLOW}17) Fscarmen-Singbox${NC}"
  echo -e "${YELLOW}18) Mack-a八合一${NC}"
  echo -e "${YELLOW}19) Warp集合${NC}"
  echo -e "${YELLOW}20) 安装docker${NC}"
  echo -e "${YELLOW}98) 清理系统${NC}"
  echo -e "${YELLOW}99) 卸载脚本${NC}"
  echo -e "${YELLOW}0) 退出${NC}"
  
  read -p "输入数字选择对应的脚本: " choice

  case $choice in
    1)
      clear
      echo -e "${YELLOW}执行更新系统...${NC}"
      (sudo apt update && sudo apt upgrade -y) &
      pid=$!
      while kill -0 $pid 2>/dev/null; do
          echo -n "."
          sleep 1
      done
      echo "更新完成"
      ;;
    2)
      clear
      echo -e "${YELLOW}执行 Yabs 脚本...${NC}"
      wget -qO- yabs.sh | bash
      ;;
    3)
      clear
      echo -e "${YELLOW}执行 融合怪 脚本...${NC}"
      curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
      ;;
    4)
      clear
      echo -e "${YELLOW}执行 IP质量 脚本...${NC}"
      bash <(curl -Ls IP.Check.Place)
      ;;
    5)
      clear
      echo -e "${YELLOW}执行 流媒体解锁 脚本...${NC}"
      bash <(curl -L -s media.ispvps.com)
      ;;
    6)
      clear
      echo -e "${YELLOW}执行 响应测试 脚本...${NC}"
      bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
      ;;
    7)
      clear
      echo -e "${YELLOW}执行 三网测速（多/单线程） 脚本...${NC}"
      bash <(curl -sL bash.icu/speedtest)
      ;;
    8)
      clear
      echo -e "${YELLOW}执行 安装并启动iperf3服务端 脚本...${NC}"
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

      echo -e "${BLUE}上面的操作是客户端操作案例，下面启动服务端iperf3服务端:${NC}"
      echo "不加任何参数，则默认监听TCP端口5201"
      echo -e "${BLUE}等待看到服务端监听端口5201后 回到客户端按照案例操作即可:${NC}"
      apt-get install -y iperf3
      iperf3 -s
      ;;
    9)
      clear
      echo -e "${YELLOW}执行 AutoTrace三网回程路由 脚本...${NC}"
      wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
      ;;
    10)
      clear
      echo -e "${YELLOW}执行 超售测试脚本 脚本...${NC}"
      wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh
      ;;
    11)
      clear
      echo -e "${YELLOW}执行 VPS一键脚本工具箱 脚本...${NC}"
      bash <(curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh)
      ;;
    12)
      clear
      echo -e "${YELLOW}执行 jcnf 常用脚本工具包 脚本...${NC}"
      wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh
      ;;
    13)
      clear
      echo -e "${YELLOW}执行 科技lion脚本 脚本...${NC}"
      curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
      ;;
    14)
      clear
      echo -e "${YELLOW}执行 BlueSkyXN脚本 脚本...${NC}"
      wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
      ;;
    15)
      clear
      echo -e "${YELLOW}执行 勇哥Singbox 脚本...${NC}"
      bash <(curl -Ls https://gitlab.com/rwkgyg/sing-box-yg/raw/main/sb.sh)
      ;;
    16)
      clear
      echo -e "${YELLOW}执行 勇哥x-ui 脚本...${NC}"
      bash <(curl -Ls https://gitlab.com/rwkgyg/x-ui-yg/raw/main/install.sh
      ;;
    17)
      clear
      echo -e "${YELLOW}执行 Fscarmen-Singbox 脚本...${NC}"
      bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)
      ;;
    18)
      clear
      echo -e "${YELLOW}执行 Mack-a八合一 脚本...${NC}"
      wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
      ;;
    19)
      clear
      echo -e "${YELLOW}执行 Warp集合 脚本...${NC}"
      bash <(curl -sSL https://gitlab.com/fscarmen/warp_unlock/-/raw/main/unlock.sh)
      ;;
    20)
      clear
      echo -e "${YELLOW}执行 安装docker 脚本...${NC}"
      curl -fsSL https://get.docker.com | bash -s docker
      ;;
    98)
      clear
      echo -e "${YELLOW}执行 清理系统...${NC}"
      clean_system
      echo "清理完成"
      ;;
    99)
      clear
      echo -e "${YELLOW}执行 卸载脚本...${NC}"
      
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
      
      echo "卸载完成"
      ;;
    0)
      break
      ;;
    *)
      echo -e "${RED}无效选择，请重新输入。${NC}"
      ;;
  esac

  # 等待用户按回车返回主菜单
  read -p "按回车键返回主菜单..."
done
