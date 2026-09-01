# 企业微信 Wine/Flatpak

为 Windows 企业微信提供用户级 Wine/Flatpak 隔离运行、KDE Portal 文件选择器、
Fcitx5 输入法和 systemd 无人值守管理。本仓库是后续生成独立包的源码项目，
不包含企业微信安装包、Wine 前缀、用户数据或构建缓存。

参考部署已在 Debian 13、KDE Plasma 6 Wayland/XWayland、Fcitx5、Wine 11.0 和
企业微信 5.0.10.6015 上验证。

## 已验证能力

- Wine 11.0 传统 WoW64，支持企业微信 32 位主程序和 64 位辅助组件。
- Wine MR10060 Portal 补丁：兼容的打开、保存和目录对话框交给
  `xdg-desktop-portal-kde`；hook/template 调用自动回退 Wine 原生实现。
- Fcitx5/XIM 预编辑、候选和中文上屏；候选框模式为 `overthespot`。
- 只读复用宿主 Noto Sans CJK SC，不复制或安装大型字体包。
- 每次启动读取 KDE/X11 的 `Xft.dpi` 并设置 Wine `LogPixels`，跟随系统缩放。
- 仅对企业微信自绘、无焦点的透明阴影窗设为不可见，不修改 KDE 全局阴影。
- 用户级 systemd 自动启动、失败重试、异常重启和官方 Wine runner 回滚。
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
`WECOM_DISABLE_WINDOW_SHADOW=0`；该功能依赖宿主已有的 `xprop` 和 `xwininfo`，
缺失时只记录提示，不影响企业微信启动。

缩放检测优先使用 `Xft.dpi / 96`，其次使用 KScreen 输出倍率，无法读取时回退
到 100%。可用 `WECOM_SCALE_FACTOR=1.5` 显式覆盖；允许范围为 0.5～4。
Wine DPI 写入和企业微信启动位于同一个 Flatpak/wineserver 生命周期，避免共享
前缀的注册表写入竞争。

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
