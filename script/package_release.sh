#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 MAJOR.MINOR.PATCH" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must use MAJOR.MINOR.PATCH with numeric components" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AILimitBar"
HELPER_NAME="AILimitBarClaudeStatusLine"
EXPECTED_BUNDLE_ID="io.github.Prontsevich.AILimitBar"
EXPECTED_ARCHITECTURE="arm64"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ARCHIVE="$ROOT_DIR/dist/$APP_NAME-$VERSION.zip"

"$ROOT_DIR/script/stage_app_bundle.sh" \
  --configuration release \
  --version "$VERSION" \
  --arch "$EXPECTED_ARCHITECTURE"

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

  [[ -x "$bundle_binary" ]] || { echo "error: missing app executable" >&2; exit 1; }
  [[ -x "$bundle_helper" ]] || { echo "error: missing helper executable" >&2; exit 1; }
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
  assert_equal "$VERSION" "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$bundle_info")" "bundle version"
  assert_equal "26.0" "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$bundle_info")" "minimum system version"
  assert_equal "$EXPECTED_ARCHITECTURE" "$(/usr/bin/lipo -archs "$bundle_binary")" "app architecture"
  assert_equal "$EXPECTED_ARCHITECTURE" "$(/usr/bin/lipo -archs "$bundle_helper")" "helper architecture"

  /usr/bin/codesign --verify --deep --strict "$bundle"
}

validate_app_bundle "$APP_BUNDLE"

rm -f "$ARCHIVE"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
[[ -s "$ARCHIVE" ]] || { echo "error: release archive was not created" >&2; exit 1; }

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/AILimitBar-release.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIRECTORY"
}
trap cleanup EXIT

/usr/bin/ditto -x -k "$ARCHIVE" "$TEMP_DIRECTORY"
EXTRACTED_APP="$TEMP_DIRECTORY/$APP_NAME.app"
[[ -d "$EXTRACTED_APP" ]] || { echo "error: archive does not expand to $APP_NAME.app" >&2; exit 1; }

if find "$TEMP_DIRECTORY" -mindepth 1 -maxdepth 1 \
  ! -name "$APP_NAME.app" \
  ! -name '__MACOSX' \
  -print -quit | grep -q .; then
  echo "error: archive contains an unexpected top-level item" >&2
  exit 1
fi

validate_app_bundle "$EXTRACTED_APP"
echo "Created $ARCHIVE"
