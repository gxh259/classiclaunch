#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
BUILD_DIR="$PWD/.build"
DIST_DIR="$PWD/dist"
APP_DIR="$DIST_DIR/启动台.app"
PACKAGE_DIR="$DIST_DIR/启动台安装包"

mkdir -p "$BUILD_DIR/cache" "$DIST_DIR"

swiftc \
  -sdk "$SDK_PATH" \
  -module-cache-path "$BUILD_DIR/cache" \
  -target "$ARCH-apple-macosx15.0" \
  -O \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  -framework QuartzCore \
  Sources/LauncherStore.swift \
  Sources/LoginStartup.swift \
  Sources/LauncherModel.swift \
  Sources/Hotkey.swift \
  Sources/LaunchpadClassic.swift \
  -lsqlite3 \
  -o "$BUILD_DIR/ClassicLaunchpad"

rm -rf "$APP_DIR" "$PACKAGE_DIR" "$DIST_DIR/启动台.zip"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PACKAGE_DIR"
cp "$BUILD_DIR/ClassicLaunchpad" "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/AppIcon.png "$APP_DIR/Contents/Resources/"
codesign --force --sign - "$APP_DIR"

cp -R "$APP_DIR" "$PACKAGE_DIR/启动台.app"
ln -s /Applications "$PACKAGE_DIR/应用程序"
printf '%s\n' '将“启动台.app”拖入“应用程序”，然后从“应用程序”打开。' > "$PACKAGE_DIR/安装说明.txt"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$DIST_DIR/启动台.zip"

printf '已生成：%s\n' "$DIST_DIR/启动台.zip"
