# 安装 cc-connect 连接微信（AI 自动执行版）

你现在是安装向导。用户已经在 Termux 上跑通了 Claude Code（能跟你对话），你要帮他装 cc-connect 把 Claude Code 接入微信。

**核心原则：你能用 Bash 跑的命令全都自己跑，不要让用户复制粘贴。用户只需要做两件事：扫码和装 APK。**

---

## 第零步：检查并修复 DNS

先自己跑：
```bash
ping -c 2 -W 3 registry.npmmirror.com
```

通了 → 继续下一步。

超时或不通 → 自己跑：
```bash
echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
```
再 ping 一次。还不行换阿里 DNS：223.5.5.5。始终不通才告诉用户"网络有问题，检查 Wi-Fi 或代理"。

---

## 第一步：安装 cc-connect npm 包

直接跑：
```bash
npm install -g cc-connect --ignore-scripts
```
`--ignore-scripts` 跳过 postinstall（Termux 上可能失败）。

---

## 第二步：下载并安装 ARM64 二进制

直接跑：
```bash
curl -L -o /tmp/cc-connect.tar.gz https://github.com/chenhg5/cc-connect/releases/download/v1.3.4/cc-connect-v1.3.4-linux-arm64.tar.gz
```

如果 5 秒内失败或太慢，换加速：
```bash
curl -L -o /tmp/cc-connect.tar.gz https://ghproxy.net/https://github.com/chenhg5/cc-connect/releases/download/v1.3.4/cc-connect-v1.3.4-linux-arm64.tar.gz
```

下载成功后直接跑：
```bash
tar xzf /tmp/cc-connect.tar.gz -C /tmp/
mkdir -p /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/
cp /tmp/cc-connect /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect
chmod +x /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect
```

---

## 第三步：修复命令路径

直接跑：
```bash
rm -f /data/data/com.termux/files/usr/bin/cc-connect
ln -s /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect /data/data/com.termux/files/usr/bin/cc-connect
cc-connect --version
```
输出版本号即成功。

---

## 第四步：写入 config.toml

直接跑：
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

告诉用户：account_id 和 token 先写占位符，后面扫码自动更新。system_prompt 可以之后按喜好改。

---

## 第五步：写入启动脚本

直接跑：
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

---

## 第六步：proot 启动

先检查 proot 装了没：
```bash
which proot || pkg install proot -y
```

然后直接跑：
```bash
pkill -f cc-connect 2>/dev/null
termux-wake-lock
nohup proot -0 \
  -b /data/data/com.termux/files/usr/bin/env:/usr/bin/env \
  -b /data/data/com.termux/files/usr/etc/resolv.conf:/etc/resolv.conf \
  -b /data/data/com.termux/files/usr/etc/hosts:/etc/hosts \
  ~/.cc-connect/start.sh > ~/.cc-connect/cc-connect.log 2>&1 &
```

等 3 秒后检查日志：
```bash
tail -20 ~/.cc-connect/cc-connect.log
```

看到 `ilink ready-for-poll` 和 `platform ready` → 启动成功，告诉用户。
没看到 → 把日志关键行发给用户，问要不要排查。

---

## 第七步：扫码绑定微信（唯一需要用户动手的步骤）

告诉用户"现在需要在手机上扫码绑定微信"。

先跑：
```bash
proot -0 cc-connect weixin setup --config ~/.cc-connect/config.toml
```

运行后会输出二维码链接或图片。告诉用户用微信扫描。如果输出太长、用户看不到二维码，让用户截图给你看。

用户扫码成功后才继续下一步。

---

## 第八步：验证

告诉用户"绑好了，现在用微信给这个账号发一条消息试试"。

同时你自己盯着日志：
```bash
tail -f ~/.cc-connect/cc-connect.log
```

收到消息 → 回复一条测试消息"通啦！"
没收到 → 检查日志报错，对照下表排查。


## 遇错自查表

| 现象 | 原因 | 动作 |
|-----|------|------|
| ping 不通 | DNS 没配 | 回第零步配 resolv.conf |
| curl 下载超时 | 网络问题 | 换 ghproxy 加速地址 |
| cc-connect --version 报 not found | ln -s 没生效 | 回第三步修复 |
| 启动日志报 SIGSYS | 没加 proot -0 | 回第六步用 proot 包装 |
| 日志报 EAI_AGAIN | DNS 没绑进 proot | 检查 -b resolv.conf |
| 启动后日志空 | start.sh 可能报错 | 直接跑 ~/.cc-connect/start.sh 看输出 |
| 微信发消息没回复 | 没扫码或 system_prompt 空 | 回第七步绑定，检查第四步 |
| 扫码后 token 没更新 | setup 没加 --config | 重跑第七步指定 config 路径 |


## 重要规则

- **你能执行的全部自己执行**。用户除了扫码之外不需要碰命令行。
- 每一步执行完后检查结果，成功了才走下一步。
- 出错了自查上表，能修的自己修。修不了才告诉用户具体问题和建议。
- 所有文件写入用 cat heredoc，禁止让用户用 nano/vim。
