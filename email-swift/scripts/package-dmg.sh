#!/usr/bin/env bash
# Package dist/Email Vault.app into a drag-to-install DMG: dist/EmailVault-<version>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Email Vault"
VOL_NAME="Email Vault"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/EmailVault-$VERSION.dmg"
ICON="$ROOT/../assets/EmailVault.icns"

# Window geometry (points) and icon centers; keep in sync with dmg-background.swift.
WIN_W=660
WIN_H=400
ICON_SIZE=128
APP_POS="170, 185"
APPS_POS="490, 185"

DRY_RUN=0
SKIP_BUILD=0

usage() {
  cat <<USAGE
Usage: scripts/package-dmg.sh [--skip-build] [--dry-run]

Builds the app (Release) and packages it as $DIST/EmailVault-<version>.dmg
with a background image and an Applications shortcut.

Options:
  --skip-build  Package the existing dist/$APP_NAME.app as-is.
  --dry-run     Print the steps; do not build or write anything.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  [[ "$SKIP_BUILD" -eq 1 ]] || echo "+ scripts/build.sh"
  cat <<STEPS
+ render background (scripts/dmg-background.swift) -> .background/background.tiff
+ stage: "$APP_NAME.app", Applications -> /Applications; volume icon from assets/EmailVault.icns
+ hdiutil create (UDRW) -> attach -> Finder layout (${WIN_W}x${WIN_H}, icons ${ICON_SIZE}px) -> detach
+ hdiutil convert UDZO -> $DMG
STEPS
  exit 0
fi

if [[ -d "/Volumes/$VOL_NAME" ]]; then
  echo "error: /Volumes/$VOL_NAME is already mounted; eject it first." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT/scripts/build.sh"
fi
[[ -d "$APP" ]] || { echo "error: $APP not found; run scripts/build.sh first." >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/emailvault-dmg.XXXXXX")"
MOUNT_DEV=""
cleanup() {
  if [[ -n "$MOUNT_DEV" ]]; then
    hdiutil detach "$MOUNT_DEV" -quiet -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Rendering background"
swift "$ROOT/scripts/dmg-background.swift" "$WORK/bg.png" "$WORK/bg@2x.png"

echo "==> Staging"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$STAGE/.background/background.tiff" >/dev/null 2>&1

echo "==> Creating writable image"
RW_DMG="$WORK/rw.dmg"
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOL_NAME" -fs HFS+ \
  -format UDRW -size "${SIZE_MB}m" "$RW_DMG"

MOUNT_DEV="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen \
  | awk '/Apple_HFS/ {print $1; exit}')"
[[ -n "$MOUNT_DEV" ]] || { echo "error: failed to attach image" >&2; exit 1; }
MOUNT_POINT="/Volumes/$VOL_NAME"


echo "==> Laying out Finder window"
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, $((200 + WIN_W)), $((120 + WIN_H))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "$APP_NAME.app" of container window to {$APP_POS}
    set position of item "Applications" of container window to {$APPS_POS}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

# Volume icon goes in last: hdiutil -srcfolder drops it and Finder's layout pass clears it.
if [[ -f "$ICON" ]]; then
  cp "$ICON" "$MOUNT_POINT/.VolumeIcon.icns"
  SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns"
  SetFile -a C "$MOUNT_POINT"
else
  echo "warning: $ICON not found; DMG will use the generic disk icon" >&2
fi

# Let Finder flush .DS_Store before detaching.
sync
sleep 1
hdiutil detach "$MOUNT_DEV" -quiet
MOUNT_DEV=""

echo "==> Compressing"
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil convert -quiet "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
hdiutil verify -quiet "$DMG"

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
