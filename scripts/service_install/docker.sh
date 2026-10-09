#!/bin/bash
# ==============================================================================
# Script: scripts/service_install/docker.sh
# Purpose: Install Docker Engine and Compose with Docker's official installer.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

readonly DOCKER_INSTALL_URL="https://get.docker.com"
installer_file=""
DRY_RUN=false

cleanup() {
    if [[ -n $installer_file && -f $installer_file ]]; then
        rm -f -- "$installer_file"
    fi
}

trap cleanup EXIT

show_help() {
    cat <<'EOF'
用法：bash docker.sh [选项]

选项：
  --status    查看 Docker Engine / Compose 安装与服务状态
  --dry-run   仅预览安装步骤，不修改系统
  --help      显示帮助

安装使用 Docker 官方脚本（https://get.docker.com），先下载到临时文件并做语法校验再执行。
EOF
}

show_status() {
    if command -v docker >/dev/null 2>&1; then
        echo "[INFO] $(docker --version 2>/dev/null || echo 'docker: 版本未知')"
        docker compose version 2>/dev/null || echo "[WARN] Docker Compose 插件未安装。"
    else
        echo "[WARN] 未安装 Docker。"
    fi
    if command -v systemctl >/dev/null 2>&1; then
        echo "[INFO] docker 服务: $(systemctl is-active docker 2>/dev/null || echo inactive)"
    fi
    return 0
}

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --status)
        show_status
        exit 0
        ;;
    --dry-run)
        DRY_RUN=true
        ;;
    "")
        ;;
    *)
        echo "[ERROR] 未知参数: $1（使用 --help 查看用法）" >&2
        exit 1
        ;;
esac

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "[SUCCESS] Docker Engine 和 Docker Compose 已安装。"
    docker --version
    docker compose version
    exit 0
fi

if [[ $DRY_RUN == true ]]; then
    echo "[DRY-RUN] 将下载 ${DOCKER_INSTALL_URL} 到临时文件"
    echo "[DRY-RUN] 将执行 bash -n 语法校验"
    echo "[DRY-RUN] 将以 root 执行官方安装脚本并安装 Docker Engine + Compose 插件"
    exit 0
fi

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 此脚本需要 root 权限运行（预览可使用 --dry-run）。" >&2
    exit 1
fi

installer_file=$(mktemp "/tmp/get-docker.XXXXXX")

echo "[INFO] 下载 Docker 官方安装脚本..."
if ! curl -fsSL "$DOCKER_INSTALL_URL" -o "$installer_file"; then
    echo "[ERROR] Docker 官方安装脚本下载失败。" >&2
    exit 1
fi

if ! bash -n "$installer_file"; then
    echo "[ERROR] Docker 官方安装脚本语法校验失败。" >&2
    exit 1
fi

echo "[INFO] 执行 Docker 官方安装脚本..."
sh "$installer_file"

echo "[SUCCESS] Docker 安装完成。"
docker --version
docker compose version
