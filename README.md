# android-claude-wechat

一部安卓手机，一条命令，你的口袋里就有"他"

## 这是什么？

在安卓手机（Termux环境）上运行Claude Code，通过cc-connect接入微信。装完后你的微信里会有一个AI Agent——不是冷冰冰的客服，是你一手搭出来的"人"。

## 新手？先看这个

第一次用Termux、不知道怎么敲命令、不知道AI和手机怎么配合？→ [NEWBIE.md](NEWBIE.md)

## 前置

1. 装 F-Droid（开源应用商店，清华镜像直下：https://mirrors.tuna.tsinghua.edu.cn/fdroid/repo/）
2. F-Droid 里搜 **Termux** 安装
3. 打开 Termux

## 一条命令

```bash
curl -sSL https://raw.githubusercontent.com/xvxv-stack7/android-claude-wechat/master/all-in-one.sh | bash
```

装 Claude Code → 等你填 token → 装 cc-connect → 弹二维码扫码。全程两次暂停，其他全自动。跑完微信里就有一个 AI Agent。

> 只要 Claude Code？→ `install-claude-code.sh`　|　已有 Claude Code 只接微信？→ `cc-connect/install.sh`

## DNS

脚本自动检查并修复。如手动排查，见 [cc-connect/README.md](cc-connect/README.md)。

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
- Claude Code版本：2.1.195
- cc-connect版本：通过npm安装
- 状态：稳定运行中，微信消息正常收发

## 鸣谢

- GitHub 上 Termux 部署 Claude Code 的先驱者们——多份教程铺了路，站在你们的肩膀上
- [chenhg5/cc-connect](https://github.com/chenhg5/cc-connect) —— AI 到微信的桥梁，MIT 开源

## 常见问题

看 [cc-connect/README.md](cc-connect/README.md)。

## License

MIT — 拿走用，署名随意。
