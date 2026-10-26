#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${CODEXVOLT_BUILD_DIR:-$PROJECT_DIR/.build}"
DIST_DIR="${CODEXVOLT_DIST_DIR:-$PROJECT_DIR/dist}"
# Stage bundles outside cloud-synced folders to preserve the code signature.
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexvolt.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP="$STAGING_DIR/CodexVolt.app"
ARCH="${CODEXVOLT_ARCH:-$(uname -m)}"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;; esac
mkdir -p "$BUILD_DIR/ModuleCache" "$DIST_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O -whole-module-optimization -swift-version 5 -target "$ARCH-apple-macos13.0" \
  -module-cache-path "$BUILD_DIR/ModuleCache" \
  -framework AppKit -framework ServiceManagement \
  "$PROJECT_DIR/Sources/Quota.swift" "$PROJECT_DIR/Sources/Provider.swift" \
  "$PROJECT_DIR/Sources/Themes.swift" "$PROJECT_DIR/Sources/App.swift" "$PROJECT_DIR/Sources/main.swift" \
  -o "$APP/Contents/MacOS/CodexVolt"
cp "$PROJECT_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"
ARCHIVE="$DIST_DIR/CodexVolt-macOS-$ARCH.zip"
/usr/bin/ditto -c -k --keepParent --norsrc "$APP" "$ARCHIVE"
echo "Built: $ARCHIVE"
