#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(
  CDPATH= cd -- "$(dirname -- "$0")"
  pwd -P
)
REPO_ROOT=$(
  CDPATH= cd -- "$SCRIPT_DIR/.."
  pwd -P
)

APP_NAME="Russian Corner.app"
EXECUTABLE_NAME="RussianCornerApp"
RESOURCE_PROBE_NAME="RussianCornerResourceProbe"
BUNDLE_IDENTIFIER="com.openclaw.russiancorner"
DIST_DIR="$REPO_ROOT/dist"
LOCK_DIR="$REPO_ROOT/.build-app.lock"
SOURCE_RESOURCES_DIR="$REPO_ROOT/Sources/RussianCornerCore/Resources"
CODESIGN_BIN=${CODESIGN_BIN:-/usr/bin/codesign}

STAGING_ROOT=""
NEW_DIST=""
STAGED_APP=""
BACKUP_DIST=""
LOCK_HELD=0
OLD_MOVED=0
NEW_PUBLISHED=0
PUBLISH_COMMITTED=0

entry_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

remove_trusted_scratch_entry() {
  scratch_entry=$1
  case "$scratch_entry" in
    "$REPO_ROOT"/.build-app-stage.* | "$REPO_ROOT"/.build-app-backup.*)
      ;;
    *)
      printf \
        'error: refusing to clean unexpected scratch path: %s\n' \
        "$scratch_entry" >&2
      return 1
      ;;
  esac

  if [ -L "$scratch_entry" ] || [ -f "$scratch_entry" ]; then
    /bin/rm -f -- "$scratch_entry"
  elif [ -d "$scratch_entry" ]; then
    /bin/rm -rf -- "$scratch_entry"
  fi
}

rollback_publish() {
  if [ "$PUBLISH_COMMITTED" -eq 1 ]; then
    return 0
  fi

  if [ "$NEW_PUBLISHED" -eq 1 ] && entry_exists "$DIST_DIR"; then
    rejected_dist="$STAGING_ROOT/rejected-dist"
    if entry_exists "$rejected_dist"; then
      printf 'error: rollback target already exists: %s\n' "$rejected_dist" >&2
      return 1
    fi
    /bin/mv -h "$DIST_DIR" "$rejected_dist"
    NEW_PUBLISHED=0
  fi

  if [ "$OLD_MOVED" -eq 1 ] && entry_exists "$BACKUP_DIST"; then
    if entry_exists "$DIST_DIR"; then
      printf 'error: cannot restore old dist; target exists\n' >&2
      return 1
    fi
    /bin/mv -h "$BACKUP_DIST" "$DIST_DIR"
    OLD_MOVED=0
  fi
}

cleanup() {
  result=$?
  trap - EXIT HUP INT TERM

  if [ "$result" -ne 0 ]; then
    rollback_publish || result=1
  fi

  if [ -n "$STAGING_ROOT" ] && entry_exists "$STAGING_ROOT"; then
    remove_trusted_scratch_entry "$STAGING_ROOT" || result=1
  fi

  if [ "$LOCK_HELD" -eq 1 ]; then
    if ! /bin/rmdir "$LOCK_DIR"; then
      printf 'error: failed to release build lock: %s\n' "$LOCK_DIR" >&2
      result=1
    fi
  fi

  exit "$result"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  printf \
    'error: another build-app process holds %s\n' \
    "$LOCK_DIR" >&2
  exit 1
fi
LOCK_HELD=1

if [ ! -x "$CODESIGN_BIN" ]; then
  printf 'error: codesign command is not executable: %s\n' "$CODESIGN_BIN" >&2
  exit 1
fi

if [ -L "$DIST_DIR" ]; then
  printf 'error: refusing symlinked dist path: %s\n' "$DIST_DIR" >&2
  exit 1
fi
if [ -e "$DIST_DIR" ] && [ ! -d "$DIST_DIR" ]; then
  printf 'error: dist path is not a directory: %s\n' "$DIST_DIR" >&2
  exit 1
fi
if [ -d "$DIST_DIR" ]; then
  REAL_DIST=$(
    CDPATH= cd -- "$DIST_DIR"
    pwd -P
  )
  if [ "$REAL_DIST" != "$REPO_ROOT/dist" ]; then
    printf 'error: dist resolved outside repository: %s\n' "$REAL_DIST" >&2
    exit 1
  fi
  EXISTING_APP="$DIST_DIR/$APP_NAME"
  if [ -L "$EXISTING_APP" ]; then
    printf 'error: refusing symlinked app path: %s\n' "$EXISTING_APP" >&2
    exit 1
  fi
fi

if [ -n "${RUSSIAN_CORNER_TEST_BUILD_DELAY_SECONDS:-}" ]; then
  if [ "${RUSSIAN_CORNER_PACKAGING_TEST_MODE:-}" != "1" ]; then
    printf 'error: build delay hook requires packaging test mode\n' >&2
    exit 1
  fi
  sleep "$RUSSIAN_CORNER_TEST_BUILD_DELAY_SECONDS"
fi

STAGING_ROOT=$(mktemp -d "$REPO_ROOT/.build-app-stage.XXXXXX")
chmod 0700 "$STAGING_ROOT"
STAGING_PARENT=$(
  CDPATH= cd -- "$(dirname -- "$STAGING_ROOT")"
  pwd -P
)
if [ "$STAGING_PARENT" != "$REPO_ROOT" ] || [ -L "$STAGING_ROOT" ]; then
  printf 'error: staging root is not a trusted repository entry\n' >&2
  exit 1
fi

NEW_DIST="$STAGING_ROOT/new-dist"
STAGED_APP="$NEW_DIST/$APP_NAME"
STAGED_CONTENTS="$STAGED_APP/Contents"
STAGED_MACOS="$STAGED_CONTENTS/MacOS"
STAGED_RESOURCES="$STAGED_CONTENTS/Resources"
STAGED_INFO_PLIST="$STAGED_CONTENTS/Info.plist"
STAGED_EXECUTABLE="$STAGED_MACOS/$EXECUTABLE_NAME"

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

if strings "$BUILT_EXECUTABLE" | grep -F "$REPO_ROOT" >/dev/null; then
  printf 'error: production executable contains repository path\n' >&2
  exit 1
fi
if strings "$BUILT_EXECUTABLE" |
  grep -E '\.build/.+RussianCorner_RussianCornerCore\.bundle|RussianCorner_RussianCornerCore\.bundle' \
    >/dev/null; then
  printf 'error: production executable contains SwiftPM resource fallback\n' >&2
  exit 1
fi

SOURCE_LEXEMES_SHA_BEFORE=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/lexemes.json" | awk '{print $1}'
)
SOURCE_SENTENCES_SHA_BEFORE=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/sentences.json" | awk '{print $1}'
)

mkdir -p "$STAGED_MACOS" "$STAGED_RESOURCES"
chmod 0755 \
  "$NEW_DIST" \
  "$STAGED_APP" \
  "$STAGED_CONTENTS" \
  "$STAGED_MACOS" \
  "$STAGED_RESOURCES"
install -m 0755 "$BUILT_EXECUTABLE" "$STAGED_EXECUTABLE"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/lexemes.json" \
  "$STAGED_RESOURCES/lexemes.json"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/sentences.json" \
  "$STAGED_RESOURCES/sentences.json"

SOURCE_LEXEMES_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/lexemes.json" | awk '{print $1}'
)
SOURCE_SENTENCES_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/sentences.json" | awk '{print $1}'
)
STAGED_LEXEMES_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/lexemes.json" | awk '{print $1}'
)
STAGED_SENTENCES_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/sentences.json" | awk '{print $1}'
)
if [ "$SOURCE_LEXEMES_SHA_BEFORE" != "$SOURCE_LEXEMES_SHA_AFTER" ] ||
  [ "$SOURCE_SENTENCES_SHA_BEFORE" != "$SOURCE_SENTENCES_SHA_AFTER" ] ||
  [ "$SOURCE_LEXEMES_SHA_AFTER" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$SOURCE_SENTENCES_SHA_AFTER" != "$STAGED_SENTENCES_SHA" ]; then
  printf 'error: JSON resources changed or differed during staging\n' >&2
  exit 1
fi

BUILT_SHA=$(shasum -a 256 "$BUILT_EXECUTABLE" | awk '{print $1}')
STAGED_EXECUTABLE_SHA=$(
  shasum -a 256 "$STAGED_EXECUTABLE" | awk '{print $1}'
)
if [ "$BUILT_SHA" != "$STAGED_EXECUTABLE_SHA" ]; then
  printf 'error: staged executable differs from SwiftPM product\n' >&2
  exit 1
fi
printf 'copied_executable_sha256=%s\n' "$BUILT_SHA"

plutil -create xml1 "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleIdentifier string $BUNDLE_IDENTIFIER" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleDisplayName string Russian Corner" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleName string Russian Corner" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleExecutable string $EXECUTABLE_NAME" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleShortVersionString string 1.0.0" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleVersion string 1" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :CFBundlePackageType string APPL" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :LSMinimumSystemVersion string 14.0" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :NSMicrophoneUsageDescription string Russian Corner 需要使用麦克风录制你的俄语练习；录音不会自动分析。" \
  "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :NSHighResolutionCapable bool true" "$STAGED_INFO_PLIST"
printf 'APPL????' >"$STAGED_CONTENTS/PkgInfo"
chmod 0644 "$STAGED_INFO_PLIST" "$STAGED_CONTENTS/PkgInfo"
plutil -lint "$STAGED_INFO_PLIST"

"$BUILT_RESOURCE_PROBE" "$STAGED_RESOURCES"
MISSING_RESOURCES_DIR="$STAGING_ROOT/missing-resources"
mkdir -m 0755 "$MISSING_RESOURCES_DIR"
if "$BUILT_RESOURCE_PROBE" "$MISSING_RESOURCES_DIR" \
  >"$STAGING_ROOT/missing-probe.log" 2>&1; then
  printf 'error: missing-resource probe unexpectedly succeeded\n' >&2
  exit 1
fi
if ! grep -q 'resource_probe=FAIL' "$STAGING_ROOT/missing-probe.log"; then
  printf 'error: missing-resource probe did not fail explicitly\n' >&2
  exit 1
fi
printf 'missing_resource_probe=PASS\n'

"$CODESIGN_BIN" --sign - --force --deep "$STAGED_APP"
"$CODESIGN_BIN" --verify --deep --strict --verbose=2 "$STAGED_APP"

if [ "$(stat -f '%Lp' "$STAGED_RESOURCES")" != "755" ] ||
  [ "$(stat -f '%Lp' "$STAGED_EXECUTABLE")" != "755" ] ||
  [ "$(stat -f '%Lp' "$STAGED_RESOURCES/lexemes.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$STAGED_RESOURCES/sentences.json")" != "644" ]; then
  printf 'error: staged app permissions are incorrect\n' >&2
  exit 1
fi
printf 'permissions=PASS resources=0755 executable=0755 json=0644\n'

stage_token=$(basename -- "$STAGING_ROOT")
BACKUP_DIST="$REPO_ROOT/.build-app-backup.${stage_token##*.}"
if entry_exists "$BACKUP_DIST"; then
  printf 'error: backup entry already exists: %s\n' "$BACKUP_DIST" >&2
  exit 1
fi

if entry_exists "$DIST_DIR"; then
  /bin/mv -h "$DIST_DIR" "$BACKUP_DIST"
  OLD_MOVED=1
fi
if [ "${RUSSIAN_CORNER_TEST_FORCE_PUBLISH_FAILURE:-0}" = "1" ]; then
  if [ "${RUSSIAN_CORNER_PACKAGING_TEST_MODE:-}" != "1" ]; then
    printf 'error: publish failure injection requires packaging test mode\n' >&2
    exit 1
  fi
  printf 'error: injected publish failure\n' >&2
  exit 1
fi
if entry_exists "$DIST_DIR"; then
  printf 'error: dist target reappeared during publish\n' >&2
  exit 1
fi
/bin/mv -h "$NEW_DIST" "$DIST_DIR"
NEW_PUBLISHED=1

if [ -L "$DIST_DIR" ] || [ ! -d "$DIST_DIR" ]; then
  printf 'error: published dist is not a real directory\n' >&2
  exit 1
fi
FINAL_REAL_DIST=$(
  CDPATH= cd -- "$DIST_DIR"
  pwd -P
)
if [ "$FINAL_REAL_DIST" != "$REPO_ROOT/dist" ]; then
  printf 'error: published dist resolved outside repository\n' >&2
  exit 1
fi

FINAL_APP="$DIST_DIR/$APP_NAME"
FINAL_RESOURCES="$FINAL_APP/Contents/Resources"
FINAL_EXECUTABLE="$FINAL_APP/Contents/MacOS/$EXECUTABLE_NAME"
FINAL_LEXEMES_SHA=$(
  shasum -a 256 "$FINAL_RESOURCES/lexemes.json" | awk '{print $1}'
)
FINAL_SENTENCES_SHA=$(
  shasum -a 256 "$FINAL_RESOURCES/sentences.json" | awk '{print $1}'
)
CURRENT_SOURCE_LEXEMES_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/lexemes.json" | awk '{print $1}'
)
CURRENT_SOURCE_SENTENCES_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/sentences.json" | awk '{print $1}'
)
if [ "$CURRENT_SOURCE_LEXEMES_SHA" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$CURRENT_SOURCE_SENTENCES_SHA" != "$STAGED_SENTENCES_SHA" ] ||
  [ "$FINAL_LEXEMES_SHA" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$FINAL_SENTENCES_SHA" != "$STAGED_SENTENCES_SHA" ]; then
  printf 'error: final JSON resources differ from source or staging\n' >&2
  exit 1
fi

plutil -lint "$FINAL_APP/Contents/Info.plist"
"$CODESIGN_BIN" --verify --deep --strict --verbose=2 "$FINAL_APP"
if [ "$(stat -f '%Lp' "$FINAL_RESOURCES")" != "755" ] ||
  [ "$(stat -f '%Lp' "$FINAL_EXECUTABLE")" != "755" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/lexemes.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/sentences.json")" != "644" ]; then
  printf 'error: published app permissions are incorrect\n' >&2
  exit 1
fi

if [ "$OLD_MOVED" -eq 1 ]; then
  remove_trusted_scratch_entry "$BACKUP_DIST"
  OLD_MOVED=0
fi
PUBLISH_COMMITTED=1
NEW_PUBLISHED=0

printf \
  'resource_sha256=PASS lexemes=%s sentences=%s\n' \
  "$FINAL_LEXEMES_SHA" \
  "$FINAL_SENTENCES_SHA"
printf 'Published app: %s\n' "$FINAL_APP"
