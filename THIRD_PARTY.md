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
- 安装包 SHA-256：`d46b1cc2603c70ff9cccd85998eed0c0d61f11a3a68e050b0695111294c10c87`
- 企业微信是腾讯的专有软件。本项目不保存、不提交、不公开再分发其安装包或
  Wine 前缀；目标机器自行下载并在安装前校验摘要。
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

- CJK 字体只读复用宿主 Noto Sans CJK，不复制到项目或发行包。
- Freedesktop Platform、Wine Flatpak base、Mono、Gecko 和图形扩展由 Flatpak
  依赖解析获取；正式发布时需要同步生成完整的第三方许可证清单。

## Microsoft RichEdit A/B 组件

- 原生 RichEdit 仅用于验证企业微信图片粘贴兼容性；当前验证样本为 Win2k
  `riched20.dll`，SHA-256 为
  `c741226a0465a8c4edcbe0f3af54de02e21931122afe3a4dad8d49553fececcc`。
- 该 DLL 是 Microsoft 专有组件。本项目不保存、提交，也不随公开 Flatpak、
  源码归档或公开 CI artifact 再分发。自有机器之间可由私有 CI 将用户合法持有
  且摘要匹配的文件封装为独立 RichEdit Flatpak 扩展；扩展不得进入公开仓库。
- 公开 Release 只发布安装脚本和不含微软 DLL 的 Wine Runner。安装脚本接受用户
  本地路径并在用户机器生成扩展，不提供 RichEdit 下载地址，也不上传生成结果。
