#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${CODEXVOLT_BUILD_DIR:-$PROJECT_DIR/.build}"
mkdir -p "$BUILD_DIR/ModuleCache"
xcrun swiftc -swift-version 5 -module-cache-path "$BUILD_DIR/ModuleCache" \
  "$PROJECT_DIR/Sources/Quota.swift" "$PROJECT_DIR/Tests/QuotaTests.swift" -o "$BUILD_DIR/QuotaTests"
"$BUILD_DIR/QuotaTests"
