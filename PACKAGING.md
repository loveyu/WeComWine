# 独立包准备说明

## 建议交付物

项目最终区分三个独立层：

1. `io.github.loveyu.WeComWine` Flatpak runner：包含 Wine 11.16、传统 WoW64
   32/64 位运行库、Portal 补丁和 smoke test，不包含腾讯二进制。
2. `io.github.loveyu.WeComWine.RichEdit` 可选 Flatpak 扩展：只接受固定摘要的
   用户自备 Win2k 32 位 `riched20.dll`，仅在私有 CI 和用户自有机器之间分发。
3. `wecom-wine-flatpak` 用户级集成层：包含下载校验、前缀初始化、systemd
   单元、桌面入口、切换/回滚和诊断脚本。

另有本机兼容性验证专用的 `io.github.loveyu.WeComWine.Deepin` Flatpak。它使用
Deepin/统信官方应用商店的 `deepin-wine10-stable 10.14deepin11`，并在本机
构建时提取官方企业微信包 `5.0.0.6008deepin8` 中的 `WINEPREDLL` 适配层。该包
完整携带该包的适配目录和 `files.7z`，首次切换时直接初始化其官方预制前缀，
包括 `WINEPREDLL`、原生 RichEdit、注册表以及预运行/更新辅助文件；随后在同一
前缀内静默安装腾讯官方企业微信 5.0.10.6025。它不复制其他现有前缀，使用独立的
`/var/data/wine-wecom-deepin` 前缀，不覆盖正式 Wine 11 前缀；同时封装适配包
声明依赖的文泉驿微米黑字体，并在构建时移除 WineDbg 入口，禁止以调试模式运行。
完整 Deepin 企业微信代码和腾讯安装包只进入本机私有测试包，不进入 Git。
腾讯 5.0.10 使用与标准 Runner 相同的窄匹配 CEF 107 兼容补丁；宿主顶栏管理器
同时识别 Deepin Wine 的 `WM_CLASS=Wine`，仅在最大化主窗口失去焦点时隐藏其
独立 ARGB 自绘顶栏，避免覆盖其他应用右上角。

Deepin Wine 的 WoW64 加载器硬编码安装路径 `/opt/deepin-wine10-stable`，而
Flatpak 应用负载位于 `/app/deepin-wine10-stable`。构建脚本会在引擎及官方
`WINEPREDLL` 适配层内执行 25 字节等长路径替换；这不是企业微信二进制补丁。
新 WoW64 虽然只包含 64 位 Unix 模块，Flatpak 沙箱仍必须声明
`--allow=multiarch`，否则所有 32 位 PE 会在进入程序代码前启动失败。

腾讯企业微信安装包由目标机器根据固定 HTTPS URL 下载并校验 SHA-256，不能进入
Git、源码归档、公开 Flatpak 仓库或公开发行附件；上述本机私有 Deepin 测试包是
仅限用户自有机器的封装，不得上传或再分发。

企业微信外部图片粘贴还需要上述可选 RichEdit 扩展。DLL 不得进入 Git、源码
归档、公开 Flatpak 仓库或公开发行附件；私有 CI 通过受控文件路径注入并在构建
前校验固定 SHA-256。组件缺失时企业微信仍可使用 Wine 内置 RichEdit 启动，但
外部图片粘贴能力不作保证。

## 当前可用入口

```bash
make check
make install-user
make dist SOURCE_DATE_EPOCH=0
make flatpak-bundles
make deepin-flatpak-local
```

- `make check` 校验 shell 语法、补丁数量，并阻止 EXE/MSI/Flatpak 二进制进入仓库。
- `make install-user` 安装到 `~/.local/share/wecom-wine-flatpak`，部署用户级
  systemd 和桌面入口，但不会自动启动或安装企业微信专用 KWin 窗口规则。
- `scripts/install-native-richedit.sh /path/to/riched20.dll` 校验并安装用户自备
  RichEdit 到独立数据目录，不修改正式 Wine 前缀。
- `make dist` 生成排序、固定时间戳和固定 owner 的源码归档及 SHA-256 文件。
- `make flatpak-bundles` 从已构建 OSTree 仓库导出主 Flatpak；设置
  `WECOM_RICHEDIT_DLL=/secure/path/riched20.dll` 时同时生成私有 RichEdit 扩展。
- `make deepin-flatpak-local` 从 Deepin/统信官方应用商店下载并校验 Deepin Wine
  和企业微信适配包，并校验腾讯官方企业微信 5.0.10.6025 安装包，生成、安装独立
  应用 ID 的本地测试 Flatpak。生成物位于
  `artifacts/deepin-private/`，含官方适配二进制，仅限本机测试，不进入公开 CI、
  GitHub Release 或项目 Flatpak 仓库。
- `scripts/switch-to-deepin-runner.sh` 停止当前 runner，直接从 Flatpak 内置的
  Deepin 官方代码包初始化独立前缀并切换集成层；默认只准备、不启动，加
  `--start` 才会以正常模式启动。Deepin 模式启用适用于 5.0.10 的 CEF 补丁和
  宿主顶栏管理，但仍不启用 Portal、Win2k RichEdit 扩展、任务栏图标或图片
  剪贴板桥接。
- `scripts/install-flatpak-bundles.sh MAIN.flatpak [RICHEDIT.flatpak]` 以用户级
  Flatpak 模式安装制品和集成层，但不自动安装企业微信程序。
- GitHub CI 把版本化 `install-wecomwine-VERSION.sh`、主 Runner、源码归档及统一
  `RELEASE_SHA256SUMS` 一起输出。安装脚本下载并校验 Release 制品；若用户传入
  自己合法持有的 `riched20.dll`，则仅在用户机器上生成并安装可选扩展。
- `scripts/package-richedit-extension.sh DLL OUTPUT.flatpak` 是上述用户侧扩展打包
  入口，固定校验摘要；它不负责获取微软文件。
- 自建 runner 模式下 bootstrap 只安装 Gecko/Mono 扩展，不安装完整的
  `org.winehq.Wine` 应用；企业微信前缀落在新应用的用户级 Flatpak 数据目录。

Flatpak runner 的权威构建实现是 `scripts/build-portal-wine.sh`；
`scripts/ci-package-flatpaks.sh` 在 CI 节点完成传统 WoW64 配对构建并调用
`scripts/package-flatpaks.sh` 生成多个单文件 Flatpak 和 `SHA256SUMS`。GitHub
Actions 入口为 `.github/workflows/package-flatpaks.yml`，全部公开制品在 GitHub
托管的 `ubuntu-24.04` Runner 构建。线上工作流不读取或生成微软 RichEdit DLL；
用户侧安装脚本只读取用户明确提供的本地路径。

用户级集成包的阴影抑制功能依赖 `xprop`、`xwininfo` 和 coreutils `stdbuf`，
不写入或维护 KWin 窗口规则；安装升级时仅迁移并清理本项目旧版本遗留的
`wecom-wine-system-frame` 规则。任务栏图标管理依赖宿主 `python3`、ImageMagick
`magick` 和 X11 `libX11`，依赖缺失时安全降级；它仅规范化企业微信任务窗口的
标准 X11 图标和 KDE 桌面文件关联。

公开制品不包含腾讯安装包、企业微信私有 `libcef.dll` 或其修改副本。CEF
兼容处理只分发指令特征校验与本地修补脚本，由用户从腾讯官方渠道安装或更新
企业微信后在自己的可写前缀中执行；原文件按摘要备份，未知布局不修改、不阻止
启动。上游官方 CEF 二进制若另行分发，必须同时满足 CEF/Chromium 及第三方
许可证通知要求，不能据此推定腾讯私有构建也可再分发。

## 正式发布前阻塞项

- [ ] 明确本项目自有脚本、测试和文档的许可证；第三方补丁继续遵守 Wine 许可。
- [x] 增加自托管 CI 的传统 WoW64 构建、多 Flatpak 导出、摘要和 artifact 上传流程。
- [ ] 将传统 WoW64 构建进一步转换为纯 flatpak-builder manifest。
- [ ] 增加 AppStream metadata、截图、版本和发行说明。
- [ ] 使用独立 GPG key 签名 Flatpak OSTree 仓库或生成受信任的 single-file bundle。
- [ ] 设计从 `wecom-flatpak-poc.*` 服务名和 XDG 数据目录迁移到正式名称的兼容策略。
- [x] 正式前缀保持可写，允许企业微信内置更新器升级；已验证版本只作为回归记录，
  不作为运行上限。
- [ ] 在干净用户账户执行安装、升级、回滚、卸载和数据保留测试。
- [x] 在本机完成两个 bundle 的用户级安装和全新企业微信独立安装，并在远程机
  完成旧应用 ID 到 `io.github.loveyu.WeComWine` 的原地前缀迁移。
- [ ] 扫码后完成企业微信真实输入框、收发文件、托盘、外部链接和内置网页验收。

## 发布安全边界

- 不把 Wine 前缀、聊天数据、二维码、Cookie、Token、日志或崩溃转储打包。
- 不默认开放整个 home、host、摄像头、系统总线或容器管理 socket。
- 只开放 `~/Downloads/WeCom` 作为文件交换目录。
- Portal 补丁仍是上游草案；每次 Wine 或企业微信升级必须重跑 Portal 和 Fcitx5
  自动测试，并进行一次登录后业务验收。
