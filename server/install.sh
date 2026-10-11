#!/bin/bash
# ==============================================================================
# Pad Harness Standalone Engine Installer for iPadOS Rootless Jailbreak
# 专为 M2 iPad Pro 11寸 8G 运存量身打造的独立闭环部署脚本
# 彻底脱离任何外部电脑，iPad 本机即是独立服务器
# ==============================================================================

set -e

JB_PREFIX="/var/jb"
DSH_DIR="$JB_PREFIX/var/dsh"
PLIST_DST="$JB_PREFIX/Library/LaunchDaemons/com.dsh.server.plist"

echo "[*] 正在检查 iPad 越狱底层环境..."
if [ ! -d "$JB_PREFIX" ]; then
    echo "[!] 警告: 未探测到标准 /var/jb 路径，尝试探测 RootHide 环境..."
    # 兼容 RootHide 随机路径
    ROOTHIDE_JB=$(find /private/preboot -type d -name "jb-*" 2>/dev/null | head -n 1)
    if [ -n "$ROOTHIDE_JB" ]; then
        JB_PREFIX="$ROOTHIDE_JB"
        DSH_DIR="$JB_PREFIX/var/dsh"
        PLIST_DST="$JB_PREFIX/Library/LaunchDaemons/com.dsh.server.plist"
        echo "[+] 成功定位 RootHide 越狱路径: $JB_PREFIX"
    else
        echo "[-] 错误: 未检测到 Rootless / RootHide 越狱环境，无法部署系统级守护进程！"
        exit 1
    fi
fi

echo "[*] 正在准备 iPad 本地工作目录: $DSH_DIR"
mkdir -p "$DSH_DIR/core"
mkdir -p "$DSH_DIR/plugins"
mkdir -p "$DSH_DIR/storage"
mkdir -p "$(dirname "$PLIST_DST")"

echo "[*] 正在安装精简 DSH 核心内核与 8 大轻量插件矩阵..."
cp -R core/* "$DSH_DIR/core/"
cp -R plugins/* "$DSH_DIR/plugins/"

echo "[*] 正在注册 launchd 系统守护进程 (锁屏常驻保活，0.0.0.0:3080)..."
cp daemon/com.dsh.server.plist "$PLIST_DST"
chmod 644 "$PLIST_DST"

if command -v launchctl >/dev/null 2>&1; then
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    launchctl load -w "$PLIST_DST"
    echo "[+] Pad Harness 服务端已成功通过 launchd 启动并在后台无限制保活！"
else
    echo "[!] 未找到 launchctl 命令，请在 Sileo 中安装 base binaries。"
fi

echo "=========================================================================="
echo "🎉 Pad Harness iPad 本机独立服务端部署完成！"
echo "   - 服务地址: http://0.0.0.0:3080 (本机及局域网皆可访问)"
echo "   - 进程内存锁定: 1024MB 封顶 + 30秒空闲主动 GC"
echo "   - 本机使用: 打开 iPad 上的 Pad Harness App 即可零延迟工作！"
echo "   - 外部连接: iPhone App 可输入 http://<iPad_IP>:3080 作为随身遥控端"
echo "=========================================================================="
