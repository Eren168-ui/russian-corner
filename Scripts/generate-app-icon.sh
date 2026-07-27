#!/usr/bin/env bash

set -euo pipefail

script_dir=$(
  CDPATH= cd -- "$(dirname -- "$0")"
  pwd -P
)
repo_root=$(
  CDPATH= cd -- "$script_dir/.."
  pwd -P
)
source_png=${1:-"$repo_root/Assets/AppIcon/RussianCorner-source.png"}
output_icns=${2:-"$repo_root/Assets/AppIcon/RussianCorner.icns"}

if [ ! -f "$source_png" ]; then
  printf 'generate_app_icon=FAIL reason=missing_source path=%s\n' \
    "$source_png" >&2
  exit 1
fi

width=$(sips -g pixelWidth "$source_png" | awk '/pixelWidth/ {print $2}')
height=$(sips -g pixelHeight "$source_png" | awk '/pixelHeight/ {print $2}')
if [ "$width" != "$height" ] || [ "$width" -lt 1024 ]; then
  printf \
    'generate_app_icon=FAIL reason=invalid_source_dimensions width=%s height=%s\n' \
    "$width" "$height" >&2
  exit 1
fi

work_root=$(mktemp -d "${TMPDIR:-/tmp}/russian-corner-icon.XXXXXX")
trap 'rm -rf -- "$work_root"' EXIT HUP INT TERM
iconset="$work_root/RussianCorner.iconset"
mkdir -p "$iconset" "$(dirname -- "$output_icns")"

make_representation() {
  pixels=$1
  filename=$2
  sips \
    --resampleHeightWidth "$pixels" "$pixels" \
    "$source_png" \
    --out "$iconset/$filename" \
    >/dev/null
}

make_representation 16 icon_16x16.png
make_representation 32 icon_16x16@2x.png
make_representation 32 icon_32x32.png
make_representation 64 icon_32x32@2x.png
make_representation 128 icon_128x128.png
make_representation 256 icon_128x128@2x.png
make_representation 256 icon_256x256.png
make_representation 512 icon_256x256@2x.png
make_representation 512 icon_512x512.png
make_representation 1024 icon_512x512@2x.png

iconutil -c icns "$iconset" -o "$output_icns"
chmod 0644 "$output_icns"
printf \
  'generate_app_icon=PASS source=%sx%s representations=10 output=%s\n' \
  "$width" "$height" "$output_icns"
