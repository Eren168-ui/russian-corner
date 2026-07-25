#!/usr/bin/env bash

set -euo pipefail

TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/russian-corner-package-test.XXXXXX")
SCRIPT_UNDER_TEST=${PACKAGING_SCRIPT_UNDER_TEST:-Scripts/build-app.sh}
cleanup() {
  rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

prepare_case() {
  CASE_ROOT="$TEST_ROOT/$1"
  SANDBOX_REPO="$CASE_ROOT/repository"
  FAKE_BIN="$CASE_ROOT/fake-bin"
  FAKE_BUILD="$CASE_ROOT/fake-build/release"
  BUILD_LOG="$CASE_ROOT/build.log"

  mkdir -p \
    "$SANDBOX_REPO/Scripts" \
    "$FAKE_BIN" \
    "$FAKE_BUILD"
  git -C "$SANDBOX_REPO" init -q
  cp "$SCRIPT_UNDER_TEST" "$SANDBOX_REPO/Scripts/build-app.sh"

  cat >"$FAKE_BIN/swift" <<'SH'
#!/usr/bin/env bash
if [ "${*: -1}" = "--show-bin-path" ]; then
  printf '%s\n' "$FAKE_BUILD"
fi
SH
  chmod +x "$FAKE_BIN/swift"
}

run_script() {
  export FAKE_BUILD
  PATH="$FAKE_BIN:$PATH" bash "$SANDBOX_REPO/Scripts/build-app.sh" \
    >"$BUILD_LOG" 2>&1
}

prepare_case "dist-symlink"
EXTERNAL_DIST="$CASE_ROOT/external-dist"
mkdir -p "$EXTERNAL_DIST/Russian Corner.app"
touch "$EXTERNAL_DIST/Russian Corner.app/sentinel"
ln -s "$EXTERNAL_DIST" "$SANDBOX_REPO/dist"
if run_script; then
  printf 'error: symlinked dist was accepted\n' >&2
  exit 1
fi
grep -F 'error: refusing symlinked dist path:' "$BUILD_LOG" >/dev/null
test -f "$EXTERNAL_DIST/Russian Corner.app/sentinel"

prepare_case "app-symlink"
EXTERNAL_APP="$CASE_ROOT/external-app"
mkdir -p "$SANDBOX_REPO/dist" "$EXTERNAL_APP"
touch "$EXTERNAL_APP/sentinel"
ln -s "$EXTERNAL_APP" "$SANDBOX_REPO/dist/Russian Corner.app"
if run_script; then
  printf 'error: symlinked app was accepted\n' >&2
  exit 1
fi
grep -F 'error: refusing symlinked app path:' "$BUILD_LOG" >/dev/null
test -f "$EXTERNAL_APP/sentinel"

printf 'build_app_symlink_safety=PASS\n'
