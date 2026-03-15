#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="claude-notify"
BUNDLE_ID="com.claude.notify"
INSTALL_DIR="$HOME/bin"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

echo "Cleaning up existing bundle..."
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
fi

echo "Creating .app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"

echo "Writing Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.claude.notify</string>
    <key>CFBundleName</key>
    <string>Claude Notify</string>
    <key>CFBundleExecutable</key>
    <string>claude-notify</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Building $APP_NAME..."
swiftc "$SCRIPT_DIR/claude-notify.swift" -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" -framework UserNotifications -framework AppKit

echo "Creating symlink..."
rm -f "$INSTALL_DIR/$APP_NAME"
ln -s "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

echo ""
echo "Done! $APP_NAME installed successfully."
echo "Usage: claude-notify <message> [--title <title>] [--sound <sound>]"
