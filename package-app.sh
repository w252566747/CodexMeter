#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

./build-app.sh

APP="$ROOT/CodexMeter.app"
DIST="$ROOT/dist"
ZIP="$DIST/CodexMeter-macos.zip"
CHECKSUM="$ZIP.sha256"

codesign --verify --deep --strict "$APP"
mkdir -p "$DIST"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
(cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$CHECKSUM")")

echo "Created: $ZIP"
echo "Checksum: $CHECKSUM"
cat "$CHECKSUM"
