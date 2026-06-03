#!/bin/bash
set -euo pipefail

VERSION="${1:-1.0.0}"
TAG="${TAG:-v${VERSION}}"

echo "==> Building release..."
swift build -c release

BUILD_DIR=".build/arm64-apple-macosx/release"
APP_DIR=".build/Lightly.app"
DMG_NAME="lightly-macos.dmg"
APPCAST_NAME="appcast.xml"
RELEASE_URL="https://github.com/neerajsingh0101/lightly/releases/download/${TAG}/${DMG_NAME}"
APPCAST_URL="https://github.com/neerajsingh0101/lightly/releases/latest/download/${APPCAST_NAME}"

echo "==> Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

# Copy binary
cp "$BUILD_DIR/lightly-app" "$APP_DIR/Contents/MacOS/lightly-app"

# Copy Sparkle.framework from SwiftPM's binary artifact cache into the app.
SPARKLE_FRAMEWORK="$(find .build/artifacts -path '*/Sparkle.framework' -type d | head -n 1)"
if [ -z "$SPARKLE_FRAMEWORK" ]; then
    echo "Could not find Sparkle.framework under .build/artifacts" >&2
    exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/lightly-app" 2>/dev/null || true

# Copy app icon if one has been built
ICON_SRC="Sources/LightlyApp/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>lightly-app</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lightly.app</string>
    <key>CFBundleName</key>
    <string>Lightly</string>
    <key>CFBundleDisplayName</key>
    <string>Lightly</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${APPCAST_URL}</string>
    <key>SUPublicEDKey</key>
    <string>L0ljaNTkCDOrcaLiMg8NIPHt+XLj5dr+Fp4dZ9AmsR8=</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
    <key>SUAutomaticallyUpdate</key>
    <true/>
</dict>
</plist>
PLIST

# Re-sign the whole .app ad-hoc so the bundle has a proper code-signature
# manifest (linker-signed leaves resources unsealed, which interacts badly
# with Gatekeeper translocation on some Macs).
echo "==> Re-signing app bundle ad-hoc..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "Lightly" \
    -srcfolder "$APP_DIR" \
    -ov -format UDZO \
    "$DMG_NAME"

SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-}"
if [ -z "$SIGN_UPDATE" ] && command -v sign_update >/dev/null 2>&1; then
    SIGN_UPDATE="$(command -v sign_update)"
fi
if [ -z "$SIGN_UPDATE" ] && [ -x "/tmp/lightly-sparkle/bin/sign_update" ]; then
    SIGN_UPDATE="/tmp/lightly-sparkle/bin/sign_update"
fi

if [ -n "$SIGN_UPDATE" ]; then
    echo "==> Creating Sparkle appcast..."
    SIGNATURE_ATTRS="$("$SIGN_UPDATE" "$DMG_NAME")"
    cat > "$APPCAST_NAME" << APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Lightly Updates</title>
    <link>https://github.com/neerajsingh0101/lightly</link>
    <description>Lightly release feed</description>
    <item>
      <title>Lightly ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S %z")</pubDate>
      <enclosure url="${RELEASE_URL}" type="application/x-apple-diskimage" ${SIGNATURE_ATTRS} />
    </item>
  </channel>
</rss>
APPCAST
    echo "==> Done: $DMG_NAME and $APPCAST_NAME"
else
    echo "==> Done: $DMG_NAME"
    echo "No sign_update tool found; skipped Sparkle appcast generation." >&2
fi
