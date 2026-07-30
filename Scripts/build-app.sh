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
STATE_FILE="$REPO_ROOT/.build-app-transaction"
SOURCE_RESOURCES_DIR="$REPO_ROOT/Sources/RussianCornerCore/Resources"
ENGLISH_RESOURCE_NAMES=(
  english-lexemes.json
  english-sentences.json
  english-topics.json
  english-lessons.json
)
APP_ICON_PATH="$REPO_ROOT/Assets/AppIcon/RussianCorner.icns"
CODESIGN_BIN=${CODESIGN_BIN:-/usr/bin/codesign}

STAGING_ROOT=""
NEW_DIST=""
STAGED_APP=""
BACKUP_DIST=""
LOCK_HELD=0
TRANSACTION_OWNER_TOKEN=""
TRANSACTION_OWNED=0
OLD_MOVED=0
NEW_PUBLISHED=0
PUBLISH_COMMITTED=0

english_resource_manifest_hash() {
  resource_directory=$1
  for resource_name in "${ENGLISH_RESOURCE_NAMES[@]}"; do
    shasum -a 256 "$resource_directory/$resource_name" |
      awk '{print $1}'
  done | shasum -a 256 | awk '{print $1}'
}

GIT_ADMIN_DIR=$(
  /usr/bin/git -C "$REPO_ROOT" rev-parse --absolute-git-dir
)
LOCK_FILE=$(
  /usr/bin/git -C "$REPO_ROOT" rev-parse \
    --path-format=absolute \
    --git-path russian-corner-build.lock
)
if [ "$LOCK_FILE" != "$GIT_ADMIN_DIR/russian-corner-build.lock" ] ||
  [ -L "$LOCK_FILE" ] ||
  { [ -e "$LOCK_FILE" ] && [ ! -f "$LOCK_FILE" ]; }; then
  printf 'error: unsafe build lock file: %s\n' "$LOCK_FILE" >&2
  exit 1
fi
exec 9>"$LOCK_FILE"
if ! /usr/bin/lockf -s -t 0 9; then
  printf 'error: another build-app process holds %s\n' "$LOCK_FILE" >&2
  exit 1
fi
LOCK_HELD=1

entry_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

is_trusted_root_entry() {
  trusted_path=$1
  [ "$(dirname -- "$trusted_path")" = "$REPO_ROOT" ] || return 1
  trusted_name=$(basename -- "$trusted_path")
  case "$trusted_name" in
    .build-app-stage.* | .build-app-backup.* | .build-app-transaction)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_real_root_directory() {
  directory_path=$1
  directory_label=$2
  if ! is_trusted_root_entry "$directory_path"; then
    printf 'error: %s is outside trusted repository entries: %s\n' \
      "$directory_label" "$directory_path" >&2
    return 1
  fi
  if [ -L "$directory_path" ] || [ ! -d "$directory_path" ]; then
    printf 'error: %s is not a real directory: %s\n' \
      "$directory_label" "$directory_path" >&2
    return 1
  fi
  real_directory=$(
    CDPATH= cd -- "$directory_path"
    pwd -P
  )
  if [ "$real_directory" != "$directory_path" ]; then
    printf 'error: %s resolves outside its trusted path: %s\n' \
      "$directory_label" "$directory_path" >&2
    return 1
  fi
}

remove_trusted_root_entry() {
  scratch_entry=$1
  if ! is_trusted_root_entry "$scratch_entry"; then
    printf 'error: refusing to clean unexpected scratch path: %s\n' \
      "$scratch_entry" >&2
    return 1
  fi

  if [ -L "$scratch_entry" ]; then
    /bin/rm -f -- "$scratch_entry"
  elif [ -f "$scratch_entry" ]; then
    /bin/rm -f -- "$scratch_entry"
  elif [ -d "$scratch_entry" ]; then
    validate_real_root_directory "$scratch_entry" "scratch entry" || return 1
    /bin/rm -rf -- "$scratch_entry"
  fi
}

validate_dist_directory() {
  if [ -L "$DIST_DIR" ]; then
    printf 'error: refusing symlinked dist path: %s\n' "$DIST_DIR" >&2
    return 1
  fi
  if [ -e "$DIST_DIR" ] && [ ! -d "$DIST_DIR" ]; then
    printf 'error: dist path is not a directory: %s\n' "$DIST_DIR" >&2
    return 1
  fi
  if [ -d "$DIST_DIR" ]; then
    real_dist=$(
      CDPATH= cd -- "$DIST_DIR"
      pwd -P
    )
    if [ "$real_dist" != "$DIST_DIR" ]; then
      printf 'error: dist resolved outside repository: %s\n' "$real_dist" >&2
      return 1
    fi
    existing_app="$DIST_DIR/$APP_NAME"
    if [ -L "$existing_app" ]; then
      printf 'error: refusing symlinked app path: %s\n' "$existing_app" >&2
      return 1
    fi
  fi
}

validate_transaction_paths() {
  state_staging_root=${STATE_NEW_DIST%/new-dist}
  if [ "$state_staging_root/new-dist" != "$STATE_NEW_DIST" ] ||
    [ "$(dirname -- "$state_staging_root")" != "$REPO_ROOT" ]; then
    printf 'error: transaction new-dist path is untrusted\n' >&2
    return 1
  fi
  state_stage_name=$(basename -- "$state_staging_root")
  case "$state_stage_name" in
    .build-app-stage.?*)
      ;;
    *)
      printf 'error: transaction staging root is untrusted\n' >&2
      return 1
      ;;
  esac

  if [ "$(dirname -- "$STATE_BACKUP_DIST")" != "$REPO_ROOT" ]; then
    printf 'error: transaction backup path is untrusted\n' >&2
    return 1
  fi
  expected_backup_name=".build-app-backup.${state_stage_name#.build-app-stage.}"
  if [ "$(basename -- "$STATE_BACKUP_DIST")" != "$expected_backup_name" ]; then
    printf 'error: transaction backup does not match staging token\n' >&2
    return 1
  fi

  if entry_exists "$state_staging_root"; then
    validate_real_root_directory "$state_staging_root" \
      "transaction staging root" || return 1
  fi
  if entry_exists "$STATE_NEW_DIST"; then
    if [ -L "$STATE_NEW_DIST" ] || [ ! -d "$STATE_NEW_DIST" ]; then
      printf 'error: transaction new-dist is not a real directory\n' >&2
      return 1
    fi
  fi
  if entry_exists "$STATE_BACKUP_DIST"; then
    validate_real_root_directory "$STATE_BACKUP_DIST" \
      "transaction backup" || return 1
  fi
}

load_transaction_state() {
  if [ -L "$STATE_FILE" ] || [ ! -f "$STATE_FILE" ]; then
    printf 'error: transaction state is not a regular root file\n' >&2
    return 1
  fi
  STATE_PHASE=$(sed -n '1p' "$STATE_FILE")
  STATE_OWNER_TOKEN=$(sed -n '2p' "$STATE_FILE")
  STATE_BACKUP_DIST=$(sed -n '3p' "$STATE_FILE")
  STATE_NEW_DIST=$(sed -n '4p' "$STATE_FILE")
  state_line_count=$(wc -l <"$STATE_FILE" | tr -d '[:space:]')
  if [ "$state_line_count" != "4" ]; then
    printf 'error: transaction state has an invalid line count\n' >&2
    return 1
  fi
  case "$STATE_OWNER_TOKEN" in
    "" | *[!A-Za-z0-9._-]*)
      printf 'error: transaction owner token is invalid\n' >&2
      return 1
      ;;
  esac
  case "$STATE_PHASE" in
    prepared | old_moved | new_published)
      ;;
    *)
      printf 'error: transaction phase is invalid: %s\n' "$STATE_PHASE" >&2
      return 1
      ;;
  esac
  validate_transaction_paths
}

transaction_state_owner_matches() {
  expected_owner=$1
  [ -f "$STATE_FILE" ] &&
    [ ! -L "$STATE_FILE" ] &&
    [ "$(sed -n '2p' "$STATE_FILE")" = "$expected_owner" ]
}

write_transaction_phase() {
  next_phase=$1
  if [ "$TRANSACTION_OWNED" -eq 1 ] &&
    ! transaction_state_owner_matches "$TRANSACTION_OWNER_TOKEN"; then
    printf 'error: transaction ownership changed before phase update\n' >&2
    return 1
  fi
  state_temp="$STAGING_ROOT/transaction-state.next"
  printf '%s\n%s\n%s\n%s\n' \
    "$next_phase" \
    "$TRANSACTION_OWNER_TOKEN" \
    "$BACKUP_DIST" \
    "$NEW_DIST" >"$state_temp"
  chmod 0600 "$state_temp"
  /bin/mv -f "$state_temp" "$STATE_FILE"
  if ! transaction_state_owner_matches "$TRANSACTION_OWNER_TOKEN"; then
    printf 'error: transaction ownership could not be established\n' >&2
    return 1
  fi
  TRANSACTION_OWNED=1
}

remove_transaction_state_for_owner() {
  expected_owner=$1
  if [ -L "$STATE_FILE" ]; then
    printf 'error: refusing symlinked transaction state\n' >&2
    return 1
  fi
  if [ -e "$STATE_FILE" ]; then
    if [ ! -f "$STATE_FILE" ]; then
      printf 'error: transaction state is not a regular file\n' >&2
      return 1
    fi
    if ! transaction_state_owner_matches "$expected_owner"; then
      printf 'error: refusing transaction state owned by another process\n' >&2
      return 1
    fi
    /bin/rm -f -- "$STATE_FILE"
  fi
}

remove_owned_transaction_state() {
  if [ "$TRANSACTION_OWNED" -ne 1 ]; then
    printf 'error: current process does not own transaction state\n' >&2
    return 1
  fi
  remove_transaction_state_for_owner "$TRANSACTION_OWNER_TOKEN"
  TRANSACTION_OWNED=0
}

final_dist_is_valid() {
  validate_dist_directory >/dev/null 2>&1 || return 1
  recovery_app="$DIST_DIR/$APP_NAME"
  recovery_executable="$recovery_app/Contents/MacOS/$EXECUTABLE_NAME"
  recovery_resources="$recovery_app/Contents/Resources"
  [ -d "$recovery_app" ] &&
    [ ! -L "$recovery_app" ] &&
    [ -x "$recovery_executable" ] &&
    [ ! -L "$recovery_executable" ] &&
    [ -f "$recovery_app/Contents/Info.plist" ] &&
    [ ! -L "$recovery_app/Contents/Info.plist" ] &&
    [ -f "$recovery_resources/lexemes.json" ] &&
    [ ! -L "$recovery_resources/lexemes.json" ] &&
    [ -f "$recovery_resources/sentences.json" ] &&
    [ ! -L "$recovery_resources/sentences.json" ] &&
    [ -f "$recovery_resources/trial-slice.json" ] &&
    [ ! -L "$recovery_resources/trial-slice.json" ] &&
    [ -f "$recovery_resources/english-lexemes.json" ] &&
    [ ! -L "$recovery_resources/english-lexemes.json" ] &&
    [ -f "$recovery_resources/english-sentences.json" ] &&
    [ ! -L "$recovery_resources/english-sentences.json" ] &&
    [ -f "$recovery_resources/english-topics.json" ] &&
    [ ! -L "$recovery_resources/english-topics.json" ] &&
    [ -f "$recovery_resources/english-lessons.json" ] &&
    [ ! -L "$recovery_resources/english-lessons.json" ] &&
    "$CODESIGN_BIN" --verify --deep --strict "$recovery_app" \
      >/dev/null 2>&1
}

recover_transaction() {
  entry_exists "$STATE_FILE" || return 0
  load_transaction_state || return 1
  recovery_owner_token=$STATE_OWNER_TOKEN

  recovery_staging_root=${STATE_NEW_DIST%/new-dist}
  backup_exists=0
  dist_exists=0
  entry_exists "$STATE_BACKUP_DIST" && backup_exists=1
  entry_exists "$DIST_DIR" && dist_exists=1

  if [ "$dist_exists" -eq 0 ]; then
    if [ "$backup_exists" -ne 1 ]; then
      printf 'error: transaction has neither final dist nor backup\n' >&2
      return 1
    fi
    /bin/mv -h "$STATE_BACKUP_DIST" "$DIST_DIR"
    printf 'Recovered previous dist from interrupted transaction.\n'
  elif [ "$backup_exists" -eq 1 ]; then
    if final_dist_is_valid; then
      remove_trusted_root_entry "$STATE_BACKUP_DIST" || return 1
      printf 'Recovered committed dist from interrupted transaction.\n'
    else
      if ! entry_exists "$recovery_staging_root"; then
        printf 'error: cannot quarantine invalid final dist without staging\n' >&2
        return 1
      fi
      rejected_dist="$recovery_staging_root/rejected-dist"
      if entry_exists "$rejected_dist"; then
        printf 'error: recovery quarantine already exists\n' >&2
        return 1
      fi
      /bin/mv -h "$DIST_DIR" "$rejected_dist"
      /bin/mv -h "$STATE_BACKUP_DIST" "$DIST_DIR"
      printf 'Restored backup after invalid interrupted publication.\n'
    fi
  elif [ "$STATE_PHASE" = "new_published" ] &&
    ! final_dist_is_valid; then
    printf 'error: interrupted publication has no valid final dist or backup\n' >&2
    return 1
  fi

  if entry_exists "$recovery_staging_root"; then
    remove_trusted_root_entry "$recovery_staging_root" || return 1
  fi
  remove_transaction_state_for_owner "$recovery_owner_token"
}

rollback_publish() {
  if [ "$LOCK_HELD" -ne 1 ] || [ "$TRANSACTION_OWNED" -ne 1 ]; then
    printf 'error: refusing rollback without lock and transaction ownership\n' >&2
    return 1
  fi
  if [ "$PUBLISH_COMMITTED" -eq 1 ]; then
    return 0
  fi
  if ! transaction_state_owner_matches "$TRANSACTION_OWNER_TOKEN"; then
    printf 'error: refusing rollback after transaction ownership changed\n' >&2
    return 1
  fi

  if [ "$NEW_PUBLISHED" -eq 1 ] && entry_exists "$DIST_DIR"; then
    if entry_exists "$NEW_DIST"; then
      printf 'error: rollback new-dist target already exists\n' >&2
      return 1
    fi
    /bin/mv -h "$DIST_DIR" "$NEW_DIST"
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

  remove_owned_transaction_state
}

cleanup() {
  result=$?
  trap - EXIT HUP INT TERM

  if [ "$LOCK_HELD" -ne 1 ]; then
    exit "$result"
  fi

  if [ "$result" -ne 0 ] && [ "$TRANSACTION_OWNED" -eq 1 ]; then
    rollback_publish || result=1
  fi

  if [ "$TRANSACTION_OWNED" -eq 0 ] &&
    ! entry_exists "$STATE_FILE" &&
    [ -n "$STAGING_ROOT" ] &&
    entry_exists "$STAGING_ROOT"; then
    remove_trusted_root_entry "$STAGING_ROOT" || result=1
  fi

  exit "$result"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [ ! -x "$CODESIGN_BIN" ]; then
  printf 'error: codesign command is not executable: %s\n' "$CODESIGN_BIN" >&2
  exit 1
fi

recover_transaction
validate_dist_directory

STAGING_ROOT=$(mktemp -d "$REPO_ROOT/.build-app-stage.XXXXXX")
chmod 0700 "$STAGING_ROOT"
validate_real_root_directory "$STAGING_ROOT" "staging root"

NEW_DIST="$STAGING_ROOT/new-dist"
if entry_exists "$DIST_DIR"; then
  /bin/cp -a "$DIST_DIR" "$NEW_DIST"
else
  mkdir -m 0755 "$NEW_DIST"
fi
if [ -L "$NEW_DIST" ] || [ ! -d "$NEW_DIST" ]; then
  printf 'error: staged dist snapshot is not a real directory\n' >&2
  exit 1
fi
REAL_NEW_DIST=$(
  CDPATH= cd -- "$NEW_DIST"
  pwd -P
)
if [ "$REAL_NEW_DIST" != "$NEW_DIST" ]; then
  printf 'error: staged dist snapshot resolves outside staging\n' >&2
  exit 1
fi

STAGED_APP="$NEW_DIST/$APP_NAME"
if entry_exists "$STAGED_APP"; then
  REPLACED_APP="$STAGING_ROOT/replaced-app"
  if entry_exists "$REPLACED_APP"; then
    printf 'error: staged replaced-app entry already exists\n' >&2
    exit 1
  fi
  /bin/mv -h "$STAGED_APP" "$REPLACED_APP"
fi

if [ -n "${RUSSIAN_CORNER_TEST_BUILD_DELAY_SECONDS:-}" ]; then
  if [ "${RUSSIAN_CORNER_PACKAGING_TEST_MODE:-}" != "1" ]; then
    printf 'error: build delay hook requires packaging test mode\n' >&2
    exit 1
  fi
  sleep "$RUSSIAN_CORNER_TEST_BUILD_DELAY_SECONDS"
fi

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
  [ ! -f "$SOURCE_RESOURCES_DIR/sentences.json" ] ||
  [ ! -f "$SOURCE_RESOURCES_DIR/trial-slice.json" ] ||
  [ ! -f "$SOURCE_RESOURCES_DIR/topics.json" ] ||
  [ ! -f "$SOURCE_RESOURCES_DIR/long-term-sentences.json" ]; then
  printf 'error: source JSON resources are incomplete\n' >&2
  exit 1
fi
for resource_name in "${ENGLISH_RESOURCE_NAMES[@]}"; do
  if [ ! -f "$SOURCE_RESOURCES_DIR/$resource_name" ]; then
    printf 'error: English resource is missing: %s\n' \
      "$resource_name" >&2
    exit 1
  fi
done
if [ ! -f "$APP_ICON_PATH" ]; then
  printf 'error: app icon is missing: %s\n' "$APP_ICON_PATH" >&2
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
SOURCE_TRIAL_SLICE_SHA_BEFORE=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/trial-slice.json" | awk '{print $1}'
)
SOURCE_TOPICS_SHA_BEFORE=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/topics.json" | awk '{print $1}'
)
SOURCE_LONG_TERM_SHA_BEFORE=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/long-term-sentences.json" | awk '{print $1}'
)
SOURCE_ENGLISH_SHA_BEFORE=$(
  english_resource_manifest_hash "$SOURCE_RESOURCES_DIR"
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
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/trial-slice.json" \
  "$STAGED_RESOURCES/trial-slice.json"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/topics.json" \
  "$STAGED_RESOURCES/topics.json"
install -m 0644 \
  "$SOURCE_RESOURCES_DIR/long-term-sentences.json" \
  "$STAGED_RESOURCES/long-term-sentences.json"
for resource_name in "${ENGLISH_RESOURCE_NAMES[@]}"; do
  install -m 0644 \
    "$SOURCE_RESOURCES_DIR/$resource_name" \
    "$STAGED_RESOURCES/$resource_name"
done
install -m 0644 \
  "$APP_ICON_PATH" \
  "$STAGED_RESOURCES/RussianCorner.icns"

SOURCE_LEXEMES_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/lexemes.json" | awk '{print $1}'
)
SOURCE_SENTENCES_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/sentences.json" | awk '{print $1}'
)
SOURCE_TRIAL_SLICE_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/trial-slice.json" | awk '{print $1}'
)
SOURCE_TOPICS_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/topics.json" | awk '{print $1}'
)
SOURCE_LONG_TERM_SHA_AFTER=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/long-term-sentences.json" | awk '{print $1}'
)
STAGED_LEXEMES_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/lexemes.json" | awk '{print $1}'
)
STAGED_SENTENCES_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/sentences.json" | awk '{print $1}'
)
STAGED_TRIAL_SLICE_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/trial-slice.json" | awk '{print $1}'
)
STAGED_TOPICS_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/topics.json" | awk '{print $1}'
)
STAGED_LONG_TERM_SHA=$(
  shasum -a 256 "$STAGED_RESOURCES/long-term-sentences.json" | awk '{print $1}'
)
SOURCE_ENGLISH_SHA_AFTER=$(
  english_resource_manifest_hash "$SOURCE_RESOURCES_DIR"
)
STAGED_ENGLISH_SHA=$(
  english_resource_manifest_hash "$STAGED_RESOURCES"
)
if [ "$SOURCE_LEXEMES_SHA_BEFORE" != "$SOURCE_LEXEMES_SHA_AFTER" ] ||
  [ "$SOURCE_SENTENCES_SHA_BEFORE" != "$SOURCE_SENTENCES_SHA_AFTER" ] ||
  [ "$SOURCE_TRIAL_SLICE_SHA_BEFORE" != "$SOURCE_TRIAL_SLICE_SHA_AFTER" ] ||
  [ "$SOURCE_TOPICS_SHA_BEFORE" != "$SOURCE_TOPICS_SHA_AFTER" ] ||
  [ "$SOURCE_LONG_TERM_SHA_BEFORE" != "$SOURCE_LONG_TERM_SHA_AFTER" ] ||
  [ "$SOURCE_LEXEMES_SHA_AFTER" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$SOURCE_SENTENCES_SHA_AFTER" != "$STAGED_SENTENCES_SHA" ] ||
  [ "$SOURCE_TRIAL_SLICE_SHA_AFTER" != "$STAGED_TRIAL_SLICE_SHA" ] ||
  [ "$SOURCE_TOPICS_SHA_AFTER" != "$STAGED_TOPICS_SHA" ] ||
  [ "$SOURCE_LONG_TERM_SHA_AFTER" != "$STAGED_LONG_TERM_SHA" ]; then
  printf 'error: JSON resources changed or differed during staging\n' >&2
  exit 1
fi
if [ "$SOURCE_ENGLISH_SHA_BEFORE" != "$SOURCE_ENGLISH_SHA_AFTER" ] ||
  [ "$SOURCE_ENGLISH_SHA_AFTER" != "$STAGED_ENGLISH_SHA" ]; then
  printf 'error: English JSON resources changed during staging\n' >&2
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
/usr/libexec/PlistBuddy -c \
  "Add :CFBundleIconFile string RussianCorner.icns" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool false" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :LSMinimumSystemVersion string 14.0" "$STAGED_INFO_PLIST"
/usr/libexec/PlistBuddy -c \
  "Add :NSMicrophoneUsageDescription string Russian Corner 需要读取实时麦克风音量以估算口述活动；不会录音或保存音频。" \
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
  [ "$(stat -f '%Lp' "$STAGED_RESOURCES/sentences.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$STAGED_RESOURCES/trial-slice.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$STAGED_RESOURCES/RussianCorner.icns")" != "644" ]; then
  printf 'error: staged app permissions are incorrect\n' >&2
  exit 1
fi
for resource_name in "${ENGLISH_RESOURCE_NAMES[@]}"; do
  if [ "$(stat -f '%Lp' "$STAGED_RESOURCES/$resource_name")" != "644" ]; then
    printf 'error: staged English resource permissions are incorrect\n' >&2
    exit 1
  fi
done
printf 'permissions=PASS resources=0755 executable=0755 json=0644\n'

validate_dist_directory
stage_token=$(basename -- "$STAGING_ROOT")
BACKUP_DIST="$REPO_ROOT/.build-app-backup.${stage_token##*.}"
if entry_exists "$BACKUP_DIST"; then
  printf 'error: backup entry already exists: %s\n' "$BACKUP_DIST" >&2
  exit 1
fi
if entry_exists "$STATE_FILE"; then
  printf 'error: transaction state reappeared before publication\n' >&2
  exit 1
fi

TRANSACTION_OWNER_TOKEN=$(
  /usr/bin/uuidgen | tr '[:upper:]' '[:lower:]'
)
case "$TRANSACTION_OWNER_TOKEN" in
  "" | *[!A-Za-z0-9._-]*)
    printf 'error: generated transaction owner token is invalid\n' >&2
    exit 1
    ;;
esac
write_transaction_phase "prepared"
if entry_exists "$DIST_DIR"; then
  /bin/mv -h "$DIST_DIR" "$BACKUP_DIST"
  OLD_MOVED=1
fi
write_transaction_phase "old_moved"

if [ -n "${RUSSIAN_CORNER_TEST_PAUSE_AFTER_OLD_MOVED_SECONDS:-}" ]; then
  if [ "${RUSSIAN_CORNER_PACKAGING_TEST_MODE:-}" != "1" ]; then
    printf 'error: transaction pause requires packaging test mode\n' >&2
    exit 1
  fi
  pause_until=$((SECONDS + RUSSIAN_CORNER_TEST_PAUSE_AFTER_OLD_MOVED_SECONDS))
  while [ "$SECONDS" -lt "$pause_until" ]; do
    :
  done
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
write_transaction_phase "new_published"

if [ -L "$DIST_DIR" ] || [ ! -d "$DIST_DIR" ]; then
  printf 'error: published dist is not a real directory\n' >&2
  exit 1
fi
FINAL_REAL_DIST=$(
  CDPATH= cd -- "$DIST_DIR"
  pwd -P
)
if [ "$FINAL_REAL_DIST" != "$DIST_DIR" ]; then
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
FINAL_TRIAL_SLICE_SHA=$(
  shasum -a 256 "$FINAL_RESOURCES/trial-slice.json" | awk '{print $1}'
)
FINAL_TOPICS_SHA=$(
  shasum -a 256 "$FINAL_RESOURCES/topics.json" | awk '{print $1}'
)
FINAL_LONG_TERM_SHA=$(
  shasum -a 256 "$FINAL_RESOURCES/long-term-sentences.json" | awk '{print $1}'
)
CURRENT_SOURCE_LEXEMES_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/lexemes.json" | awk '{print $1}'
)
CURRENT_SOURCE_SENTENCES_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/sentences.json" | awk '{print $1}'
)
CURRENT_SOURCE_TRIAL_SLICE_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/trial-slice.json" | awk '{print $1}'
)
CURRENT_SOURCE_TOPICS_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/topics.json" | awk '{print $1}'
)
CURRENT_SOURCE_LONG_TERM_SHA=$(
  shasum -a 256 "$SOURCE_RESOURCES_DIR/long-term-sentences.json" | awk '{print $1}'
)
FINAL_ENGLISH_SHA=$(
  english_resource_manifest_hash "$FINAL_RESOURCES"
)
CURRENT_SOURCE_ENGLISH_SHA=$(
  english_resource_manifest_hash "$SOURCE_RESOURCES_DIR"
)
if [ "$CURRENT_SOURCE_LEXEMES_SHA" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$CURRENT_SOURCE_SENTENCES_SHA" != "$STAGED_SENTENCES_SHA" ] ||
  [ "$CURRENT_SOURCE_TRIAL_SLICE_SHA" != "$STAGED_TRIAL_SLICE_SHA" ] ||
  [ "$CURRENT_SOURCE_TOPICS_SHA" != "$STAGED_TOPICS_SHA" ] ||
  [ "$CURRENT_SOURCE_LONG_TERM_SHA" != "$STAGED_LONG_TERM_SHA" ] ||
  [ "$FINAL_LEXEMES_SHA" != "$STAGED_LEXEMES_SHA" ] ||
  [ "$FINAL_SENTENCES_SHA" != "$STAGED_SENTENCES_SHA" ] ||
  [ "$FINAL_TRIAL_SLICE_SHA" != "$STAGED_TRIAL_SLICE_SHA" ] ||
  [ "$FINAL_TOPICS_SHA" != "$STAGED_TOPICS_SHA" ] ||
  [ "$FINAL_LONG_TERM_SHA" != "$STAGED_LONG_TERM_SHA" ]; then
  printf 'error: final JSON resources differ from source or staging\n' >&2
  exit 1
fi
if [ "$CURRENT_SOURCE_ENGLISH_SHA" != "$STAGED_ENGLISH_SHA" ] ||
  [ "$FINAL_ENGLISH_SHA" != "$STAGED_ENGLISH_SHA" ]; then
  printf 'error: final English resources differ from source or staging\n' >&2
  exit 1
fi

plutil -lint "$FINAL_APP/Contents/Info.plist"
"$CODESIGN_BIN" --verify --deep --strict --verbose=2 "$FINAL_APP"
if [ "$(stat -f '%Lp' "$FINAL_RESOURCES")" != "755" ] ||
  [ "$(stat -f '%Lp' "$FINAL_EXECUTABLE")" != "755" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/lexemes.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/sentences.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/trial-slice.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/topics.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/long-term-sentences.json")" != "644" ] ||
  [ "$(stat -f '%Lp' "$FINAL_RESOURCES/RussianCorner.icns")" != "644" ]; then
  printf 'error: published app permissions are incorrect\n' >&2
  exit 1
fi
for resource_name in "${ENGLISH_RESOURCE_NAMES[@]}"; do
  if [ "$(stat -f '%Lp' "$FINAL_RESOURCES/$resource_name")" != "644" ]; then
    printf 'error: published English resource permissions are incorrect\n' >&2
    exit 1
  fi
done

PUBLISH_COMMITTED=1
NEW_PUBLISHED=0
if [ "$OLD_MOVED" -eq 1 ]; then
  remove_trusted_root_entry "$BACKUP_DIST"
  OLD_MOVED=0
fi
if entry_exists "$STAGING_ROOT"; then
  remove_trusted_root_entry "$STAGING_ROOT"
fi
STAGING_ROOT=""
remove_owned_transaction_state

printf \
  'resource_sha256=PASS lexemes=%s sentences=%s trial_slice=%s topics=%s long_term=%s\n' \
  "$FINAL_LEXEMES_SHA" \
  "$FINAL_SENTENCES_SHA" \
  "$FINAL_TRIAL_SLICE_SHA" \
  "$FINAL_TOPICS_SHA" \
  "$FINAL_LONG_TERM_SHA"
printf 'english_resource_sha256=PASS manifest=%s\n' "$FINAL_ENGLISH_SHA"
printf 'Published app: %s\n' "$FINAL_APP"
