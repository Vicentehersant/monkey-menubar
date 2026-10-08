#!/bin/bash
# make-icon.sh — build Monkey.icns from the Monkey OS logo with sips + iconutil
# (no Xcode needed). Output: build/Monkey.icns. Called by make-app.sh.
#
#   SOURCE=<png> ./make-icon.sh   # override the logo

set -euo pipefail
cd "$(dirname "$0")"

SOURCE="${SOURCE:-$HOME/Desktop/Monkey OS app/Monkey-os-logo.png}"
OUT_DIR="build"
ICONSET="$OUT_DIR/Monkey.iconset"
ICNS="$OUT_DIR/Monkey.icns"

if [ ! -f "$SOURCE" ]; then
  echo "make-icon: logo not found at $SOURCE — skipping icon" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"

# Square the source first (the logo is 723x724) on a transparent canvas.
SQ="$OUT_DIR/icon-1024.png"
sips -s format png -z 1024 1024 "$SOURCE" --out "$SQ" > /dev/null

for size in 16 32 128 256 512; do
  sips -z $size $size "$SQ" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  dbl=$((size * 2))
  sips -z $dbl $dbl "$SQ" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET" "$SQ"
echo "icon: $ICNS"
