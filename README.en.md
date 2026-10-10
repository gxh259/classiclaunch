# Launchpad (ClassicLaunchpad)

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · **English**

A macOS application launcher built with Swift and AppKit. It offers a full-screen app grid, search, folders, pagination, and several ways to open the launcher for people who prefer the classic Launchpad layout. The current version is **0.38**, distributed as a **universal app for Apple silicon (arm64) and Intel (x86_64)**. The recommended download is a DMG that opens a drag-to-install window. The minimum deployment target is macOS 15.0. Native execution has been verified on macOS 27.0 / Apple M1, and x86_64 self-tests have passed through Rosetta. Execution on a physical Intel Mac has not yet been verified.

The files in the installation package retain their Simplified Chinese names, including `启动台.app`. The commands and paths below use the actual filenames and can be copied as written.

## Features

- Full-screen app grid and search, with labels closer to icons and horizontal spacing that adapts to screen size; supports drag-to-reorder, folder creation and renaming, hidden apps, and custom app names.
- Choose a 5×7, 6×8, 7×8, or 7×9 grid, or enter a custom layout of 2–12 rows and 3–16 columns in Settings. Existing saved 7×7 layouts remain available as custom layouts. Switch pages by dragging horizontally with the left mouse button, swiping horizontally with three fingers on a trackpad, using the scroll wheel or arrow keys, or clicking the fixed page dots at the bottom.
- Scan apps from `/Applications`, preferring names that match the system language. Apps in Finder's Utilities folder are grouped into an **Other** folder. Rescan manually or optionally supplement system apps using the Dock Launchpad database.
- Open from the Dock, menu bar, a recordable global keyboard shortcut, or a hot corner.
- Settings provide Light, Dark, and Follow System themes, Launch at Login, and the option to show or hide the menu bar icon. The interface can follow the system language or use Simplified Chinese, Traditional Chinese, or English.
- Click the background outside the grid or press Escape to close the launcher. Context menus let you open, rename, hide, or reveal apps in Finder. Third-party apps can also be moved to the Trash when permissions allow.
- The Light theme uses a transparent window with system frosted glass to show the desktop underneath, including dynamic wallpapers. The Dark theme blurs the desktop wallpaper inside the window. The background is separate from the icon page animation, and the window adapts to display size changes.
- **Completely Uninstall Launchpad…** removes the app, login item, and local settings. The installation package also includes a tool to clean up data left by older versions.
- A colorful nine-square app icon, with regenerated `.icns` resources to fix malformed small icons that may appear in Finder's Applications list.

## Build

Requires macOS, Apple's command line developer tools (`xcode-select --install`), the Swift compiler, and Python 3.10 or later. Run these commands from the repository root:

```bash
chmod +x build.sh
./build.sh
```

The script compiles arm64 and x86_64 separately, merges them into a universal executable, and generates `启动台.app`, `启动台-通用版.dmg`, and a fallback `启动台-通用版.zip` in `dist/`. On the first build, it creates a Python virtual environment in `.build/dmg-tools` and installs [`dmgbuild`](https://github.com/dmgbuild/dmgbuild) and pinned packaging dependencies. This requires network access; later builds can reuse the environment. If your default `python3` is too old, select an interpreter with `PYTHON_BIN=/path/to/python3 ./build.sh`. The DMG includes a custom background, fixed icon positions, and an Applications shortcut. The script builds against the local macOS SDK and applies an ad hoc signature to the merged app. The build is not notarized by Apple.

## Installation and Usage

### Manual installation

Download the universal **DMG** from [GitHub Releases](https://github.com/gxh259/classiclaunch/releases). Double-click to mount it. The window shows Launchpad on the left, an **Applications** folder on the right, and an arrow between them. Drag Launchpad onto the folder, then open it from `/Applications`. After installation, eject the “启动台” disk image from Finder's sidebar. The lower part of the window retains a red warning for apps that cannot be opened and a Privacy & Security → Open Anyway illustration, followed by installation notes and the legacy cleanup tool. The illustration is in Simplified Chinese with English hints.

To upgrade, quit every running Launchpad instance first (check Activity Monitor), then replace the app and wait for copying to finish. Do not launch it during replacement. If macOS says it cannot open the app, confirm copying has finished, quit any old process, and open `/Applications/启动台.app`. Launch at Login requires the app to be installed in `/Applications`. A fallback ZIP is also available: extract it and drag `启动台.app` onto the shortcut named `应用程序` in the same folder.

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

If an older version has already been removed from Applications, double-click to mount the new DMG (or extract the fallback ZIP), then double-click **`清理旧版残留.command`**. Follow the prompts to confirm cleanup. The tool only deletes Launchpad's own user data. If an old entry remains in **System Settings > General > Login Items**, remove it in System Settings. To reinstall or upgrade, simply replace the app; you do not need to run the cleanup tool.

## Implementation Notes

App scanning primarily uses `/Applications` and also includes the system Utilities directories. Localized app bundle names take priority over English names inside bundles; user-defined aliases have the highest priority. The Dock Launchpad database is an optional, read-only supplemental source. If the database is missing or its structure is incompatible, it is skipped. The app does not modify system files.

Source code is in `Sources/`. The app's `Info.plist`, localization resources, and original PNG icon are in `Resources/`. The build script generates `.icns` resources from the PNG, including clear large images that Finder can scale to list sizes. The main executable includes command line self-tests for language, icon ordering, and pagination. Run them with `dist/启动台.app/Contents/MacOS/ClassicLaunchpad --self-test-language`, `--self-test-indicator`, `--self-test-scroll`, or `--self-test-gestures`.
