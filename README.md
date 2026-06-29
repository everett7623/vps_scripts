# VPS Scripts - 多功能 VPS 脚本工具集

> 当前主入口已恢复可用，推荐使用模块化启动器 `vps.sh`。
> 兼容入口 `vps_scripts.sh` 以 legacy-only 状态保留，仅维护旧命令转交能力；新功能统一进入 `vps.sh` 和模块脚本。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh)
```

<div align="center">

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/everett7623/vps_scripts)
[![License](https://img.shields.io/badge/license-AGPL--3.0-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20%7C%20Debian%20%7C%20CentOS%20%7C%20RHEL%20%7C%20Fedora%20%7C%20Arch-orange.svg)](https://github.com/everett7623/vps_scripts)
[![Architecture](https://img.shields.io/badge/arch-x86__64%20%7C%20arm64-lightgrey.svg)](https://github.com/everett7623/vps_scripts)
[![Stars](https://img.shields.io/github/stars/everett7623/vps_scripts?style=social)](https://github.com/everett7623/vps_scripts)

[**项目地址**](https://github.com/everett7623/vps_scripts) | [**更新日志**](CHANGELOG.md) | [**开发指南**](DEVELOPMENT_GUIDE.md) | [**发布清单**](RELEASE_CHECKLIST.md)

</div>

## 目录

- [当前状态](#当前状态)
- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [详细功能](#详细功能)
- [项目结构](#项目结构)
- [验证与维护](#验证与维护)
- [更新日志](#更新日志)
- [开发与贡献](#开发与贡献)
- [常见问题](#常见问题)
- [免责声明](#免责声明)

## 当前状态

### 当前主线
- `vps.sh` 已恢复为当前推荐主入口
- `vps_scripts.sh` 作为受支持的 legacy-only 兼容入口保留，不再新增独立功能
- 主框架、公共函数库和系统工具已完成一轮集中优化
- 主启动器支持宽窄终端自适应、中文对齐和更清晰的视觉层级
- 仓库现有 30 个验证脚本，便于后续逐分类继续升级

### 已完成的重点
- 启动器安全性与菜单映射修正
- 公共函数库清理与高风险 `eval` 移除
- 依赖安装与系统更新脚本幂等性增强
- 系统工具核心脚本统一到新的日志、校验、备份风格
- 启动器与共享 UI 已统一响应式宽度、中文显示宽度和窄屏布局
- README、CHANGELOG、开发/发布文档补齐

### 当前优化阶段
- `system_tools`：主脚本已完成首轮收口
- `network_test`：已完成 `set -euo pipefail` 与 `mktemp` 安全加固
- `performance_test`：已完成 `set -euo pipefail` 与 `mktemp` 安全加固
- `service_install`：全部 21 个脚本已启用 `set -euo pipefail` 严格模式

## 功能特性

### 系统工具
- **系统信息查看** - 查看 CPU、内存、硬盘、网络、服务状态等信息
- **系统更新** - 支持多种 Linux 发行版更新与基础清理
- **系统清理** - 清理缓存、日志、临时文件、孤包与 Docker 垃圾
- **系统优化** - 提供保守型内核参数、limits、swap 与 SSH 基线优化
- **主机名管理** - 支持主机名修改、校验、备份、回滚
- **时区管理** - 支持时区设置、NTP 配置与时间同步
- **系统健康巡检** - 只读检查负载、内存、磁盘、服务、重启标记与网络连通
- **安全基线巡检** - 只读检查 SSH、防火墙、Fail2ban、监听端口、账号与关键权限

### 网络测试
- **IP 质量检测** - 检测 IP 信息、可用性与基础网络表现
- **流媒体解锁** - 测试 Netflix、YouTube、Disney+ 等平台
- **三网测速** - 电信、联通、移动及国际节点测速
- **回程路由** - 跟踪 VPS 到国内方向的回程路由
- **响应测试** - 测试不同地区到 VPS 的连通与延迟

### 性能测试
- **YABS 测试** - 综合性能基准测试
- **融合怪测试** - 多项能力集合测试
- **超售测试** - 检测 CPU、内存、I/O 等超售迹象
- **硬件性能测试** - CPU、内存、硬盘等基础性能检测

### 服务部署
- **Docker 环境** - Docker 与 Compose 一键安装
- **Web 环境** - Nginx、Apache、PHP、MySQL 等常见组件
- **开发环境** - Node.js、Python、Java、Go 等运行环境
- **代理服务** - Shadowsocks、V2Ray、WireGuard 等相关部署
- **监控服务** - 哪吒监控等常见 VPS 运维组件

## 系统要求

### 支持的操作系统
- **Ubuntu** 18.04+
- **Debian** 10+
- **CentOS** 7+
- **RHEL / Rocky / AlmaLinux** 8+
- **Fedora**
- **Arch / Manjaro**
- **Alpine Linux** 3.10+

详细兼容信息以 [version.json](version.json) 为准。

### 基础要求
- **CPU**：1 核及以上
- **内存**：建议 512MB 及以上
- **硬盘**：至少 1GB 可用空间
- **权限**：大多数安装、清理、系统修改功能需要 root 或 sudo
- **Shell**：Bash 4.0+
- **网络**：需要访问 GitHub 与部分第三方检测/安装源

## 快速开始

### 推荐方式：模块化主入口

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh)
```

如果没有 `curl`，也可以使用：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh)
```

### 兼容方式：旧入口

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps_scripts.sh)
```

### 本地使用

```bash
git clone https://github.com/everett7623/vps_scripts.git
cd vps_scripts
chmod +x vps.sh
./vps.sh
```

### 快捷命令

```bash
curl -fsSL https://raw.githubusercontent.com/everett7623/vps_scripts/main/vps.sh -o /tmp/vps.sh
bash /tmp/vps.sh --install
vps
```

请使用 root 用户执行安装；普通用户可在命令前加 `sudo`。该命令会安装到 `/usr/local/bin/vps`，重新登录或切换目录后仍可直接运行。
再次执行 `vps --install` 可更新启动器，执行 `vps --uninstall-command` 可移除快捷命令。

### 使用建议

- 新环境优先使用 `vps.sh`
- 老习惯或旧文档引用场景可继续使用 `vps_scripts.sh`，但新功能与修复优先进入 `vps.sh`
- 涉及系统修改、软件安装、网络配置的功能建议先在可回滚环境中验证
- 运行前尽量确认主机已具备 `bash`、`curl` 或 `wget`

## 详细功能

### 系统工具模块

<details>
<summary>点击展开系统工具详细说明</summary>

#### 系统信息查看
- 显示主机名、系统版本、内核、架构、运行时间
- 显示 CPU、内存、Swap、硬盘、网络接口、公共 IP
- 显示虚拟化环境、常见服务状态与基础登录信息

#### 系统更新
- 自动识别 apt / yum / dnf / apk / pacman
- 支持常规更新、安全更新、清理与重启检查
- 已补充备份、日志和较稳的非交互流程

#### 系统清理
- 支持缓存、日志、临时文件、孤包、Docker 清理
- 深度模式可选清理旧内核与用户缓存
- 支持 `--dry-run` 和磁盘分析模式

#### 系统优化
- 保守启用 TCP/BBR、limits、swap 保护、SSH 基线
- 以稳定优先，不再默认做过激调优
- 关键配置会先备份再写入

#### 主机名与时区
- 主机名脚本支持校验、备份、报告、回滚
- 时区脚本支持常用时区、搜索、NTP 配置与同步

</details>

### 网络测试模块

<details>
<summary>点击展开网络测试详细说明</summary>

#### 常见能力
- IP 检测与归属信息查看
- 流媒体解锁检测
- 三网测速与国际测速
- 回程路由追踪
- 网络响应与基础可达性测试

</details>

### 性能测试模块

<details>
<summary>点击展开性能测试详细说明</summary>

#### 常见能力
- YABS 综合测试
- 融合怪测试
- 超售检测
- CPU / 内存 / 硬盘基础性能测试

</details>

### 服务部署模块

<details>
<summary>点击展开服务部署详细说明</summary>

#### 常见能力
- Docker 环境部署
- Web 服务栈部署
- 多语言开发环境安装
- 代理与监控类服务安装

</details>

## 项目结构

```text
config/                    项目配置
lib/                       公共函数库
scripts/
  system_tools/            系统工具
  network_test/            网络测试
  performance_test/        性能测试
  service_install/         服务安装
  other_tools/             其他工具
  uninstall_scripts/       卸载脚本
  update_scripts/          旧更新脚本（仅历史参考，不在主入口启用）
tests/                     仓库级校验脚本
vps.sh                     主启动器
vps_scripts.sh             legacy-only 兼容启动器
version.json               版本与元数据
```

当前脚本分类数量：
- `system_tools`: 9
- `network_test`: 5
- `performance_test`: 4
- `service_install`: 21
- `other_tools`: 4
- `uninstall_scripts`: 4
- `update_scripts`: 4 legacy scripts + 1 policy note

## 验证与维护

### 当前主框架状态
- `vps.sh` 已作为主入口恢复可用
- `vps_scripts.sh` 仅作为 legacy-only 转交入口保留
- `lib/common_functions.sh`、`install_deps.sh`、`update_system.sh` 已完成一轮核心重构
- `system_tools` 核心脚本已补上统一的语法校验链

### 推荐验证命令

```bash
bash -n vps.sh
bash -n vps_scripts.sh
LAUNCHER_OVERRIDE="$PWD/vps.sh" REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_launcher_paths.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_core_assets.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_system_tools_launcher.sh
REPO_ROOT_OVERRIDE="$PWD" bash tests/validate_service_install_strict_mode.sh
```

如果本机装有 `shellcheck`，建议在提交前补跑。

### 相关文档
- [AGENTS.md](AGENTS.md)：协作规范与代理工作约束
- [DEVELOPMENT_GUIDE.md](DEVELOPMENT_GUIDE.md)：开发指南
- [TASKS.md](TASKS.md)：待办与优先级
- [PROGRESS.md](PROGRESS.md)：当前进展
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)：发布前检查
- [VERSIONING.md](VERSIONING.md)：版本策略
- [PRIVACY.md](PRIVACY.md)：隐私与网络访问说明
- [code_review.md](code_review.md)：代码审查记录
- [SESSION.md](SESSION.md)：最近一次优化会话摘要
- [CHANGELOG.md](CHANGELOG.md)：更新历史

## 更新日志

### 最近这一轮重点变化
- 全部 21 个 service_install 脚本已启用 `set -euo pipefail` 严格模式
- 全部 network_test 和 performance_test 脚本已加入严格模式与安全临时目录
- 新增 `die()` 共享辅助函数，简化 `print_error; exit 1` 模式
- 新增 `wppanel.sh` 作为 WP Panel 一等脚本（替代原内联 `run_remote_command`）
- 新增 `tests/validate_service_install_strict_mode.sh` 自动化覆盖测试
- 消除全项目 `curl | sh` 管道执行模式，统一使用下载-校验-执行流程
- 发布 `1.0.0`：项目版本体系正式初始化，主启动器与模块进入首个稳定版本
- 中文与英文混排菜单改为按终端显示宽度对齐
- 24-88 列终端可响应式显示，窄屏详情自动换行

### 查看完整历史
- [CHANGELOG.md](CHANGELOG.md)：正式更新日志
- [update_log.sh](update_log.sh)：兼容查看器，会读取版本元数据并显示 `CHANGELOG.md` 摘要

## 开发与贡献

欢迎继续完善这个项目。

### 建议的开发方向
- 继续优化 `network_test`、`performance_test`、`service_install` 分类
- 进一步减少高风险远程执行模式
- 提升 UTF-8 文档一致性与脚本可维护性
- 增加更多 repo-local 验证脚本
- 不再恢复 `update_scripts/` 到主菜单；如需复用其中逻辑，应迁移为新的窄范围模块并配套测试

### 贡献方式
1. Fork 本仓库
2. 创建功能分支
3. 提交变更
4. 推送分支
5. 发起 Pull Request

### 提交前建议
- 至少运行 README 中列出的基础验证命令
- 用户可见行为变化要同步更新 `README.md` 与 `CHANGELOG.md`
- 涉及系统脚本的改动，尽量说明风险、回滚方式和适用范围

### 报告问题时建议附带
- 发行版与版本号
- 架构信息
- 触发问题的脚本名称
- 报错输出或复现步骤

## 常见问题

<details>
<summary>Q: 现在应该用哪个入口？</summary>

A: 优先使用 `vps.sh`。`vps_scripts.sh` 是受支持的 legacy-only 转交入口，不再承载独立功能。
</details>

<details>
<summary>Q: 脚本支持 ARM 架构的 VPS 吗？</summary>

A: 支持 x86_64 和 arm64，具体能力仍取决于目标脚本和所依赖的第三方工具。
</details>

<details>
<summary>Q: 系统工具现在稳定吗？</summary>

A: 主框架和系统工具已经完成一轮集中优化，并增加了基础校验链；但服务安装、网络测试等分类仍在持续优化中。
</details>

<details>
<summary>Q: 为什么有些功能仍会访问第三方源？</summary>

A: 这类脚本本身就依赖软件源、测速节点、流媒体检测点或第三方项目，README 只做如实说明，不代表所有外部脚本都由本仓库维护。
</details>

## 免责声明

1. 本项目仅供学习、运维参考与自动化辅助使用。
2. 涉及系统修改、服务安装、网络测试的功能请自行评估风险。
3. 第三方脚本、第三方软件源和第三方服务的稳定性与安全性不完全由本仓库控制。
4. 使用本项目产生的后果由使用者自行承担。

## 鸣谢

- [Eooce](https://github.com/eooce/ssh_tool)
- [Netflixxp](https://github.com/Netflixxp/jcnf-box)
- [BlueSkyXN](https://github.com/BlueSkyXN/SKY-BOX)
- [yonggekkk](https://github.com/yonggekkk/sing-box_hysteria2_tuic_argo_reality)
- [Fscarmen](https://github.com/fscarmen/sba)
- [mack-a](https://github.com/mack-a/v2ray-agent)

## 许可证

本项目采用 [AGPL-3.0](LICENSE) 许可证。

---

<div align="center">

**如果这个项目对你有帮助，欢迎点个 Star 支持一下。**

[![Star History Chart](https://api.star-history.com/svg?repos=everett7623/vps_scripts&type=Date)](https://star-history.com/#everett7623/vps_scripts&Date)

Made by [Jensfrank](https://github.com/Jensfrank)

</div>
