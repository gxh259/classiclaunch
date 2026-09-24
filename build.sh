#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_DIR="$PWD/.build"
DIST_DIR="$PWD/dist"
APP_DIR="$DIST_DIR/启动台.app"
PACKAGE_DIR="$DIST_DIR/启动台安装包"
ZIP_PATH="$DIST_DIR/启动台-通用版.zip"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

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
    Sources/LoginStartup.swift \
    Sources/LauncherModel.swift \
    Sources/Hotkey.swift \
    Sources/LaunchpadClassic.swift \
    -lsqlite3 \
    -o "$BUILD_DIR/ClassicLaunchpad-$arch"
}

build_arch arm64
build_arch x86_64

rm -rf "$APP_DIR" "$PACKAGE_DIR" "$ZIP_PATH" "$DIST_DIR/启动台.zip"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PACKAGE_DIR"
lipo -create \
  "$BUILD_DIR/ClassicLaunchpad-arm64" \
  "$BUILD_DIR/ClassicLaunchpad-x86_64" \
  -output "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch arm64 "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch x86_64 "$APP_DIR/Contents/MacOS/ClassicLaunchpad"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/AppIcon.png "$APP_DIR/Contents/Resources/"
codesign --force --sign - "$APP_DIR"

cp -R "$APP_DIR" "$PACKAGE_DIR/启动台.app"
ln -s /Applications "$PACKAGE_DIR/应用程序"
printf '%s\n' '将“启动台.app”拖入“应用程序”，然后从“应用程序”打开。' > "$PACKAGE_DIR/安装说明.txt"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$ZIP_PATH"

printf '已生成：%s（arm64 + x86_64）\n' "$ZIP_PATH"
