#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p .build/ModuleCache .build/AppIcon.iconset Resources docs/images
xcrun swiftc -swift-version 5 -module-cache-path .build/ModuleCache -framework AppKit \
  Sources/Themes.swift scripts/RenderAssets.swift -o .build/render-assets
.build/render-assets "$PROJECT_DIR"
for size in 16 32 128 256 512; do
  cp ".build/icon-$size.png" ".build/AppIcon.iconset/icon_${size}x${size}.png"
  cp ".build/icon-$((size * 2)).png" ".build/AppIcon.iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
