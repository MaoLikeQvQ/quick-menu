#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}/.."
cd "$ROOT"
swift build -c release --triple arm64-apple-macosx13.0
swift build -c release --triple x86_64-apple-macosx13.0

APP="$ROOT/build/快点菜单.app"
EXT="$APP/Contents/PlugIns/RClickFinder.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS"
lipo -create \
  .build/arm64-apple-macosx/release/RClickHost \
  .build/x86_64-apple-macosx/release/RClickHost \
  -output "$APP/Contents/MacOS/快点菜单"
lipo -create \
  .build/arm64-apple-macosx/release/RClickFinder \
  .build/x86_64-apple-macosx/release/RClickFinder \
  -output "$EXT/Contents/MacOS/RClickFinder"
cp Resources/Host-Info.plist "$APP/Contents/Info.plist"
cp Resources/Finder-Info.plist "$EXT/Contents/Info.plist"
codesign --force --sign - --entitlements Resources/Extension.entitlements "$EXT" >/dev/null
codesign --force --sign - --entitlements Resources/Host.entitlements "$APP" >/dev/null
echo "Built $APP"
