# 第三方组件与再分发边界

## Wine

- 版本：Wine 11.16
- 源码地址：`https://dl.winehq.org/wine/source/11.x/wine-11.16.tar.xz`
- SHA-256：`c66e2090343dcd727f7f7fd2f87ee0bfb0b118790c1d745ab7b8a4c3a4197f2f`
- 本项目的 `patches/wine-portal/` 来源于 Wine MR10060 草案及配套修正。
- Wine 和派生二进制必须按照 Wine/LGPL 的适用条款提供许可证与对应源码。

## 企业微信

- 验证版本：5.0.10.6015、5.0.10.6025
- 官方下载地址由 `scripts/common.sh` 记录。
- 5.0.10.6015 安装包 SHA-256：
  `d46b1cc2603c70ff9cccd85998eed0c0d61f11a3a68e050b0695111294c10c87`。
- 腾讯 CDN 当前提供的 5.0.10.6025 安装包 SHA-256：
  `f9b028420b84dda6888246516e8a1dddd3174eaeb3d8d930e8e04264a9cfa513`；
  安装后 `WXWork.exe` SHA-256 为
  `46fbd8d193e6c42aa9cac4b38cf857cd125127cb658129b7d166dee8f17d6db2`。
- 企业微信是腾讯的专有软件。本项目源码和公开制品不保存、不提交、不再分发其
  安装包或 Wine 前缀；目标机器自行下载并在安装前校验摘要。本机私有 Deepin
  测试包可临时封装该安装包，但不得上传或再分发。
- `icons/` 中的企业微信应用图标提取自已验证的官方客户端，仅用于标识该客户端；
  企业微信名称、图标及相关商标权利归腾讯所有。

## Chromium Embedded Framework

- 企业微信 5.0.10.6025 自带腾讯私有 CEF 107 构建。本项目只发布本地特征校验
  和兼容修补脚本，不保存、提交或公开再分发企业微信的 `libcef.dll`、PDB、资源
  文件或修改副本。
- 上游官方 CEF 使用 BSD 风格许可证，官方二进制发行包允许在满足其许可证、
  Chromium 第三方许可证和通知文件要求后再分发；该授权不能自动延伸到腾讯的
  私有构建及修改。

## 字体与运行时

- 标准 Runner 只读复用宿主 Noto Sans CJK；本地 Deepin 私有包则携带其适配包
  明确依赖的文泉驿微米黑字体。
- Freedesktop Platform、Wine Flatpak base、Mono、Gecko 和图形扩展由 Flatpak
  依赖解析获取；正式发布时需要同步生成完整的第三方许可证清单。

## Deepin 官方兼容引擎（本地测试包）

- 引擎包：`deepin-wine10-stable 10.14deepin11`，来源为 Deepin/统信官方应用
  商店，SHA-256 为
  `a3412982cfb16d8e20d29508779ac5ad8a3b389a41737eebb7f657a1b5b9cb0f`。
- 企业微信适配包：`com.qq.weixin.work.deepin 5.0.0.6008deepin8`，同样来源于
  官方应用商店，SHA-256 为
  `e1ec28e988d5823287dd83ce4715072375314d81af2df5ca5c8ce8f84553010b`。
- 中文字体包：Deepin 官方仓库中的
  `fonts-wqy-microhei 0.2.0-beta-3.1`，SHA-256 为
  `fc23a97e13c0ac783b96710e2ed8e28d8aa34392cc10f3725d0e020392fb0a8a`。
  企业微信适配包明确依赖该字体；构建脚本将字体文件及版权说明装入本地
  Flatpak，使官方前缀已有的宋体、微软雅黑字体替换规则能够生效。该字体采用
  Apache-2.0 或带字体例外的 GPL-3+ 双重许可。
- 运行辅助包：`deepin-wine-helper 5.4.10-1`，SHA-256 为
  `ad23f45e60e574b1eb6bd1964cc0f54e434478e1b3114be6cdb4f0dcfc6caa41`。
  本地包只提取官方启动路径需要的 OpenGL 探测与 GDI 回退文件；不封装依赖
  Deepin DTK 桌面的横幅、更新器、卸载器、热键和托盘程序。
- Deepin Wine 声明但 Freedesktop 25.08 不提供兼容 SONAME 的运行库包括
  `libcapi20.so.3`、`libgphoto2.so.6`、`libgphoto2_port.so.12`、
  `libpcsclite.so.1` 和 `libsane.so.1`。构建脚本从 Deepin 官方 beige 仓库
  下载相应包，并只封装 Wine 会直接加载的 ABI。`libsane.so.1` 所需的旧版
  `libxml2.so.2`、`libicuuc.so.74` 和 `libicudata.so.74` 也一并封装；运行时
  自带的 libxml2/ICU 新 ABI 不能替代它们。
- `p7zip 16.02+dfsg-8` 与 `p7zip-full 16.02+dfsg-8` 用于在新用户数据目录中
  解压官方 `files.7z` 前缀模板。所有下载均固定版本并校验 SHA-256。
- `scripts/build-deepin-wine-flatpak.sh` 只在用户本机下载、校验和封装上述内容；
  本地包完整携带 Deepin 官方适配目录和 `files.7z`，并在该前缀内安装腾讯官方
  企业微信 5.0.10.6025。仓库不保存 `.deb`、`.exe`、企业微信程序、适配 DLL 或
  生成的 Flatpak。
  由于企业微信适配包包含专有客户端发布内容，本地测试 Flatpak 不得进入公开
  CI artifact 或公开发行附件。
- 官方预制前缀另含 Microsoft 原生 `riched20.dll` 和 `msftedit.dll`，并配置
  `native,builtin` 覆盖。本地 Deepin 测试包为复现官方兼容组合而从已校验的
  官方包中提取它们；这些 Microsoft 二进制同样不得提交或公开再分发。
- Deepin Wine 包附带的版权文件声明 Wine 代码采用 LGPL-2.1；公开再分发前仍需
  单独核实 Deepin 修改的对应源码和企业微信专用适配文件的完整授权边界。

## Microsoft RichEdit A/B 组件

- 原生 RichEdit 仅用于验证企业微信图片粘贴兼容性；当前验证样本为 Win2k
  `riched20.dll`，SHA-256 为
  `c741226a0465a8c4edcbe0f3af54de02e21931122afe3a4dad8d49553fececcc`。
- 该 DLL 是 Microsoft 专有组件。本项目不保存、提交，也不随公开 Flatpak、
  源码归档或公开 CI artifact 再分发。自有机器之间可由私有 CI 将用户合法持有
  且摘要匹配的文件封装为独立 RichEdit Flatpak 扩展；扩展不得进入公开仓库。
- 公开 Release 只发布安装脚本和不含微软 DLL 的 Wine Runner。安装脚本接受用户
  本地路径并在用户机器生成扩展，不提供 RichEdit 下载地址，也不上传生成结果。
