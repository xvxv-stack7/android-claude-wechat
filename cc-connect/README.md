# cc-connect：把 Claude Code 接入微信

## 安装和配置

```bash
# 安装cc-connect（自动下载对应平台的二进制）
npm install -g cc-connect

# 创建配置目录
mkdir -p ~/.cc-connect

# 复制配置模板
cp cc-connect/config.toml.example ~/.cc-connect/config.toml

# 编辑配置：填你的微信账号ID和token（从微信机器人平台获取）
nano ~/.cc-connect/config.toml

# 扫码绑定微信
cc-connect weixin setup --config ~/.cc-connect/config.toml

# 启动
bash cc-connect/start.sh
```

扫码成功后配置会被写入config.toml，之后每次启动只需要最后一步。

## DNS 配置

## 为什么需要手动配 DNS？

Termux 默认不写 `/etc/resolv.conf`。npm 下载、cc-connect 连微信服务器、Claude Code 调 API——全都需要域名解析。DNS 不通，后面全白搭。

## 一步修复

```bash
# 创建resolv.conf
echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
```

## 验证

```bash
# 国内用这个
ping -c 2 registry.npmmirror.com

# 国外用这个
ping -c 2 registry.npmjs.org
```

如果能ping通，DNS就对了。

## DNS还是不通？

### 1. 检查你是不是在代理/VPN模式

如果你的代理app开的是VPN模式（而不是HTTP代理），DNS可能被代理接管。切到HTTP代理模式，或者在代理app里检查DNS设置。

### 2. 换国内DNS

```bash
echo "nameserver 223.5.5.5" > /data/data/com.termux/files/usr/etc/resolv.conf   # 阿里DNS
echo "nameserver 119.29.29.29" > /data/data/com.termux/files/usr/etc/resolv.conf  # 腾讯DNS
```

### 3. 检查resolv.conf路径

Termux不同版本resolv.conf位置可能不同：
```bash
# 试试这几个位置
ls -la /data/data/com.termux/files/usr/etc/resolv.conf
ls -la /etc/resolv.conf
```

## 启动脚本说明

`start.sh` 里 `SSL_CERT_FILE` 环境变量是指定TLS证书路径——没有它，HTTPS连接会报证书错误。DNS和证书两样配好，cc-connect才能稳定连接微信服务器。

## 常见报错

| 报错 | 原因 | 解决 |
|-----|------|-----|
| `EAI_AGAIN` | DNS解析失败 | 配resolv.conf |
| `certificate verify failed` | 证书路径不对 | 检查 `SSL_CERT_FILE` 路径 |
| `ECONNREFUSED` | 连不上服务器 | 检查代理/VPN是否拦截 |
| `ETIMEDOUT` | 连接超时 | 换DNS或检查网络 |

## 启动

```bash
bash cc-connect/start.sh
```

后台运行，重启Termux窗口后也不断。想关掉：
```bash
pkill -f cc-connect
```
