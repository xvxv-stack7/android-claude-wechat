# cc-connect：把 Claude Code 接入微信

> 实测通过版本。Termux环境需要手动安装+proot包装启动。

## 零、DNS（先配，否则后面全断）

Termux默认没有 `/etc/resolv.conf`，curl下载和微信连接都会断：

```bash
echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
```

验证：
```bash
ping -c 2 registry.npmmirror.com
```

通了再往下走。

## 一、安装 cc-connect

```bash
# 1. 安装npm包本体（跳过自动下载二进制）
npm install -g cc-connect --ignore-scripts

# 2. 手动下载 linux-arm64 二进制
#    去 https://github.com/chenhg5/cc-connect/releases 看最新版本号（当前v1.3.4）
#    国内慢用加速：https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/v1.3.4/cc-connect-v1.3.4-linux-arm64.tar.gz
curl -L -o /tmp/cc-connect.tar.gz https://github.com/chenhg5/cc-connect/releases/download/v1.3.4/cc-connect-v1.3.4-linux-arm64.tar.gz

# 3. 解压到npm全局bin目录
tar xzf /tmp/cc-connect.tar.gz -C /tmp/
mkdir -p /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/
cp /tmp/cc-connect /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect
chmod +x /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect

# 4. 修复命令路径
rm -f /data/data/com.termux/files/usr/bin/cc-connect
ln -s /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect /data/data/com.termux/files/usr/bin/cc-connect
```

## 二、配置 config.toml

```bash
mkdir -p ~/.cc-connect
cat > ~/.cc-connect/config.toml << 'EOF'
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
  token = "默认管理token"
EOF
```

> account_id 和 token 先写占位符，后面 `cc-connect weixin setup` 会自动更新。

### 配置关键点（踩坑记录）

- **system_prompt 必须填**：不写的话Claude没有角色设定，回复会变成冷冰冰的客服语气
- **work_dir 写绝对路径**：不要写 `~`，proot 里不认
- **weixin token 格式**：账号ID和token值用冒号连接
- **心跳 interval**：微信限速，建议不开启或30分钟以上
- **management port 9820**：管理端口，用于定时任务等功能

## 三、创建启动脚本

```bash
cat > ~/.cc-connect/start.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
export HOME=/data/data/com.termux/files/home
exec /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect \
  --config /data/data/com.termux/files/home/.cc-connect/config.toml
EOF
chmod +x ~/.cc-connect/start.sh
```

> SSL_CERT_FILE 指向Termux的TLS证书——没有它HTTPS连微信服务器会失败。路径跟普通Linux不一样，别改。

## 四、启动

Termux直跑cc-connect有三个必踩的坑，proot -0一步解决：

```bash
termux-wake-lock
nohup proot -0 \
  -b /data/data/com.termux/files/usr/bin/env:/usr/bin/env \
  -b /data/data/com.termux/files/usr/etc/resolv.conf:/etc/resolv.conf \
  -b /data/data/com.termux/files/usr/etc/hosts:/etc/hosts \
  ~/.cc-connect/start.sh > ~/.cc-connect/cc-connect.log 2>&1 &
```

三个坑对应三行 -b：
- **faccessat2 SIGSYS** → `proot -0` 系统调用模拟
- **DNS解析失败** → `-b resolv.conf`
- **shebang /usr/bin/env** → `-b env` + `-b hosts`

### 验证启动成功

```bash
# 检查日志
tail -20 ~/.cc-connect/cc-connect.log
```

看到 `"ilink ready-for-poll"` 和 `"platform ready"` 就说明启动成功。

## 五、扫码绑定微信

```bash
proot -0 cc-connect weixin setup --config ~/.cc-connect/config.toml
```

运行后会生成二维码，用手机微信扫描绑定。绑定成功后token会自动写入config.toml。

### 测试消息

绑定完成后发一条消息到微信，确认AI能正常回复。如果不通，检查日志：

```bash
tail -f ~/.cc-connect/cc-connect.log
```

## 停止

```bash
pkill -f cc-connect
```

## 常见报错

| 报错 | 原因 | 解决 |
|-----|------|-----|
| `EAI_AGAIN` | DNS解析失败 | 配resolv.conf，检查proot是否绑了 |
| `SIGSYS` | faccessat2不被支持 | 启动命令加 `proot -0` |
| `/usr/bin/env: not found` | shebang路径不存在 | proot -b 映射env |
| `certificate verify failed` | TLS证书路径不对 | 检查 `SSL_CERT_FILE` |
| `ECONNREFUSED` | 连不上服务器 | 检查代理/VPN是否拦截 |
| `exec: cc-connect: not found` | 二进制没在PATH里 | 检查ln -s是否生效，ls -la /usr/bin/cc-connect |
