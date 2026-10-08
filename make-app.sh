#!/bin/bash
# make-app.sh — build Monkey and assemble a real .app bundle in /Applications.
#
# There's no Xcode on this machine, so the bundle is put together by hand:
# SwiftPM produces the binary, we write Info.plist, then ad-hoc codesign.
# Bundling matters for more than tidiness — an unbundled binary has no bundle
# identifier, which is what UNUserNotificationCenter needs.

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Monkey"
BUNDLE_ID="com.vhs.monkey"
# Override with MONKEY_APP_DIR=<dir> to build somewhere other than /Applications.
APP_DIR="${MONKEY_APP_DIR:-/Applications}"
DEST="$APP_DIR/$APP_NAME.app"
LEGACY="$HOME/Applications/$APP_NAME.app"
VERSION="$(cat VERSION 2>/dev/null || echo "0.0.0")"

echo "==> building release"
swift build -c release

echo "==> app icon"
ICON_KEY=""
if ./make-icon.sh; then
  ICON_KEY="	<key>CFBundleIconFile</key>          <string>Monkey</string>"
fi

echo "==> assembling bundle"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp ".build/release/$APP_NAME" "$DEST/Contents/MacOS/$APP_NAME"
[ -f build/Monkey.icns ] && cp build/Monkey.icns "$DEST/Contents/Resources/Monkey.icns"

cat > "$DEST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>              <string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>       <string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key>        <string>$APP_NAME</string>
	<key>CFBundlePackageType</key>       <string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key>           <string>1</string>
	<key>LSMinimumSystemVersion</key>    <string>14.0</string>
	<key>LSUIElement</key>               <true/>
	<key>NSHighResolutionCapable</key>   <true/>
$ICON_KEY
</dict>
</plist>
PLIST

plutil -lint "$DEST/Contents/Info.plist" > /dev/null

echo "==> ad-hoc signing"
codesign --force --sign - --timestamp=none "$DEST"

echo "==> registering with LaunchServices"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$DEST" 2>/dev/null || true

# Installs used to land in ~/Applications; one copy is enough. Only removed when
# installing to the default location, so a MONKEY_APP_DIR build never deletes anything.
if [ -z "${MONKEY_APP_DIR:-}" ] && [ -d "$LEGACY" ] && [ "$LEGACY" != "$DEST" ]; then
  echo "==> removing old $LEGACY"
  rm -rf "$LEGACY"
fi

echo
echo "installed: $DEST"
echo "run it:    open -a \"$DEST\""
