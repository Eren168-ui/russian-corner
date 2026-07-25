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
BUNDLE_NAME="RussianCorner_RussianCornerCore.bundle"
BUNDLE_IDENTIFIER="com.openclaw.russiancorner"
DIST_DIR="$REPO_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
PACKAGED_EXECUTABLE="$MACOS_DIR/$EXECUTABLE_NAME"
PACKAGED_RESOURCE_BUNDLE="$RESOURCES_DIR/$BUNDLE_NAME"

printf 'Building release executable...\n'
swift build --package-path "$REPO_ROOT" -c release
BIN_PATH=$(swift build --package-path "$REPO_ROOT" -c release --show-bin-path)
BUILT_EXECUTABLE="$BIN_PATH/$EXECUTABLE_NAME"
BUILD_TRIPLE=$(basename -- "$(dirname -- "$BIN_PATH")")
DEPLOYMENT_TARGET="${BUILD_TRIPLE}14.0"
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

if [ ! -x "$BUILT_EXECUTABLE" ]; then
  printf 'error: release executable not found: %s\n' "$BUILT_EXECUTABLE" >&2
  exit 1
fi

RESOURCE_BUNDLE_COUNT=$(
  find "$BIN_PATH" -maxdepth 2 -type d -name "$BUNDLE_NAME" -print |
    wc -l |
    tr -d '[:space:]'
)
if [ "$RESOURCE_BUNDLE_COUNT" -ne 1 ]; then
  printf \
    'error: expected exactly one %s under %s; found %s\n' \
    "$BUNDLE_NAME" \
    "$BIN_PATH" \
    "$RESOURCE_BUNDLE_COUNT" >&2
  find "$BIN_PATH" -maxdepth 2 -type d -name "$BUNDLE_NAME" -print >&2
  exit 1
fi
BUILT_RESOURCE_BUNDLE=$(
  find "$BIN_PATH" -maxdepth 2 -type d -name "$BUNDLE_NAME" -print
)

if [ ! -f "$BUILT_RESOURCE_BUNDLE/lexemes.json" ] ||
  [ ! -f "$BUILT_RESOURCE_BUNDLE/sentences.json" ]; then
  printf \
    'error: %s is not the RussianCornerCore resource bundle\n' \
    "$BUILT_RESOURCE_BUNDLE" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
if [ -e "$APP_BUNDLE" ]; then
  case "$APP_BUNDLE" in
    "$REPO_ROOT/dist/Russian Corner.app")
      rm -rf -- "$APP_BUNDLE"
      ;;
    *)
      printf 'error: refusing to remove unexpected path: %s\n' "$APP_BUNDLE" >&2
      exit 1
      ;;
  esac
fi
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

install -m 755 "$BUILT_EXECUTABLE" "$PACKAGED_EXECUTABLE"
cp -R "$BUILT_RESOURCE_BUNDLE" "$PACKAGED_RESOURCE_BUNDLE"

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
plutil -lint "$INFO_PLIST"

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/russian-corner-package.XXXXXX")
cleanup() {
  rm -rf -- "$TEMP_DIR"
}
trap cleanup EXIT HUP INT TERM

ORIGINAL_EXECUTABLE="$TEMP_DIR/$EXECUTABLE_NAME"
PROBE_SOURCE="$TEMP_DIR/ResourceProbe.swift"
RESOURCE_ACCESSOR="$BIN_PATH/RussianCornerCore.build/DerivedSources/resource_bundle_accessor.swift"
PACKAGING_RESOURCE_ACCESSOR="$TEMP_DIR/resource_bundle_accessor.swift"
PACKAGING_CORE_OBJECT="$TEMP_DIR/RussianCornerCore.swift.o"
PACKAGING_LINK_FILE="$TEMP_DIR/Objects.LinkFileList"
SWIFTPM_LINK_FILE="$BIN_PATH/RussianCornerApp.product/Objects.LinkFileList"

if [ ! -f "$RESOURCE_ACCESSOR" ] || [ ! -f "$SWIFTPM_LINK_FILE" ]; then
  printf 'error: SwiftPM resource accessor not found: %s\n' "$RESOURCE_ACCESSOR" >&2
  exit 1
fi

# SwiftPM emits a command-line executable accessor that looks beside
# Bundle.main.bundleURL. A signed macOS app must keep resources under
# Contents/Resources, so rebuild only the derived Core object and relink the
# release objects without changing checked-in business source.
sed \
  's/Bundle\.main\.bundleURL/Bundle.main.resourceURL.unsafelyUnwrapped/' \
  "$RESOURCE_ACCESSOR" >"$PACKAGING_RESOURCE_ACCESSOR"
if ! grep -q \
  'Bundle.main.resourceURL.unsafelyUnwrapped' \
  "$PACKAGING_RESOURCE_ACCESSOR" ||
  grep -q 'Bundle.main.bundleURL' "$PACKAGING_RESOURCE_ACCESSOR"; then
  printf 'error: failed to adapt the SwiftPM resource accessor\n' >&2
  exit 1
fi

xcrun swiftc \
  -frontend \
  -c \
  "$REPO_ROOT"/Sources/RussianCornerCore/*.swift \
  "$PACKAGING_RESOURCE_ACCESSOR" \
  -target "$DEPLOYMENT_TARGET" \
  -sdk "$SDK_PATH" \
  -I "$BIN_PATH/Modules" \
  -g \
  -debug-info-format=dwarf \
  -dwarf-version=4 \
  -swift-version 6 \
  -O \
  -D SWIFT_PACKAGE \
  -D SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE \
  -enable-default-cmo \
  -parse-as-library \
  -module-name RussianCornerCore \
  -o "$PACKAGING_CORE_OBJECT"

awk \
  -v replacement="$PACKAGING_CORE_OBJECT" \
  'BEGIN { emitted = 0 }
   /RussianCornerCore\.build\/[A-Za-z_]+\.swift\.o$/ {
     if (!emitted) {
       print replacement
       emitted = 1
     }
     next
   }
   { print }' \
  "$SWIFTPM_LINK_FILE" >"$PACKAGING_LINK_FILE"
if ! grep -Fxq "$PACKAGING_CORE_OBJECT" "$PACKAGING_LINK_FILE" ||
  grep -q 'RussianCornerCore\.build/[A-Za-z_]*\.swift\.o$' \
    "$PACKAGING_LINK_FILE"; then
  printf 'error: failed to replace SwiftPM Core objects for app packaging\n' >&2
  exit 1
fi

xcrun swiftc \
  @"$PACKAGING_LINK_FILE" \
  -target "$DEPLOYMENT_TARGET" \
  -sdk "$SDK_PATH" \
  -Xlinker -alias \
  -Xlinker _RussianCornerApp_main \
  -Xlinker _main \
  -Xlinker -dead_strip \
  -o "$ORIGINAL_EXECUTABLE"
install -m 755 "$ORIGINAL_EXECUTABLE" "$PACKAGED_EXECUTABLE"

cat >"$PROBE_SOURCE" <<'SWIFT'
import Foundation

@main
struct ResourceProbe {
  static func main() throws {
    guard CommandLine.arguments.count == 2 else {
      throw ProbeError(message: "expected packaged bundle path")
    }
    let expectedBundleURL = URL(
      fileURLWithPath: CommandLine.arguments[1],
      isDirectory: true
    ).resolvingSymlinksInPath().standardizedFileURL
    let actualBundleURL =
      Bundle.module.bundleURL.resolvingSymlinksInPath().standardizedFileURL
    guard actualBundleURL == expectedBundleURL else {
      throw ProbeError(
        message:
          "Bundle.module resolved \(actualBundleURL.path), expected \(expectedBundleURL.path)"
      )
    }

    let catalog = try ContentCatalog()
    guard catalog.lexemes.count == 360, catalog.sentences.count == 72 else {
      throw ProbeError(
        message:
          "unexpected resource counts \(catalog.lexemes.count)/\(catalog.sentences.count)"
      )
    }
    guard let identifier = Bundle.main.bundleIdentifier,
      identifier == "com.openclaw.russiancorner"
    else {
      throw ProbeError(
        message: "main bundle identifier is missing or incorrect"
      )
    }

    print(
      "resource_probe=PASS bundle=\(actualBundleURL.path) " +
        "lexemes=360 sentences=72 bundleIdentifier=\(identifier) " +
        "reminderBareBinaryFallback=false"
    )
  }
}

private struct ProbeError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
SWIFT

swiftc \
  -module-name RussianCornerCore \
  -parse-as-library \
  "$REPO_ROOT"/Sources/RussianCornerCore/*.swift \
  "$PACKAGING_RESOURCE_ACCESSOR" \
  "$PROBE_SOURCE" \
  -o "$PACKAGED_EXECUTABLE"
"$PACKAGED_EXECUTABLE" "$PACKAGED_RESOURCE_BUNDLE"
install -m 755 "$ORIGINAL_EXECUTABLE" "$PACKAGED_EXECUTABLE"

codesign --sign - --force --deep "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

printf 'Packaged app: %s\n' "$APP_BUNDLE"
