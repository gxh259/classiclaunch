#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
output="${1:-$PWD/.build/AppIcon.icns}"
image_dir="$PWD/.build/icon-pngs"
mkdir -p "$image_dir" "$(dirname "$output")" "$PWD/.build/cache-icon"

swift -module-cache-path "$PWD/.build/cache-icon" \
  scripts/pad-icon.swift Resources/AppIcon.png "$image_dir/1024.png"

for size in 128 256 512; do
  sips -s format png -z "$size" "$size" "$image_dir/1024.png" \
    --out "$image_dir/$size.png" >/dev/null
done

swift -module-cache-path "$PWD/.build/cache-icon" \
  scripts/pack-icon.swift "$image_dir" "$output"
