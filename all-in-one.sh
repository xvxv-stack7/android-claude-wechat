#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 一条命令：Claude Code + cc-connect 微信
# 全程两次暂停：拿token、扫码
# ============================================
set -e

echo ""
echo "=============================================="
echo "  安卓 → AI Agent + 微信，一条命令"
echo "  中途会等你两次：填token、扫二维码"
echo "=============================================="
echo ""

# ====== 阶段一：Claude Code ======

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
pkg update -y && pkg install nodejs binutils make python3 git proot ca-certificates curl -y
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第3步：换镜像 + 装 Claude Code ====="
npm config set registry https://registry.npmmirror.com
npm config set allow-scripts=@anthropic-ai/claude-code --location=user 2>/dev/null || true
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code@2.1.195
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
# Termux 修复（2026-07-01 絮絮实测 v2：wrapper 不能再设 LD_PRELOAD，bionic preload 会喂给 glibc 链接器炸掉）
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
WRAPPER="/data/data/com.termux/files/usr/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
mkdir -p "$VERSIONS_DIR"
# 检查 glibc
if [ ! -f "$GLIBC_LIB" ]; then
    echo "[fix] glibc 缺失，尝试安装..."
    pkg install glibc-runner patchelf-glibc -y
fi
# 清理残留
rm -f "$VERSIONS_DIR"/2.1.196.tmp "$VERSIONS_DIR"/2.1.196 2>/dev/null
echo "2.1.196" >> "$VERSIONS_DIR/.blocklist" 2>/dev/null
echo "2.1.195" > "$VERSIONS_DIR/.verified" 2>/dev/null
echo "[fix] 196 已拉黑，195 已验证"
# libc.so 是 ld script 不是真 ELF → 换成符号链接
if [ -f "$GLIBC_LIB" ] && [ ! -L "$GLIBC_LIB" ]; then
    cp "$GLIBC_LIB" "${GLIBC_LIB}.bak" 2>/dev/null || true
    ln -sf libc.so.6 "$GLIBC_LIB"
    echo "[fix] libc.so → libc.so.6"
fi
# wrapper：不管 npm 有没有创建，统一用我们的干净版本覆盖
cat > "$WRAPPER" << 'WRAPPEREOF'
#!/data/data/com.termux/files/usr/bin/bash
BIN="$HOME/.local/share/claude/versions/2.1.195"
LD_PRELOAD= exec proot -0 "$BIN" "$@"
WRAPPEREOF
chmod +x "$WRAPPER"
rm -f "$HOME/.local/bin/claude" 2>/dev/null
hash -r 2>/dev/null || true
echo "[fix] wrapper 已覆盖"

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
cat > ~/.claude.json << 'EOF'
{ "hasCompletedOnboarding": true }
EOF
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo "[ok] 配置写入完成"

echo ""
echo "=============================================="
echo "  暂停：需要你去 DeepSeek 拿 token"
echo "  1. 浏览器打开 https://platform.deepseek.com"
echo "  2. 注册登录 → API Keys → 创建 → 复制 sk-xxx"
echo "  3. 回来粘贴 token（直接粘贴然后回车）"
echo "=============================================="
echo ""
read -p "你的 DeepSeek token: " USER_TOKEN < /dev/tty
# 替换占位符
sed -i "s/你的token填这里/${USER_TOKEN}/" ~/.claude/settings.json
echo "[ok] token 已写入配置"

echo ""
echo "===== 第5步：验证 ====="
claude --version && echo "[ok] Claude Code 安装成功！" || { echo "[!] claude 命令未找到，重开 Termux 窗口再试"; exit 1; }

# ====== 阶段二：cc-connect ======

echo ""
echo "===== 第6步：装 cc-connect ====="
npm install -g cc-connect --ignore-scripts

CC_VERSION="v1.3.4"
CC_FILE="cc-connect-${CC_VERSION}-linux-arm64.tar.gz"
BIN_DIR="/data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin"
TMP_DIR="$HOME/.tmp"
mkdir -p "$TMP_DIR"

if curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" 2>/dev/null; then
    echo "[ok] 从 GitHub 下载成功"
else
    echo "[info] 换加速..."
    curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || {
        echo "[info] 试 Gitee..."
        curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://gitee.com/cg33/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || { echo "[!] 下载失败"; exit 1; }
    }
fi

tar xzf "$TMP_DIR/${CC_FILE}" -C "$TMP_DIR/"
mkdir -p ${BIN_DIR}
BIN=$(find "$TMP_DIR/" -name "cc-connect*" -type f 2>/dev/null | awk '{print length, $0}' | sort -rn | head -1 | cut -d' ' -f2-)
[ -z "$BIN" ] && { echo "[!] 找不到二进制"; exit 1; }
cp "$BIN" ${BIN_DIR}/cc-connect
chmod +x ${BIN_DIR}/cc-connect
rm -f /data/data/com.termux/files/usr/bin/cc-connect
ln -s ${BIN_DIR}/cc-connect /data/data/com.termux/files/usr/bin/cc-connect
echo "[ok] cc-connect 安装完成"

echo ""
echo "===== 第7步：写 cc-connect 配置 ====="
mkdir -p ~/.cc-connect
cat > ~/.cc-connect/config.toml << 'TOML'
data_dir = ""
attachment_send = ""
language = "zh"

[display]
mode = "quiet"
thinking_messages = false
tool_messages = false

[[projects]]
  name = "main"
  reset_on_idle_mins = 0
  show_context_indicator = false
  reply_footer = false
  admin_from = '*'

  [projects.agent]
    type = "claudecode"

    [projects.agent.options]
      cmd = "claude"
      mode = "acceptEdits"
      system_prompt = """你是一个AI助手，和用户通过微信聊天，用中文回复。"""
      work_dir = "/data/data/com.termux/files/home"

  [[projects.platforms]]
    type = "weixin"

    [projects.platforms.options]
      account_id = "占位符"
      allow_from = "*"
      base_url = "https://ilinkai.weixin.qq.com"
      token = "占位符"

[log]
  level = "info"

[management]
  enabled = true
  port = 9820
  token = "xiaoke-mgmt-2026"
TOML

cat > ~/.cc-connect/start.sh << 'SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
export HOME=/data/data/com.termux/files/home
exec /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect \
  --config /data/data/com.termux/files/home/.cc-connect/config.toml
SCRIPT
chmod +x ~/.cc-connect/start.sh
echo "[ok] cc-connect 配置完成"

echo ""
echo "===== 第8步：启动 cc-connect ====="
termux-wake-lock 2>/dev/null || true
nohup proot -0 \
  -b /data/data/com.termux/files/usr/bin/env:/usr/bin/env \
  -b /data/data/com.termux/files/usr/etc/resolv.conf:/etc/resolv.conf \
  -b /data/data/com.termux/files/usr/etc/hosts:/etc/hosts \
  ~/.cc-connect/start.sh > ~/.cc-connect/cc-connect.log 2>&1 &
sleep 3
if tail -10 ~/.cc-connect/cc-connect.log | grep -qE "ready-for-poll|platform ready"; then
    echo "[ok] cc-connect 启动成功"
else
    echo "[warn] 日志未见就绪标志，查看：tail ~/.cc-connect/cc-connect.log"
fi

echo ""
echo "===== 第9步：扫码绑定微信 ====="
echo ""
echo "=============================================="
echo "  即将弹出二维码，用微信扫描"
echo "=============================================="
echo ""
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
proot -0 cc-connect weixin setup --config ~/.cc-connect/config.toml

# 补偿逻辑：扫码成功但 token 未自动写入时，尝试从日志恢复
CURRENT_TOKEN=$(grep -oP 'token\s*=\s*"\K[^"]+' ~/.cc-connect/config.toml 2>/dev/null | head -1)
if [ "$CURRENT_TOKEN" = "占位符" ] || [ -z "$CURRENT_TOKEN" ]; then
    echo "[!] token 未自动写入，尝试从 cc-connect 输出中恢复..."
    # 尝试从 cc-connect 最近日志中提取 token
    LOG_TOKEN=$(grep -oP 'token["\s:=]+\K[0-9a-f]{20,}' ~/.cc-connect/cc-connect.log 2>/dev/null | tail -1)
    if [ -n "$LOG_TOKEN" ]; then
        sed -i "s/token = \"占位符\"/token = \"$LOG_TOKEN\"/" ~/.cc-connect/config.toml
        echo "[ok] 已从日志恢复 token"
    else
        echo "[!] 自动恢复失败，请重新扫码：proot -0 cc-connect weixin setup --config ~/.cc-connect/config.toml"
        echo "    如果多次扫码无效，请到 Gitee 提 Issue 附上这条日志："
        echo "    tail -20 ~/.cc-connect/cc-connect.log"
    fi
fi

echo ""
echo "===== 验证 ====="
sleep 1
proot -0 cc-connect send -m "全部装好了！" -p main 2>/dev/null && echo "[ok] 测试消息已发送" || echo "[warn] 测试消息失败"

echo ""
echo "=============================================="
echo "  全部完成！"
echo "  现在用微信发条消息试试"
echo "  仓库：github.com/xvxv-stack7/android-claude-wechat"
echo "=============================================="
