#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building LookAway binary with SwiftPM..."
swift build -c release

BIN_PATH="$(find .build -name "EyeBreak" -type f -perm +111 | grep -i release | head -n 1)"
if [ -z "$BIN_PATH" ]; then
    echo "Release binary not found, checking debug build..."
    BIN_PATH="$(find .build -name "EyeBreak" -type f -perm +111 | head -n 1)"
fi

echo "Found binary at: $BIN_PATH"

APP_BUNDLE="LookAway.app"
echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/EyeBreak"
chmod +x "$APP_BUNDLE/Contents/MacOS/EyeBreak"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "Resources/EyeBreak.entitlements" ]; then
    echo "==> Ad-hoc signing $APP_BUNDLE..."
    codesign --force --deep --sign - --entitlements "Resources/EyeBreak.entitlements" "$APP_BUNDLE" 2>/dev/null || codesign --force --deep --sign - "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "==> Successfully created $APP_BUNDLE!"
