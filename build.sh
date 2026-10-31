#!/bin/bash
set -euo pipefail
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${1:-$SOURCE_DIR/dist}"
PREVIEW="${KEYPAD_PREVIEW:-0}"
if [[ "$PREVIEW" == 1 ]]; then
  APP="$OUTPUT_DIR/Keypad Lighting Preview.app"
  BUNDLE_ID="local.pranay.keypadcompanion.lightingpreview"
elif [[ "$PREVIEW" == 0 ]]; then
  APP="$OUTPUT_DIR/Keypad Companion.app"
  BUNDLE_ID="local.pranay.keypadcompanion"
else
  echo "KEYPAD_PREVIEW must be 0 or 1" >&2
  exit 1
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$SOURCE_DIR/.cache"
swift -module-cache-path "$SOURCE_DIR/.cache" "$SOURCE_DIR/Tools/BuildIcon.swift" \
  "$SOURCE_DIR/Resources/AppIcon.png" "$SOURCE_DIR/.cache/AppIcon.iconset"
iconutil -c icns "$SOURCE_DIR/.cache/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$SOURCE_DIR/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
swiftc -swift-version 5 -target arm64-apple-macos13.0 -module-cache-path "$SOURCE_DIR/.cache" \
  "$SOURCE_DIR"/Sources/*.swift -o "$APP/Contents/MacOS/KeypadCompanion" \
  -framework AppKit -framework SwiftUI -framework IOKit -framework ServiceManagement
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.pranay.keypadcompanion</string>
<key>CFBundleName</key><string>Keypad Companion</string>
<key>CFBundleDisplayName</key><string>Keypad Companion</string>
<key>CFBundleExecutable</key><string>KeypadCompanion</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Control Spotify playback and volume from your keypad.</string>
<key>NSInputMonitoringUsageDescription</key><string>Read controls from your Bright Data keypad.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
if [[ "$PREVIEW" == 1 ]]; then
  /usr/libexec/PlistBuddy -c 'Add :KPHLightingPreview bool true' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Keypad Lighting Preview' "$APP/Contents/Info.plist"
fi
codesign --force --sign - --identifier "$BUNDLE_ID" \
  -r "=designated => identifier \"$BUNDLE_ID\"" "$APP"
codesign --verify --strict "$APP"
echo "Built: $APP"
