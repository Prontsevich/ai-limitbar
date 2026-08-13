#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 MAJOR.MINOR.PATCH BUILD_NUMBER arm64|x86_64" >&2
}

if [[ $# -ne 3 ]]; then
  usage
  exit 2
fi

VERSION="$1"
BUILD_NUMBER="$2"
ARCHITECTURE="$3"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must use MAJOR.MINOR.PATCH with numeric components" >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  echo "error: build number must use one to three numeric components" >&2
  exit 2
fi

case "$ARCHITECTURE" in
  arm64|x86_64)
    ;;
  *)
    usage
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AILimitBar"
HELPER_NAME="AILimitBarClaudeStatusLine"
EXPECTED_BUNDLE_ID="io.github.Prontsevich.AILimitBar"
EXPECTED_TEAM="${AILIMITBAR_DEVELOPMENT_TEAM:-}"
EXPECTED_IDENTITY="${AILIMITBAR_DEVELOPER_IDENTITY:-}"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ARCHIVE="$ROOT_DIR/dist/$APP_NAME-$VERSION-$ARCHITECTURE.zip"
TEMP_DIRECTORY=""

cleanup() {
  [[ -z "$TEMP_DIRECTORY" ]] || rm -rf "$TEMP_DIRECTORY"
}
trap cleanup EXIT

"$ROOT_DIR/script/stage_app_bundle.sh" \
  --configuration release \
  --version "$VERSION" \
  --build-number "$BUILD_NUMBER" \
  --arch "$ARCHITECTURE"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: expected $label '$expected', found '$actual'" >&2
    exit 1
  fi
}

validate_app_bundle() {
  local bundle="$1"
  local bundle_info="$bundle/Contents/Info.plist"
  local bundle_binary="$bundle/Contents/MacOS/$APP_NAME"
  local bundle_helper="$bundle/Contents/Helpers/$HELPER_NAME"
  local bundle_icon="$bundle/Contents/Resources/AppIcon.icns"
  local bundle_profile="$bundle/Contents/embedded.provisionprofile"
  local english_strings="$bundle/Contents/Resources/en.lproj/Localizable.strings"
  local russian_strings="$bundle/Contents/Resources/ru.lproj/Localizable.strings"
  local app_signing_state
  local app_entitlements="$TEMP_DIRECTORY/app-entitlements.plist"
  local helper_signing_state

  [[ -x "$bundle_binary" ]] || { echo "error: missing app executable" >&2; exit 1; }
  [[ -x "$bundle_helper" ]] || { echo "error: missing helper executable" >&2; exit 1; }
  [[ -s "$bundle_icon" ]] || { echo "error: missing compiled app icon" >&2; exit 1; }
  [[ -s "$bundle_profile" ]] || { echo "error: missing Developer ID provisioning profile" >&2; exit 1; }
  [[ -s "$english_strings" ]] || { echo "error: missing English localization resources" >&2; exit 1; }
  [[ -s "$russian_strings" ]] || { echo "error: missing Russian localization resources" >&2; exit 1; }
  [[ -d "$bundle/Contents/Resources/GRDB_GRDB.bundle" ]] || {
    echo "error: missing GRDB production resource bundle" >&2
    exit 1
  }

  if find "$bundle/Contents/Resources" -maxdepth 1 -name '*Tests.bundle' -print -quit | grep -q .; then
    echo "error: test resource bundle was staged into the app" >&2
    exit 1
  fi

  assert_equal "$EXPECTED_BUNDLE_ID" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle_info")" "bundle identifier"
  assert_equal "$VERSION" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle_info")" "short version"
  assert_equal "$BUILD_NUMBER" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$bundle_info")" "bundle version"
  assert_equal "15.0" "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$bundle_info")" "minimum system version"
  assert_equal "en" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDevelopmentRegion' "$bundle_info")" "development region"
  assert_equal "AppIcon" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$bundle_info")" "app icon file"
  assert_equal "AppIcon" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$bundle_info")" "app icon name"
  assert_equal "$ARCHITECTURE" "$(/usr/bin/lipo -archs "$bundle_binary")" "app architecture"
  assert_equal "$ARCHITECTURE" "$(/usr/bin/lipo -archs "$bundle_helper")" "helper architecture"

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"
  app_signing_state="$(/usr/bin/codesign -dvvv "$bundle" 2>&1)"
  helper_signing_state="$(/usr/bin/codesign -dvvv "$bundle_helper" 2>&1)"
  /usr/bin/codesign \
    --display \
    --entitlements - \
    --xml \
    "$bundle" \
    >"$app_entitlements" \
    2>/dev/null
  /bin/bash \
    "$ROOT_DIR/script/validate_release_entitlements.sh" \
    "$app_entitlements" \
    "$EXPECTED_TEAM" \
    "$EXPECTED_BUNDLE_ID"

  [[ "$app_signing_state" == *"Authority=$EXPECTED_IDENTITY"* ]] || {
    echo "error: app is not Developer ID signed" >&2
    exit 1
  }
  [[ "$app_signing_state" == *"TeamIdentifier=$EXPECTED_TEAM"* ]] || {
    echo "error: app signature contains an unexpected team" >&2
    exit 1
  }
  [[ "$app_signing_state" == *"flags="*"runtime"* ]] || {
    echo "error: app signature is missing Hardened Runtime" >&2
    exit 1
  }
  [[ "$app_signing_state" == *"Timestamp="* ]] || {
    echo "error: app signature is missing a secure timestamp" >&2
    exit 1
  }
  [[ "$helper_signing_state" == *"Authority=$EXPECTED_IDENTITY"* ]] || {
    echo "error: helper is not Developer ID signed" >&2
    exit 1
  }
  [[ "$helper_signing_state" == *"TeamIdentifier=$EXPECTED_TEAM"* ]] || {
    echo "error: helper signature contains an unexpected team" >&2
    exit 1
  }
  [[ "$helper_signing_state" == *"flags="*"runtime"* ]] || {
    echo "error: helper signature is missing Hardened Runtime" >&2
    exit 1
  }
  [[ "$helper_signing_state" == *"Timestamp="* ]] || {
    echo "error: helper signature is missing a secure timestamp" >&2
    exit 1
  }
}

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/AILimitBar-release.XXXXXX")"
validate_app_bundle "$APP_BUNDLE"

rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
[[ -s "$ARCHIVE" ]] || { echo "error: release archive was not created" >&2; exit 1; }

EXTRACTION_DIRECTORY="$TEMP_DIRECTORY/archive"
mkdir -p "$EXTRACTION_DIRECTORY"
/usr/bin/ditto -x -k "$ARCHIVE" "$EXTRACTION_DIRECTORY"
EXTRACTED_APP="$EXTRACTION_DIRECTORY/$APP_NAME.app"
[[ -d "$EXTRACTED_APP" ]] || { echo "error: archive does not expand to $APP_NAME.app" >&2; exit 1; }

if find "$EXTRACTION_DIRECTORY" -mindepth 1 -maxdepth 1 \
  ! -name "$APP_NAME.app" \
  ! -name '__MACOSX' \
  -print -quit | grep -q .; then
  echo "error: archive contains an unexpected top-level item" >&2
  exit 1
fi

validate_app_bundle "$EXTRACTED_APP"
echo "Created $ARCHIVE"
