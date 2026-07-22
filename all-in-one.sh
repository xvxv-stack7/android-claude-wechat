#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# 一条命令：Claude Code + cc-connect 微信
# 全程两次暂停：拿token、扫码
# ============================================
set -e
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 自动反馈：出错时自动提交 Gitee Issue
source "$SCRIPT_DIR/auto-feedback.sh" 2>/dev/null || {
    source <(curl -sL "https://gitee.com/xvxv663/android-claude-wechat/raw/master/auto-feedback.sh") 2>/dev/null || true
}

# 先诊断（--pre 安装前模式：未安装的组件只警告不致命）
if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
    set +e
    bash "$SCRIPT_DIR/doctor.sh" --pre
    DR_EXIT=$?
    set -e
    if [ "$DR_EXIT" -eq 2 ]; then
        echo "[!] 环境有致命问题，请先修复再继续"
        exit 1
    fi
fi

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
echo "===== 第2步：换 Termux 国内源 ====="
# 1. 写 sources.list（兜底，兼容所有版本）
for SRC in "$PREFIX/etc/apt/sources.list" "$PREFIX/etc/apt/sources.list.d/glibc.list"; do
    if [ -f "$SRC" ]; then
        sed -i -e 's@https\?://[^/]*/termux/apt@https://mirrors.tuna.tsinghua.edu.cn/termux/apt@g' \
               -e 's@https\?://[^/]*/apt@https://mirrors.tuna.tsinghua.edu.cn/termux/apt@g' "$SRC" 2>/dev/null
    fi
done
# 2. 写 mirror 配置（新版 Termux 的镜像选择系统）
MIRROR_DIR="$PREFIX/etc/termux/mirrors"
mkdir -p "$MIRROR_DIR" 2>/dev/null
cat > "$MIRROR_DIR/default" << 'MIRROREOF'
WEIGHT=10
MAIN="https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main"
ROOT="https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-root"
X11="https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-x11"
MIRROREOF
	# 验证镜像源是否生效（新版 Termux 可能不认直接写入的配置文件）
	if pkg update -y > /dev/null 2>&1; then
		echo "[ok] Termux 源已切到清华镜像"
	else
		echo "[!] 镜像源未生效，请先手动配置："
		echo "    1. 新开一个 Termux 窗口，运行: termux-change-repo"
		echo "    2. 选择清华镜像 (Tsinghua)"
		echo "    3. 回到这个窗口重新运行: bash all-in-one.sh"
		echo ""
		echo "    配好源之后直接重新跑一键命令就行，不需要额外操作。"
		exit 1
	fi

echo ""
echo "===== 第3步：装依赖 ====="
# 防止 dpkg 配置文件交互弹窗（保留用户已修改的配置）
mkdir -p /data/data/com.termux/files/usr/etc/apt/apt.conf.d 2>/dev/null
echo 'Dpkg::Options {"--force-confdef"; "--force-confold";};' > /data/data/com.termux/files/usr/etc/apt/apt.conf.d/99-noninteractive.conf
pkg install nodejs binutils make python3 git proot ca-certificates curl -y
# 修复 Termux 经典问题：openssl 升级后 node 符号不匹配
if ! node --version >/dev/null 2>&1; then
    echo "[fix] node 与 openssl 版本不匹配，修复中..."
    pkg upgrade -y 2>/dev/null || pkg install --reinstall openssl nodejs -y 2>/dev/null
fi
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第4步：换 npm 镜像 + 装 Claude Code ====="
npm config set registry https://registry.npmmirror.com
npm config set allow-scripts=@anthropic-ai/claude-code --location=user 2>/dev/null || true
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code@2.1.195
if ! claude --version &> /dev/null 2>&1; then
    echo "[fix] 二进制缺失，手动下载..."
    node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs" 2>&1 || true
    if ! claude --version &> /dev/null 2>&1; then
        echo "[fix] install.cjs失败，curl直下二进制..."
        mkdir -p ~/.local/share/claude/versions ~/.local/bin
        # 优先本地 bin/ 目录（git clone 已带回），真正免下载
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        if [ -f "$SCRIPT_DIR/bin/claude-2.1.195-arm64.xz" ]; then
            python3 -c "import lzma,sys; sys.stdout.buffer.write(lzma.open('$SCRIPT_DIR/bin/claude-2.1.195-arm64.xz').read())" > ~/.local/share/claude/versions/2.1.195 2>/dev/null
            echo "[ok] 本地 xz 解压成功（Gitee 仓库自带）"
        fi
        if [ ! -f ~/.local/share/claude/versions/2.1.195 ]; then
            if curl -fsSL --connect-timeout 10 --max-time 120 "https://github.com/xvxv-stack7/android-claude-wechat/releases/download/binary-2.1.195/claude-2.1.195-arm64.xz" -o ~/.local/share/claude/versions/claude.xz 2>/dev/null; then
                python3 -c "import lzma,sys; sys.stdout.buffer.write(lzma.open('$HOME/.local/share/claude/versions/claude.xz').read())" > ~/.local/share/claude/versions/2.1.195 2>/dev/null
                rm -f ~/.local/share/claude/versions/claude.xz
                echo "[ok] GitHub xz 压缩包下载解压成功"
            fi
        fi
        if [ ! -f ~/.local/share/claude/versions/2.1.195 ]; then
            curl -fsSL --connect-timeout 10 --max-time 300 "https://downloads.claude.ai/claude-code-releases/2.1.195/linux-arm64/claude" -o ~/.local/share/claude/versions/2.1.195 2>/dev/null \
            || curl -fsSL --connect-timeout 10 --max-time 300 "https://downloads.claude.ai/claude-code-releases/2.1.195/linux-arm64-musl/claude" -o ~/.local/share/claude/versions/2.1.195 2>/dev/null
        fi
        if [ -f ~/.local/share/claude/versions/2.1.195 ]; then
            chmod +x ~/.local/share/claude/versions/2.1.195
            echo "[ok] 二进制就绪"
        else
            echo "[!] 二进制下载失败，手动操作："
            echo "    浏览器打开 https://gitee.com/xvxv663/android-claude-wechat"
            echo "    下载仓库里 bin/claude-2.1.195-arm64.xz 放到 ~/.local/share/claude/versions/"
            echo "    然后运行: cd ~/.local/share/claude/versions && python3 -c \"import lzma,sys; sys.stdout.buffer.write(lzma.open('claude-2.1.195-arm64.xz').read())\" > 2.1.195 && chmod +x 2.1.195"
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
    pkg install glibc-runner patchelf-glibc -y 2>/dev/null || echo "[warn] glibc-runner 安装失败，跳过（不影响运行）"
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
echo "===== 第5步：写配置 ====="
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
echo "===== 第6步：验证 ====="
claude --version && echo "[ok] Claude Code 安装成功！" || { echo "[!] claude 命令未找到，重开 Termux 窗口再试"; exit 1; }

# ====== 阶段二：cc-connect ======

echo ""
echo "===== 第7步：装 cc-connect ====="
npm install -g cc-connect --ignore-scripts

CC_VERSION="v1.3.4"
CC_FILE="cc-connect-${CC_VERSION}-linux-arm64.tar.gz"
BIN_DIR="/data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin"
TMP_DIR="$HOME/.tmp"
mkdir -p "$TMP_DIR"

# 优先 Gitee（国内直连最稳），其次 GitHub，最后 ghproxy 加速
if curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://gitee.com/cg33/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" 2>/dev/null; then
    echo "[ok] 从 Gitee 下载成功"
else
    echo "[info] Gitee 失败，试 GitHub..."
    if curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" 2>/dev/null; then
        echo "[ok] 从 GitHub 下载成功"
    else
        echo "[info] 换 ghproxy 加速..."
        curl -L --connect-timeout 5 --max-time 60 -o "$TMP_DIR/${CC_FILE}" "https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || { echo "[!] 下载失败"; exit 1; }
    fi
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
echo "===== 第8步：写 cc-connect 配置 ====="
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
echo "===== 第9步：启动 cc-connect ====="
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
echo "===== 第10步：扫码绑定微信 ====="
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
echo "  仓库：gitee.com/xvxv663/android-claude-wechat"
echo "=============================================="
