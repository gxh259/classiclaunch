#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_DIR="$PWD/.build"
DMG_PYTHON="${PYTHON_BIN:-python3}"
DMG_ENV="$BUILD_DIR/dmg-tools"
DMG_PATH="$PWD/dist/启动台-通用版.dmg"

if [ ! -x "$DMG_ENV/bin/python" ]; then
  "$DMG_PYTHON" -c 'import sys; assert sys.version_info >= (3, 10), "DMG packaging requires Python 3.10+. Set PYTHON_BIN to a compatible interpreter."'
  "$DMG_PYTHON" -m venv "$DMG_ENV"
fi
PIP_CACHE_DIR="$BUILD_DIR/pip-cache" "$DMG_ENV/bin/python" -m pip install --quiet \
  --disable-pip-version-check -r scripts/dmg-requirements.txt

swift -module-cache-path "$BUILD_DIR/cache-icon" scripts/dmg-background.swift "$BUILD_DIR/dmg-background.tiff"
"$DMG_ENV/bin/dmgbuild" -s scripts/dmg-settings.py -D "root=$PWD" "启动台" "$DMG_PATH"
hdiutil verify "$DMG_PATH"

# Verify the packaged app after copying it onto the image, since Finder metadata
# added during packaging can invalidate an otherwise valid signed bundle.
CHECK_MOUNT="$(mktemp -d "$BUILD_DIR/dmg-check.XXXXXX")"
cleanup_mount() {
  hdiutil detach "$CHECK_MOUNT" -quiet >/dev/null 2>&1 || true
  rmdir "$CHECK_MOUNT" 2>/dev/null || true
}
trap cleanup_mount EXIT
hdiutil attach -readonly -nobrowse -noautoopen -quiet -mountpoint "$CHECK_MOUNT" "$DMG_PATH"
codesign --verify --deep --strict "$CHECK_MOUNT/启动台.app"
codesign --verify --deep --strict "$CHECK_MOUNT/安装启动台.app"
lipo -verify_arch arm64 "$CHECK_MOUNT/启动台.app/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch x86_64 "$CHECK_MOUNT/启动台.app/Contents/MacOS/ClassicLaunchpad"
lipo -verify_arch arm64 "$CHECK_MOUNT/安装启动台.app/Contents/MacOS/ClassicLaunchpadInstaller"
lipo -verify_arch x86_64 "$CHECK_MOUNT/安装启动台.app/Contents/MacOS/ClassicLaunchpadInstaller"
if [ "$(readlink "$CHECK_MOUNT/Applications")" != "/Applications" ]; then
  printf 'DMG Applications shortcut is invalid\n' >&2
  exit 1
fi
hdiutil detach "$CHECK_MOUNT" -quiet
rmdir "$CHECK_MOUNT" 2>/dev/null || true
trap - EXIT
printf '已生成：%s（arm64 + x86_64）\n' "$DMG_PATH"
