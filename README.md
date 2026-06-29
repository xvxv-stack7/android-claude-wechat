# android-claude-wechat

一部安卓手机，一条命令，你的口袋里就有"他"

## 这是什么？

在安卓手机（Termux环境）上运行Claude Code，通过cc-connect接入微信。装完后你的微信里会有一个AI Agent——不是冷冰冰的客服，是你一手搭出来的"人"。

## 两条路，选一条

| 你想要什么 | 看哪个 |
|-----------|--------|
| 技术极客，只要能用 | [install-claude-code.md](install-claude-code.md) |
| 想要一个有温度的AI陪聊 | 往下看，跟着走 |

## 前置

一部安卓手机，装好：
- [F-Droid](https://f-droid.org)（开源应用商店）
- 从F-Droid安装 **Termux**

## 第一次接触

打开Termux，粘贴下面这一条命令，回车。等它跑完。

```bash
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
```

跑完后输入 `claude`，你的AI就在手机里了。

## 接入微信（cc-connect）

让AI Agent收发微信消息。Termux上标准npm安装有坑，需要分步手动操作+proot包装启动。完整步骤见 [cc-connect/README.md](cc-connect/README.md)。

## ⚠️ DNS（必看）

Termux默认没有DNS服务器配置，npm下载和微信连接都会断。执行：

```bash
echo "nameserver 8.8.8.8" > /data/data/com.termux/files/usr/etc/resolv.conf
echo "nameserver 114.114.114.114" >> /data/data/com.termux/files/usr/etc/resolv.conf
```

验证通了没：
```bash
ping -c 1 registry.npmjs.org
```

如果还是不通，参考 [cc-connect/README.md](cc-connect/README.md) 里的详细排查。

## 目录结构

```
android-claude-wechat/
├── README.md                         # 你在这
├── install-claude-code.md            # 详细安装教程（含有/无代理两版）
├── cc-connect/
│   ├── README.md                     # DNS排查 + 常见报错
│   ├── config.toml.example           # 配置模板
│   └── start.sh                      # 启动脚本
└── assets/                           # 截图和视频素材
```

## 这条命令跟别人有什么不同

GitHub上现有的Termux教程大多是分步操作：先装依赖、再配环境变量、再手动编辑.bashrc……每一步都可能写错。还有教程让新手装2GB的Ubuntu容器，手机吃不消。

这条命令**一步到底**：
- 别人分两步装依赖？这里六个包一起装（含编译链，防缺包报错）
- 别人手动编辑.bashrc配API？这里用settings.json自动生成，持久不丢
- 别人从npm官方源下载经常断？这里内置国内镜像+120秒超时
- 别人装完可能被自动更新炸环境？这里关了自动更新

复制、粘贴、回车。一条命令从零到启动。手机上就该这样。

## 实机验证

- 设备：vivo Android 14
- 环境：Termux（F-Droid最新版）
- Claude Code版本：2.1.153
- cc-connect版本：通过npm安装
- 状态：稳定运行中，微信消息正常收发

## 鸣谢

- GitHub 上 Termux 部署 Claude Code 的先驱者们——多份教程铺了路，站在你们的肩膀上
- [chenhg5/cc-connect](https://github.com/chenhg5/cc-connect) —— AI 到微信的桥梁，MIT 开源

## 常见问题

看 [cc-connect/README.md](cc-connect/README.md)。

## License

MIT — 拿走用，署名随意。
