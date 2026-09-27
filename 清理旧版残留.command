#!/bin/bash
set -euo pipefail

if [[ "$EUID" -eq 0 || ! -d "$HOME/Library" ]]; then
  printf '%s\n' '请以当前 Mac 用户身份运行此工具，不要使用 sudo。'
  exit 1
fi

if [[ -e /Applications/启动台.app ]]; then
  printf '%s\n' '检测到“启动台.app”仍在“应用程序”。请打开启动台，在设置中选择“完全卸载启动台…”。'
  read -r -p '按回车键退出…' _
  exit 1
fi

printf '%s\n' '此工具用于已经将旧版“启动台.app”移到废纸篓的情况。'
printf '%s\n' '将永久删除启动台的图标排序、文件夹、隐藏状态、应用别名和其他设置。'
read -r -p '确认清理？输入 y 后按回车：' answer
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  exit 0
fi

library_dir="$HOME/Library"
bundle_id='local.codex.classiclaunchpad'
legacy_agent="$library_dir/LaunchAgents/$bundle_id.login.plist"
if [[ -e "$legacy_agent" ]]; then
  /bin/launchctl bootout "gui/$(id -u)" "$legacy_agent" >/dev/null 2>&1 || true
  rm -f -- "$legacy_agent"
fi

defaults delete "$bundle_id" >/dev/null 2>&1 || true
rm -rf -- "$library_dir/Application Support/ClassicLaunchpad"
rm -rf -- "$library_dir/Caches/$bundle_id"
rm -rf -- "$library_dir/Saved Application State/$bundle_id.savedState"
rm -f -- "$library_dir/Preferences/$bundle_id.plist"

printf '%s\n' '启动台的用户数据已清理。如“系统设置 > 通用 > 登录项”仍显示旧条目，请在系统设置中移除。'
read -r -p '按回车键退出…' _
