# CodexBar

CodexBar 是一个 macOS 菜单栏 + Touch Bar 小工具，用本机 Codex app-server 读取 Codex 额度，并把额度窗口或可用重置次数持续显示在 Touch Bar 上。

项目维护者：[wjx8](https://github.com/wjx8)

它不抓网页，也不需要你填写 API Key。应用会自动查找 ChatGPT 合并版或旧版 Codex 中的本机 `codex`：

```bash
/Applications/ChatGPT.app/Contents/Resources/codex app-server --listen stdio://
# 或旧版
/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
```

然后通过 JSON-RPC 调用：

```text
account/rateLimits/read
```

## 来源与致谢

CodexBar 基于 Jack Chen 的开源项目 [TouchBarCodexToken](https://github.com/jackchensky/TouchBarCodexToken) 二次开发。感谢原作者完成额度读取、菜单栏与 Touch Bar 的基础实现。本项目保留 MIT 许可证要求的原始版权声明，并在此基础上增加持久 Touch Bar、语音直接输入、自动生命周期联动与新版 UI。

## 功能

- 菜单栏状态：根据接口实际返回显示额度窗口；只有周额度时不再重复显示成 5 小时额度。
- 持久 Touch Bar：Codex 输入框获得焦点后仍保持额度与语音按钮，不再依赖桌面浮窗。
- Touch Bar 语音输入：点击 `🎙 语音` 开始中文识别，第二次点击后直接输入到当前 Codex 文本框。
- 同步状态：菜单栏和 Touch Bar 使用同一份额度状态。
- 自动联动 Codex：检测到 ChatGPT 合并版或旧版 Codex 启动后自动运行，宿主应用退出后自动退出。
- 刷新保护：刷新失败时保留旧数据，不清空已有额度。
- 本地优先：只调用本机 Codex app-server，不保存账号、密钥或授权码。

## 兼容性

### Mac 机型

| 机型 | 支持情况 | 说明 |
| --- | --- | --- |
| Intel Mac | 支持 | 当前发布的 DMG 是 `x86_64` 构建，适合 Intel 芯片 Mac，包括 2016-2019 款带 Touch Bar 的 MacBook Pro。 |
| Apple Silicon Mac | 支持 | M1 / M2 / M3 / M4 系列 Mac 可通过 Rosetta 2 运行当前 Intel 版应用；首次打开时系统可能提示安装 Rosetta。 |
| 无 Touch Bar 的 Mac | 部分支持 | 菜单栏额度显示可以正常使用，只是不会显示 Touch Bar 额度条。 |

### Touch Bar

Touch Bar 不是必需硬件。

- 有 Touch Bar 的 Mac：可以使用菜单栏和 Touch Bar 额度条。
- 没有 Touch Bar 的 Mac：可以正常使用菜单栏，Touch Bar 相关功能会自然不可见。

### 系统和依赖

- macOS 11 Big Sur 或更新版本。
- 已安装 `/Applications/ChatGPT.app`（Codex 合并版）或旧版 `/Applications/Codex.app`。
- 本机 Codex app-server 可用。

## Touch Bar

应用启动后会以系统模态方式显示 Touch Bar 额度条。切换到 Codex 输入框或其他窗口时，额度条仍会保留。

Touch Bar 内容包括：

- Codex 官方图标。
- `5 小时` 额度分段电量条；窗口不存在时改为显示可用重置次数和最早到期日期、时间。
- `周限额` 分段电量条。
- 剩余百分比。
- 重置时间。
- 本地 token 消耗统计：`昨日` 和 `累计`。
- `🎙 语音` / `■ 输入`：使用 macOS 语音识别实时转写中文，停止后直接键入当前 Codex 文本框。

首次使用语音输入时，macOS 会请求麦克风和语音识别权限。直接输入还需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许 CodexBar。

注意：持久显示使用 macOS 未公开的 AppKit 系统模态 Touch Bar 接口，并在运行时检查系统是否支持。它适合个人安装，不适合提交 Mac App Store；未来 macOS 更新可能改变该接口。

## 菜单栏菜单

点击菜单栏图标可以打开原生 macOS 菜单：

- `显示 Touch Bar` / `隐藏 Touch Bar`
- `重新加载 Touch Bar`：界面被系统关闭或显示异常时，强制重新创建 Touch Bar。
- `刷新额度`
- `退出`

## 安装和运行

### 方式一：构建 app

```bash
scripts/build-app.sh
```

构建成功后会生成：

```text
build/CodexBar.app
```

双击这个 app，或运行：

```bash
open build/CodexBar.app
```

首次手动打开后，应用会安装用户级 LaunchAgent。以后 Codex / ChatGPT 启动时它会自动启动，Codex / ChatGPT 完全退出时它会自动退出。通过菜单手动退出后，本轮 Codex 会话中不会被重新拉起；下次重启 Codex 时恢复自动联动。

### 方式二：打包 DMG

```bash
scripts/package-dmg.sh
```

打包成功后会生成：

```text
dist/CodexBar-0.1.12.dmg
```

分享给其他人时，推荐上传这个 DMG 到 GitHub Releases。当前项目没有 Apple Developer 签名和公证，首次打开时 macOS 可能提示无法验证开发者；用户可以在 Finder 中右键点击 app，选择“打开”，再确认一次。

### 方式三：开发期直接运行

```bash
swift run
```

## 要求

见上方“兼容性”章节。

## 构建说明

项目使用 Swift / AppKit 实现。

常规构建走 SwiftPM：

```bash
swift build -c release
```

如果本机 Command Line Tools 的 SwiftPM SDK 探测失败，`scripts/build-app.sh` 会 fallback 到 `swiftc -sdk` 直接编译。

### 重新生成 App 图标

项目图标源图在 `Resources/AppIcon.png`，macOS 图标文件在 `Resources/AppIcon.icns`。

```bash
scripts/make-app-icon.py
```

脚本会为 Finder 列表视图常用的小尺寸层生成专门的简化图标，并用标准 ICNS 写入器输出，避免小图标被直接缩小或被系统读成杂色噪点。

## 更新记录

### 0.1.12 - 2026-08-10

- 改用系统模态 Touch Bar，Codex 输入框获得焦点后仍保持显示。
- 移除桌面 HUD，只保留菜单栏额度提示和 Touch Bar。
- 恢复 LaunchAgent，与 Codex / ChatGPT 同启同退。
- 语音识别失败时短暂显示原因，随后自动返回额度主界面。
- 移除 Touch Bar 内容易误触并退出整个程序的 `×` 按钮。
- 放大额度文字和电量条，并将语音按钮改为 Siri 风格的彩色圆形波形图标。
- 菜单栏新增“重新加载 Touch Bar”，可在界面被系统关闭后快速恢复。
- 精简 Touch Bar 行末 token 用量文字为“昨 / 总”，避免挤占右侧语音按钮空间。

### 0.1.11 - 2026-08-10

- Touch Bar 新增中文语音输入、实时转写预览与直接输入功能。
- 使用 Apple Speech 与 AVFoundation，本地应用无需 OpenAI API Key。
- 识别文字通过 Unicode 键盘事件直接输入当前 Codex 文本框，不使用剪贴板。

### 0.1.10 - 2026-08-01

- HUD 背景透明度与文字透明度拆分为两个独立设置。
- `背景透明度` 只控制胶囊底色；`文字透明度` 同时控制额度文字、状态点、刷新和退出图标。
- 菜单栏和 HUD 右键菜单同步两组选中状态，并自动迁移旧版统一透明度设置。

### 0.1.9 - 2026-07-31

- 桌面 HUD 新增原生右键菜单，可直接隐藏浮窗、刷新额度、修改颜色和透明度或退出。
- HUD 右键菜单与菜单栏共用同一份外观状态，颜色和透明度勾选会保持同步。
- 右键隐藏 HUD 后，可从菜单栏的 `显示浮窗` 恢复。

### 0.1.8 - 2026-07-30

- HUD 胶囊背景、额度文字、状态点、刷新和退出按钮改为使用统一透明度。
- 修复低透明度下背景已经变淡、前景内容仍保持完全不透明而显得不协调的问题。

### 0.1.7 - 2026-07-29

- HUD 透明度最低支持从 `45%` 放宽到 `10%`。
- 透明度菜单新增 `10% / 20% / 30% / 40% / 50%` 连续档位，并保留原有 `60% / 75% / 86% / 100%`。
- 透明度只影响 HUD 胶囊背景，额度文字、状态点、刷新和退出按钮保持清晰。

### 0.1.6 - 2026-07-18

- 适配只返回周额度的新账号结构，不再把同一份周额度重复显示成 `5h`。
- 没有 5 小时窗口时，HUD、菜单栏和 Touch Bar 动态显示可用完整重置次数。
- 没有可用重置次数时只显示周额度，并自动收窄 HUD。
- 修复 Codex 合并到 ChatGPT 后 Touch Bar 左侧官方图标不显示的问题，优先使用白底 Codex 官方图标。
- Touch Bar 的到期/重置文字、`|` 分隔线和昨日/累计用量改为固定列，上下两行保持对齐。
- HUD 小幅加宽，避免 `5h 100%` 与 `7d 100%` 同时显示时百分号被遮挡。

### 0.1.5 - 2026-07-10

- 兼容 Codex 合并到 ChatGPT 后的新应用名称和安装路径。
- 自动启动器现在可识别 `ChatGPT`、`Codex` 和 `GPT` 进程。
- app-server 会自动从 ChatGPT 合并版或旧版 Codex 中选择可用的本机 `codex`。
- 应用内生命周期监听同步兼容新旧宿主，继续保持宿主启动时拉起、退出时关闭。

### 0.1.4 - 2026-06-16

- README 增加 Intel Mac、Apple Silicon Mac、无 Touch Bar Mac 的兼容性说明。
- Touch Bar 增加本地 token 消耗统计，显示 `昨日` 和 `累计` 用量。
- 重置时间统一显示为 `MM月dd日 HH:mm 重置`，让 5 小时额度和周额度两行更容易对齐阅读。
- 本地 token 统计改为后台读取，避免刷新时桌面 HUD 和菜单栏短暂卡住。
- 更新 README 宣传图，并新增一张更清晰的 Touch Bar 细节图。

### 0.1.3 - 2026-06-13

- 新增 LaunchAgent 启动器，首次运行后可在 Codex 启动时自动打开额度条。
- 新增 `scripts/package-dmg.sh`，可生成用于分享安装的 DMG。
- README 加入第一版项目宣传图。

### 0.1.2 - 2026-06-11

- 修正 Finder 详情列表小图标模式下图标显示成彩色噪点的问题。
- 调整 `scripts/make-app-icon.py`，改用 Pillow 的标准 ICNS 写入器生成兼容的小尺寸图层。

### 0.1.1 - 2026-06-11

- 修正 Finder 列表等小尺寸场景下 App 图标显示不清楚的问题。
- 新增 `scripts/make-app-icon.py`，用于重新生成带专门小尺寸图层的 `AppIcon.icns`。

### 0.1.0 - 2026-06-10

- 首次开源发布 Swift/AppKit 菜单栏、桌面 HUD 和 Touch Bar 应用。
- 通过本机 Codex app-server 读取 5 小时额度和周额度，不抓网页、不需要 API Key。
- 菜单栏、HUD 和 Touch Bar 使用同一份额度状态，并支持刷新失败时保留旧数据。

## 隐私

CodexBar 不保存密码、API Key、授权码或账号凭据。额度数据来自本机 Codex app-server，并只显示在本机 UI 中。

## 许可证

MIT License
