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
    echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
    echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
    ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] DNS 修好了" || { echo "[!] DNS 不通"; exit 1; }
fi

echo ""
echo "===== 第2步：装依赖 ====="
pkg update -y && pkg install nodejs binutils make python3 git proot ca-certificates curl -y
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第3步：换镜像 + 装 Claude Code ====="
npm config set registry https://registry.npmmirror.com
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code
if ! command -v claude &> /dev/null; then
    echo "[fix] 二进制缺失，手动下载..."
    node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs" 2>/dev/null || true
fi
# Termux 修复（2026-06-30 絮絮实测）
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
WRAPPER="/data/data/com.termux/files/usr/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
mkdir -p "$VERSIONS_DIR"
rm -f "$VERSIONS_DIR"/2.1.196.tmp "$VERSIONS_DIR"/2.1.196 2>/dev/null
echo "2.1.196" >> "$VERSIONS_DIR/.blocklist" 2>/dev/null
echo "2.1.195" > "$VERSIONS_DIR/.verified" 2>/dev/null
[ -f "$GLIBC_LIB" ] && [ ! -L "$GLIBC_LIB" ] && { cp "$GLIBC_LIB" "${GLIBC_LIB}.bak" 2>/dev/null; ln -sf libc.so.6 "$GLIBC_LIB"; }
[ -f "$WRAPPER" ] && { sed -i 's/exec "\$bin"/LD_PRELOAD= exec "\$bin"/' "$WRAPPER" 2>/dev/null; }
sed -i 's/^RATE_LIMIT=.*/RATE_LIMIT=315360000/' "$WRAPPER" 2>/dev/null
echo "[ok] Claude Code 安装完成（Termux 修复已应用）"

echo ""
echo "===== 第4步：写配置 ====="
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
claude --version && echo "[ok] Claude Code 安装成功！"

# ====== 阶段二：cc-connect ======

echo ""
echo "===== 第6步：装 cc-connect ====="
npm install -g cc-connect --ignore-scripts

CC_VERSION="v1.3.4"
CC_FILE="cc-connect-${CC_VERSION}-linux-arm64.tar.gz"
BIN_DIR="/data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin"

if curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" 2>/dev/null; then
    echo "[ok] 从 GitHub 下载成功"
else
    echo "[info] 换加速..."
    curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || {
        echo "[info] 试 Gitee..."
        curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://gitee.com/cg33/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || { echo "[!] 下载失败"; exit 1; }
    }
fi

tar xzf /tmp/${CC_FILE} -C /tmp/
mkdir -p ${BIN_DIR}
BIN=$(find /tmp/ -name "cc-connect*" -type f 2>/dev/null | head -1)
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
