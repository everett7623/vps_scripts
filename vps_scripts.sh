#!/bin/bash

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
echo "-----------------By'Jensfrank-----------------"
echo ""
echo "脚本地址: https://github.com/everett7623/vps_scripts"
echo ""
echo "#     # #####   #####    #####   #####  #####  ### #####  #######  #####  "
echo "#     # #    # #     #  #     # #     # #    #  #  #    #    #    #     # "
echo "#     # #    # #        #       #       #    #  #  #    #    #    #       "
echo "#     # #####   #####   #        #####  #####   #  #####     #     #####  "
echo " #   #  #             #  #             # #   #   #  #         #          # "
echo "  # #   #       #     #  #     # #     # #    #  #  #         #    #     # "
echo "   #    #        #####    #####   #####  #     # ### #         #    #####  "
echo ""
echo "                            VPS脚本集合 v2024.06.24"
echo "支持Ubuntu/Debian"
echo "快捷键已设置为v,下次运行输入v可快速启动此脚本"
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

# 检查并安装依赖
echo "检查并安装必要的依赖项..."

# 检查是否安装curl
if ! command -v curl &> /dev/null; then
    echo "curl 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y curl
else
    echo "curl 已安装"
fi

# 检查是否安装wget
if ! command -v wget &> /dev/null; then
    echo "wget 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y wget
else
    echo "wget 已安装"
fi

# 检查是否安装bash
if ! command -v bash &> /dev/null; then
    echo "bash 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y bash
else
    echo "bash 已安装"
fi

echo "依赖项安装完成。"

while true; do
  echo "请选择要执行的脚本："
  echo "1) 更新系统"
  echo "2) Yabs"
  echo "3) 融合怪"
  echo "4) IP质量"
  echo "5) 流媒体解锁"
  echo "6) 响应测试"
  echo "7) 三网测速（多/单线程）"
  echo "8) 三网回程路由"
  echo "9) 超售测试"
  echo "10) VPS一键脚本工具箱"
  echo "11) jcnf 常用脚本工具包"
  echo "12) 科技lion脚本"
  echo "13) BlueSkyXN脚本"
  echo "14) 勇哥Singbox"
  echo "15) 勇哥x-ui"
  echo "16) Sing-box全家桶"
  echo "17) Mack-a八合一"
  echo "18) 安装docker"
  echo "19) 完全卸载删除测试脚本"  
  echo "20) 完全卸载删除全部脚本"
  echo "0) 退出"

  read -p "输入数字选择对应的脚本: " choice

  case $choice in
    1)
      echo "执行系统更新..."
      (sudo apt update && sudo apt upgrade -y) &
      pid=$!
      while kill -0 $pid 2>/dev/null; do
          echo -n "."
          sleep 1
      done
      echo "更新完成"
      ;;
    2)
      echo "执行 Yabs 脚本..."
      wget -qO- yabs.sh | bash
      ;;
    3)
      echo "执行 融合怪 脚本..."
      curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
      ;;
    4)
      echo "执行 IP质量 脚本..."
      bash <(curl -Ls https://www.ipcheck.tools/check)
      ;;
    5)
      echo "执行 流媒体解锁 脚本..."
      bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh)
      ;;
    6)
      echo "执行 响应测试 脚本..."
      bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
      ;;
    7)
      echo "执行 三网测速（多/单线程） 脚本..."
      bash <(curl -sL bash.icu/speedtest)
      ;;
    8)
      echo "执行 三网回程路由 脚本..."
      wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
      ;;
    9)
      echo "执行 超售测试脚本 脚本..."
      wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh
      ;;
    10)
      echo "执行 VPS一键脚本工具箱 脚本..."
      curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
      ;;
    11)
      echo "执行 jcnf 常用脚本工具包 脚本..."
      wget -O jcnfbox.sh https://raw.githubusercontent.com/Netflixxp/jcnf-box/main/jcnfbox.sh && chmod +x jcnfbox.sh && clear && ./jcnfbox.sh
      ;;
    12)
      echo "执行 科技lion脚本 脚本..."
      curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
      ;;
    13)
      echo "执行 BlueSkyXN脚本 脚本..."
      wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
      ;;
    14)
      echo "执行 勇哥Singbox 脚本..."
      bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-setup/main/sb.sh)
      ;;
    15)
      echo "执行 勇哥x-ui 脚本..."
      bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-setup/main/x-ui.sh)
      ;;
    16)
      echo "执行 Sing-box全家桶 脚本..."
      bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-setup/main/sb-full.sh)
      ;;
    17)
      echo "执行 Mack-a八合一 脚本..."
      bash <(curl -Ls https://raw.githubusercontent.com/mack-a/v2ray-agent/main/install.sh)
      ;;
    18)
      echo "执行 安装docker 脚本..."
      curl -fsSL https://get.docker.com | bash -s docker
      ;;
    19)
      echo "完全卸载删除测试脚本..."
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
    20)
      echo "完全卸载删除全部脚本..."
      # 删除之前可能运行过的脚本(2-13选项)
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
      echo "退出"
      break
      ;;
    *)
      echo "无效的选择，请重新输入"
      ;;
  esac

  # 等待用户按回车返回主菜单
  read -p "按回车键返回主菜单..."
done
