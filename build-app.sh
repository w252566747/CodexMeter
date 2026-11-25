#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
swift build -c release
APP="$ROOT/CodexMeter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/CodexMeter "$APP/Contents/MacOS/CodexMeter"
cp CodexMeterWatcher.sh "$APP/Contents/MacOS/CodexMeterWatcher.sh"
chmod +x "$APP/Contents/MacOS/CodexMeterWatcher.sh"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources "$APP/Contents/Resources"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
