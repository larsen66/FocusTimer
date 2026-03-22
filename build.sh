#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FocusTimer"
BUNDLE_ID="com.dav.focustimer"
VERSION="1.0.0"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"
ENTITLEMENTS="/tmp/FocusTimer.entitlements"

echo "▸ Building release binary..."
swift build -c release --arch arm64

echo "▸ Creating .app bundle..."
rm -rf "dist/${APP_NAME}.app"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "▸ Copying binary..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo "▸ Writing PkgInfo..."
printf 'APPL????' > "${CONTENTS}/PkgInfo"

echo "▸ Writing Info.plist..."
cat > "${CONTENTS}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>FocusTimer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>FocusTimer хочет читать и писать заметки в Apple Notes для трекинга задач.</string>
</dict>
</plist>
EOF

echo "▸ Writing entitlements..."
cat > "${ENTITLEMENTS}" << 'ENTSEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
ENTSEOF

echo "▸ Signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "${ENTITLEMENTS}" \
    --options runtime \
    "${APP_BUNDLE}"

codesign --verify --deep --strict "${APP_BUNDLE}" && echo "  Signature OK"

echo ""
echo "✓ Built: ${APP_BUNDLE}"
echo "  Run:    open ${APP_BUNDLE}"
echo "  Or:     cp -r ${APP_BUNDLE} /Applications/"
