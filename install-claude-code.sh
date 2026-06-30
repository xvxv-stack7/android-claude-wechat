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
    echo "nameserver 223.5.5.5" > /data/data/com.termux/files/usr/etc/resolv.conf
    echo "nameserver 119.29.29.29" >> /data/data/com.termux/files/usr/etc/resolv.conf
    ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] DNS 修好了（阿里/腾讯）" || {
        echo "nameserver 8.8.8.8" >> /data/data/com.termux/files/usr/etc/resolv.conf
        echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
        ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] DNS 修好了（谷歌/114）" || { echo "[!] DNS 不通，检查网络或开代理后重试"; exit 1; }
    }
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
npm config set allow-scripts=@anthropic-ai/claude-code --location=user 2>/dev/null || true
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code@2.1.195
# 如果原生二进制没下载成功（国内常见），手动跑postinstall
if ! claude --version &> /dev/null 2>&1; then
    echo "[fix] 二进制缺失，手动下载..."
    node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs" 2>&1 || true
    if ! claude --version &> /dev/null 2>&1; then
        echo "[fix] install.cjs失败，curl直下二进制..."
        mkdir -p ~/.local/share/claude/versions ~/.local/bin
        # 优先下载47MB xz压缩包（快），失败再试官方CDN直下241MB
        if curl -fsSL --connect-timeout 10 --max-time 120 "https://github.com/xvxv-stack7/android-claude-wechat/releases/download/binary-2.1.195/claude-2.1.195-arm64.xz" -o ~/.local/share/claude/versions/claude.xz 2>/dev/null; then
            python3 -c "import lzma,sys; sys.stdout.buffer.write(lzma.open('$HOME/.local/share/claude/versions/claude.xz').read())" > ~/.local/share/claude/versions/2.1.195 2>/dev/null
            rm -f ~/.local/share/claude/versions/claude.xz
            echo "[ok] xz压缩包下载解压成功"
        fi
        if [ ! -f ~/.local/share/claude/versions/2.1.195 ]; then
            curl -fsSL --connect-timeout 10 --max-time 300 "https://downloads.claude.ai/claude-code-releases/2.1.195/linux-arm64/claude" -o ~/.local/share/claude/versions/2.1.195 2>/dev/null \
            || curl -fsSL --connect-timeout 10 --max-time 300 "https://downloads.claude.ai/claude-code-releases/2.1.195/linux-arm64-musl/claude" -o ~/.local/share/claude/versions/2.1.195 2>/dev/null
        fi
        if [ -f ~/.local/share/claude/versions/2.1.195 ]; then
            chmod +x ~/.local/share/claude/versions/2.1.195
            echo "[ok] 二进制就绪"
        else
            echo "[!] 二进制下载失败，手动运行："
            echo "    mkdir -p ~/.local/share/claude/versions && curl -x http://127.0.0.1:7890 -fsSL --max-time 120 \"https://github.com/xvxv-stack7/android-claude-wechat/releases/download/binary-2.1.195/claude-2.1.195-arm64.xz\" -o ~/.local/share/claude/versions/claude.xz && python3 -c \"import lzma,sys; sys.stdout.buffer.write(lzma.open('\$HOME/.local/share/claude/versions/claude.xz').read())\" > ~/.local/share/claude/versions/2.1.195 && chmod +x ~/.local/share/claude/versions/2.1.195"
        fi
        fi
    fi
fi

# Termux 修复（2026-06-30 絮絮实测）
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
WRAPPER="/data/data/com.termux/files/usr/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
mkdir -p "$VERSIONS_DIR"
# 0. 检查 glibc
if [ ! -f "$GLIBC_LIB" ]; then
    echo "[fix] glibc 缺失，尝试安装..."
    pkg install glibc-repo -y 2>/dev/null && pkg install glibc -y 2>/dev/null || echo "[!] glibc 安装失败，手动装：pkg install glibc-repo -y && pkg install glibc -y"
fi
# 1. 清理残留 .tmp 和 196 版本
rm -f "$VERSIONS_DIR"/2.1.196.tmp "$VERSIONS_DIR"/2.1.196 2>/dev/null
echo "[fix] 残留文件已清"
# 2. 拉黑 196，不反复下载
echo "2.1.196" >> "$VERSIONS_DIR/.blocklist" 2>/dev/null
# 3. 195 设为已验证，跳过 smoke test
echo "2.1.195" > "$VERSIONS_DIR/.verified" 2>/dev/null
echo "[fix] 196 已拉黑，195 已验证"
# 4. libc.so 是 ld script 不是真 ELF → 换成符号链接
if [ -f "$GLIBC_LIB" ] && [ ! -L "$GLIBC_LIB" ]; then
    cp "$GLIBC_LIB" "${GLIBC_LIB}.bak" 2>/dev/null || true
    ln -sf libc.so.6 "$GLIBC_LIB"
    echo "[fix] libc.so → libc.so.6"
fi
# 5. wrapper 不存在则创建，存在则清 LD_PRELOAD（Termux bionic 与 glibc 冲突）
if [ ! -f "$WRAPPER" ]; then
    cat > "$WRAPPER" << 'WRAPPEREOF'
#!/bin/bash
VERSIONS_DIR="$HOME/.local/share/claude/versions"
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
BIN="$VERSIONS_DIR/2.1.195"
[ -f "$GLIBC_LIB" ] && export LD_PRELOAD="$GLIBC_LIB"
exec "$BIN" "$@"
WRAPPEREOF
    chmod +x "$WRAPPER"
    echo "[fix] wrapper 已创建"
else
    sed -i 's/exec "\$bin"/LD_PRELOAD= exec "\$bin"/' "$WRAPPER" 2>/dev/null || true
    echo "[fix] LD_PRELOAD 已清"
fi
# 6. 永不自动更新（RATE_LIMIT=10年）
sed -i 's/^RATE_LIMIT=.*/RATE_LIMIT=315360000/' "$WRAPPER" 2>/dev/null || true

echo "[ok] Claude Code 安装完成（Termux 修复已应用）"

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
read -p "粘贴你的 token: " USER_TOKEN < /dev/tty
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
echo "  输入 claude 回车即可开始对话"
echo "  token 已写入配置，无需手动编辑"
echo "=============================================="
