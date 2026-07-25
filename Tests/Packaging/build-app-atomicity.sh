#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/russian-corner-atomic-test.XXXXXX")
SOURCE_SCRIPT=${PACKAGING_SCRIPT_UNDER_TEST:-Scripts/build-app.sh}
TEST_CASE=${PACKAGING_TEST_CASE:-all}

cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'error: %s\n' "$1" >&2
  return 1
}

wait_for_path() {
  path=$1
  attempts=0
  while [ "$attempts" -lt 100 ]; do
    if [ -e "$path" ] || [ -L "$path" ]; then
      return 0
    fi
    sleep 0.05
    attempts=$((attempts + 1))
  done
  fail "timed out waiting for $path"
}

prepare_case() {
  case_name=$1
  CASE_ROOT="$TEST_ROOT/$case_name"
  SANDBOX_REPO="$CASE_ROOT/repository"
  FAKE_BIN="$CASE_ROOT/fake-bin"
  FAKE_BUILD="$CASE_ROOT/fake-build/release"
  BUILD_MARKER="$CASE_ROOT/build-started"
  BUILD_LOG="$CASE_ROOT/build.log"
  FAKE_CODESIGN_OK="$CASE_ROOT/codesign-ok"
  FAKE_CODESIGN_FAIL="$CASE_ROOT/codesign-fail"

  mkdir -p \
    "$SANDBOX_REPO/Scripts" \
    "$SANDBOX_REPO/Sources/RussianCornerCore/Resources" \
    "$FAKE_BIN" \
    "$FAKE_BUILD"
  cp "$SOURCE_SCRIPT" "$SANDBOX_REPO/Scripts/build-app.sh"
  cp Sources/RussianCornerCore/Resources/lexemes.json \
    "$SANDBOX_REPO/Sources/RussianCornerCore/Resources/lexemes.json"
  cp Sources/RussianCornerCore/Resources/sentences.json \
    "$SANDBOX_REPO/Sources/RussianCornerCore/Resources/sentences.json"

  cat >"$FAKE_BIN/swift" <<'SH'
#!/usr/bin/env bash
for argument in "$@"; do
  if [ "$argument" = "--show-bin-path" ]; then
    printf '%s\n' "$FAKE_BUILD"
    exit 0
  fi
done
touch "$FAKE_BUILD_MARKER"
if [ "${FAKE_BUILD_DELAY_SECONDS:-0}" != "0" ]; then
  sleep "$FAKE_BUILD_DELAY_SECONDS"
fi
SH
  chmod +x "$FAKE_BIN/swift"

  cat >"$FAKE_BUILD/RussianCornerApp" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$FAKE_BUILD/RussianCornerApp"

  cat >"$FAKE_BUILD/RussianCornerResourceProbe" <<'SH'
#!/usr/bin/env bash
resource_directory=$1
if [ -f "$resource_directory/lexemes.json" ] &&
  [ -f "$resource_directory/sentences.json" ]; then
  printf 'resource_probe=PASS lexemes=360 sentences=72 directory=%s\n' \
    "$resource_directory"
  exit 0
fi
printf 'resource_probe=FAIL missing resources\n' >&2
exit 1
SH
  chmod +x "$FAKE_BUILD/RussianCornerResourceProbe"

  cat >"$FAKE_CODESIGN_OK" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$FAKE_CODESIGN_OK"

  cat >"$FAKE_CODESIGN_FAIL" <<'SH'
#!/usr/bin/env bash
printf 'injected codesign failure\n' >&2
exit 42
SH
  chmod +x "$FAKE_CODESIGN_FAIL"
}

create_signed_old_app() {
  app_path="$SANDBOX_REPO/dist/Russian Corner.app"
  mkdir -p \
    "$app_path/Contents/MacOS" \
    "$app_path/Contents/Resources"
  install -m 0755 /usr/bin/true \
    "$app_path/Contents/MacOS/RussianCornerApp"
  plutil -create xml1 "$app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c \
    'Add :CFBundleIdentifier string com.openclaw.russiancorner.old' \
    "$app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c \
    'Add :CFBundleExecutable string RussianCornerApp' \
    "$app_path/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c \
    'Add :CFBundlePackageType string APPL' \
    "$app_path/Contents/Info.plist"
  printf 'signed-old-app\n' >"$app_path/Contents/Resources/sentinel"
  /usr/bin/codesign --sign - --force --deep "$app_path"
  /usr/bin/codesign --verify --deep --strict "$app_path"
  OLD_EXECUTABLE_SHA=$(
    shasum -a 256 "$app_path/Contents/MacOS/RussianCornerApp" |
      awk '{print $1}'
  )
}

run_packager() {
  PATH="$FAKE_BIN:$PATH" \
    FAKE_BUILD="$FAKE_BUILD" \
    FAKE_BUILD_MARKER="$BUILD_MARKER" \
    CODESIGN_BIN="$1" \
    RUSSIAN_CORNER_PACKAGING_TEST_MODE=1 \
    RUSSIAN_CORNER_TEST_BUILD_DELAY_SECONDS="${2:-0}" \
    RUSSIAN_CORNER_TEST_FORCE_PUBLISH_FAILURE="${4:-0}" \
    FAKE_BUILD_DELAY_SECONDS="${3:-0}" \
    bash "$SANDBOX_REPO/Scripts/build-app.sh" \
    >"$BUILD_LOG" 2>&1
}

assert_old_app_unchanged() {
  app_path="$SANDBOX_REPO/dist/Russian Corner.app"
  test -f "$app_path/Contents/Resources/sentinel" ||
    fail "old app sentinel changed"
  current_sha=$(
    shasum -a 256 "$app_path/Contents/MacOS/RussianCornerApp" |
      awk '{print $1}'
  )
  [ "$current_sha" = "$OLD_EXECUTABLE_SHA" ] ||
    fail "old app executable hash changed"
  /usr/bin/codesign --verify --deep --strict "$app_path" ||
    fail "old app signature changed"
}

assert_no_packaging_scratch() {
  scratch_count=$(
    find "$SANDBOX_REPO" -maxdepth 1 \
      \( -name '.build-app-stage.*' -o -name '.build-app-backup.*' \
      -o -name '.build-app.lock' \) -print |
      wc -l |
      tr -d '[:space:]'
  )
  [ "$scratch_count" -eq 0 ] ||
    fail "packaging scratch entries remain"
}

test_codesign_failure_preserves_old_app() {
  prepare_case "codesign-failure"
  create_signed_old_app

  if run_packager "$FAKE_CODESIGN_FAIL"; then
    fail "injected codesign failure unexpectedly succeeded"
  fi
  assert_old_app_unchanged
  assert_no_packaging_scratch
  printf 'codesign_failure_preserves_old_app=PASS\n'
}

test_concurrent_build_is_rejected() {
  prepare_case "concurrency"
  create_signed_old_app

  run_packager "$FAKE_CODESIGN_OK" 2 0 &
  first_pid=$!
  wait_for_path "$SANDBOX_REPO/.build-app.lock"

  second_log="$CASE_ROOT/second-build.log"
  if PATH="$FAKE_BIN:$PATH" \
    FAKE_BUILD="$FAKE_BUILD" \
    FAKE_BUILD_MARKER="$BUILD_MARKER" \
    CODESIGN_BIN="$FAKE_CODESIGN_OK" \
    RUSSIAN_CORNER_PACKAGING_TEST_MODE=1 \
    bash "$SANDBOX_REPO/Scripts/build-app.sh" \
    >"$second_log" 2>&1; then
    fail "concurrent packager unexpectedly succeeded"
  fi
  grep -F 'error: another build-app process holds' "$second_log" >/dev/null ||
    fail "concurrent packager did not report lock contention"
  assert_old_app_unchanged

  wait "$first_pid"
  test -d "$SANDBOX_REPO/dist/Russian Corner.app" ||
    fail "first packager did not publish"
  assert_no_packaging_scratch
  printf 'concurrent_build_rejected=PASS\n'
}

test_dist_swap_never_touches_external_target() {
  prepare_case "dist-swap"
  create_signed_old_app
  external_target="$CASE_ROOT/external-target"
  mkdir -p "$external_target"
  printf 'external\n' >"$external_target/sentinel"

  run_packager "$FAKE_CODESIGN_OK" 2 0 &
  packager_pid=$!
  wait_for_path "$SANDBOX_REPO/.build-app.lock"
  /bin/mv -h "$SANDBOX_REPO/dist" "$SANDBOX_REPO/old-dist-by-test"
  ln -s "$external_target" "$SANDBOX_REPO/dist"

  wait "$packager_pid"
  test -f "$external_target/sentinel" ||
    fail "external sentinel changed"
  test -f \
    "$SANDBOX_REPO/old-dist-by-test/Russian Corner.app/Contents/Resources/sentinel" ||
    fail "pre-swap old dist changed"
  test -d "$SANDBOX_REPO/dist" ||
    fail "safe repository dist was not published"
  test ! -L "$SANDBOX_REPO/dist" ||
    fail "final dist remains a symlink"
  test -x \
    "$SANDBOX_REPO/dist/Russian Corner.app/Contents/MacOS/RussianCornerApp" ||
    fail "published app is missing"
  assert_no_packaging_scratch
  printf 'dist_swap_external_sentinel_safe=PASS\n'
}

test_publish_failure_restores_old_dist() {
  prepare_case "publish-failure"
  create_signed_old_app

  if run_packager "$FAKE_CODESIGN_OK" 0 0 1; then
    fail "injected publish failure unexpectedly succeeded"
  fi
  assert_old_app_unchanged
  assert_no_packaging_scratch
  printf 'publish_failure_restores_old_dist=PASS\n'
}

case "$TEST_CASE" in
  signfail)
    test_codesign_failure_preserves_old_app
    ;;
  concurrency)
    test_concurrent_build_is_rejected
    ;;
  toctou)
    test_dist_swap_never_touches_external_target
    ;;
  publishfail)
    test_publish_failure_restores_old_dist
    ;;
  all)
    test_codesign_failure_preserves_old_app
    test_concurrent_build_is_rejected
    test_dist_swap_never_touches_external_target
    test_publish_failure_restores_old_dist
    ;;
  *)
    fail "unknown PACKAGING_TEST_CASE: $TEST_CASE"
    ;;
esac
