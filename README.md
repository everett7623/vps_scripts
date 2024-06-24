集合了自己常用的一些脚本

1，yabs：wget -qO- yabs.sh | bash
2，融合怪：curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh
3，IP质量体检：bash <(curl -Ls IP.Check.Place)
4，流媒体解锁：bash <(curl -L -s media.ispvps.com)
5，AutoTrace 三网回程路由：wget -N --no-check-certificate https://raw.githubusercontent.com/Chennhaoo/Shell_Bash/master/AutoTrace.sh && chmod +x AutoTrace.sh && bash AutoTrace.sh
6，响应测试：
bash <(curl -sL https://nodebench.mereith.com/scripts/curltime.sh)
7，三网测速（含多/单线程）：
bash <(curl -sL bash.icu/speedtest)
8，超售测试脚本：命令：wget --no-check-certificate -O memoryCheck.sh https://raw.githubusercontent.com/uselibrary/memoryCheck/main/memoryCheck.sh && chmod +x memoryCheck.sh && bash memoryCheck.sh
9，VPS一键脚本工具箱：curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
10. Kejilion脚本：curl -fsSL https://raw.githubusercontent.com/eooce/ssh_tool/main/ssh_tool.sh -o ssh_tool.sh && chmod +x ssh_tool.sh && ./ssh_tool.sh
11.BlueSkyXN脚本(开启Swap等)：wget -O box.sh https://raw.githubusercontent.com/BlueSkyXN/SKY-BOX/main/box.sh && chmod +x box.sh && clear && ./box.sh
11.安装docker：curl -fsSL https://get.docker.com | bash -s docker
