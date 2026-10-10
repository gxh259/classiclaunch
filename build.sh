#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_DIR="$PWD/.build"
DIST_DIR="$PWD/dist"
APP_DIR="$DIST_DIR/启动台.app"
INSTALLER_DIR="$DIST_DIR/安装启动台.app"
PACKAGE_DIR="$DIST_DIR/启动台安装包"
ZIP_PATH="$DIST_DIR/启动台-通用版.zip"

mkdir -p "$BUILD_DIR" "$DIST_DIR"
./scripts/generate-icon.sh "$BUILD_DIR/AppIcon.icns"
mkdir -p "$BUILD_DIR/installer-icon-pngs"
swift -module-cache-path "$BUILD_DIR/cache-icon" \
  scripts/generate-installer-icon.swift Resources/AppIcon.png \
  "$BUILD_DIR/installer-icon-pngs/1024.png"
for size in 128 256 512; do
  sips -s format png -z "$size" "$size" "$BUILD_DIR/installer-icon-pngs/1024.png" \
    --out "$BUILD_DIR/installer-icon-pngs/$size.png" >/dev/null
done
swift -module-cache-path "$BUILD_DIR/cache-icon" \
  scripts/pack-icon.swift "$BUILD_DIR/installer-icon-pngs" "$BUILD_DIR/InstallerIcon.icns"

build_arch() {
  local arch="$1"
  mkdir -p "$BUILD_DIR/cache-$arch"
  swiftc \
    -sdk "$SDK_PATH" \
    -module-cache-path "$BUILD_DIR/cache-$arch" \
    -target "$arch-apple-macosx15.0" \
    -O \
    -framework AppKit \
    -framework Carbon \
    -framework ServiceManagement \
    -framework QuartzCore \
    Sources/LauncherStore.swift \
    Sources/Localization.swift \
    Sources/LoginStartup.swift \
    Sources/AppInstaller.swift \
    Sources/LauncherModel.swift \
    Sources/Hotkey.swift \
    Sources/PageGestures.swift \
    Sources/LaunchpadClassic.swift \
    -lsqlite3 \
    -o "$BUILD_DIR/ClassicLaunchpad-$arch"
}

build_arch arm64
build_arch x86_64

build_installer_arch() {
  local arch="$1"
  swiftc \
    -sdk "$SDK_PATH" \
    -module-cache-path "$BUILD_DIR/cache-$arch" \
    -target "$arch-apple-macosx15.0" \
    -O \
    -framework AppKit \
    Sources/AppInstaller.swift \
    Sources/InstallerApp.swift \
    -o "$BUILD_DIR/ClassicLaunchpadInstaller-$arch"
}

build_installer_arch arm64
build_installer_arch x86_64

rm -rf "$APP_DIR" "$INSTALLER_DIR" "$PACKAGE_DIR" "$ZIP_PATH" "$DIST_DIR/启动台.zip"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" \
  "$INSTALLER_DIR/Contents/MacOS" "$INSTALLER_DIR/Contents/Resources" "$PACKAGE_DIR"
lipo -create \
  "$BUILD_DIR/ClassicLaunchpad-arm64" \
  "$BUILD_DIR/ClassicLaunchpad-x86_64" \
  -output "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch arm64 "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch x86_64 "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" Resources/AppIcon.png "$APP_DIR/Contents/Resources/"
cp -R Resources/en.lproj Resources/zh-Hant.lproj "$APP_DIR/Contents/Resources/"
codesign --force --sign - "$APP_DIR"

lipo -create \
  "$BUILD_DIR/ClassicLaunchpadInstaller-arm64" \
  "$BUILD_DIR/ClassicLaunchpadInstaller-x86_64" \
  -output "$INSTALLER_DIR/Contents/MacOS/ClassicLaunchpadInstaller"
lipo -verify_arch arm64 "$INSTALLER_DIR/Contents/MacOS/ClassicLaunchpadInstaller"
lipo -verify_arch x86_64 "$INSTALLER_DIR/Contents/MacOS/ClassicLaunchpadInstaller"
cp Resources/InstallerInfo.plist "$INSTALLER_DIR/Contents/Info.plist"
cp "$BUILD_DIR/InstallerIcon.icns" "$INSTALLER_DIR/Contents/Resources/"
cp -R Resources/en.lproj Resources/zh-Hant.lproj "$INSTALLER_DIR/Contents/Resources/"
codesign --force --sign - "$INSTALLER_DIR"

cp -R "$APP_DIR" "$PACKAGE_DIR/启动台.app"
cp -R "$INSTALLER_DIR" "$PACKAGE_DIR/安装启动台.app"
ln -s /Applications "$PACKAGE_DIR/应用程序"
cp 清理旧版残留.command "$PACKAGE_DIR/清理旧版残留.command"
chmod +x "$PACKAGE_DIR/清理旧版残留.command"
cat > "$PACKAGE_DIR/安装说明.txt" <<'EOF'
启动台安装说明

推荐安装方式：
双击挂载 DMG，再双击左侧“安装启动台.app”。安装器会自动退出正在运行的旧版启动台，等待退出后替换“应用程序”中的应用，并保留图标排序和设置。
安装完成后可直接从安装器打开新版启动台。
如果手动将“启动台.app”拖入右侧 Applications 文件夹，访达的“替换”按钮不会自动退出旧版；更新时请使用安装器。
安装完成后可在访达侧边栏推出“启动台”磁盘映像。

ZIP 备用安装：
1. 解压后双击“安装启动台.app”，由安装器自动退出旧版并安装新版。
2. 或者先退出旧版，再将“启动台.app”拖入旁边的“应用程序”快捷方式。

Homebrew 安装：
brew tap gxh259/classiclaunch https://github.com/gxh259/classiclaunch.git
brew install --cask gxh259/classiclaunch/classiclaunch

本应用使用临时签名，尚未经过 Apple 公证。如果 macOS 阻止打开，确认安装包来源可信且未被篡改后，请先尝试打开一次应用，再到“系统设置 > 隐私与安全性”向下滚动，点击“仍要打开”，按系统提示确认。
DMG 中保留了该流程的操作示意图；图中的按钮仅供示意，需在系统设置中操作。
Apple 官方操作说明：https://support.apple.com/zh-cn/102445

确认安装包来源可信后，如仍被隔离标记阻止，可在终端运行：
sudo xattr -r -d com.apple.quarantine /Applications/启动台.app

这条 xattr 命令仅清除隔离标记，不会执行签名验证，也不能代替 Apple 公证。如需检查应用签名完整性，可运行：
codesign --verify --deep --strict /Applications/启动台.app
EOF
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$ZIP_PATH"

printf '已生成：%s（arm64 + x86_64）\n' "$ZIP_PATH"
bash ./scripts/build-dmg.sh
