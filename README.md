# WeComWine

为 Windows 企业微信提供用户级 Wine/Flatpak 隔离运行、KDE Portal 文件选择器、
Fcitx5 输入法和 systemd 无人值守管理。本仓库是后续生成独立包的源码项目，
不包含企业微信安装包、Wine 前缀、用户数据或构建缓存。

参考部署已在 Debian 13、KDE Plasma 6 Wayland/XWayland、Fcitx5、Wine 11.0 和
企业微信 5.0.10.6015 上验证。

## 已验证能力

- Wine 11.0 传统 WoW64，支持企业微信 32 位主程序和 64 位辅助组件。
- Wine MR10060 Portal 补丁：兼容的打开、保存和目录对话框交给
  `xdg-desktop-portal-kde`。企业微信启动入口默认强制使用 Portal，即使应用注册
  Win32 hook/事件监听器也不回退 Wine 选择器；其他测试程序仍保留兼容的自动
  回退策略。
- 受限沙箱内不可访问的 Wine 用户目录链接会转换为前缀内部目录，避免
  `IFileDialog` 初始化崩溃；宿主文件仍按文件选择结果通过文档 Portal 授权。
- 回移 Wine 11.3 的 X11 剪贴板格式注册修复，并补齐 RichEdit 静态图片 OLE
  存储路径；32 位自动探针已覆盖 `CF_DIB`、`CF_DIBV5`、`CF_BITMAP` 和
  `CF_ENHMETAFILE`。用户自备的 Win2k 原生 RichEdit 已通过真实输入框外部图片
  粘贴、预览和发送验收，发送当时未崩溃；约 13 分钟后出现一次既有特征的
  `BackgroundThread` 栈溢出，仍在独立排查长期稳定性。
- Fcitx5/XIM 预编辑、候选和中文上屏；候选框模式为 `overthespot`。
- 只读复用宿主 Noto Sans CJK SC，不复制或安装大型字体包。
- 每次启动读取 KDE/X11 的 `Xft.dpi` 并设置 Wine `LogPixels`，跟随系统缩放。
- 仅对企业微信自绘、无焦点的透明阴影窗设为不可见，覆盖登录窗、强制系统边框
  后的非对称主窗口及右键菜单 transient 阴影，不修改 KDE 全局阴影。抑制器按
  窗口列表事件快速处理，并保留低频兜底；每个 XID 只写一次 opacity。
- 通过只匹配 `wxwork.exe` 且标题为“企业微信”的 KWin 强制规则启用系统边框，
  避免企业微信恢复无边框后只能拖动一次。
- 用户级 systemd 自动启动、失败重试、异常重启和官方 Wine runner 回滚。
- 默认给企业微信内置 Chromium 禁用 GPU 加速，避免 ANGLE 无法创建设备时持续
  重启 GPU 子进程并最终触发栈溢出；每次启动记录并只清理自己的 Flatpak 实例。
- Flatpak 默认不开放整个 home、host、摄像头、系统总线和容器 socket。

摄像头和屏幕共享不在范围内。扫码后的企业微信自绘输入框、文件入口、托盘、
内置网页等仍需真实账号验收。

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `patches/wine-portal/` | Wine Portal 补丁及长路径修正 |
| `scripts/` | 构建、安装、切换、回滚、运行和验证 |
| `tests/` | Win32 Portal/IME smoke test 和 X11 输入驱动 |
| `flatpak/` | Flatpak 依赖与补丁来源记录 |
| `systemd/` | 用户级无人值守单元 |
| `desktop/` | KDE/桌面环境启动入口 |
| `PACKAGING.md` | 独立包拆分、发布阻塞项和安全边界 |
| `THIRD_PARTY.md` | 第三方来源、摘要和再分发边界 |

## 开发检查与安装

```bash
make check
make install-user
systemctl --user enable --now wecom-flatpak-poc.target
```

## Flatpak 多包构建与安装

新制品统一使用 `io.github.loveyu` 命名空间。主 runner 与可选 RichEdit 兼容层
分别打包，腾讯企业微信安装程序始终单独下载和安装：

```bash
# 从已经构建的本地 OSTree 仓库只导出主包
make flatpak-bundles

# 私有 CI/自有机器同时导出 RichEdit 扩展
WECOM_RICHEDIT_DLL=/secure/path/riched20.dll make flatpak-bundles

# 用户级安装，不写入 /usr，也不自动安装企业微信
scripts/install-flatpak-bundles.sh \
  artifacts/flatpak/io.github.loveyu.WeComWine-0.1.0-x86_64.flatpak \
  artifacts/flatpak/io.github.loveyu.WeComWine.RichEdit-0.1.0-x86_64.flatpak

# 之后单独下载、校验并安装企业微信
systemctl --user start wecom-flatpak-poc-bootstrap.service
```

CI 入口为 `.github/workflows/package-flatpaks.yml`。公开主包由 GitHub 托管的
Ubuntu Runner 独立构建；只有私有仓库的自托管节点提供
`WECOM_RICHEDIT_DLL` 文件路径并通过固定摘要校验后，才会生成
RichEdit 扩展。两个 Flatpak、`SHA256SUMS` 和企业微信用户数据彼此独立。使用
自建 runner 引导安装时只补充 Wine Gecko/Mono 扩展，不再安装完整的
`org.winehq.Wine` 应用；全新安装的 Wine 前缀位于自建应用自己的 Flatpak 数据
目录，已有共享前缀则继续原地使用。

安装根目录默认为 `~/.local/share/wecom-wine-flatpak`。运行数据继续使用已验证的
兼容命名空间：

| 内容 | 位置 |
| --- | --- |
| Wine 前缀和本地 Flatpak 仓库 | `~/.local/share/wecom-flatpak-poc/` |
| 下载缓存 | `~/.cache/wecom-flatpak-poc/` |
| 状态和日志 | `~/.local/state/wecom-flatpak-poc/` |

保留旧命名空间是为了以后独立包可以原地接管现有 POC 部署，不复制 2 GB 以上
Wine 前缀。正式更名和迁移策略列在 `PACKAGING.md`。

## 日常维护

```bash
~/.local/share/wecom-wine-flatpak/scripts/status.sh
systemctl --user stop wecom-flatpak-poc.target
systemctl --user start wecom-flatpak-poc.target
journalctl --user -u wecom-flatpak-poc-app.service -f
```

企业微信内选择“退出”后会被 `Restart=always` 拉起；需要保持退出时，先停止
target。

默认启用企业微信窗口阴影抑制。临时回退时给运行服务设置
`WECOM_DISABLE_WINDOW_SHADOW=0`；该功能依赖宿主已有的 `xprop`、`xwininfo` 和
coreutils `stdbuf`，缺失时只记录提示，不影响企业微信启动。候选窗口先由 X11
窗口树按应用、空标题和尺寸预筛，避免常态轮询整个桌面。

缩放检测优先使用 `Xft.dpi / 96`，其次使用 KScreen 输出倍率，无法读取时回退
到 100%。可用 `WECOM_SCALE_FACTOR=1.5` 显式覆盖；允许范围为 0.5～4。
Wine DPI 写入和企业微信启动位于同一个 Flatpak/wineserver 生命周期，避免共享
前缀的注册表写入竞争。

默认启用 `--disable-gpu`，让企业微信内置 Chromium 使用软件合成。在隔离测试
新版 Wine 图形栈时，可给运行服务设置 `WECOM_DISABLE_GPU=0` 临时恢复 GPU
路径。异常退出后的清理由 Flatpak instance ID 精确定位，不会终止使用同一
应用 ID 的构建或冒烟测试实例。

企业微信默认设置 `WECOM_FORCE_PORTAL=1`，将兼容的 Win32 文件打开、保存和
目录选择请求强制交给 `xdg-desktop-portal`；KDE 会由
`xdg-desktop-portal-kde` 显示系统原生选择窗口。Dolphin 是文件管理器而不是
Portal chooser，但两者使用同一套 KDE 文件组件和位置/书签集成。临时诊断 Wine
原生对话框时可设置 `WECOM_FORCE_PORTAL=0` 回退自动策略。企业微信真实入口
已捕获到 `FileChooser.OpenFile`，主 Portal 明确转发到 KDE 后端；选择完成后
Document Portal 只向本 Flatpak 应用授权所选对象，没有开放整个宿主 Home。
企业微信不会直接读取标准 `IFileOpenDialog` 结果，而是在 `OnFolderChange` 中经
`SID_STopLevelBrowser` 获取 `IFolderView2`，再于 `OnFileOk` 读取 Shell View
选择。Portal 没有 ExplorerBrowser 时这条链原本为空；定制 Wine 现仅在 Portal
已返回结果时提供只读 Shell View 代理，将 Document Portal 授权后的
`IShellItemArray` 交给应用。已登录真实入口完成文本文件选择并进入发送流程，
服务未重启；保存和纯目录模式继续由自动 Portal 探针覆盖。

原生 RichEdit 运行入口把 DLL 和注册表覆盖限制在临时 Overlay，同时把
`drive_c/users` 实时绑定到正式前缀，避免企业微信刷新登录令牌后正式实例只剩
旧令牌。Win2k `riched20.dll` 单 DLL 已确认可被企业微信加载并完成启动，但会
增加约 14 秒冷启动时间；微软 DLL 只允许从用户持有的合法介质提取，不进入
仓库或发行包。配置用户自备 DLL：

```bash
~/.local/share/wecom-wine-flatpak/scripts/install-native-richedit.sh \
  /path/to/riched20.dll
systemctl --user restart wecom-flatpak-poc-app.service
```

安装器只接受已验证的 Win2k 32 位 DLL 摘要。组件缺失或摘要不符时默认安全
回退 Wine 内置 RichEdit，并在 `native-richedit.status` 中记录原因；设置
`WECOM_REQUIRE_NATIVE_RICHEDIT=1` 可改为拒绝降级启动，设置
`WECOM_NATIVE_RICHEDIT=0` 可显式禁用原生组件。

真实发送后的新转储为 `0xc00000fd`，崩溃线程名 `BackgroundThread`。其异常
地址和寄存器模板与启用原生 RichEdit 前 14:31 的转储一致，因此现有证据不支持
将其归因于原生 DLL。两次转储生成时阴影抑制器都写入了同一类 X11 opacity
属性；脚本现已改为每个 XID 生命周期只写一次，避免与企业微信周期性移除属性
形成 PropertyNotify 争抢。暂停阴影抑制器后，群公告、内置网页、企业微信文档
和邮件路径均未复现崩溃；根因仍未查明，按当前安排暂缓排查，后续仅在再次出现
同类崩溃时结合新转储和当时操作继续定位。

KWin 规则只影响标题精确为“企业微信”的窗口，空标题阴影窗不会命中。卸载或
临时回退系统边框时执行：

```bash
~/.local/share/wecom-wine-flatpak/scripts/install-kwin-rule.sh remove
```

首次安装前的 `kwinrulesrc` 会备份到项目状态目录；安装时可用
`WECOM_SKIP_KWIN_RULE=1 make install-user` 跳过该集成。

## 构建定制 runner

```bash
systemctl --user restart wecom-flatpak-poc-build.service
systemctl --user restart wecom-flatpak-poc-switch.service
systemctl --user restart wecom-flatpak-poc-portal-test.service
```

权威构建入口是 `scripts/build-portal-wine.sh`。它按需安装用户级 Freedesktop
SDK、配对编译 Wine 64/32 位、导出本地 OSTree 仓库并安装 runner。构建完成后
可清理 SDK 和中间目录；运行所需 Platform 扩展必须保留。

回到官方 Wine runner：

```bash
~/.local/share/wecom-wine-flatpak/scripts/rollback-runner.sh
```

## 生成源码归档

```bash
make dist SOURCE_DATE_EPOCH=0
```

输出位于 `dist/`，包含固定顺序、时间戳和 owner 的源码压缩包及 SHA-256 文件。
该归档不是最终 Flatpak bundle，也不包含腾讯二进制。正式发行要求见
`PACKAGING.md`。
