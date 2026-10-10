# Launchpad (ClassicLaunchpad)

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · **English**

A macOS application launcher built with Swift and AppKit. It offers a full-screen app grid, search, folders, pagination, and several ways to open the launcher for people who prefer the classic Launchpad layout. The current version is **0.41**, distributed as a **universal app for Apple silicon (arm64) and Intel (x86_64)**. Double-clicking Launchpad in the recommended DMG starts installation or an update. The minimum deployment target is macOS 15.0. See the compatibility reports below for observed results.

## Compatibility reports

| Device and system | Known result |
| --- | --- |
| Apple M1 / macOS 27.0 | v0.40 has been run locally. |
| Apple M4 / macOS 15.3 | A user reports that the app runs; the exact app version is unconfirmed. |
| Apple M4 / macOS 26.5 | A user reports that v0.34 runs, but Finder says it cannot open v0.40 after replacement. The cause is under investigation; v0.41 has not yet been verified on this Mac. |
| Intel | x86_64 self-tests have passed through Rosetta; execution on a physical Intel Mac has not yet been verified. |

If v0.40 will not open, you can temporarily use [v0.34, reported to run on M4 / macOS 26.5](https://github.com/gxh259/classiclaunch/releases/tag/v0.34). Preserve your personal app data while troubleshooting. On the affected Mac, run these two Terminal commands and save their complete output; the first checks the installed app's signature, and the second may show the specific launch error:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/启动台.app
/Applications/启动台.app/Contents/MacOS/ClassicLaunchpad
```

The separate `安装启动台.app` in v0.40 looks for `启动台.app` beside itself. macOS may move an app launched from a downloaded DMG to a randomized location ([Apple's App Translocation documentation](https://developer.apple.com/documentation/fileprovider/nsfileprovidererror/code/providertranslocated)), so the installer can fail to find its sibling and report an incomplete app. That message does not mean the older version was replaced. v0.41 puts installation inside the same app and no longer depends on a sibling path; its DMG places the app and Applications shortcut on opposite sides of the arrow. v0.41 has not yet been verified on the affected M4 / macOS 26.5 Mac.

The Terminal message `operation not permitted` means execution was denied, but that line alone cannot distinguish quarantine, signature policy, or other security software. On the affected Mac, check the output of `xattr -p com.apple.quarantine /Applications/启动台.app` and `spctl --assess --type execute -vv /Applications/启动台.app`. If you trust the source, see **First launch and signing** below for handling quarantine after installation.

The files in the installation package retain their Simplified Chinese names, including `启动台.app`. The commands and paths below use the actual filenames and can be copied as written.

## Features

- Full-screen app grid and search. Icon size, label size, and row spacing adapt to the available screen area, keeping the built-in display compact and enlarging icons on external displays. The search field and its Settings and Rescan buttons are repositioned together when the display changes. Also supports drag-to-reorder, folder creation and renaming, hidden apps, and custom app names.
- Choose a 5×7, 6×8, 7×8, or 7×9 grid, or enter a custom layout of 2–12 rows and 3–16 columns in Settings. Existing saved 7×7 layouts remain available as custom layouts. Switch pages by dragging horizontally with the left mouse button, swiping horizontally with three fingers on a trackpad, using the scroll wheel or arrow keys, or clicking the fixed page dots at the bottom.
- Scan apps from `/Applications`, preferring names that match the system language. Apps in Finder's Utilities folder are grouped into an **Other** folder. Rescan manually or optionally supplement system apps using the Dock Launchpad database.
- Open from the Dock, menu bar, a recordable global keyboard shortcut, or a hot corner.
- Settings provide Light, Dark, and Follow System themes, Launch at Login, and the option to show or hide the menu bar icon. The interface can follow the system language or use Simplified Chinese, Traditional Chinese, or English.
- Click the background outside the grid or press Escape to close the launcher. Context menus let you open, rename, hide, or reveal apps in Finder. Third-party apps can also be moved to the Trash when permissions allow.
- The Light theme uses a transparent window with system frosted glass to show the desktop underneath, including dynamic wallpapers. The Dark theme blurs the desktop wallpaper inside the window. The background is separate from the icon page animation, and the window adapts to display size changes.
- **Completely Uninstall Launchpad…** removes the app, login item, and local settings.
- A colorful nine-square app icon, with regenerated `.icns` resources to fix malformed small icons that may appear in Finder's Applications list.

## Build

Requires macOS, Apple's command line developer tools (`xcode-select --install`), the Swift compiler, and Python 3.10 or later. Run these commands from the repository root:

```bash
chmod +x build.sh
./build.sh
```

The script compiles arm64 and x86_64 separately, merges them into a universal app, and generates `启动台.app`, `启动台-通用版.dmg`, and a fallback `启动台-通用版.zip` in `dist/`. On the first build, it creates a Python virtual environment in `.build/dmg-tools` and installs [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) and pinned packaging dependencies. This requires network access; later builds can reuse the environment. If your default `python3` is too old, select an interpreter with `PYTHON_BIN=/path/to/python3 ./build.sh`. The DMG includes a custom background, fixed icon positions, and an Applications shortcut. The script builds against the local macOS SDK and applies an ad hoc signature to the app. The build is not notarized by Apple.

## Installation and Usage

### Automatic installation and updates

Download the universal **DMG** from [GitHub Releases](https://github.com/gxh259/classiclaunch/releases), mount it, and double-click its single **`启动台.app`**. If Launchpad is not installed, the app copies itself to `/Applications/启动台.app` and opens the installed version automatically. If an older version exists, it prompts for an update, quits the old version after confirmation, replaces the app, and opens the new version. Your icon layout, folders, and settings are kept. Eject the disk image afterward. The lower part of the DMG window retains the Privacy & Security → Open Anyway illustration.

You can also drag `启动台.app` to Applications and then open it there. If it is already in Applications on first launch, it runs normally. **Finder drag and Replace only copy files; they cannot execute installation code before copying.** If double-clicking the new app in the DMG only activates a running old version, quit the old version, then double-click the new one and follow the update prompt. Also quit the old version before updating by dragging. The fallback ZIP likewise contains only `启动台.app`. If the app cannot write to `/Applications`, it keeps the old version and reports the error.

### Homebrew installation

[`Casks/classiclaunch.rb`](Casks/classiclaunch.rb) provides a Homebrew Cask. Because the repository is named `classiclaunch`, specify its URL when adding the tap:

```bash
brew tap gxh259/classiclaunch https://github.com/gxh259/classiclaunch.git
brew install --cask gxh259/classiclaunch/classiclaunch
```

Use `brew upgrade --cask gxh259/classiclaunch/classiclaunch` to update, or `brew uninstall --cask gxh259/classiclaunch/classiclaunch` to uninstall. Homebrew keeps user settings by default. Add `--zap` when uninstalling to remove local settings as well.

### First launch and signing

The app uses an ad hoc signature and is not notarized by Apple. After confirming that the download source is trustworthy and the app has not been tampered with, if macOS blocks it, try opening the app once, then go to **System Settings > Privacy & Security**, scroll down, click **Open Anyway**, and follow the confirmation prompts. See [Apple’s official instructions](https://support.apple.com/en-us/102445). The DMG retains an illustration of this process; its button is illustrative, so perform the action in System Settings.

If the quarantine flag still blocks the app after you have confirmed that you trust its source, run this command in Terminal:

```bash
sudo xattr -r -d com.apple.quarantine /Applications/启动台.app
```

This command only removes the quarantine flag. **It does not verify the signature or notarize the app.** To check the app bundle's signature integrity, run `codesign --verify --deep --strict /Applications/启动台.app`. An ad hoc signature does not authenticate an Apple developer identity.

The default global shortcut is **Control–Option–L**, which you can change in Settings. The gear beside the search field opens Settings. **Rescan Apps** clears the currently loaded app list and reads the app directories again. You can also press **Command–R** to rescan.

The **Menu Bar Icon** setting immediately shows or hides the launcher icon and saves your choice. When hidden, you can still open the launcher from the Dock or with the global shortcut to show the icon again.

**Language** follows the macOS preferred language by default. You can select Simplified Chinese, Traditional Chinese, or English manually; the interface updates immediately and remembers your choice. Third-party app names in the grid continue to follow the macOS/Finder language, and custom app names are preserved.

### Transparent frosted glass theme

Select **Light** in Settings to use a transparent background with system frosted glass. **Follow System** uses the same effect when macOS is in light appearance. The settings window retains a white background, and folders keep their own panels. App names have text shadows to improve readability over wallpaper.

The effect uses AppKit's [fullScreenUI material](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material-swift.enum/fullscreenui) and [behindWindow blending mode](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum/behindwindow). It displays content underneath the window, so other app windows underneath may also show through. When macOS **Reduce Transparency** is enabled, the system may replace the glass effect with a solid color. The new transparent effect has not yet been tested in a ToDesk remote session.

### Dragging and page gestures

Hold the left mouse button and drag horizontally on an empty area to switch pages. Drag left for the next page and right for the previous page. A quick horizontal drag on an icon also switches pages. To reorder an icon, hold it for about 0.35 seconds before dragging, or drag it vertically. Each drag switches at most one page; releasing the mouse does not accidentally open an app or close the launcher. Clicking an empty area still closes the launcher. Pagination also works inside folders.

With the pointer over the app grid, you can swipe horizontally with three fingers on a trackpad. The app handles three-finger touch events and AppKit's native swipe events. macOS may handle three-finger gestures first. If the gesture switches desktops instead, adjust conflicting gestures in **System Settings > Trackpad**. See [Apple's trackpad event documentation](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html) for event handling details.

Layouts, folders, hidden apps, app aliases, and preferences are stored at:

```text
~/Library/Application Support/ClassicLaunchpad/Data.store
```

You do not need to delete this file when updating the app. To reset all personal settings, quit Launchpad first, then back up or move this file.

## Complete Uninstallation

Moving `启动台.app` to the Trash in Finder does not automatically delete user data in `~/Library/Application Support/ClassicLaunchpad`. This is how macOS normally removes apps, and it also preserves your layout if you temporarily move the old app during an upgrade.

To remove settings as well, open the installed app, click the gear beside the search field, and select **Completely Uninstall Launchpad…** at the bottom of Settings. After confirmation, the app removes the login item, moves itself to the Trash, and deletes its app data, preferences, caches, and saved window state.

The installation packages no longer include the leftover cleanup script. If an older app has already been removed from Applications, you can reinstall it and then use **Completely Uninstall Launchpad…** in Settings. The repository still provides a separate [`清理旧版残留.command`](清理旧版残留.command) for manual use if needed. If an old entry remains in **System Settings > General > Login Items**, remove it in System Settings.

## Implementation Notes

App scanning primarily uses `/Applications` and also includes the system Utilities directories. Localized app bundle names take priority over English names inside bundles; user-defined aliases have the highest priority. The Dock Launchpad database is an optional, read-only supplemental source. If the database is missing or its structure is incompatible, it is skipped. The app does not modify system files.

Source code is in `Sources/`. The app's `Info.plist`, localization resources, and original PNG icon are in `Resources/`. The build script generates `.icns` resources from the PNG, including clear large images that Finder can scale to list sizes. The main executable includes command line self-tests for language, icon ordering, and pagination. Run them with `dist/启动台.app/Contents/MacOS/ClassicLaunchpad --self-test-language`, `--self-test-indicator`, `--self-test-scroll`, or `--self-test-gestures`.
