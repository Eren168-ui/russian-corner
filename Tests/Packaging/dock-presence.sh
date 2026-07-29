#!/usr/bin/env bash

set -euo pipefail

repo_root=$(
  CDPATH= cd -- "$(dirname -- "$0")/../.."
  pwd -P
)
app_path=${1:-"$repo_root/dist/Russian Corner.app"}
info_plist="$app_path/Contents/Info.plist"

if [ ! -f "$info_plist" ]; then
  printf 'dock_presence=FAIL reason=missing_info_plist path=%s\n' \
    "$info_plist" >&2
  exit 1
fi

ui_element=$(
  /usr/libexec/PlistBuddy -c 'Print :LSUIElement' \
    "$info_plist" 2>/dev/null || true
)
if [ "$ui_element" = "true" ]; then
  printf 'dock_presence=FAIL reason=agent_app_hides_dock_icon\n' >&2
  exit 1
fi

printf 'dock_presence=PASS ls_ui_element=%s\n' \
  "${ui_element:-<absent>}"
