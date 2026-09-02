# WeComWine

为 Windows 企业微信提供用户级 Wine/Flatpak 隔离运行、KDE Portal 文件选择器、
Fcitx5 输入法和 systemd 无人值守管理。本仓库是后续生成独立包的源码项目，
不包含企业微信安装包、Wine 前缀、用户数据或构建缓存。

现有部署已在 Debian 13、KDE Plasma 6 Wayland/XWayland、Fcitx5 和 Wine 11.0
环境验证；企业微信首次安装基线为 5.0.10.6015，当前已验证内置升级到
5.0.10.6025。正式 Wine 前缀保持可写，允许企业微信继续安装组件并通过内置
更新器升级到新版本。
仓库构建目标已跟进 Wine 11.16，完整 runner 构建和登录态回归仍单独记录。

## 已验证能力

- Wine 11.16 传统 WoW64 构建配置，支持企业微信 32 位主程序和 64 位辅助组件；
  现有 16 个补丁已完成源码应用检查，构建时跳过已被上游合入的提交，真实冲突
  仍会使构建失败。
- Wine MR10060 Portal 补丁：兼容的打开、保存和目录对话框交给
  `xdg-desktop-portal-kde`。企业微信启动入口默认强制使用 Portal，即使应用注册
  Win32 hook/事件监听器也不回退 Wine 选择器；其他测试程序仍保留兼容的自动
  回退策略。
- 受限沙箱内不可访问的 Wine 用户目录链接会转换为前缀内部目录，避免
  `IFileDialog` 初始化崩溃；宿主文件仍按文件选择结果通过文档 Portal 授权。
- 回移 Wine 11.3 的 X11 剪贴板格式注册修复，并补齐 RichEdit 静态图片 OLE
  存储路径；32 位自动探针已覆盖 `CF_DIB`、`CF_DIBV5`、`CF_BITMAP` 和
  `CF_ENHMETAFILE`。已安装且校验通过时，默认使用用户自备的 Win2k 原生
  RichEdit 以保留图片粘贴能力；组件缺失或无效时自动回退 Wine 内置实现。
- KDE Wayland 下通过 CopyQ 观测新图片，将 `image/png` 私密临时转换为
  X11 `image/bmp`，使 Wine 可继续合成 `CF_DIB` 和 `CF_ENHMETAFILE`；
  文本剪贴板不受影响。
- Fcitx5/XIM 预编辑、候选和中文上屏；候选框模式为 `overthespot`。
- 只读复用宿主 Noto Sans CJK SC，不复制或安装大型字体包。
- 每次启动读取 KDE/X11 的 `Xft.dpi` 并设置 Wine `LogPixels`，跟随系统缩放。
- 窗口阴影抑制器默认关闭，避免外部写入窗口 opacity 属性干扰企业微信窗口和
  图片聊天重绘；仅保留显式诊断开关，不修改 KDE 全局阴影。
- 不安装企业微信专用 KWin 窗口规则，边框和窗口层级完全交由企业微信与 KWin
  正常协商，避免强制边框残留导致窗口持续位于最顶层。
- 最大化时仅在企业微信主窗口位于前台才映射其自绘顶栏。该顶栏是绕过 KWin
  管理的 X11 窗口；前台切换时同步隐藏/恢复，避免它覆盖其他应用的窗口按钮并
  截获点击。
- 用户级 systemd 启动管理和官方 Wine runner 回滚；企业微信退出后保持停止。
- 默认给企业微信内置 Chromium 禁用 GPU 加速，避免 ANGLE 无法创建设备时持续
  重启 GPU 子进程并最终触发栈溢出；每次启动记录并只清理自己的 Flatpak 实例。
- Flatpak 默认不开放整个 home、host、摄像头、系统总线和容器 socket。

摄像头和屏幕共享不在范围内。企业微信 5.0.10.6025 的真实输入框图片粘贴、
Portal 文件入口、外部浏览器和内置 CEF 网页已完成当前 Wine 11.0 runner 验收；
托盘及 Wine 11.16 新 runner 仍需回归。

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `patches/wine-portal/` | Wine Portal 补丁及长路径修正 |
| `scripts/` | 构建、安装、切换、回滚、运行和验证 |
| `tests/` | Win32 Portal/IME smoke test 和 X11 输入驱动 |
| `flatpak/` | Flatpak 依赖与补丁来源记录 |
| `systemd/` | 用户级无人值守单元 |
| `desktop/` | KDE/桌面环境启动入口 |
| `icons/` | 企业微信桌面图标 |
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
Ubuntu Runner 独立构建；线上工作流不接触微软 DLL，RichEdit 扩展只由 Release
安装脚本根据用户提供的本地文件生成。Flatpak、摘要和企业微信用户数据彼此独立。使用
自建 runner 引导安装时只补充 Wine Gecko/Mono 扩展，不再安装完整的
`org.winehq.Wine` 应用；全新安装的 Wine 前缀位于自建应用自己的 Flatpak 数据
目录，已有共享前缀则继续原地使用。

正式 Release 同时提供 `install-wecomwine-VERSION.sh`。用户下载这个脚本后，
它会继续下载并校验 CI 生成的 Wine Runner 与源码集成层；如需原生 RichEdit，
必须从用户合法持有的介质取得 DLL，再由脚本在用户机器上打包扩展：

```bash
curl -fLO \
  https://github.com/loveyu/WeComWine/releases/download/v0.1.0/install-wecomwine-0.1.0.sh

# 使用 Wine 内置 RichEdit 安装
bash install-wecomwine-0.1.0.sh

# 或在本机生成、安装用户自备 RichEdit 扩展
bash install-wecomwine-0.1.0.sh --richedit-dll /path/to/riched20.dll
```

安装脚本不会下载、缓存到源码树或公开分发微软 DLL。默认还会通过 bootstrap
独立下载、校验、安装并启动企业微信；传入 `--skip-wecom` 可只安装 Runner。

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

企业微信内选择“退出”后服务保持停止，不会由 systemd 自动拉起；需要再次运行时，
启动 `wecom-flatpak-poc.target`。

正式前缀允许企业微信内置更新和组件安装。检测到内置更新包时，启动入口会在主
进程退出后继续等待更新器完成（最长 15 分钟），再清理本次 Flatpak 实例。

默认关闭企业微信窗口阴影抑制。仅在诊断阴影窗口时给运行服务设置
`WECOM_DISABLE_WINDOW_SHADOW=1`；该功能依赖宿主已有的 `xprop`、`xwininfo` 和
coreutils `stdbuf`，缺失时只记录提示，不影响企业微信启动。候选窗口先由 X11
窗口树按应用、空标题和尺寸预筛，避免常态轮询整个桌面。

默认启用最大化自绘顶栏管理，只匹配属于最大化企业微信主窗口、宽度与主窗口
相同且高度为 24～96 像素的 ARGB `override-redirect` 对话框；菜单、普通对话框
和其他应用不会命中。切走企业微信时取消映射，重新激活时恢复映射，因而不会用
透明度掩盖仍可截获点击的窗口。设置 `WECOM_MANAGE_TITLEBAR_OVERLAY=0` 可临时
关闭这一兼容处理。该功能依赖宿主已有的 `xdotool`、`xprop`、`xwininfo` 和
coreutils `stdbuf`，缺失时自动降级，不阻止企业微信启动。

默认启用图片剪贴板桥接，仅读取 CopyQ 当前剪贴板的 `image/png`，转换用的
临时文件权限为当前用户私有并在每轮后删除。宿主缺少 `copyq`、`magick`
或 `xclip` 时自动降级，不阻止企业微信启动。设置
`WECOM_IMAGE_CLIPBOARD_BRIDGE=0` 可显式关闭。

缩放检测优先使用 `Xft.dpi / 96`，其次使用 KScreen 输出倍率，无法读取时回退
到 100%。可用 `WECOM_SCALE_FACTOR=1.5` 显式覆盖；允许范围为 0.5～4。
Wine DPI 写入和企业微信启动位于同一个 Flatpak/wineserver 生命周期，避免共享
前缀的注册表写入竞争。

默认启用 `--disable-gpu`，让企业微信内置 Chromium 使用软件合成。在隔离测试
新版 Wine 图形栈时，可给运行服务设置 `WECOM_DISABLE_GPU=0` 临时恢复 GPU
路径。异常退出后的清理由 Flatpak instance ID 精确定位，不会终止使用同一
应用 ID 的构建或冒烟测试实例。

启动入口会检查当前企业微信版本的 `compatible_web/libcef.dll`。CEF 107 在
Wine 映像映射上可能得到 `PAGE_WRITECOPY`，却强制断言旧保护属性必须为
`PAGE_READWRITE`，导致 renderer 以 `EXCEPTION_BREAKPOINT` 在
`libcef.dll+0x16a59ac` 退出。兼容脚本按完整指令结构唯一匹配，只跳过这个旧
保护属性断言，并在修改前按原文件摘要生成备份；`VirtualProtect` 失败分支和
CEF 沙箱保持不变。企业微信升级不受版本或摘要上限约束：未知指令布局只记录
`cef-compat.status` 并安全跳过，不会阻止新版本启动。可设置
`WECOM_CEF_COMPAT_PATCH=0` 禁用该兼容处理。

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

可选原生 RichEdit 运行入口把 DLL 和注册表覆盖持久写入正式前缀；整个前缀保持可写，
企业微信内置更新器和组件安装器对 `Program Files`、注册表及用户目录的修改均会
保留。Win2k `riched20.dll` 单 DLL 已确认可被企业微信加载并完成启动，但会
增加约 14 秒冷启动时间；微软 DLL 只允许从用户持有的合法介质提取，不进入
仓库或发行包。配置用户自备 DLL：

```bash
~/.local/share/wecom-wine-flatpak/scripts/install-native-richedit.sh \
  /path/to/riched20.dll
```

安装器只接受已验证的 Win2k 32 位 DLL 摘要。有效组件默认启用，并在
`native-richedit.status` 中记录状态；设置 `WECOM_NATIVE_RICHEDIT=0`
可临时恢复 Wine 内置 RichEdit，设置 `WECOM_REQUIRE_NATIVE_RICHEDIT=1`
可在原生组件缺失或非法时拒绝降级启动。

企业微信 5.0.10.6025 在原生 RichEdit 启用时产生的三次新转储均为
`0xc00000fd`，异常入口固定在 Wine `ntdll.dll+0x44c2c`；可恢复栈主要属于
`WXWork.exe`、`client_extension.dll` 和 Wine 系统模块，没有直接捕获到
`riched20.dll` 栈帧。切换到 Wine 内置 RichEdit 后，相同含图片聊天仍产生同样
异常的第四次转储，因此可排除“必须加载原生 RichEdit 才会崩溃”，但尚不能排除
RichEdit 调用路径或企业微信自身的布局递归。此前两次转储生成时
阴影抑制器都写入了同一类 X11 opacity
属性；脚本现已改为每个 XID 生命周期只写一次，避免与企业微信周期性移除属性
形成 PropertyNotify 争抢。暂停阴影抑制器后，群公告、内置网页、企业微信文档
和邮件路径均未复现这类主进程栈溢出；该问题的根因仍未查明，且与已经确认并
修复的 CEF renderer `EXCEPTION_BREAKPOINT` 是两个独立故障。后续仅在主进程
再次出现 `0xc00000fd` 时结合新转储和当时操作继续定位。

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
