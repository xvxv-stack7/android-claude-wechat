#!/bin/bash
# ============================================
# cc-connect Ubuntu 容器测试版
# ============================================
set -e

echo "===== Ubuntu 容器测试环境 ====="

echo ""
echo "===== 第0步：修复 DNS ====="
echo "nameserver 8.8.8.8" > /etc/resolv.conf 2>/dev/null || true
echo "nameserver 114.114.114.114" >> /etc/resolv.conf 2>/dev/null || true
ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1 && echo "[ok] DNS 通" || echo "[warn] DNS 可能不通，继续..."

echo ""
echo "===== 第1步：检查网络 ====="
ping -c 1 -W 3 registry.npmmirror.com > /dev/null 2>&1 && echo "[ok] 网络通" || echo "[note] 网络不通但不影响测试"

echo ""
echo "===== 第2步：装依赖 ====="
export DEBIAN_FRONTEND=noninteractive
echo "tzdata tzdata/Areas select Asia" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Zones/Asia select Shanghai" | debconf-set-selections 2>/dev/null || true
apt update -y && apt install curl ca-certificates -y
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install nodejs -y
echo "[ok] 依赖安装完成"

echo ""
echo "===== 第3步：安装 cc-connect ====="
npm install -g cc-connect --ignore-scripts
# 找到npm全局安装的实际路径
NODE_DIR="$(npm root -g)/cc-connect"
echo "[info] npm全局路径: $NODE_DIR"
[ -d "$NODE_DIR" ] || { echo "[!] cc-connect npm包未安装到预期路径"; exit 1; }
echo "[ok] npm 包安装完成"

echo ""
echo "===== 第4步：下载二进制 ====="
CC_VERSION="v1.3.4"
CC_FILE="cc-connect-${CC_VERSION}-linux-arm64.tar.gz"
curl -L --connect-timeout 10 --max-time 30 --retry 1 -o /tmp/${CC_FILE} "https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}" || curl -L --connect-timeout 10 --max-time 30 -o /tmp/${CC_FILE} "https://github.com/chenhg5/cc-connect/releases/download/${CC_VERSION}/${CC_FILE}"

mkdir -p "${NODE_DIR}/bin"
tar xzf /tmp/${CC_FILE} -C /tmp/
BIN=$(find /tmp/ -name "cc-connect*" -type f 2>/dev/null | head -1)
[ -z "$BIN" ] && { echo "[!] 找不到解压后的二进制"; exit 1; }
cp "$BIN" "${NODE_DIR}/bin/cc-connect"
chmod +x "${NODE_DIR}/bin/cc-connect"
ln -sf "${NODE_DIR}/bin/cc-connect" /usr/local/bin/cc-connect
cc-connect --version && echo "[ok] 二进制安装成功"

echo ""
echo "===== 第5步：写入配置 ====="
mkdir -p ~/.cc-connect
cat > ~/.cc-connect/config.toml << TOML
data_dir = ""
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
      work_dir = "/root"

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
  token = "test-token"
TOML
echo "[ok] config.toml 写入完成"

echo ""
echo "===== 第6步：创建启动脚本 ====="
cat > ~/.cc-connect/start.sh << SCRIPT
#!/bin/bash
export HOME=/root
exec ${NODE_DIR}/bin/cc-connect --config /root/.cc-connect/config.toml
SCRIPT
chmod +x ~/.cc-connect/start.sh
echo "[ok] start.sh 创建完成（使用路径: ${NODE_DIR}）"

echo ""
echo "===== 第7步：启动 ====="
set +e
bash ~/.cc-connect/start.sh > ~/.cc-connect/cc-connect.log 2>&1 &
sleep 2
echo "[ok] 启动命令已执行（测试环境无Claude Code，找不到claude正常）"
echo "日志："
cat ~/.cc-connect/cc-connect.log 2>/dev/null | head -5 || echo "[note] 日志为空（预期）"
set -e

echo ""
echo "===== 第8步：扫码 ====="
echo "请用微信扫描二维码..."
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
cc-connect weixin setup --config ~/.cc-connect/config.toml

echo ""
echo "[done] 测试完成。exit 退出容器。"
