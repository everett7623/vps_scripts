#!/bin/bash

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

# 脚本菜单
echo "请选择要执行的脚本："
echo "1) yabs"
echo "2) 融合怪"
echo "3) IP质量体检"
echo "4) 流媒体解锁"
echo "5) AutoTrace 三网回程路由"
echo "6) 响应测试"
echo "7) 三网测速（含多/单线程）"
echo "8) 超售测试脚本"
echo "9) VPS一键脚本工具箱"
echo "10) Kejilion脚本"
echo "11) BlueSkyXN脚本(开启Swap等)"
echo "12) 安装docker"

read -p "输入数字选择对应的脚本: " choice

case $choice in
  1)
    echo "执行 yabs 脚本..."
    wget -qO- yabs.sh | bash
    ;;
  2)
    echo "执行 融合怪 脚本..."
    curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
    ;;
  3)
    echo "执行 IP质量体检 脚本..."
    bash <(curl -Ls IP.Check.Place)
    ;;
  4)
    echo "执行 流媒体解锁 脚本..."
    bash <(curl -L -s media.ispvps.com)
    ;;
  5)
    echo "执行 AutoTrace 三网回程路由 脚本..."
    wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
    ;;
  6)
    echo "执行 响应测试 脚本..."
    bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
    ;;
  7)
    echo "执行 三网测速（含多/单线程） 脚本..."
    bash <(curl -sL bash.icu/speedtest)
    ;;
  8)
    echo "执行 超售测试脚本 脚本..."
    wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh
    ;;
  9)
    echo "执行 VPS一键脚本工具箱 脚本..."
    curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
    ;;
  10)
    echo "执行 Kejilion脚本 脚本..."
    curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
    ;;
  11)
    echo "执行 BlueSkyXN脚本(开启Swap等) 脚本..."
    wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
    ;;
  12)
    echo "执行 安装docker 脚本..."
    curl -fsSL https://get.docker.com | bash -s docker
    ;;
  *)
    echo "无效的选择"
    ;;
esac
