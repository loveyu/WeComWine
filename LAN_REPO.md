# 局域网 Flatpak 仓库

本文记录企业微信、微信开发者工具和支付宝小程序开发者工具的私有局域网发布。
三个应用共用一个 Deepin Wine 10.14deepin11 基础包，包含通用字体及 Portal 模块。
仓库未使用 GPG 签名，只适用于受信任的局域网。

## 当前拓扑

| 项目 | 当前值 |
| --- | --- |
| 共享基础包 | `io.github.loveyu.Wine.Deepin//10.14deepin11-25.08` |
| 企业微信 | `io.github.loveyu.WeComWine.Deepin//stable-25.08`，5.0.7.6005 |
| 微信开发者工具 | `io.github.loveyu.WeChatDevToolsWine//stable-25.08`，2.02.2608070 |
| 支付宝开发者工具 | `io.github.loveyu.AlipayDevToolsWine//stable-25.08`，3.10.5 |
| 对外 LAN repo | `~/.local/share/flatpak-lan/repo` |
| HTTP 根目录 | `~/.local/share/flatpak-lan` |
| systemd 服务 | `flatpak-lan-repo.service` |
| 仓库地址 | `http://LAN_REPO_HOST:18080/repo/` |
| 宿主启动集成 | `http://LAN_REPO_HOST:18080/integration/` |
| 客户端远程名 | `loveyu-lan` |
| 客户端默认状态 | 禁用，仅在安装或更新时临时启用 |

内部构建 repo 和对外 LAN repo 相互独立。完成本机构建后还需执行发布，
客户端才能看到新包。分支表示运行时兼容线，实际发布提交见 `integration/refs.tsv`，
源码提交见 `integration/sources.tsv`。

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

先构建共享底包和三个应用层，安装宿主集成，并在本机实际启动验证：

```bash
cd /path/to/wine/wecom-wine-flatpak
make shared-wecom-app
make install-user
make -C ../wechat-devtools-wine-flatpak build-deepin-runner install-user-integration
make -C ../alipay-devtools-wine-flatpak build-deepin-runner install-user-integration
```

验证通过后提交三个源码仓库中的变更，再发布已安装的部署：

```bash
make publish-lan
```

`scripts/publish-lan-repo.sh` 要求三个源码仓库均无未提交变更，核对三个应用引用的
共享扩展版本与字体摘要，从用户级 Flatpak repo 导入已安装的四个部署，最后生成
静态增量并更新 summary。可用 `WECOM_LAN_ROOT` 指定其他私有发布根目录。

该入口还会用 `git archive HEAD` 导出三个源码集成包及其校验清单。两个开发者工具
的 Flatpak 是 Wine 应用层，菜单、下载校验、前缀初始化和单实例启动由宿主脚本完成；
因此不能只发布薄 Flatpak 而遗漏宿主集成。企业微信的 `.desktop` 在 Flatpak 中，
共享应用层重建时会同步当前源码中的启动文件。

发布入口不读取用户前缀、聊天数据、项目、凭据或日志，也不清理历史提交。
运行期间会占用构建所需 CPU；静态增量并行度限制为 2。

发布后检查：

```bash
curl -fsSI http://LAN_REPO_HOST:18080/repo/summary
curl -fsS http://LAN_REPO_HOST:18080/integration/refs.tsv
curl -fsS http://LAN_REPO_HOST:18080/integration/sources.tsv
```

## 客户端全新安装

在局域网客户端执行：

```bash
flatpak remote-add --user --if-not-exists --no-gpg-verify \
  --disable --no-enumerate --no-use-for-deps \
  loveyu-lan http://LAN_REPO_HOST:18080/repo/

flatpak remote-modify --user --enable loveyu-lan
flatpak install --user loveyu-lan \
  runtime/io.github.loveyu.Wine.Deepin//10.14deepin11-25.08 \
  app/io.github.loveyu.WeComWine.Deepin//stable-25.08 \
  app/io.github.loveyu.WeChatDevToolsWine//stable-25.08 \
  app/io.github.loveyu.AlipayDevToolsWine//stable-25.08
flatpak remote-modify --user --disable loveyu-lan
```

三个应用依赖 `org.freedesktop.Platform/x86_64/25.08`。共享 Wine 扩展须显式安装；
它不能替代 Freedesktop 运行时。企业微信还需要 25.08 的 i386 兼容扩展。客户端缺少该运行时时，需要有
可用的 Flathub 远程，或者另行提供运行时源。

即使安装失败，也应执行最后一条 `remote-modify --disable`。该 LAN 服务不保证
持续在线，不应让客户端在日常 Flatpak 刷新时默认访问它。

## 安装宿主启动集成

将三份源码包和校验清单下载到同一目录，校验后解压到稳定目录。启动文件会引用
该目录中的脚本，安装后不要删除该目录：

```bash
integration_dir="$HOME/.local/share/wine-app-integrations"
mkdir -p "$integration_dir"
cd "$integration_dir"
for project in wecom-wine-flatpak wechat-devtools-wine-flatpak alipay-devtools-wine-flatpak; do
  curl -fLO "http://LAN_REPO_HOST:18080/integration/${project}.tar.gz"
done
curl -fLO http://LAN_REPO_HOST:18080/integration/SHA256SUMS
sha256sum --check SHA256SUMS
for project in wecom-wine-flatpak wechat-devtools-wine-flatpak alipay-devtools-wine-flatpak; do
  tar -xzf "${project}.tar.gz"
done
make -C wecom-wine-flatpak install-user
make -C wechat-devtools-wine-flatpak install
make -C alipay-devtools-wine-flatpak install
```

开发者工具安装入口会从固定地址下载并校验官方安装器，程序写入各自前缀；
首次安装请等待完成。已有安装若仅更新菜单和启动脚本，改用
`make install-user-integration`，保留当前程序、登录、项目和设置。企业微信可从
Flatpak 菜单直接启动，不需要为 Deepin 路径启动旧 baseline 的 bootstrap 服务。

开始菜单提供标准中文名、英文名、拼音全拼和首字母关键词。例如企业微信支持
`WeCom`、`qiyeweixin`、`qywx`；微信开发者工具支持 `WeChat DevTools`、
`weixinkaifazhegongju`、`wxkfzgj`；支付宝支持 `Alipay DevTools`、
`zhifubaokaifazhegongju`、`zfbkfzgj`，以及完整“小程序”名称的拼音。

## 客户端更新

已经从 `loveyu-lan` 安装的客户端直接执行：

```bash
flatpak remote-modify --user --enable loveyu-lan
flatpak update --user \
  runtime/io.github.loveyu.Wine.Deepin//10.14deepin11-25.08 \
  app/io.github.loveyu.WeComWine.Deepin//stable-25.08 \
  app/io.github.loveyu.WeChatDevToolsWine//stable-25.08 \
  app/io.github.loveyu.AlipayDevToolsWine//stable-25.08
flatpak remote-modify --user --disable loveyu-lan
```

如客户端保存的是旧地址，先修正远程 URL：

```bash
flatpak remote-modify --user \
  --url=http://LAN_REPO_HOST:18080/repo/ \
  loveyu-lan
```

修正 URL 不会改变 remote 的启用状态。需要更新时仍应临时启用，并在操作结束后
恢复为禁用。

## 验证

在客户端比较远程提交和已安装提交：

```bash
flatpak remote-modify --user --enable loveyu-lan
flatpak remote-info --user loveyu-lan \
  io.github.loveyu.WeComWine.Deepin
flatpak remote-modify --user --disable loveyu-lan

flatpak info --user --show-commit \
  io.github.loveyu.WeComWine.Deepin
```

两者提交一致表示客户端已更新到 LAN repo 当前版本。还应按 `integration/refs.tsv`
核对共享基础包和另两个应用的提交。随后可启动应用做业务验证：

```bash
flatpak run io.github.loveyu.WeComWine.Deepin
```

## 回滚

先从远程历史中找到需要恢复的提交：

```bash
flatpak remote-modify --user --enable loveyu-lan
flatpak remote-info --user --log loveyu-lan \
  io.github.loveyu.WeComWine.Deepin
```

再在客户端指定提交回滚：

```bash
flatpak update --user --commit=COMMIT \
  io.github.loveyu.WeComWine.Deepin
flatpak remote-modify --user --disable loveyu-lan
```

回滚 Flatpak 部署不会自动回滚企业微信的可写 Wine 前缀和用户数据。若新版本执行
了前缀迁移，应先确认对应迁移脚本的恢复方案。

## 排查顺序

1. 使用 `systemctl --user is-active flatpak-lan-repo.service` 确认 HTTP 服务运行。
2. 从客户端请求 `/repo/summary`，确认路由、防火墙和地址正确。
3. 临时启用 remote，再用 `flatpak remote-info` 检查客户端看到的远程提交。
4. 用 `flatpak info --show-commit` 检查客户端实际安装的提交。
5. 若两者不同，运行 `flatpak update`；若仍无更新，检查 remote URL 和分支。
6. 操作结束后确认 `loveyu-lan` 已恢复为禁用状态。

若包内 desktop 文件已有新关键词，但 KDE 搜索仍使用旧内容，检查
`~/.local/share/applications/io.github.loveyu.WeComWine.Deepin.desktop`。旧版集成
曾在该高优先级目录留下同名 Flatpak 启动项，从而覆盖当前 Flatpak export。仅在
文件同时包含匹配的 `X-Flatpak` 和 `flatpak run` 行时删除，再重建 KDE 缓存：

```bash
desktop="$HOME/.local/share/applications/io.github.loveyu.WeComWine.Deepin.desktop"
if [[ -f "${desktop}" ]] && \
   grep -Fxq 'X-Flatpak=io.github.loveyu.WeComWine.Deepin' "${desktop}" && \
   grep -Eq '^Exec=.*/flatpak run .*io\.github\.loveyu\.WeComWine\.Deepin([[:space:]]|$)' \
       "${desktop}"; then
    rm -f -- "${desktop}"
fi
kbuildsycoca6 --noincremental
```

更新和卸载禁止使用 `--delete-data`，也不要删除现有 Wine 前缀和工作区。
不要把安装器、Wine 前缀、登录数据、聊天数据、项目或凭据复制到公开仓库。
LAN repo 包含不可公开再分发的私有二进制，只能在授权范围内使用。
