#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"

if [[ ! "$APP_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  echo "Info.plist 中的 CFBundleShortVersionString 不是三段版本号：$APP_VERSION" >&2
  exit 1
fi

BUILD_DIR="$ROOT_DIR/build/v$APP_VERSION"
APP_DIR="$BUILD_DIR/说人话.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [[ -d "$APP_DIR" ]]; then
  /usr/bin/trash "$APP_DIR"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

xcrun swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  -framework ApplicationServices \
  -framework Security \
  -framework LocalAuthentication \
  "$ROOT_DIR"/Sources/*.swift \
  -o "$MACOS_DIR/说人话"

cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/LydiaLogo.png" "$RESOURCES_DIR/LydiaLogo.png"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null
xattr -cr "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "$APP_DIR"
