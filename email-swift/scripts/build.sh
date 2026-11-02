#!/usr/bin/env bash
# Build Email Vault.app for macOS (run on a Mac with Xcode 15+).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
CONFIGURATION=Release

usage() {
  cat <<USAGE
Usage: scripts/build.sh [--dry-run] [--debug]

Builds dist/Email Vault.app via xcodebuild / swift build.
Requires macOS 14+ and Xcode 15+ (Swift 5.9+).

Options:
  --dry-run   Print the commands that would run; do not build.
  --debug     Build Debug instead of Release.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --debug) CONFIGURATION=Debug; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)"

DIST="$ROOT/dist"
APP="$DIST/Email Vault.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Resolving Swift packages"
run swift package resolve

BUILT=""
CONFIG_LOWER=$(echo "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')

if xcodebuild -version >/dev/null 2>&1; then
  echo "==> xcodebuild ($CONFIGURATION) via Swift Package"
  DERIVED="$ROOT/.build/DerivedData"
  run mkdir -p "$DERIVED"
  # Open Package.swift schemes (EmailVault executable)
  run xcodebuild \
    -scheme EmailVault \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED" \
    -destination 'platform=macOS' \
    ONLY_ACTIVE_ARCH=NO \
    build
  if [[ "$DRY_RUN" -eq 0 ]]; then
    BUILT=$(find "$DERIVED/Build/Products" -name 'EmailVault' -type f | head -1 || true)
  else
    BUILT="$DERIVED/Build/Products/$CONFIGURATION/EmailVault"
  fi
else
  echo "==> xcodebuild not found; using swift build"
  if [[ "$CONFIGURATION" == "Release" ]]; then
    run swift build -c release --product EmailVault
    BUILT="$ROOT/.build/release/EmailVault"
  else
    run swift build --product EmailVault
    BUILT="$ROOT/.build/debug/EmailVault"
  fi
fi

echo "==> Assembling $APP"
run rm -rf "$APP"
run mkdir -p "$MACOS" "$RESOURCES"

INFO="$CONTENTS/Info.plist"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "+ write Info.plist -> $INFO"
else
  cat > "$INFO" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Email Vault</string>
  <key>CFBundleIconFile</key>
  <string>EmailVault</string>
  <key>CFBundleIdentifier</key>
  <string>local.email-vault</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Email Vault</string>
  <key>CFBundleDisplayName</key>
  <string>Email Vault</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "+ cp <built binary> -> \"$MACOS/Email Vault\""
  echo "+ chmod 755 \"$MACOS/Email Vault\""
else
  if [[ -z "${BUILT:-}" || ! -f "$BUILT" ]]; then
    echo "error: built binary not found (looked for EmailVault under DerivedData / .build)" >&2
    exit 1
  fi
  cp "$BUILT" "$MACOS/Email Vault"
  chmod 755 "$MACOS/Email Vault"
fi

# App icon.
ICON="$ROOT/../assets/EmailVault.icns"
if [[ -f "$ICON" ]]; then
  run cp "$ICON" "$RESOURCES/EmailVault.icns"
else
  echo "warning: $ICON not found; app will use the generic icon" >&2
fi

# Brand PDFs: the app reads Contents/Resources/BrandIcons (no SPM Bundle.module in .app).
BRAND_PDFS="$ROOT/Sources/EmailVaultApp/Resources/BrandIcons"
if [[ -d "$BRAND_PDFS" ]]; then
  run mkdir -p "$RESOURCES/BrandIcons"
  run cp -R "$BRAND_PDFS/." "$RESOURCES/BrandIcons/"
else
  echo "warning: $BRAND_PDFS not found; brand logos will fall back to initials" >&2
fi

echo "==> Done: $APP ($VERSION build $BUILD_NUMBER)"
echo "    Unsigned; open with: open \"$APP\""
echo "    First launch may need right-click → Open (Gatekeeper)."
