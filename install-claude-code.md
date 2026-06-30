Termux 安装 Claude Code 完整教程
====================================
最后更新：2026-06-30


路线A：有代理（推荐，一步过）
==============================

A1. 开代理去 https://f-droid.org 下 F-Droid 的 apk。
    （F-Droid 是一个开源软件应用商店，只有 F-Droid 下的最新版 Termux 才能装 Claude Code）

A2. 装好 F-Droid 后搜 Termux 安装。

A3. 打开 Termux，配代理（端口改成你自己的）：

--- 开始复制 ---
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
--- 结束复制 ---

   常见代理软件默认端口：
     Clash / Clash Meta → 7890
     v2rayNG / v2rayN   → 10809
     Shadowsocks        → 1080
     Sing-Box           → 2080

   不确定就打开代理 app → 设置 → 找"端口""HTTP 端口""本地端口"。

   注意：代理 app 开的是 VPN 模式而不是 HTTP 代理模式，export 不管用。
   去代理 app 设置里把"允许来自局域网的连接"打开，Wi-Fi 里查本机局域网 IP
   （一般是 192.168.x.x），export 里把 127.0.0.1 换成这个 IP。

A4. 验证代理通了没：

--- 开始复制 ---
curl -I https://registry.npmjs.org
--- 结束复制 ---

   看到 HTTP/2 200 就是通了。

A5. 更新包列表并装依赖：

--- 开始复制 ---
pkg update -y && pkg install nodejs binutils make python3 git -y
--- 结束复制 ---

A6. 安装 Claude Code：

--- 开始复制 ---
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code
--- 结束复制 ---

A7. 如果 claude 命令找不到，手动下载二进制：

--- 开始复制 ---
node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs"
--- 结束复制 ---

A8. Termux 修复（glibc + LD_PRELOAD + 196拉黑 + 永不更新）：

--- 开始复制 ---
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
WRAPPER="/data/data/com.termux/files/usr/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
mkdir -p "$VERSIONS_DIR"
rm -f "$VERSIONS_DIR"/2.1.196.tmp "$VERSIONS_DIR"/2.1.196
echo "2.1.196" >> "$VERSIONS_DIR/.blocklist"
echo "2.1.195" > "$VERSIONS_DIR/.verified"
[ -f "$GLIBC_LIB" ] && [ ! -L "$GLIBC_LIB" ] && { cp "$GLIBC_LIB" "${GLIBC_LIB}.bak"; ln -sf libc.so.6 "$GLIBC_LIB"; }
sed -i 's/exec "\$bin"/LD_PRELOAD= exec "\$bin"/' "$WRAPPER" 2>/dev/null
sed -i 's/^RATE_LIMIT=.*/RATE_LIMIT=315360000/' "$WRAPPER" 2>/dev/null
--- 结束复制 ---

A9. 写 settings.json（先替换 sk-你的key，再整段粘贴）：

--- 开始复制（替换 sk-你的key 后整段粘贴） ---
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-你的key",
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
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
--- 结束复制 ---

A10. 新开一个 Termux 窗口，输入 claude 回车。


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

B3. 打开 Termux，更新包列表并装依赖：

--- 开始复制 ---
pkg update -y && pkg install nodejs binutils make python3 git -y
--- 结束复制 ---

B4. 换国内镜像源：

--- 开始复制 ---
npm config set registry https://registry.npmmirror.com
--- 结束复制 ---

B5. 安装 Claude Code（超时设长，断了重跑即可）：

--- 开始复制 ---
npm install -g --fetch-timeout=120000 @anthropic-ai/claude-code
--- 结束复制 ---

B6. 如果 claude 命令找不到，手动下载二进制：

--- 开始复制 ---
node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs"
--- 结束复制 ---

B7. Termux 修复（glibc + LD_PRELOAD + 196拉黑 + 永不更新）：

--- 开始复制 ---
GLIBC_LIB="/data/data/com.termux/files/usr/glibc/lib/libc.so"
WRAPPER="/data/data/com.termux/files/usr/bin/claude"
VERSIONS_DIR="$HOME/.local/share/claude/versions"
mkdir -p "$VERSIONS_DIR"
rm -f "$VERSIONS_DIR"/2.1.196.tmp "$VERSIONS_DIR"/2.1.196
echo "2.1.196" >> "$VERSIONS_DIR/.blocklist"
echo "2.1.195" > "$VERSIONS_DIR/.verified"
[ -f "$GLIBC_LIB" ] && [ ! -L "$GLIBC_LIB" ] && { cp "$GLIBC_LIB" "${GLIBC_LIB}.bak"; ln -sf libc.so.6 "$GLIBC_LIB"; }
sed -i 's/exec "\$bin"/LD_PRELOAD= exec "\$bin"/' "$WRAPPER" 2>/dev/null
sed -i 's/^RATE_LIMIT=.*/RATE_LIMIT=315360000/' "$WRAPPER" 2>/dev/null
--- 结束复制 ---

B8. 写 settings.json（先替换 sk-你的key，再整段粘贴）：

--- 开始复制（替换 sk-你的key 后整段粘贴） ---
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "sk-你的key",
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
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
--- 结束复制 ---

B9. 新开一个 Termux 窗口，输入 claude 回车。


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

【报错】claude 启动后报 invalid ELF header 或 ld 错误
原因：Termux glibc 的 libc.so 不是真库，以及 LD_PRELOAD 冲突
解决：执行路线 A8 或 B7 的 Termux 修复代码段

【报错】wrapper 每次启动反复下载更新
原因：196 版本二进制损坏，wrapper 一直重试
解决：执行路线 A8 或 B7 的 Termux 修复代码段

【关于固定版本】
如果需要固定版本不自动升级：npm install -g @anthropic-ai/claude-code@2.1.195

【关于开机自启】
Termux 开机自启需要额外配置 Termux:Boot 插件，可在 F-Droid 里搜。
安装后把启动脚本放到 ~/.termux/boot/ 目录下即可。

【关于 Token 安全】
不要在聊天记录里直接粘贴 token。教程里的 token 位置写的是占位符，替换成你自己的就行。
如果 token 已经泄露了，去对应平台重新生成一个。
