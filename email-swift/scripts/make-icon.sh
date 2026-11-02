#!/usr/bin/env bash
# Regenerate assets/EmailVault.icns from assets/icon.svg (requires rsvg-convert: brew install librsvg).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SVG="$ROOT/assets/icon.svg"
ICNS="$ROOT/assets/EmailVault.icns"

command -v rsvg-convert >/dev/null || { echo "error: rsvg-convert not found (brew install librsvg)" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/emailvault-icon.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
SET="$WORK/EmailVault.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$SET/icon_${size}x${size}.png"
  rsvg-convert -w $((size * 2)) -h $((size * 2)) "$SVG" -o "$SET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$SET" -o "$ICNS"
echo "==> Wrote $ICNS"
