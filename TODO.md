# 独立包 TODO

更新时间：2026-09-02

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
- [x] Flatpak 应用、桌面文件和可选扩展统一迁移到 `io.github.loveyu` 命名空间。
- [x] 增加主 runner 与私有 RichEdit 扩展的多 Flatpak 打包脚本、GitHub 托管 CI
  工作流、SHA-256 清单和用户级安装入口；企业微信安装程序保持独立。
- [x] 增加由 GitHub CI 生成的版本化 Release 安装脚本：自动下载、校验并安装
  Runner/集成层，并支持用用户本地合法持有的 DLL 在用户机器打包 RichEdit。
- [x] 修正 RichEdit 扩展挂载点未被 OSTree 保留的问题，并在 runner 沙箱内以
  固定 SHA-256 验证扩展 DLL 可见。
- [x] 在本机安装两个 Flatpak 并独立安装企业微信；bootstrap 在自建 runner
  模式不再额外安装完整 `org.winehq.Wine`，全新前缀正确映射到新应用数据目录。
- [x] 远程部署原地切换到 `io.github.loveyu.WeComWine`，保留既有登录前缀，移除
  已停用的旧应用 ID、桌面入口和临时 bundle。
- [x] 移除企业微信自绘透明阴影窗，不修改 KDE 或其他应用的全局阴影；覆盖
  非对称主窗以及右键菜单 transient 阴影。真实窗口模拟右键验证中，
  菜单阴影在 0.8 秒检查点已透明，服务未重启；每个 XID 仍只写一次 opacity。
- [x] 企业微信 Wine DPI 自动跟随 KDE/X11 系统缩放，并支持显式倍率覆盖。
- [x] 企业微信启动入口默认强制使用 KDE XDG Desktop Portal 文件选择器，
  避免 Win32 hook/事件监听器使 `auto` 策略回退到 Wine 原生对话框；保留
  `WECOM_FORCE_PORTAL=0` 诊断开关。真实入口已显示 KDE 选择器、完成 Document
  Portal 单文件授权，并通过 Portal 专用只读 `IShellBrowser`/`IFolderView2`
  代理将 `IShellItemArray` 交给企业微信；用户选择文本文件后已进入发送流程。
- [x] 补齐 IFileDialog Portal 成功后的 `OnFolderChange`、
  `OnSelectionChange`、`OnFileOk` 事件顺序，并让 `GetCurrentSelection`/
  `GetSelectedItems` 在事件回调期间返回当前选择；真实 runner 已完成验证。
- [x] 移除企业微信专用 KWin 强制系统边框规则，避免边框状态残留导致窗口持续
  位于最顶层；后续安装和升级不再写入 `kwinrulesrc`。
- [x] 修复最大化企业微信切到后台后自绘顶栏仍覆盖前台应用的问题：精确识别与
  主窗口同宽的 `override-redirect` ARGB 顶栏，仅在其主窗口位于前台时映射，
  避免残留最小化/最大化按钮截获 Chrome 等应用右上角点击；管理器已拆成独立
  用户服务，使 Flatpak 桌面入口直接启动时同样生效。
- [x] 回移 Wine X11 剪贴板格式注册修复，并增加 32 位图片/OLE 剪贴板探针。
- [x] 补齐 RichEdit 粘贴静态图片时的 `IRichEditOleCallback::GetNewStorage`
  持久化路径，强校验探针已验证对象类别、存储和尺寸。
- [x] 企业微信默认传入 `--disable-gpu`，消除 ANGLE D3D11/D3D9 初始化失败
  导致的 GPU 子进程重启风暴；保留 `WECOM_DISABLE_GPU=0` 隔离回退开关。
- [x] 按 Flatpak instance ID 清理单次启动的残留 Wine/Bugly 进程，并阻止子进程
  继承运行锁，不影响使用同一应用 ID 的并行构建和冒烟测试。
- [x] 完成原生 Win2k `riched20.dll` 单 DLL A/B：企业微信真实主程序确认加载
  native 模块并完整启动；冷启动约增加 14 秒，合成 RichEdit 探针的建窗失败
  不能代表企业微信实际加载结果。
- [x] 修正原生 RichEdit 的前缀写入边界：DLL 和注册表覆盖持久写入正式前缀，
  避免整前缀 Overlay 丢弃企业微信更新、组件安装和令牌刷新；
  首次试验造成的失效登录配置已从保留的 upper 回填，并保留回填前备份。
- [x] 内置更新期间保持 Flatpak 实例和 wineserver 存活，允许更新器在主进程退出后
  完成程序文件与注册表写入，不锁定企业微信运行版本。
- [x] 在正式可写前缀中从 5.0.10.6015 升级到 5.0.10.6025，并完成新版本启动、
  登录态、原生 RichEdit 覆盖和持续运行验证。
- [x] 解析 5.0.10.6025 三次含图片聊天崩溃转储：均为 `0xc00000fd`，异常入口
  `ntdll.dll+0x44c2c`，已捕获栈未出现 `riched20.dll`；原生组件相关性待 A/B。
- [x] 完成 Wine 内置 RichEdit 对照：相同含图片聊天仍触发同样的
  `0xc00000fd`，证明崩溃不以原生 DLL 为必要条件；为保留图片粘贴能力，
  有效的原生 Win2k 组件恢复为默认启用。
- [x] 恢复历史已验证的 Wayland PNG → X11 BMP 剪贴板链路：Wine 探针实际
  获取 `CF_DIB/CF_BITMAP/CF_ENHMETAFILE`，RichEdit 插入非空图片对象，真实
  企业微信输入框粘贴成功；增加仅在运行期处理图片的自动桥接。
- [x] 默认停用窗口阴影抑制器，避免外部 opacity 写入参与含图片聊天的窗口重绘；
  仅保留 `WECOM_DISABLE_WINDOW_SHADOW=1` 作为显式诊断开关。
- [x] 定位并修复企业微信 5.0.10.6025 内置 CEF renderer 启动即崩溃：Wine
  `VirtualProtect` 返回 `PAGE_WRITECOPY` 后触发 CEF 对旧保护属性的强制断言；
  启动时按唯一指令结构定点修补并保留摘要备份，未知新版本安全跳过且不限制更新。
- [x] 真实账号复验内置 CEF 网页恢复正常；Flatpak Portal → Chromium 的系统
  浏览器链路也已直接验证，私有 CEF 二进制不进入仓库或公开制品。

## 生成正式独立包前

- [ ] 为项目自有脚本、测试和文档选择并加入许可证。
- [ ] 将传统 WoW64 构建完整转换为 CI 可复现的 Flatpak manifest/构建环境。
- [ ] 增加 AppStream metadata、截图和发行说明。
- [x] 用多尺寸官方图标规范化 Wine 主窗口图标，避免任务栏锯齿和提醒时黑块。
- [x] 安装升级时定点清理历史强制系统边框 KWin 规则，保留其他用户规则。
- [ ] 增加 Flatpak 仓库 GPG 签名或 single-file bundle 发布流程。
- [ ] 设计服务名和 XDG 数据目录从 POC 名称迁移到正式名称的兼容方案。
- [ ] 增加干净账户的安装、升级、回滚、卸载和数据保留测试。
- [ ] 增加 Wine/企业微信版本升级锁定与回归策略。
- [x] 将权威 runner 源码更新到 Wine 11.16，不保留运行版本上限；逐项验证现有
  16 个补丁，15 个仍可应用，已被上游合入的 X11 剪贴板补丁自动跳过，冲突不
  静默忽略。完成构建后继续验证缩放、窗口边框/拖动、输入法、文本与图片剪贴板、
  Portal 文件对话框和 CEF 子窗口。
- [ ] 继续完成收发文件、托盘和 Wine 11.16 runner 回归；当前 Wine 11.0 runner
  的真实输入框图片粘贴、Portal 文件入口、外部链接和内置网页已验收。
- [x] 在已登录真实输入框完成原生 Win2k RichEdit 的外部图片粘贴、非空预览和
  实际发送验收；接收侧可见完整图片，发送当时企业微信未崩溃。
- [x] 增加原生 RichEdit 正式入口、固定摘要安装器、缺失/非法组件安全回退、
  用户数据实时挂载和诊断状态；源码/发行归档检查显式禁止 `.dll` 污染。
- [ ] 增加从用户合法持有的官方介质自动提取 Win2k `riched20.dll` 的可审计流程，
  不下载、不缓存到源码树，也不在独立包中再分发 Microsoft DLL。
- [ ] 暂缓定位 WXWork `BackgroundThread` 的 `0xc00000fd` 栈溢出：16:53 转储
  发生于启动约 13 分钟后，异常模板与启用原生 RichEdit 前 14:31 的转储完全
  一致，暂无原生 DLL 因果证据。暂停运行期阴影抑制器后，用户复验群公告、
  内置网页、企业微信文档和邮件均未复现崩溃；下一版抑制器已改为每个 XID 只
  写一次 opacity。按 2026-09-01 安排不再主动复现，仅在再次崩溃时采集新转储、
  阴影抑制器状态和触发前操作后继续处理。

## 已有自动验证基线

- Portal：`GetOpenFileNameA/W`、`GetSaveFileNameA/W`、`IFileOpenDialog`、
  `IFileSaveDialog`、`SHBrowseForFolderW`、过滤器、多选和 hook 回退；D-Bus
  计数 `OpenFile=5`、`SaveFile=3`，新增强制策略下带 hook 仍进入 Portal 的
  覆盖。企业微信真实入口已验证转发到 KDE FileChooser，并由 Document Portal
  向本 Flatpak 应用授权所选对象；Portal Shell View 代理被业务回调实际读取，
  文本文件已进入发送流程，服务重启次数保持为 0。
- 输入法：Fcitx5 拼音 `nihao` 上屏结果 UTF-16 为 `4F60 597D`（“你好”）。
- 剪贴板：32 位探针验证 `CF_BITMAP`、`CF_DIB`、`CF_DIBV5` 和 OLE
  `IDataObject`；RichEdit 强校验探针确认静态图片对象拥有非空 OLE 存储。
- 图形稳定性：软件合成启动后仅保留一个 GPU 辅助进程，未再出现 ANGLE
  D3D 初始化失败及约每 0.4 秒一次的重启风暴。
- 生命周期：停止后没有残留项目 Flatpak/Wine 实例或运行锁持有者；冷启动后
  已登录主窗口恢复，构建/测试实例不会被运行服务的退出清理误杀。

## 明确不纳入范围

- 会议摄像头。
- 屏幕共享。
- 在仓库或公开制品中再分发腾讯企业微信安装包。
