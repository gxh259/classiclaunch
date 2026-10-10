# 启动台（ClassicLaunchpad）

**简体中文** · [繁體中文](README.zh-Hant.md) · [English](README.en.md)

用 Swift 和 AppKit 编写的 macOS 启动台。它提供全屏应用网格、搜索、文件夹、翻页和多种唤出方式，供希望继续使用经典启动台布局的用户使用。当前版本为 **0.38**，构建产物为同时包含 **Apple 芯片（arm64）与 Intel（x86_64）** 的通用应用。推荐下载 DMG，双击即可打开拖拽安装窗口。最低部署目标为 macOS 15.0；目前在 macOS 27.0 / Apple M1 上完成了原生运行验证，x86_64 自测已通过 Rosetta 验证，尚未在 Intel 实机上运行验证。

## 功能

- 全屏网格与应用搜索；图标名称紧贴图标，横向间距随屏幕大小自适应；支持拖拽排序、创建和重命名文件夹、隐藏应用及自定义应用名称。
- 可选 5×7、6×8、7×8、7×9 网格布局，也可在设置中自定义 2–12 行、3–16 列；旧版保存的 7×7 会作为自定义布局保留。鼠标左键左右拖动、触控板三指横向轻扫、滚轮、方向键或固定在页面底部的圆点均可切换页面。
- 从 `/Applications` 扫描应用，优先使用与系统语言匹配的应用名称。访达“实用工具”中的应用会归入「其他」文件夹。可手动重新扫描，并可选用 Dock 启动台数据库补充系统应用。
- 通过 Dock、菜单栏、可录制的全局快捷键或触发角打开。
- 设置窗口提供明亮、黑暗、跟随系统三种主题，以及开机自启动、显示或隐藏菜单栏图标等选项。界面语言可选跟随系统、简体中文、繁體中文或 English。
- 点击网格外背景或按 Escape 关闭启动台。右键菜单可打开、重命名、隐藏或在访达中显示应用；有权限的第三方应用还可移到废纸篓。
- 明亮主题使用透明窗口和系统毛玻璃显示下方桌面，兼容动态壁纸；黑暗主题在窗口内模糊桌面壁纸。背景与图标的翻页动画分层，并随显示器尺寸变化调整窗口。
- 设置中提供“完全卸载启动台…”，可移除应用、开机自启动和本地设置；安装包还包含旧版卸载后使用的残留清理工具。
- 应用包使用彩色九宫格图标；重新生成访达所读取的 `.icns`，修复“应用程序”列表可能显示的异常小图标。

## 构建

需要 macOS、Apple 命令行开发工具（`xcode-select --install`）、Swift 编译器和 Python 3.10 或更高版本。仓库根目录运行：

```bash
chmod +x build.sh
./build.sh
```

脚本分别编译 arm64 和 x86_64，然后合并成一个通用二进制，在 `dist/` 中生成 `启动台.app`、`启动台-通用版.dmg` 和备用的 `启动台-通用版.zip`。首次构建会在 `.build/dmg-tools` 创建 Python 虚拟环境并安装 [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) 及固定版本的打包依赖，需要联网；后续可复用。若 `python3` 版本较旧，可用 `PYTHON_BIN=/path/to/python3 ./build.sh` 指定解释器。DMG 使用自定义背景、固定图标位置和 Applications 快捷方式。脚本使用本机 macOS SDK 编译，并对合并后的应用执行临时签名。这个构建没有经过 Apple 公证。

## 安装与使用

### 手动安装

从 [GitHub Releases](https://github.com/gxh259/classiclaunch/releases) 下载通用版 **DMG**。双击挂载后，窗口左侧显示“启动台”，右侧显示 **Applications** 文件夹，中间有拖拽箭头。将启动台拖入右侧文件夹，再从 `/Applications` 打开；安装完成后可在访达侧边栏推出“启动台”磁盘映像。窗口下方保留红色“安装后若提示无法打开”提示，以及“隐私与安全性 → 仍要打开”的操作示意图，并提供安装说明和旧版残留清理工具。

若已有旧版本，请先完全退出所有正在运行的“启动台”（可在“活动监视器”中确认），再拖动新版并等待复制完成；复制期间不要启动应用。若替换时出现“无法打开”，请确认复制完成、退出残留的旧进程，然后从 `/Applications/启动台.app` 打开。开机自启动需要应用位于 `/Applications`。也提供备用 ZIP：解压后，将“启动台.app”拖到同一文件夹内的“应用程序”快捷方式即可。

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

如果想连设置一起删除，请先打开已安装的启动台，点击搜索框旁的齿轮，在设置底部选择 **“完全卸载启动台…”** 并确认。应用会移除登录项，将自身移到废纸篓，再删除应用数据、偏好、缓存和窗口状态。

如果旧版应用已经从“应用程序”移走，可双击挂载新版 DMG（或解压备用 ZIP），双击其中的 **`清理旧版残留.command`**，按提示确认清理。这个工具只删除启动台自己的用户数据；若“系统设置 > 通用 > 登录项”还显示旧条目，请在系统设置中移除。重新安装或升级时，直接替换应用即可，无需运行清理工具。

## 实现说明

应用扫描以 `/Applications` 为主，并包含系统“实用工具”目录。应用包的本地化名称会优先于 bundle 内的英文名称；用户设置的别名优先级最高。Dock 启动台数据库为可选的只读补充来源，数据库不存在或结构不兼容时会跳过。程序不修改系统文件。

源代码位于 `Sources/`，应用的 `Info.plist`、本地化资源和原始 PNG 图标位于 `Resources/`。构建脚本会由 PNG 生成应用包的 `.icns`；图标包含清晰的大尺寸图像，让访达按需要缩放到列表尺寸。语言、图标排序与分页相关的命令行自测入口包含在主程序中，可用 `dist/启动台.app/Contents/MacOS/ClassicLaunchpad --self-test-language`、`--self-test-indicator`、`--self-test-scroll` 和 `--self-test-gestures` 运行。
