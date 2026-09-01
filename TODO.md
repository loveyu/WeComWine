# 独立包 TODO

更新时间：2026-09-01

## 已完成的项目化准备

- [x] 建立独立源码目录和 Git 忽略规则。
- [x] 排除企业微信 EXE、Wine 前缀、用户数据、日志、截图和构建缓存。
- [x] 脚本不再硬编码开发目录或用户名，支持 XDG 目录和环境变量覆盖。
- [x] 日志从源码树迁移到 `XDG_STATE_HOME`。
- [x] 用户级安装脚本部署源码、systemd 单元和桌面入口，但不擅自启动。
- [x] 增加 shell/补丁/二进制污染检查。
- [x] 增加可重复源码归档和 SHA-256 生成入口。
- [x] 记录 Wine、企业微信、字体和运行时的第三方来源及再分发边界。
- [x] 保留现有 `wecom-flatpak-poc` 状态/数据命名空间，支持以后原地升级。
- [x] 移除企业微信自绘透明阴影窗，不修改 KDE 或其他应用的全局阴影。

## 生成正式独立包前

- [ ] 为项目自有脚本、测试和文档选择并加入许可证。
- [ ] 将传统 WoW64 构建完整转换为 CI 可复现的 Flatpak manifest/构建环境。
- [ ] 增加 AppStream metadata、正式图标、截图和发行说明。
- [ ] 增加 Flatpak 仓库 GPG 签名或 single-file bundle 发布流程。
- [ ] 设计服务名和 XDG 数据目录从 POC 名称迁移到正式名称的兼容方案。
- [ ] 增加干净账户的安装、升级、回滚、卸载和数据保留测试。
- [ ] 增加 Wine/企业微信版本升级锁定与回归策略。
- [ ] 扫码完成企业微信实际输入框、收发文件、托盘、外部链接和内置网页验收。

## 已有自动验证基线

- Portal：`GetOpenFileNameA/W`、`GetSaveFileNameA/W`、`IFileOpenDialog`、
  `IFileSaveDialog`、`SHBrowseForFolderW`、过滤器、多选和 hook 回退；D-Bus
  计数 `OpenFile=4`、`SaveFile=3`。
- 输入法：Fcitx5 拼音 `nihao` 上屏结果 UTF-16 为 `4F60 597D`（“你好”）。
- 生命周期：停止后没有残留项目 Flatpak/Wine 实例，冷启动后二维码窗口恢复。

## 明确不纳入范围

- 会议摄像头。
- 屏幕共享。
- 在仓库或公开制品中再分发腾讯企业微信安装包。
