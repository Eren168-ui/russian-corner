#!/usr/bin/env bash

set -euo pipefail

repo_root=$(
  CDPATH= cd -- "$(dirname -- "$0")/../.."
  pwd -P
)
app_path=${1:-"$repo_root/dist/Russian Corner.app"}
info_plist="$app_path/Contents/Info.plist"
icon_path="$app_path/Contents/Resources/RussianCorner.icns"

if [ ! -f "$info_plist" ]; then
  printf 'app_icon=FAIL reason=missing_info_plist path=%s\n' \
    "$info_plist" >&2
  exit 1
fi

declared_icon=$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' \
    "$info_plist" 2>/dev/null || true
)
if [ "$declared_icon" != "RussianCorner.icns" ]; then
  printf 'app_icon=FAIL reason=undeclared_icon actual=%s\n' \
    "${declared_icon:-<missing>}" >&2
  exit 1
fi

if [ ! -f "$icon_path" ]; then
  printf 'app_icon=FAIL reason=missing_icns path=%s\n' \
    "$icon_path" >&2
  exit 1
fi

dimensions=$(sips -g pixelWidth -g pixelHeight "$icon_path")
if [[ "$dimensions" != *"pixelWidth: 1024"* ]] ||
  [[ "$dimensions" != *"pixelHeight: 1024"* ]]; then
  printf 'app_icon=FAIL reason=missing_1024_representation\n' >&2
  exit 1
fi

printf 'app_icon=PASS declared=%s width=1024 height=1024\n' \
  "$declared_icon"
