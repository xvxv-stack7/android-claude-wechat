# cc-connect：把 Claude Code 接入微信

> 实测通过版本。非标准npm安装——Termux环境需要特殊处理。

## 前置依赖

装Claude Code时已装过的跳过，缺的补：

```bash
pkg install proot ca-certificates -y
```

## 安装（Termux实测版）

标准 `npm install -g` 在Termux上postinstall脚本可能失败，用分步手动方式：

```bash
# 1. 安装npm包本体（跳过自动下载二进制）
npm install -g cc-connect --ignore-scripts

# 2. 手动下载ARM64二进制
#    去GitHub查最新版本：https://github.com/chenhg5/cc-connect/releases
#    下载 linux-arm64.tar.gz（国内被墙则用Gitee: https://gitee.com/cg33/cc-connect/releases）
curl -L -o /tmp/cc-connect.tar.gz https://github.com/chenhg5/cc-connect/releases/download/v1.3.4/cc-connect-v1.3.4-linux-arm64.tar.gz

# 3. 解压到npm全局目录的bin下
tar xzf /tmp/cc-connect.tar.gz -C /tmp/
cp /tmp/cc-connect /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/
chmod +x /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect
```

## 配置

```bash
# 创建配置目录
mkdir -p ~/.cc-connect

# 复制配置模板
cp cc-connect/config.toml.example ~/.cc-connect/config.toml

# 编辑：改微信账号ID和token
nano ~/.cc-connect/config.toml

# 扫码绑定微信
cc-connect weixin setup --config ~/.cc-connect/config.toml
```

扫码成功后token自动写入config.toml，以后不需要重新扫码。

## 启动（proot包装，必读）

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

## DNS

Termux默认没有 `/etc/resolv.conf`，先创建：

```bash
echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
```

验证：
```bash
ping -c 2 registry.npmmirror.com
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

## 启动脚本说明

`start.sh` 内容：
```bash
export SSL_CERT_FILE=/data/data/com.termux/files/usr/etc/tls/cert.pem
export HOME=/data/data/com.termux/files/home
exec /data/data/com.termux/files/usr/lib/node_modules/cc-connect/bin/cc-connect \
  --config /data/data/com.termux/files/home/.cc-connect/config.toml
```

SSL_CERT_FILE 指向Termux的TLS证书——没有它HTTPS连微信服务器会失败。
