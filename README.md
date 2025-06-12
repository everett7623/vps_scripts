# VPS Scripts - 多功能 VPS 脚本工具集
(新版本目前不可用，升级中)，请使用旧脚本：
```bash
bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh)
```

<div align="center">

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/everett7623/vps_scripts)
[![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian%20%7C%20CentOS%20%7C%20RHEL%20%7C%20Fedora%20%7C%20Arch-orange.svg)]()
[![Architecture](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey.svg)]()
[![Stars](https://img.shields.io/github/stars/everett7623/vps_scripts?style=social)](https://github.com/everett7623/vps_scripts)

[**中文文档**](README.md) | [**English**](README_EN.md) | [**安装指南**](docs/installation.md) | [**使用手册**](docs/usage.md)

</div>

## 📋 目录

- [功能特性](#-功能特性)
- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [详细功能](#-详细功能)
- [高级用法](#-高级用法)
- [更新日志](#-更新日志)
- [贡献指南](#-贡献指南)
- [常见问题](#-常见问题)
- [免责声明](#️-免责声明)

## ✨ 功能特性

### 🖥️ 系统工具
- **系统信息查看** - 详细展示CPU、内存、硬盘、网络等信息
- **系统更新** - 支持多种Linux发行版的系统更新
- **系统清理** - 清理缓存、日志、临时文件等
- **系统优化** - BBR加速、内核参数优化、系统限制调整

### 🌐 网络测试
- **IP质量检测** - 检测IP质量、黑名单状态、地理位置等
- **流媒体解锁** - 测试Netflix、YouTube、Disney+等流媒体解锁情况
- **三网测速** - 电信、联通、移动三网速度测试
- **回程路由** - 追踪VPS到国内的回程路由
- **响应测试** - 测试全球各地到VPS的响应时间
- **带宽测试** - 使用iperf3进行专业带宽测试

### 📊 性能测试
- **YABS测试** - 综合性能基准测试
- **融合怪测试** - 集成多种测试的综合脚本
- **超售测试** - 检测VPS是否存在超售情况
- **CPU性能** - 单核/多核性能测试
- **内存性能** - 内存读写速度测试
- **硬盘性能** - 4K随机读写、顺序读写测试

### 🚀 服务部署
- **Docker环境** - 一键安装Docker和Docker Compose
- **Web环境** - Nginx、Apache、PHP、MySQL快速部署
- **开发环境** - Node.js、Python、Java、Go环境配置
- **代理服务** - Shadowsocks、V2Ray、WireGuard等
- **监控服务** - 哪吒监控、Prometheus、Grafana等

### 📈 统计分析
- **使用统计** - 记录各功能使用次数和频率
- **性能分析** - 追踪脚本执行时间和资源消耗
- **可视化报告** - 生成直观的统计图表
- **数据导出** - 支持导出JSON、CSV格式的统计数据

## 🔧 系统要求

### 支持的操作系统
- **Ubuntu** 18.04 / 20.04 / 22.04 / 24.04
- **Debian** 9 / 10 / 11 / 12
- **CentOS** 7 / 8 / Stream 8 / Stream 9
- **RHEL** 7 / 8 / 9
- **Fedora** 35+
- **Rocky Linux** 8 / 9
- **AlmaLinux** 8 / 9
- **Arch Linux** (最新版)
- **Manjaro** (最新版)
- **Alpine Linux** 3.12+
- **openSUSE** Leap 15.3+

### 硬件要求
- **CPU**: 1核心及以上
- **内存**: 512MB及以上
- **硬盘**: 1GB可用空间
- **网络**: 需要访问GitHub和测试服务器

### 软件要求
- **权限**: root或sudo权限
- **Shell**: Bash 4.0+
- **基础工具**: curl或wget

## 🚀 快速开始

### 一键安装

```bash
bash <(curl -s https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh)
```

```bash
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh)
```

### 本地安装

```bash
# 克隆仓库
git clone https://github.com/everett7623/vps_scripts.git
cd vps_scripts

# 添加执行权限
chmod +x vps.sh

# 运行脚本
./vps.sh
```

### 设置快捷命令

```bash
# 方法1: 创建别名
echo "alias vps='bash ~/vps_scripts/vps.sh'" >> ~/.bashrc
source ~/.bashrc

# 方法2: 添加到系统路径
sudo ln -s ~/vps_scripts/vps.sh /usr/local/bin/vps

# 现在可以直接使用
vps
```

## 📖 详细功能

### 系统工具模块

<details>
<summary>点击展开系统工具详细说明</summary>

#### 系统信息查看
- 硬件信息：CPU型号、核心数、架构
- 内存信息：总量、已用、可用、缓存
- 硬盘信息：分区、使用率、文件系统
- 网络信息：IPv4/IPv6地址、网卡信息
- 系统信息：发行版、内核版本、运行时间

#### 系统更新
- 自动检测包管理器（apt/yum/dnf/pacman等）
- 更新软件包列表
- 升级已安装的软件包
- 清理不需要的依赖
- 更新内核（可选）

#### 系统清理
- 清理包管理器缓存
- 清理系统日志（保留最近7天）
- 清理临时文件
- 清理用户缓存
- 清理旧内核（保留最新2个）

#### 系统优化
- 启用BBR TCP拥塞控制
- 优化内核参数
- 调整文件描述符限制
- 优化网络参数
- 禁用不必要的服务

</details>

### 网络测试模块

<details>
<summary>点击展开网络测试详细说明</summary>

#### IP质量检测
- IP归属地查询
- 黑名单检测（Spamhaus、Barracuda等）
- 端口开放检测
- MTU探测
- DNS解析测试

#### 流媒体解锁
- Netflix（检测区域）
- YouTube Premium
- Disney+
- HBO Max
- Amazon Prime Video
- 更多流媒体平台...

#### 三网测速
- 电信节点测速
- 联通节点测速
- 移动节点测速
- 国际节点测速
- 支持多线程/单线程模式

#### 回程路由
- 自动检测三网回程
- 支持TCP/ICMP模式
- 显示AS号和运营商信息
- 地理位置可视化

</details>

### 性能测试模块

<details>
<summary>点击展开性能测试详细说明</summary>

#### YABS综合测试
- CPU性能测试（单核/多核）
- 内存性能测试
- 硬盘性能测试（fio）
- 网络性能测试
- Geekbench跑分（可选）

#### 融合怪测试
- 系统信息收集
- CPU性能评估
- 内存测试
- 硬盘I/O测试
- 网络质量测试
- 综合评分

#### 超售测试
- CPU超售检测
- 内存超售检测
- 硬盘超售检测
- 网络超售检测
- 综合评估报告

</details>

### 服务部署模块

<details>
<summary>点击展开服务部署详细说明</summary>

#### Docker环境
```bash
# 自动安装最新版Docker
# 配置Docker加速器
# 安装Docker Compose
# 设置开机自启
```

#### Web环境
```bash
# Nginx + PHP + MySQL
# Apache + PHP + MySQL
# Caddy + PHP
# 支持多版本PHP切换
```

#### 开发环境
```bash
# Node.js (支持nvm管理)
# Python (支持pyenv管理)
# Java (OpenJDK/Oracle JDK)
# Go语言环境
```

</details>

## 🔍 高级用法

### 配置文件

创建 `~/.vps_scripts/config.conf` 自定义配置：

```bash
# 自动更新
AUTO_UPDATE=true
UPDATE_CHECK_INTERVAL=7

# 界面设置
USE_COLOR=true
MENU_STYLE=advanced

# 统计设置
ENABLE_STATS=true
STATS_SERVER=https://your-stats-server.com/api

# 代理设置
HTTP_PROXY=
HTTPS_PROXY=
```

### 命令行参数

```bash
# 直接执行指定功能
vps.sh --sysinfo          # 显示系统信息
vps.sh --update           # 更新系统
vps.sh --speedtest        # 运行测速
vps.sh --docker           # 安装Docker

# 其他参数
vps.sh --no-color         # 禁用彩色输出
vps.sh --quiet            # 静默模式
vps.sh --debug            # 调试模式
```

### API接口

脚本提供JSON格式的统计数据输出：

```bash
# 获取统计数据
vps.sh --stats-json > stats.json

# 发送到远程服务器
vps.sh --send-stats --server=https://api.example.com --key=YOUR_API_KEY
```

## 📅 更新日志

### v2.0.0 (2025-06-12)
- 🎉 全新架构重构，模块化设计
- ✨ 新增多系统支持（CentOS/RHEL/Arch等）
- 🎨 全新分级菜单系统
- 📊 新增统计分析功能
- 🔧 优化错误处理机制
- 📝 完善文档和注释

### v1.2.4 (2025-05-19)
- 添加哪吒agent清理脚本
- 修复统计功能bug
- 优化菜单显示

[查看完整更新日志](CHANGELOG.md)

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 如何贡献

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 开发规范

- 遵循Shell脚本最佳实践
- 添加必要的注释和文档
- 确保在多个系统上测试通过
- 保持向后兼容性

### 报告问题

[提交Issue](https://github.com/everett7623/vps_scripts/issues/new)时请包含：
- 系统版本信息
- 错误信息截图
- 复现步骤

## ❓ 常见问题

<details>
<summary>Q: 脚本支持ARM架构的VPS吗？</summary>

A: 是的，脚本支持x86_64和ARM64架构。部分功能在ARM上可能有限制。
</details>

<details>
<summary>Q: 如何卸载脚本？</summary>

A: 运行 `vps.sh` 选择 `99) 卸载脚本` 即可完全卸载。
</details>

<details>
<summary>Q: 统计数据存储在哪里？</summary>

A: 统计数据存储在 `~/.vps_scripts/` 目录下，不会上传到任何服务器。
</details>

<details>
<summary>Q: 如何关闭自动更新？</summary>

A: 编辑 `~/.vps_scripts/config.conf`，设置 `AUTO_UPDATE=false`。
</details>

[查看更多常见问题](docs/FAQ.md)

## ⚠️ 免责声明

1. 本脚本仅供学习和参考使用
2. 使用本脚本产生的任何后果由使用者自行承担
3. 请勿将本脚本用于任何违法违规用途
4. 第三方脚本的安全性和稳定性由原作者负责

## 鸣谢
* [Eooce](https://github.com/eooce/ssh_tool)
* [Netflixxp](https://github.com/Netflixxp/jcnf-box)
* [科技lion]
* [BlueSkyXN](https://github.com/BlueSkyXN/SKY-BOX)
* [yonggekkk](https://github.com/yonggekkk/sing-box_hysteria2_tuic_argo_reality)
* [Fscarmen](https://github.com/fscarmen/sba)
* [mack-a](https://github.com/mack-a/v2ray-agent)

## 广告
[VPS，梯子等小工具推荐](https://github.com/everett7623/tool)

## 📄 许可证

本项目采用 [AGPL-3.0](LICENSE) 许可证。

---

<div align="center">

**如果这个项目对您有帮助，请给个 ⭐ Star 支持一下！**

[![Star History Chart](https://api.star-history.com/svg?repos=everett7623/vps_scripts&type=Date)](https://star-history.com/#everett7623/vps_scripts&Date)

Made with ❤️ by [Jensfrank](https://github.com/everett7623)

</div>
