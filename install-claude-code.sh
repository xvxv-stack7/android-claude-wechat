#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# Claude Code 一键安装
# curl ... | bash
# ============================================
set -e

echo "===== 第1步：检查 DNS ====="
if ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1; then
    echo "[ok] DNS 通"
else
    echo "[fix] 配 DNS..."
    echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
    echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
    ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] DNS 修好了" || { echo "[!] DNS 还是不通"; exit 1; }
fi

echo ""
echo "===== 第2步：装依赖 ====="
pkg update -y && pkg install nodejs binutils make python3 git -y
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第3步：换镜像源 ====="
npm config set registry https://registry.npmmirror.com
echo "[ok] npm 镜像已切到国内源"

echo ""
echo "===== 第4步：安装 Claude Code ====="
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code
echo "[ok] Claude Code 安装完成"

echo ""
echo "===== 第5步：写配置 ====="
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "你的token填这里",
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
cat > ~/.claude.json << 'EOF'
{
  "hasCompletedOnboarding": true
}
EOF
echo "[ok] 配置写入完成"

echo ""
echo "=============================================="
echo "  去 DeepSeek 拿 token（没有就先去注册）"
echo "  1. 浏览器 https://platform.deepseek.com"
echo "  2. 注册 → API Keys → 创建 → 复制 sk-xxx"
echo "=============================================="
echo ""
read -p "粘贴你的 token: " USER_TOKEN
sed -i "s/你的token填这里/${USER_TOKEN}/" ~/.claude/settings.json
echo "[ok] token 已写入"

echo ""
echo "===== 第6步：修复 PATH ====="
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc 2>/dev/null || true
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "===== 第7步：验证 ====="
claude --version && echo "[ok] Claude Code 安装成功！" || { echo "[!] claude 命令未找到，重开 Termux 窗口再试"; exit 1; }

echo ""
echo "=============================================="
echo "  全部完成！"
echo "  下一步：去 DeepSeek 官网注册拿 token"
echo "  https://platform.deepseek.com"
echo "  拿到后编辑 ~/.claude/settings.json 替换 token"
echo "  然后输入 claude 回车即可"
echo "=============================================="
