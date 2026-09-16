#!/usr/bin/env bash
# Builds KeepAwake.app and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="KeepAwake"
BUNDLE_ID="com.nhat.keepawake"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RES="$CONTENTS/Resources"

echo "==> Checking toolchain"
command -v swiftc  >/dev/null || { echo "swiftc not found — run: xcode-select --install"; exit 1; }
command -v iconutil >/dev/null || { echo "iconutil not found (Command Line Tools)"; exit 1; }

echo "==> Cleaning previous build"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

echo "==> Writing Info.plist"
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHumanReadableCopyright</key><string>KeepAwake</string>
</dict>
</plist>
EOF

echo "==> Generating icon"
swiftc -O makeicon.swift -o "$BUILD_DIR/makeicon"
"$BUILD_DIR/makeicon" "$BUILD_DIR/icon_1024.png"

ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
gen() { sips -z "$2" "$2" "$BUILD_DIR/icon_1024.png" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png       16
gen icon_16x16@2x.png    32
gen icon_32x32.png       32
gen icon_32x32@2x.png    64
gen icon_128x128.png    128
gen icon_128x128@2x.png 256
gen icon_256x256.png    256
gen icon_256x256@2x.png 512
gen icon_512x512.png    512
gen icon_512x512@2x.png 1024
iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns"

echo "==> Building app binary (SwiftPM)"
swift build -c release --product "$APP_NAME"
cp -f ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

echo "==> Ad-hoc signing"
codesign --force --deep -s - "$APP"

if [ -n "${SKIP_INSTALL:-}" ]; then
    echo "==> SKIP_INSTALL set — built at $APP (not installed)"
else
    echo "==> Installing to /Applications"
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/"
    echo "==> Done. Launch it from /Applications or run:  open -a $APP_NAME"
fi
