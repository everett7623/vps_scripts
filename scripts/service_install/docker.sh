#!/bin/bash
# ==============================================================================
# Script: scripts/service_install/docker.sh
# Purpose: Install Docker Engine and Compose with Docker's official installer.
# Author: everettlabs
# ==============================================================================

set -euo pipefail

readonly DOCKER_INSTALL_URL="https://get.docker.com"
installer_file=""

cleanup() {
    if [[ -n $installer_file && -f $installer_file ]]; then
        rm -f -- "$installer_file"
    fi
}

trap cleanup EXIT

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 此脚本需要 root 权限运行。" >&2
    exit 1
fi

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "[SUCCESS] Docker Engine 和 Docker Compose 已安装。"
    docker --version
    docker compose version
    exit 0
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
