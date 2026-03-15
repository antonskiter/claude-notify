#!/bin/bash
set -e

APP_NAME="claude-notify"
BUNDLE_ID="com.claude.notify"
INSTALL_DIR="$HOME/bin"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swiftc claude-notify.swift -o claude-notify -framework UserNotifications -framework AppKit

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

echo "Installing binary into bundle..."
mv claude-notify "$APP_BUNDLE/Contents/MacOS/claude-notify"

echo "Creating symlink..."
if [ -L "$INSTALL_DIR/$APP_NAME" ]; then
    rm "$INSTALL_DIR/$APP_NAME"
fi
ln -s "$APP_BUNDLE/Contents/MacOS/$APP_NAME" "$INSTALL_DIR/$APP_NAME"

echo ""
echo "Done! $APP_NAME installed successfully."
echo "Usage: claude-notify \"Title\" \"Message\""
