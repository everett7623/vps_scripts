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

# 自动更新函数
auto_update() {
    echo "正在检查更新..."
    LATEST_VERSION=$(curl -s -H "Cache-Control: no-cache" "$VERSION_URL")
    if [ -z "$LATEST_VERSION" ]; then
        echo "无法检查更新，继续使用当前版本。"
        return
    fi
    
    echo "正在更新到最新版本..."
    TEMP_FILE=$(mktemp)
    if wget -O "$TEMP_FILE" "$SCRIPT_URL"; then
        mv "$TEMP_FILE" "$0"
        echo "更新完成，设置更新标志并重新启动脚本..."
        touch "$UPDATE_FLAG"
        exec bash "$0"
        exit
    else
        echo "更新失败，继续使用当前版本。"
        rm -f "$TEMP_FILE"
    fi
}

# 检查是否存在更新标志
if [ ! -f "$UPDATE_FLAG" ]; then
    auto_update
else
    echo "检测到更新标志，跳过更新检查。"
    rm -f "$UPDATE_FLAG"
fi

# 统计运行次数
COUNT_FILE="/root/.vps_script_count"
DAILY_COUNT_FILE="/root/.vps_script_daily_count"
TODAY=$(date +%Y-%m-%d)

# 使用锁机制更新累计运行次数
{
    flock -x 200
    if [ -f "$COUNT_FILE" ]; then
        TOTAL_COUNT=$(cat "$COUNT_FILE")
        TOTAL_COUNT=$((TOTAL_COUNT + 1))
    else
        TOTAL_COUNT=1
    fi
    echo $TOTAL_COUNT > "$COUNT_FILE"
} 200>"$COUNT_FILE.lock"

# 使用锁机制更新当日运行次数
{
    flock -x 201
    if [ -f "$DAILY_COUNT_FILE" ]; then
        LAST_DATE=$(head -n 1 "$DAILY_COUNT_FILE")
        if [ "$LAST_DATE" = "$TODAY" ]; then
            DAILY_COUNT=$(tail -n 1 "$DAILY_COUNT_FILE")
            DAILY_COUNT=$((DAILY_COUNT + 1))
        else
            DAILY_COUNT=1
        fi
    else
        DAILY_COUNT=1
    fi
    echo "$TODAY" > "$DAILY_COUNT_FILE"
    echo "$DAILY_COUNT" >> "$DAILY_COUNT_FILE"
} 201>"$DAILY_COUNT_FILE.lock"

# 输出统计信息和脚本信息
clear
echo "当日运行：$DAILY_COUNT 次   累计运行：$TOTAL_COUNT 次"
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""
echo "VPS脚本集合 v2024.06.24"
echo "GitHub地址: https://github.com/everett7623/vps_scripts"
echo "VPS选购: https://www.nodeloc.com/vps"
echo ""
echo -e "${colors[0]}#     # #####   #####       #####   #####  #####  ### #####  #######  #####  ${NC}"
echo -e "${colors[1]}#     # #    # #     #     #     # #     # #    #  #  #    #    #    #     # ${NC}"
echo -e "${colors[2]}#     # #    # #           #       #       #    #  #  #    #    #    #       ${NC}"
echo -e "${colors[3]}#     # #####   #####      #        #####  #####   #  #####     #     #####  ${NC}"
echo -e "${colors[4]} #   #  #            #     #             # #   #   #  #         #          # ${NC}"
echo -e "${colors[3]}  # #   #      #     #     #     # #     # #    #  #  #         #    #     # ${NC}"
echo -e "${colors[2]}   #    #       #####       #####   #####  #     # ### #         #    #####  ${NC}"
echo ""
echo "支持Ubuntu/Debian"
echo -e "快捷键已设置为${RED}v${NC},下次运行输入${RED}v${NC}可快速启动此脚本"
echo ""
echo -e "${YELLOW}---------------------------------By'Jensfrank---------------------------------${NC}"
echo ""

# 设置快捷键
if ! grep -qxF "alias v='bash /root/vps_scripts.sh'" /root/.bashrc; then
    echo "alias v='bash /root/vps_scripts.sh'" >> /root/.bashrc
    # 立即加载 .bashrc 以使快捷键生效
    source /root/.bashrc
    echo "快捷键'v'已设置并激活。"
else
    echo "快捷键'v'已存在。"
fi

# 提示用户重新登录或重新加载 .bashrc
echo "请执行 'source ~/.bashrc' 或重新登录以确保快捷键生效。"

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
  echo -e "${YELLOW}17) Sing-box全家桶${NC}"
  echo -e "${YELLOW}18) Mack-a八合一${NC}"
  echo -e "${YELLOW}19) 安装docker${NC}"
  echo -e "${YELLOW}20) 卸载测试脚本${NC}"
  echo -e "${YELLOW}21) 卸载全部脚本${NC}"
  echo -e "${YELLOW}0) 退出${NC}"
  
  read -p "输入数字选择对应的脚本: " choice

  case $choice in
    1)
      clear
      echo -e "${YELLOW}执行系统更新...${NC}"
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
      echo "不加任何参数，则默认监听TCP端口5201"
      echo "后续步骤去客户端操作，比如Windows："
      echo "iperf3客户端下载地址（https://iperf.fr/iperf-download.php）"
      echo "在Windows电脑上，下载iperf3 Windows版本，解压到任意目录，例如D:\iperf3"
      echo "打开命令提示符窗口，切换到iperf3目录:"
      echo "cd D:\iperf3"
      
      echo ""
      echo -e "${BLUE}执行客户端命令，连接到VPS的IP:${NC}"
      echo -e ""iperf3.exe -c ${RED}vps_ip${NC}"
      echo "它会进行10秒的默认TCP下载测试。"
      echo "案例：.\iperf3.exe -c 104.234.111.111"

      echo ""
      echo -e "${BLUE}单线程上传测试:${NC}"
      echo "iperf3.exe -c vps_ip -R"
      echo "该命令会测试从客户端到服务端(VPS)的上传带宽。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -R"

      echo ""
      echo -e "${BLUE}多线程下载测试:${NC}"
      echo "iperf3.exe -c vps_ip -P 4"
      echo "这会运行一个4个流并行下载测试。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -P 4"

      echo ""
      echo -e "${BLUE}多线程上传测试:${NC}"
      echo "iperf3.exe -c vps_ip -R -P 4"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -R -P 4"

      echo ""
      echo -e "${BLUE}长时间下载测试:${NC}"
      echo "iperf3.exe -c vps_ip -t 60"
      echo "该命令会测试1分钟(60秒)的长时间下载，观察带宽变化。"
      echo "案例：.\iperf3.exe -c 104.234.111.111 -t 60"

      echo ""
      echo -e "${BLUE}UDP模拟视频流测试:${NC}"
      echo "iperf3.exe -c vps_ip -u -b 200m"
      echo "以200mbps的码率，测试UDP下载(模拟视频流)"
      echo "您也可以根据实际需求调整目标带宽-b值。"
      echo "案例：.\iperf3.exe -c 104.234.111.11 -u -b 200m"

      echo ""
      echo -e "${BLUE}其他参数示例:${NC}"
      echo ".\iperf3.exe -c vps_ip -i 1       # 每1秒输出带宽报告"
      echo ".\iperf3.exe -c vps_ip -p 5201    # 指定服务端端口为5201"

      echo -e "${BLUE}上面的操作是客户端参考，下面启动服务端iperf3服务端:${NC}"
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
      curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-setup/main/sb.sh
      ;;
    16)
      echo -e "${YELLOW}执行 勇哥x-ui 脚本...${NC}"
      curl -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-setup/main/x-ui.sh
      ;;
    17)
      clear
      echo -e "${YELLOW}执行 Sing-box全家桶 脚本...${NC}"
      curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-setup/main/sb-full.sh
      ;;
    18)
      clear
      echo -e "${YELLOW}执行 Mack-a八合一 脚本...${NC}"
      curl -Ls https://raw.githubusercontent.com/mack-a/v2ray-agent/main/install.sh
      ;;
    19)
      clear
      echo -e "${YELLOW}执行 安装docker 脚本...${NC}"
      curl -fsSL https://get.docker.com | bash -s docker
      ;;
    20)
      clear
      echo -e "${YELLOW}执行 卸载测试脚本...${NC}"
      # 删除所有相关测试脚本文件
      [ -f /root/ecs.sh ] && rm -f /root/ecs.sh
      [ -f /root/yabs.sh ] && rm -f /root/yabs.sh
      [ -f /root/memoryCheck.sh ] && rm -f /root/memoryCheck.sh
      [ -f /root/ssh_tool.sh ] && rm -f /root/ssh_tool.sh
      [ -f /root/jcnfbox.sh ] && rm -f /root/jcnfbox.sh
      [ -f /root/kejilion.sh ] && rm -f /root/kejilion.sh
      [ -f /root/box.sh ] && rm -f /root/box.sh
      [ -f /root/AutoTrace.sh ] && rm -f /root/AutoTrace.sh
      echo "所有测试脚本文件已被删除。"
      ;;
    21)
      clear
      echo -e "${YELLOW}执行 卸载全部脚本...${NC}"
      # 删除之前可能运行过的脚本
      [ -f /root/yabs.sh ] && rm -f /root/yabs.sh
      [ -f /root/ecs.sh ] && rm -f /root/ecs.sh
      [ -f /root/memoryCheck.sh ] && rm -f /root/memoryCheck.sh
      [ -f /root/ssh_tool.sh ] && rm -f /root/ssh_tool.sh
      [ -f /root/kejilion.sh ] && rm -f /root/kejilion.sh
      [ -f /root/box.sh ] && rm -f /root/box.sh
      [ -f /root/AutoTrace.sh ] && rm -f /root/AutoTrace.sh

      # 清理可能的残留文件和目录
      [ -d /tmp/yabs* ] && rm -rf /tmp/yabs*
      [ -f /tmp/bench.sh* ] && rm -rf /tmp/bench.sh*
      [ -f /root/.ssh_tool_cache ] && rm -f /root/.ssh_tool_cache
      [ -f /root/.ssh_tool_backup ] && rm -f /root/.ssh_tool_backup

      # 尝试卸载Docker(如果是通过脚本安装的)
      if command -v docker &> /dev/null; then
        echo "正在卸载Docker..."
        sudo apt-get remove docker docker-engine docker.io containerd runc -y
        sudo apt-get purge docker-ce docker-ce-cli containerd.io -y
        sudo rm -rf /var/lib/docker /etc/docker
        sudo groupdel docker 2>/dev/null
        sudo rm -rf /var/run/docker.sock
      fi

      # 删除主脚本及其相关文件
      [ -f /root/vps_scripts.sh ] && rm -f /root/vps_scripts.sh
      [ -f /root/.vps_script_count ] && rm -f /root/.vps_script_count
      [ -f /root/.vps_script_daily_count ] && rm -f /root/.vps_script_daily_count
      [ -f /tmp/vps_scripts_updated.flag ] && rm -f /tmp/vps_scripts_updated.flag

      # 删除快捷键设置
      sed -i '/alias v='"'"'bash \/root\/vps_scripts.sh'"'"'/d' /root/.bashrc
  
      echo "所有相关脚本和文件已被删除。"
      echo "注意: 系统更新和某些全局更改无法撤销。"
      echo "请执行 'source ~/.bashrc' 或重新登录以使快捷键更改生效。"
      exit 0
      ;;
    0)
      echo -e "${YELLOW}退出${NC}"
      break
      ;;
    *)
      echo -e "${YELLOW}无效的选择，请重新输入${NC}"
      ;;
  esac

  # 等待用户按回车返回主菜单
  read -p "${YELLOW}按回车键返回主菜单...${NC}"
done
