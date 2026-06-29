#!/data/data/com.termux/files/usr/bin/bash
# ============================================
# cc-connect 一键安装 + 微信扫码绑定
# 复制粘贴回车，坐着等二维码弹出来扫就行
# ============================================
set -e

echo "===== 第1步：检查 DNS ====="
if ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1; then
    echo "[ok] DNS 通"
else
    echo "[fix] 配 DNS..."
    echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
    echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
    ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] DNS 修好了" || { echo "[!] DNS 还是不通，检查网络后重试"; exit 1; }
fi

echo ""
echo "===== 第2步：安装 cc-connect ====="
npm install -g cc-connect --ignore-scripts 2>/dev/null
echo "[ok] npm 包安装完成"

echo ""
echo "===== 第3步：下载二进制 ====="
CC_VERSION="v1.3.4"
CC_FILE="cc-connect-${CC_VERSION}-linux-arm64.tar.gz"
BIN_DIR="/data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin"

# 先试 GitHub，5 秒超时自动切 Gitee/ghproxy
if curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" 2>/dev/null; then
    echo "[ok] 从 GitHub 下载成功"
else
    echo "[info] GitHub 超时，换加速地址..."
    curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || {
        echo "[info] 加速也失败，试 Gitee..."
        curl -L --connect-timeout 5 --max-time 60 -o /tmp/${CC_FILE} "https://gitee.com/cg33/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || {
            echo "[!] 所有源都下载失败，检查网络"; exit 1
        }
    }
fi

echo "[ok] 二进制下载完成"
tar xzf /tmp/${CC_FILE} -C /tmp/
mkdir -p ${BIN_DIR}
BIN=$(find /tmp/ -name "cc-connect*" -type f 2>/dev/null | head -1)
[ -z "$BIN" ] && { echo "[!] 找不到解压后的二进制"; exit 1; }
cp "$BIN" ${BIN_DIR}/cc-connect
chmod +x ${BIN_DIR}/cc-connect

echo ""
echo "===== 第4步：修复路径 ====="
rm -f /data/data/com.termux/files/usr/bin/cc-connect
ln -s ${BIN_DIR}/cc-connect /data/data/com.termux/files/usr/bin/cc-connect
cc-connect --version && echo "[ok] 路径修复成功"

echo ""
echo "===== 第5步：写入配置 ====="
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
echo "[ok] config.toml 写入完成"

echo ""
echo "===== 第6步：创建启动脚本 ====="
cat > ~/.cc-connect/start.sh << 'SCRIPT'
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
export HOME=/data/data/com.termux/files/home
exec /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect \
  --config /data/data/com.termux/files/home/.cc-connect/config.toml
SCRIPT
chmod +x ~/.cc-connect/start.sh
echo "[ok] start.sh 创建完成"

echo ""
echo "===== 第7步：启动 cc-connect ====="
which curl > /dev/null 2>&1 || pkg install curl -y
which proot > /dev/null 2>&1 || { echo "[fix] 装 proot..."; pkg install proot -y 2>/dev/null || true; }
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
    echo "[warn] 日志没看到就绪标志，但进程已启动。查看日志：tail ~/.cc-connect/cc-connect.log"
fi

echo ""
echo "===== 第8步：扫码绑定微信 ====="
echo ""
echo "=============================================="
echo "  马上会弹出一个二维码"
echo "  请用微信扫描"
echo "  扫码成功后 token 自动写入配置"
echo "=============================================="
echo ""

# 扫码
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
proot -0 cc-connect weixin setup --config ~/.cc-connect/config.toml

echo ""
echo "===== 第9步：验证 ====="
sleep 1
proot -0 cc-connect send -m "微信连接成功！" -p main 2>/dev/null && echo "[ok] 测试消息已发送，查下微信" || echo "[warn] 测试消息发送失败，手动检查：tail ~/.cc-connect/cc-connect.log"

echo ""
echo "=============================================="
echo "  全部完成！"
echo "  现在用微信给你绑定的账号发条消息试试"
echo "  如果没回复，运行：tail -f ~/.cc-connect/cc-connect.log"
echo "=============================================="
