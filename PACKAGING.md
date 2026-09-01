# 独立包准备说明

## 建议交付物

项目最终应区分两个制品：

1. `io.github.huzhiyu.WeComWine` Flatpak runner：包含 Wine 11.0、传统 WoW64
   32/64 位运行库、Portal 补丁和 smoke test，不包含腾讯二进制。
2. `wecom-wine-flatpak` 用户级集成包：包含下载校验、前缀初始化、systemd
   单元、桌面入口、切换/回滚和诊断脚本。

腾讯企业微信安装包由目标机器根据固定 HTTPS URL 下载并校验 SHA-256，不能进入
Git、源码归档、Flatpak 仓库或公开发行附件。

## 当前可用入口

```bash
make check
make install-user
make dist SOURCE_DATE_EPOCH=0
```

- `make check` 校验 shell 语法、补丁数量，并阻止 EXE/MSI/Flatpak 二进制进入仓库。
- `make install-user` 安装到 `~/.local/share/wecom-wine-flatpak`，部署用户级
  systemd、桌面入口和企业微信专用 KWin 系统边框规则，但不会自动启动。
- `make dist` 生成排序、固定时间戳和固定 owner 的源码归档及 SHA-256 文件。

当前 Flatpak runner 的权威构建实现仍是 `scripts/build-portal-wine.sh`。YAML
manifest 是依赖和补丁来源记录，尚不能替代传统 WoW64 配对构建。

用户级集成包在 KDE 环境还依赖 `kwriteconfig6`、`kreadconfig6`、`qdbus6`、
`xprop` 和 `xwininfo`。规则安装会保留既有 KWin 规则列表，仅增加固定 ID
`wecom-wine-system-frame`；卸载流程必须调用 `scripts/install-kwin-rule.sh remove`。

## 正式发布前阻塞项

- [ ] 明确本项目自有脚本、测试和文档的许可证；第三方补丁继续遵守 Wine 许可。
- [ ] 把定制 Wine runner 转为可由 CI/flatpak-builder 完整重现的 manifest 或容器化构建。
- [ ] 增加 AppStream metadata、正式图标、截图、版本和发行说明。
- [ ] 使用独立 GPG key 签名 Flatpak OSTree 仓库或生成受信任的 single-file bundle。
- [ ] 设计从 `wecom-flatpak-poc.*` 服务名和 XDG 数据目录迁移到正式名称的兼容策略。
- [ ] 固化企业微信版本升级策略，默认禁止未经回归的自动升级。
- [ ] 在干净用户账户执行安装、升级、回滚、卸载和数据保留测试。
- [ ] 扫码后完成企业微信真实输入框、收发文件、托盘、外部链接和内置网页验收。

## 发布安全边界

- 不把 Wine 前缀、聊天数据、二维码、Cookie、Token、日志或崩溃转储打包。
- 不默认开放整个 home、host、摄像头、系统总线或容器管理 socket。
- 只开放 `~/Downloads/WeCom` 作为文件交换目录。
- Portal 补丁仍是上游草案；每次 Wine 或企业微信升级必须重跑 Portal 和 Fcitx5
  自动测试，并进行一次登录后业务验收。
