#!/bin/bash
# ============================================
# Claude Code Ubuntu 容器测试版
# ============================================
set -e

echo "===== Ubuntu 容器测试环境 ====="

echo ""
echo "===== 第0步：修复 DNS ====="
echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null || true
echo "nameserver 114.114.114.114" >> /etc/resolv.conf 2>/dev/null || true
ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1 && echo "[ok] DNS 通" || echo "[warn] DNS 可能不通"

echo ""
echo "===== 第1步：装依赖 ====="
export DEBIAN_FRONTEND=noninteractive
echo "tzdata tzdata/Areas select Asia" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Zones/Asia select Shanghai" | debconf-set-selections 2>/dev/null || true
apt update -y && apt install curl git python3 make -y
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install nodejs -y
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第2步：换镜像 ====="
npm config set registry https://registry.npmmirror.com
echo "[ok] npm 镜像已切"

echo ""
echo "===== 第3步：安装 Claude Code ====="
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code
echo "[ok] Claude Code 安装完成"

echo ""
echo "===== 第4步：写配置 ====="
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "你的token填这里",
    "NO_PROXY": "*",
    "ANTHROPIC_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_SMALL_FAST_MODEL": "deepseek-v4-flash",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "DISABLE_AUTOUPDATER": "1"
  },
  "model": "deepseek-v4-pro",
  "language": "zh-CN"
}
EOF
echo "[ok] 配置写入完成"

echo ""
echo "=============================================="
echo "  去 DeepSeek 拿 token"
echo "  1. 浏览器 https://platform.deepseek.com"
echo "  2. 注册 → API Keys → 创建 → 复制 sk-xxx"
echo "=============================================="
echo ""
read -p "粘贴你的 token: " USER_TOKEN < /dev/tty
sed -i "s/你的token填这里/${USER_TOKEN}/" ~/.claude/settings.json
echo "[ok] token 已写入"

echo ""
echo "===== 第5步：验证 ====="
export PATH="$HOME/.local/bin:$PATH"
claude --version 2>/dev/null && echo "[ok] Claude Code 安装成功！" || echo "[warn] claude二进制可能不兼容Ubuntu proot容器（测试环境正常现象）"

echo ""
echo "[done] 测试完成。"
