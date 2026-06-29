Termux 安装 Claude Code 完整教程
====================================
最后更新：2026-06-29


路线A：有代理（推荐，一步过）
==============================

A1. 开代理去 https://f-droid.org 下 F-Droid 的 apk。
    （F-Droid 是一个开源软件应用商店，只有 F-Droid 下的最新版 Termux 才能装 Claude Code）

A2. 装好 F-Droid 后搜 Termux 安装。

A3. 打开 Termux，配代理（端口改成你自己的）：
    export http_proxy=http://127.0.0.1:7890
    export https_proxy=http://127.0.0.1:7890

A4. 验证代理通了没：
    curl -I https://registry.npmjs.org

A5. 通了就跑这一条命令：
    pkg update -y && pkg install nodejs binutils make python3 git -y && npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code && mkdir -p ~/.claude && cat > ~/.claude/settings.json << 'EOF'
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

A6. 新开一个 Termux 窗口（让 PATH 生效），输入 claude 回车。


路线B：无代理（可能断，多试几次）
==================================

B1. F-Droid 官网被墙了，从清华镜像站下 apk：
    https://mirrors.tuna.tsinghua.edu.cn/fdroid/archive/org.fdroid.fdroid_1019052.apk
    （F-Droid 是一个开源软件应用商店，只有 F-Droid 下的最新版 Termux 才能装 Claude Code）

B2. 装完 F-Droid 后配镜像源才能加载软件列表：
    - 打开 F-Droid → 设置 → 储存库
    - 删掉默认的 f-droid.org/repo（连不上）
    - 点右下角 + 号，添加：
      https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/?fingerprint=43238D512C1E5EB2D6569F4A3AFBF5523418B82E0A3ED1552770ABB9A9C9CCAB
    - 下拉刷新，搜 Termux 安装

B3. 打开 Termux，跑这一条命令（镜像源和配置全包了，断了重跑就行）：
    pkg update -y && pkg install nodejs binutils make python3 git -y && npm config set registry https://registry.npmmirror.com && npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code && mkdir -p ~/.claude && cat > ~/.claude/settings.json << 'EOF'
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

B4. 新开一个 Termux 窗口（让 PATH 生效），输入 claude 回车。


如何找到自己的代理端口
======================

常见代理软件默认端口：
  Clash / Clash Meta   →  7890
  v2rayNG / v2rayN     →  10809
  Shadowsocks          →  1080
  Sing-Box             →  2080

如果不确定，打开代理 app → 设置 → 找"端口""HTTP 端口""本地端口""监听端口"这类字眼。

注意：如果你的代理 app 开的是 VPN 模式而不是 HTTP 代理模式，export 那两行不管用。
去代理 app 设置里把"允许来自局域网的连接"打开，然后在 Wi-Fi 设置里查本机局域网 IP
（一般是 192.168.x.x），export 里把 127.0.0.1 换成这个 IP。


常见报错和解决办法
==================

【报错】curl: (7) Failed to connect to registry.npmjs.org
原因：代理没配或没开
解决：检查代理 app 是否在后台运行，export 的端口号对不对

【报错】npm ERR! network request to https://registry.npmjs.org/... failed
原因：网络超时，无代理方案常见
解决：重新跑一次 npm install 命令，多试几次

【报错】npm ERR! fetch failed / socket hang up
原因：下载中断
解决：重跑安装命令，或者切到有代理的方案

【报错】node: not found / claude: command not found
原因：npm install -g 装的东西没在 PATH 里
解决：
  echo 'export PATH=$PATH:~/.local/bin' >> ~/.bashrc
  source ~/.bashrc
  然后重开 Termux 再试

【报错】Error: Cannot find module 'xxx'
原因：依赖没装全
解决：重跑安装命令

【报错】configure: error: no acceptable C compiler found in $PATH
原因：缺少编译工具
解决：pkg install binutils make -y

【关于固定版本】
如果需要固定版本不自动升级：npm install -g @anthropic-ai/claude-code@2.1.195

【关于开机自启】
Termux 开机自启需要额外配置 Termux:Boot 插件，可在 F-Droid 里搜。
安装后把启动脚本放到 ~/.termux/boot/ 目录下即可。

【关于 Token 安全】
不要在聊天记录里直接粘贴 token。教程里的 token 位置写的是占位符，替换成你自己的就行。
如果 token 已经泄露了，去对应平台重新生成一个。
