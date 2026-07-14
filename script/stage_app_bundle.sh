#!/usr/bin/env bash
set -euo pipefail

APP_NAME="AILimitBar"
BUNDLE_ID="io.github.Prontsevich.AILimitBar"
MIN_SYSTEM_VERSION="26.0"
HELPER_NAME="AILimitBarClaudeStatusLine"

CONFIGURATION="debug"
VERSION=""
ARCHITECTURE=""

usage() {
  echo "usage: $0 [--configuration debug|release] [--version MAJOR.MINOR.PATCH] [--arch arm64|x86_64]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      VERSION="$2"
      shift 2
      ;;
    --arch)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      ARCHITECTURE="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$CONFIGURATION" in
  debug|release)
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ -n "$VERSION" && ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must use MAJOR.MINOR.PATCH with numeric components" >&2
  exit 2
fi

case "$ARCHITECTURE" in
  ""|arm64|x86_64)
    ;;
  *)
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
APP_HELPERS="$APP_CONTENTS/Helpers"
HELPER_BINARY="$APP_HELPERS/$HELPER_NAME"
APP_RESOURCES="$APP_CONTENTS/Resources"
INFO_PLIST="$APP_CONTENTS/Info.plist"

BUILD_ARGS=(--configuration "$CONFIGURATION")
if [[ -n "$ARCHITECTURE" ]]; then
  BUILD_ARGS+=(--arch "$ARCHITECTURE")
fi

swift build "${BUILD_ARGS[@]}"
BUILD_DIRECTORY="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BUILD_BINARY="$BUILD_DIRECTORY/$APP_NAME"
BUILD_HELPER="$BUILD_DIRECTORY/$HELPER_NAME"

[[ -x "$BUILD_BINARY" ]] || { echo "error: missing app executable at $BUILD_BINARY" >&2; exit 1; }
[[ -x "$BUILD_HELPER" ]] || { echo "error: missing helper executable at $BUILD_HELPER" >&2; exit 1; }

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_HELPER" "$HELPER_BINARY"
chmod +x "$APP_BINARY" "$HELPER_BINARY"

shopt -s nullglob
for resource_bundle in "$BUILD_DIRECTORY"/*.bundle; do
  resource_name="$(basename "$resource_bundle")"
  case "$resource_name" in
    *Tests.bundle)
      continue
      ;;
  esac
  /usr/bin/ditto "$resource_bundle" "$APP_RESOURCES/$resource_name"
done
shopt -u nullglob

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "$VERSION" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$INFO_PLIST"
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$INFO_PLIST"
fi

/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
/usr/bin/codesign --force --sign - --timestamp=none "$APP_BINARY"
/usr/bin/codesign --force --sign - --timestamp=none "$HELPER_BINARY"
/usr/bin/codesign --force --sign - --timestamp=none "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

echo "Staged $APP_BUNDLE"
