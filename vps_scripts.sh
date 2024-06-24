#!/bin/bash

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
    flock -x 200
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
} 200>"$DAILY_COUNT_FILE.lock"

# 输出统计信息和脚本信息
clear
echo "当日运行：$DAILY_COUNT 次   累计运行：$TOTAL_COUNT 次"
echo ""
echo "-----------------By'Jensfrank-----------------"
echo ""
echo "脚本地址: https://github.com/everett7623/vps_scripts"
echo ""
echo "#     #  #####   #####     #####   #####  #####  ### #####  #######  #####  "
echo "#     # #     # #     #   #     # #     # #    #  #  #    #    #    #     # "
echo "#     # #       #         #       #       #    #  #  #    #    #    #       "
echo "#     #  #####   #####    #        #####  #####   #  #####     #     #####  "
echo " #   #        #       #   #             # #   #   #  #         #          # "
echo "  # #   #     # #     #   #     # #     # #    #  #  #         #    #     # "
echo "   #     #####   #####     #####   #####  #     # ### #         #    #####  "
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
  echo "2) yabs"
  echo "3) 融合怪"
  echo "4) IP质量体检"
  echo "5) 流媒体解锁"
  echo "6) AutoTrace 三网回程路由"
  echo "7) 响应测试"
  echo "8) 三网测速（含多/单线程）"
  echo "9) 超售测试脚本"
  echo "10) VPS一键脚本工具箱"
  echo "11) Kejilion脚本"
  echo "12) BlueSkyXN脚本(开启Swap等)"
  echo "13) 安装docker"
  echo "14) 完全卸载删除脚本"
  echo "0) 退出"

  read -p "输入数字选择对应的脚本: " choice

  case $choice in
    1)
      echo "执行系统更新..."
      sudo apt update && sudo apt upgrade -y
      ;;
    2)
      echo "执行 yabs 脚本..."
      wget -qO- yabs.sh | bash
      ;;
    3)
      echo "执行 融合怪 脚本..."
      curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
      ;;
    4)
      echo "执行 IP质量体检 脚本..."
      bash <(curl -Ls IP.Check.Place)
      ;;
    5)
      echo "执行 流媒体解锁 脚本..."
      bash <(curl -L -s media.ispvps.com)
      ;;
    6)
      echo "执行 AutoTrace 三网回程路由 脚本..."
      wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
      ;;
    7)
      echo "执行 响应测试 脚本..."
      bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
      ;;
    8)
      echo "执行 三网测速（含多/单线程） 脚本..."
      bash <(curl -sL bash.icu/speedtest)
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
      echo "执行 Kejilion脚本 脚本..."
      curl -sS -O https://raw.githubusercontent.com/kejilion/sh/main/kejilion.sh && chmod +x kejilion.sh && ./kejilion.sh
      ;;
    12)
      echo "执行 BlueSkyXN脚本(开启Swap等) 脚本..."
      wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
      ;;
    13)
      echo "执行 安装docker 脚本..."
      curl -fsSL https://get.docker.com | bash -s docker
      ;;
    14)
      echo "执行完全卸载删除脚本..."
      # 删除脚本文件
      rm -f /root/vps_scripts.sh
      # 删除统计文件
      rm -f /root/.vps_script_count /root/.vps_script_daily_count
      # 删除快捷键设置
      sed -i '/alias v='"'"'bash \/root\/vps_scripts.sh'"'"'/d' /root/.bashrc
      source /root/.bashrc
      echo "脚本已完全卸载并删除。"
      echo "请手动关闭当前终端会话以使更改生效。"
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
