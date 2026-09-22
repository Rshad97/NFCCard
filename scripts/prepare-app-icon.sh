#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$ROOT_DIR/design/AppIconSource.png"
DEST_DIR="$ROOT_DIR/NFCCard/Assets.xcassets/AppIcon.appiconset"
DEST="$DEST_DIR/AppIcon.png"

if ! command -v sips >/dev/null 2>&1; then
  echo "error: sips is required (macOS)" >&2
  exit 1
fi

test -f "$SOURCE"
mkdir -p "$DEST_DIR"

sips -z 1024 1024 "$SOURCE" --out "$DEST" >/dev/null

WIDTH=$(sips -g pixelWidth "$DEST" | awk '/pixelWidth/{print $2}')
HEIGHT=$(sips -g pixelHeight "$DEST" | awk '/pixelHeight/{print $2}')

test "$WIDTH" = "1024"
test "$HEIGHT" = "1024"

echo "Prepared AppIcon.png (${WIDTH}x${HEIGHT})"
