#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname -- "$0")"
  pwd
)
REPO_ROOT=$(
  CDPATH= cd -- "$SCRIPT_DIR/.."
  pwd
)

APP_NAME="Russian Corner.app"
EXECUTABLE_NAME="RussianCornerApp"
RESOURCE_PROBE_NAME="RussianCornerResourceProbe"
BUNDLE_IDENTIFIER="com.openclaw.russiancorner"
DIST_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
PACKAGED_EXECUTABLE="$MACOS_DIR/$EXECUTABLE_NAME"
SOURCE_RESOURCES_DIR="$REPO_ROOT/Sources/RussianCornerCore/Resources"

REAL_ROOT=$(
  CDPATH= cd -- "$REPO_ROOT"
  pwd -P
)
EXPECTED_REAL_DIST="$REAL_ROOT/dist"
EXPECTED_REAL_APP="$EXPECTED_REAL_DIST/$APP_NAME"

if [ -L "$DIST_DIR" ]; then
  printf 'error: refusing symlinked dist path: %s\n' "$DIST_DIR" >&2
  exit 1
fi
if [ -e "$DIST_DIR" ] && [ ! -d "$DIST_DIR" ]; then
  printf 'error: dist path is not a directory: %s\n' "$DIST_DIR" >&2
  exit 1
fi
mkdir -p "$DIST_DIR"
chmod 0755 "$DIST_DIR"
REAL_DIST=$(
  CDPATH= cd -- "$DIST_DIR"
  pwd -P
)
if [ "$REAL_DIST" != "$EXPECTED_REAL_DIST" ]; then
  printf \
    'error: dist resolved outside repository: %s\n' \
    "$REAL_DIST" >&2
  exit 1
fi

if [ -L "$APP_BUNDLE" ]; then
  printf 'error: refusing symlinked app path: %s\n' "$APP_BUNDLE" >&2
  exit 1
fi
if [ -e "$APP_BUNDLE" ] && [ ! -d "$APP_BUNDLE" ]; then
  printf 'error: app path is not a directory: %s\n' "$APP_BUNDLE" >&2
  exit 1
fi
if [ -d "$APP_BUNDLE" ]; then
  REAL_EXISTING_APP=$(
    CDPATH= cd -- "$APP_BUNDLE"
    pwd -P
  )
  if [ "$REAL_EXISTING_APP" != "$EXPECTED_REAL_APP" ]; then
    printf \
      'error: app resolved outside dist: %s\n' \
      "$REAL_EXISTING_APP" >&2
    exit 1
  fi
fi

printf 'Building release executable...\n'
swift build \
  --package-path "$REPO_ROOT" \
  -c release \
  -Xswiftc -warnings-as-errors
BIN_PATH=$(
  swift build \
    --package-path "$REPO_ROOT" \
    -c release \
    -Xswiftc -warnings-as-errors \
    --show-bin-path
)
BUILT_EXECUTABLE="$BIN_PATH/$EXECUTABLE_NAME"
BUILT_RESOURCE_PROBE="$BIN_PATH/$RESOURCE_PROBE_NAME"

if [ ! -x "$BUILT_EXECUTABLE" ]; then
  printf 'error: release executable not found: %s\n' "$BUILT_EXECUTABLE" >&2
  exit 1
fi
if [ ! -x "$BUILT_RESOURCE_PROBE" ]; then
  printf 'error: resource probe not found: %s\n' "$BUILT_RESOURCE_PROBE" >&2
  exit 1
fi
if [ ! -f "$SOURCE_RESOURCES_DIR/lexemes.json" ] ||
  [ ! -f "$SOURCE_RESOURCES_DIR/sentences.json" ]; then
  printf 'error: source JSON resources are incomplete\n' >&2
  exit 1
fi

if strings "$BUILT_EXECUTABLE" | grep -F "$REAL_ROOT" >/dev/null; then
  printf 'error: production executable contains repository path\n' >&2
  exit 1
fi
if strings "$BUILT_EXECUTABLE" |
  grep -E '\.build/.+RussianCorner_RussianCornerCore\.bundle|RussianCorner_RussianCornerCore\.bundle' \
    >/dev/null; then
  printf 'error: production executable contains SwiftPM resource fallback\n' >&2
  exit 1
fi

if [ -d "$APP_BUNDLE" ]; then
  rm -rf -- "$EXPECTED_REAL_APP"
fi
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
REAL_APP=$(
  CDPATH= cd -- "$APP_BUNDLE"
  pwd -P
)
if [ "$REAL_APP" != "$EXPECTED_REAL_APP" ]; then
  printf 'error: created app resolved outside dist: %s\n' "$REAL_APP" >&2
  exit 1
fi
chmod 0755 "$CONTENTS_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

install -m 0755 "$BUILT_EXECUTABLE" "$PACKAGED_EXECUTABLE"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/lexemes.json" \
  "$RESOURCES_DIR/lexemes.json"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/sentences.json" \
  "$RESOURCES_DIR/sentences.json"

BUILT_SHA=$(shasum -a 256 "$BUILT_EXECUTABLE" | awk '{print $1}')
PACKAGED_SHA=$(shasum -a 256 "$PACKAGED_EXECUTABLE" | awk '{print $1}')
if [ "$BUILT_SHA" != "$PACKAGED_SHA" ]; then
  printf 'error: packaged executable differs from SwiftPM product\n' >&2
  exit 1
fi
printf 'copied_executable_sha256=%s\n' "$BUILT_SHA"

plutil -create xml1 "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleIdentifier string $BUNDLE_IDENTIFIER" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleDisplayName string Russian Corner" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleName string Russian Corner" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleExecutable string $EXECUTABLE_NAME" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleShortVersionString string 1.0.0" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleVersion string 1" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundlePackageType string APPL" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :LSMinimumSystemVersion string 14.0" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :NSMicrophoneUsageDescription string Russian Corner 需要使用麦克风录制你的俄语练习；录音不会自动分析。" \
  "$INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :NSHighResolutionCapable bool true" "$INFO_PLIST"
printf 'APPL????' >"$CONTENTS_DIR/PkgInfo"
chmod 0644 "$INFO_PLIST" "$CONTENTS_DIR/PkgInfo"
plutil -lint "$INFO_PLIST"

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/russian-corner-package.XXXXXX")
cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

"$BUILT_RESOURCE_PROBE" "$RESOURCES_DIR"
MISSING_RESOURCES_DIR="$TEMP_DIR/missing-resources"
mkdir -m 0755 "$MISSING_RESOURCES_DIR"
if "$BUILT_RESOURCE_PROBE" "$MISSING_RESOURCES_DIR" \
  >"$TEMP_DIR/missing-probe.log" 2>&1; then
  printf 'error: missing-resource probe unexpectedly succeeded\n' >&2
  exit 1
fi
if ! grep -q 'resource_probe=FAIL' "$TEMP_DIR/missing-probe.log"; then
  printf 'error: missing-resource probe did not fail explicitly\n' >&2
  exit 1
fi
printf 'missing_resource_probe=PASS\n'

codesign --sign - --force --deep "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [ "$(stat -f '%Lp' "$CONTENTS_DIR")" != "755" ] ||
  [ "$(stat -f '%Lp' "$RESOURCES_DIR")" != "755" ] ||
  [ "$(stat -f '%Lp' "$PACKAGED_EXECUTABLE")" != "755" ] ||
  [ "$(stat -f '%Lp' "$RESOURCES_DIR/lexemes.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$RESOURCES_DIR/sentences.json")" != "644" ]; then
  printf 'error: packaged app permissions are incorrect\n' >&2
  exit 1
fi
printf 'permissions=PASS resources=0755 executable=0755 json=0644\n'

printf 'Packaged app: %s\n' "$APP_BUNDLE"
