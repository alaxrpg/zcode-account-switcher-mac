#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$PROJECT_ROOT/macOS"
DIST_DIR="$PROJECT_ROOT/dist"
APP_NAME="ZCode Account Switcher.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME"

echo "================================================="
echo "Building Native macOS SwiftUI Client..."
echo "================================================="

cd "$MACOS_DIR"

# Build executable using Swift Package Manager
swift build -c release

BIN_PATH="$MACOS_DIR/.build/release/ZCodeAccountSwitcher"

if [ ! -f "$BIN_PATH" ]; then
    echo "Error: Swift release binary not found at $BIN_PATH"
    exit 1
fi

echo "Creating macOS Application Bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy compiled binary
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/ZCodeAccountSwitcher"
chmod +x "$APP_BUNDLE/Contents/MacOS/ZCodeAccountSwitcher"

# Copy Icon and Resources
if [ -f "$MACOS_DIR/Resources/AppIcon.icns" ]; then
    cp "$MACOS_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "$MACOS_DIR/Resources/zcode-logo.png" ]; then
    cp "$MACOS_DIR/Resources/zcode-logo.png" "$APP_BUNDLE/Contents/Resources/zcode-logo.png"
fi

# Generate Info.plist
cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>ZCodeAccountSwitcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.zcode.accountswitcher.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ZCode Account Switcher</string>
    <key>CFBundleDisplayName</key>
    <string>ZCode 账号切换器</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 ZCode Account Switcher. All rights reserved.</string>
</dict>
</plist>
EOF

echo "================================================="
echo "Successfully built Native macOS Application!"
echo "Bundle location: $APP_BUNDLE"
echo "================================================="
