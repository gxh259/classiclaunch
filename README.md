# 启动台（ClassicLaunchpad）

**简体中文** · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

用 Swift 和 AppKit 编写的 macOS 启动台。它提供全屏应用网格、搜索、文件夹、翻页和多种唤出方式，供希望继续使用经典启动台布局的用户使用。当前版本为 **0.43**，构建产物为同时包含 **Apple 芯片（arm64）与 Intel（x86_64）** 的通用应用。推荐下载 DMG，将其中的启动台拖入 Applications 安装，也可双击应用自动安装或更新。最低部署目标为 macOS 15.0。各系统的实际运行情况见下文。

## 兼容性反馈

| 设备与系统 | 已知情况 |
| --- | --- |
| Apple M1 / macOS 27.0 | v0.40 已在本机运行验证。 |
| Apple M4 / macOS 15.3 | 用户反馈可运行；具体应用版本待确认。 |
| Apple M4 / macOS 26.5 | 用户反馈 v0.34 可运行；替换成 v0.40 后，访达提示“应用程序‘启动台’无法打开”。原因调查中，v0.41–v0.43 尚未在这台电脑验证。 |
| Intel | x86_64 自测已通过 Rosetta；尚未在 Intel 实机上运行验证。 |

如果 v0.40 无法打开，可先改用[已知可在 M4 / macOS 26.5 运行的 v0.34](https://github.com/gxh259/classiclaunch/releases/tag/v0.34)。排查时请保留个人应用数据，并在故障电脑的终端运行下面两条命令，记录完整输出；第一条用于检查安装包签名，第二条可显示程序启动时的具体错误：

```bash
codesign --verify --deep --strict --verbose=2 /Applications/启动台.app
/Applications/启动台.app/Contents/MacOS/ClassicLaunchpad
```

v0.40 的独立“安装启动台.app”会在自身旁边查找“启动台.app”。macOS 可能把从下载的 DMG 打开的应用隔离到随机路径（[Apple 的 App Translocation 说明](https://developer.apple.com/documentation/fileprovider/nsfileprovidererror/code/providertranslocated)），使安装器找不到同级应用并提示“应用不完整”。这条提示不代表旧版已经被替换。v0.41 已将安装逻辑合并到同一个应用，不再依赖同级路径；DMG 里的应用图标和 Applications 快捷方式也分居箭头两侧。v0.41 尚未在反馈故障的 M4 / macOS 26.5 上验证。

终端显示 `operation not permitted` 说明系统拒绝执行，单凭这一行无法区分隔离标记、签名策略或其他安全软件。可在故障电脑上继续检查 `xattr -p com.apple.quarantine /Applications/启动台.app` 和 `spctl --assess --type execute -vv /Applications/启动台.app` 的输出。若已确认来源可信，安装后的隔离标记处理方式见下文“首次打开与签名”。

## 功能

- 全屏网格与应用搜索；图标、名称字号和行距随屏幕可用空间调整，内屏保持紧凑布局，扩展屏增大图标并缩短行间空白。搜索框与设置、刷新按钮在切换显示器时重新定位；支持拖拽排序、创建和重命名文件夹、隐藏应用及自定义应用名称。
- 可选 5×7、6×8、7×8、7×9 网格布局，也可在设置中自定义 2–12 行、3–16 列；旧版保存的 7×7 会作为自定义布局保留。鼠标左键左右拖动、触控板三指横向轻扫、滚轮、方向键或固定在页面底部的圆点均可切换页面。
- 从 `/Applications` 扫描应用，优先使用与系统语言匹配的应用名称。访达“实用工具”中的应用会归入「其他」文件夹。可手动重新扫描，并可选用 Dock 启动台数据库补充系统应用。
- 通过 Dock、菜单栏、可录制的全局快捷键或触发角打开。
- 设置窗口提供明亮、黑暗、跟随系统三种主题，以及开机自启动、显示或隐藏菜单栏图标等选项。界面语言可选跟随系统、简体中文、繁體中文或 English。
- 点击网格外背景或按 Escape 关闭启动台。右键菜单可打开、重命名、隐藏或在访达中显示应用；有权限的第三方应用还可移到废纸篓。
- 明亮主题使用透明窗口和系统毛玻璃显示下方桌面，兼容动态壁纸；黑暗主题在窗口内模糊桌面壁纸。背景与图标的翻页动画分层，并随显示器尺寸变化调整窗口。
- 设置中提供“完全卸载启动台…”，可移除应用、Dock 图标、开机自启动和本地设置。
- 应用包使用彩色九宫格图标；重新生成访达所读取的 `.icns`，修复“应用程序”列表可能显示的异常小图标。

## 构建

需要 macOS、Apple 命令行开发工具（`xcode-select --install`）、Swift 编译器和 Python 3.10 或更高版本。仓库根目录运行：

```bash
chmod +x build.sh
./build.sh
```

脚本分别编译 arm64 和 x86_64，再合并成通用应用，在 `dist/` 中生成 `启动台.app` 和指向当前版本安装包的 DMG、ZIP 快捷路径。完整安装包保存在项目根目录的 `releases/`，每次成功构建后只保留最新两个版本的 DMG 和 ZIP。首次构建会在 `.build/dmg-tools` 创建 Python 虚拟环境并安装 [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) 及固定版本的打包依赖，需要联网；后续可复用。若 `python3` 版本较旧，可用 `PYTHON_BIN=/path/to/python3 ./build.sh` 指定解释器。DMG 使用自定义背景、固定图标位置和 Applications 快捷方式。脚本使用本机 macOS SDK 编译，并对应用执行临时签名。这个构建没有经过 Apple 公证。

## 安装与使用

### 自动安装与更新

从 [GitHub Releases](https://github.com/gxh259/classiclaunch/releases) 下载通用版 **DMG**，双击挂载后，再双击其中唯一的 **「启动台.app」**。如果尚未安装，应用会自动复制到 `/Applications/启动台.app` 并打开；如果已有旧版，应用会提示更新，确认后先退出旧版、替换应用并打开新版。图标排序、文件夹和设置会保留。完成后从访达侧边栏推出磁盘映像。DMG 下方仍保留“隐私与安全性 → 仍要打开”的操作示意图。

也可以将「启动台.app」拖到右侧 Applications 文件夹，再从“应用程序”首次打开；首次打开时如已位于该目录，就直接运行。**访达拖拽仅执行复制，无法在复制前运行应用内的安装逻辑。** 如果双击 DMG 中的新版只唤醒正在运行的旧版，请先退出旧版，再双击新版并按提示更新。手动拖拽更新也须先退出旧版。备用 ZIP 解压后也只有「启动台.app」，操作相同。若没有写入 `/Applications` 的权限，应用会保留旧版并提示错误。

### Homebrew 安装

仓库的 [`Casks/classiclaunch.rb`](Casks/classiclaunch.rb) 提供 Homebrew Cask。由于仓库名是 `classiclaunch`，需要在 `brew tap` 中指定仓库地址：

```bash
brew tap gxh259/classiclaunch https://github.com/gxh259/classiclaunch.git
brew install --cask gxh259/classiclaunch/classiclaunch
```

后续可运行 `brew upgrade --cask gxh259/classiclaunch/classiclaunch` 更新，或运行 `brew uninstall --cask gxh259/classiclaunch/classiclaunch` 卸载应用。卸载时 Homebrew 默认保留用户设置；如需连本地设置一并删除，可在卸载时添加 `--zap`。

### 首次打开与签名

本应用使用临时签名，尚未经过 Apple 公证。确认安装包来源可信且未被篡改后，如果 macOS 阻止打开，请先尝试打开一次应用，再进入 **“系统设置 > 隐私与安全性”**，向下滚动并点击 **“仍要打开”**，按系统提示确认。详见 [Apple 官方操作说明](https://support.apple.com/zh-cn/102445)。DMG 中保留了该流程的示意图，图中按钮仅供示意，需要在系统设置中操作。

确认下载来源可信后，如仍被隔离标记阻止，可在终端运行：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/启动台.app
```

这条命令仅清除隔离标记，**不会验证签名或完成 Apple 公证**。如需检查应用包的签名完整性，可另行运行 `codesign --verify --deep --strict /Applications/启动台.app`；临时签名不代表 Apple 开发者身份认证。

默认全局快捷键为 **Control–Option–L**，可在设置中更改。搜索框旁的齿轮打开设置；其中的“重新扫描应用”会清空当前加载的应用列表，并重新读取应用目录。也可按 **Command–R** 重新扫描。

设置中的“菜单栏图标”可以即时显示或隐藏状态栏的启动台图标，选择会保存到应用数据中。隐藏后仍可通过 Dock 或全局快捷键打开启动台并重新显示图标。

设置中的“语言”默认跟随 macOS 首选语言；可手动选简体中文、繁體中文或 English，切换后界面立即更新并记住选择。应用网格中的第三方应用名称仍按 macOS／访达语言显示，用户自定义名称也会保留。

### 透明毛玻璃主题

在设置中选择 **明亮**，启动台将使用透明背景和系统毛玻璃呈现桌面壁纸；选择 **跟随系统** 时，系统处于明亮外观也会使用该效果。设置窗口仍保持白色底色，文件夹内容保持独立面板。应用名称使用文字阴影提高在壁纸上的可读性。

毛玻璃由 AppKit 的 [fullScreenUI 材质](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum/fullscreenui)和 [behindWindow 混合模式](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow)绘制，显示的是窗口下方内容：若下方有其他应用窗口，也会透出这些窗口。macOS 开启“减少透明度”时，系统可能使用实色替代毛玻璃。新版透明效果尚未在 ToDesk 远程会话中实测。

### 拖动与手势翻页

按住鼠标左键，在空白处左右拖动即可翻页；向左拖动前往下一页，向右拖动返回上一页。图标上快速横向拖动也可翻页；需要排序时，按住图标约 0.35 秒再拖动，或直接纵向拖动图标。每次拖动只切换一页，松开后不会误打开应用或关闭启动台。单击空白处仍会关闭启动台；文件夹内也支持翻页。

鼠标指针位于应用网格上时，可使用触控板三指横向轻扫。程序处理三指触摸事件和 AppKit 的原生 swipe 事件。macOS 的系统手势可能优先接收三指操作；若三指轻扫切换了桌面，请在“系统设置 > 触控板”的手势选项中调整冲突项。手势分发机制参见 [Apple 的触控板事件文档](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html)。

布局、文件夹、隐藏状态、应用别名和偏好存放在：

```text
~/Library/Application Support/ClassicLaunchpad/Data.store
```

更新应用时无需删除这个文件。若要重置所有个人配置，请先退出启动台，再备份或移走该文件。

## 完全卸载

仅在访达中将 `启动台.app` 移到废纸篓，不会自动删除 `~/Library/Application Support/ClassicLaunchpad` 中的用户数据。这是 macOS 对普通应用的卸载方式；若在升级时暂时移走旧版应用，也能保留现有布局。

如果想连设置一起删除，请先打开已安装的启动台，点击搜索框旁的齿轮，在设置底部选择 **“完全卸载启动台…”** 并确认。应用会移除登录项，将自身移到废纸篓，删除本地数据，并从 Dock 的固定及最近使用列表中移除启动台图标。若 Dock 有对应图标，Dock 会重新启动以刷新显示；其他图标和顺序会保留。

安装包不再包含旧版残留清理脚本。如果旧版应用已经从“应用程序”移走，可先重新安装，再从设置中使用“完全卸载启动台…”；仓库仍保留独立的 [`清理旧版残留.command`](清理旧版残留.command) 供需要时手动使用。若“系统设置 > 通用 > 登录项”还显示旧条目，请在系统设置中移除。

## 实现说明

应用扫描以 `/Applications` 为主，并包含系统“实用工具”目录。应用包的本地化名称会优先于 bundle 内的英文名称；用户设置的别名优先级最高。Dock 启动台数据库为可选的只读补充来源，数据库不存在或结构不兼容时会跳过。程序不修改系统文件。

源代码位于 `Sources/`，应用的 `Info.plist`、本地化资源和原始 PNG 图标位于 `Resources/`。构建脚本会由 PNG 生成应用包的 `.icns`；图标包含清晰的大尺寸图像，让访达按需要缩放到列表尺寸。语言、图标排序、分页和 Dock 图标清理的命令行自测入口包含在主程序中，可用 `dist/启动台.app/Contents/MacOS/ClassicLaunchpad --self-test-language`、`--self-test-indicator`、`--self-test-scroll`、`--self-test-gestures` 和 `--self-test-dock-cleanup` 运行。
