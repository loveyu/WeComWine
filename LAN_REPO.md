# 局域网 Flatpak 仓库

本文记录企业微信 Deepin 兼容版 Flatpak 的局域网发布、安装、更新和验证方式。
仓库未使用 GPG 签名，只适用于受信任的局域网。

## 当前拓扑

| 项目 | 当前值 |
| --- | --- |
| 应用 ID | `io.github.loveyu.WeComWine.Deepin` |
| Flatpak 分支 | `stable-25.08` |
| 企业微信版本 | `5.0.10.6025` |
| 内部构建 repo | `~/.local/share/wecom-flatpak-poc/deepin-flatpak-repo` |
| 对外 LAN repo | `~/.local/share/flatpak-lan/repo` |
| HTTP 根目录 | `~/.local/share/flatpak-lan` |
| systemd 服务 | `flatpak-lan-repo.service` |
| 仓库地址 | `http://LAN_REPO_HOST:18080/repo/` |
| 客户端远程名 | `loveyu-lan` |

内部构建 repo 和对外 LAN repo 是两个独立 OSTree 仓库。完成
`make deepin-flatpak-local` 并不代表局域网客户端已经能看到新版本，还需要将
appdir 导出到 LAN repo 并更新仓库 summary。

发布或安装前使用下面的命令确认本机到客户端的实际出口地址，并将后续命令中的
`LAN_REPO_HOST` 替换为该地址：

```bash
ip route get CLIENT_IP
```

## HTTP 服务

当前用户级服务文件位于
`~/.config/systemd/user/flatpak-lan-repo.service`，核心配置如下：

```ini
[Unit]
Description=Serve the private LAN Flatpak repository
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m http.server 18080 --bind 0.0.0.0 --directory %h/.local/share/flatpak-lan
Restart=on-failure
RestartSec=3
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
RestrictAddressFamilies=AF_INET

[Install]
WantedBy=default.target
```

查看或启动服务：

```bash
systemctl --user status flatpak-lan-repo.service
systemctl --user enable --now flatpak-lan-repo.service
```

检查 HTTP 仓库：

```bash
curl -fsSI http://LAN_REPO_HOST:18080/repo/summary
```

## 发布新构建

先在源码仓库完成 Deepin 私有包构建，并确认 appdir 已生成：

```bash
cd /path/to/wecom-wine-flatpak
make deepin-flatpak-local

test -f \
  ~/.cache/wecom-flatpak-poc/deepin-engine/build-10.14deepin11-5.0.0.6008deepin8/appdir/metadata
```

将 appdir 导出到对外 LAN repo：

```bash
source_commit="$(git rev-parse --short=7 HEAD)"

flatpak build-export \
  --disable-fsync \
  --subject="WeCom Wine Deepin 5.0.10.6025 (source ${source_commit})" \
  ~/.local/share/flatpak-lan/repo \
  ~/.cache/wecom-flatpak-poc/deepin-engine/build-10.14deepin11-5.0.0.6008deepin8/appdir \
  stable-25.08

flatpak build-update-repo \
  --generate-static-deltas \
  --static-delta-jobs=4 \
  ~/.local/share/flatpak-lan/repo
```

不要默认添加 `--prune`。保留父提交可以为已安装旧版本的客户端生成增量，也便于
必要时回滚。

发布后确认 ref 和 HTTP summary：

```bash
sed -n '1p' \
  ~/.local/share/flatpak-lan/repo/refs/heads/app/io.github.loveyu.WeComWine.Deepin/x86_64/stable-25.08

curl -fsSI http://LAN_REPO_HOST:18080/repo/summary
```

`build-update-repo` 可能提示应用缺少 AppStream XML。当前应用仍可按 ID 安装，
但不会提供完整的应用商店展示信息；该提示不等同于发布失败。

## 客户端全新安装

在局域网客户端执行：

```bash
flatpak remote-add --user --if-not-exists --no-gpg-verify \
  loveyu-lan http://LAN_REPO_HOST:18080/repo/

flatpak install --user loveyu-lan \
  io.github.loveyu.WeComWine.Deepin//stable-25.08
```

应用依赖 `org.freedesktop.Platform/x86_64/25.08`。客户端缺少该运行时时，需要有
可用的 Flathub 远程，或者另行提供运行时源。

## 客户端更新

已经从 `loveyu-lan` 安装的客户端直接执行：

```bash
flatpak update --user io.github.loveyu.WeComWine.Deepin
```

如客户端保存的是旧地址，先修正远程 URL：

```bash
flatpak remote-modify --user \
  --url=http://LAN_REPO_HOST:18080/repo/ \
  loveyu-lan
```

## 验证

在客户端比较远程提交和已安装提交：

```bash
flatpak remote-info --user loveyu-lan \
  io.github.loveyu.WeComWine.Deepin

flatpak info --user --show-commit \
  io.github.loveyu.WeComWine.Deepin
```

两者提交一致表示客户端已更新到 LAN repo 当前版本。随后可启动应用做业务验证：

```bash
flatpak run io.github.loveyu.WeComWine.Deepin
```

## 回滚

先从远程历史中找到需要恢复的提交：

```bash
flatpak remote-info --user --log loveyu-lan \
  io.github.loveyu.WeComWine.Deepin
```

再在客户端指定提交回滚：

```bash
flatpak update --user --commit=COMMIT \
  io.github.loveyu.WeComWine.Deepin
```

回滚 Flatpak 部署不会自动回滚企业微信的可写 Wine 前缀和用户数据。若新版本执行
了前缀迁移，应先确认对应迁移脚本的恢复方案。

## 排查顺序

1. 使用 `systemctl --user is-active flatpak-lan-repo.service` 确认 HTTP 服务运行。
2. 从客户端请求 `/repo/summary`，确认路由、防火墙和地址正确。
3. 用 `flatpak remote-info` 检查客户端看到的远程提交。
4. 用 `flatpak info --show-commit` 检查客户端实际安装的提交。
5. 若两者不同，运行 `flatpak update`；若仍无更新，检查 remote URL 和分支。

不要把企业微信安装器、Wine 前缀、登录数据、聊天数据或凭据复制到公开仓库。
LAN repo 包含不可公开再分发的私有二进制，只能在授权范围内使用。
