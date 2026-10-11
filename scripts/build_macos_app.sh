#!/usr/bin/env bash
# Build "Email Vault.app" with PyInstaller into dist/.
# Safe to re-run: each run rebuilds from scratch. Never touches vault data
# (~/.local/share/email-vault); only the .app bundle is (re)placed.
#
# Usage: scripts/build_macos_app.sh [--install] [--dry-run]
#   --install   also copy the app to /Applications (replaces an older copy)
#   --dry-run   print the commands without running them
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Email Vault"
BUNDLE_ID="local.emailvault.app"
DIST="$ROOT/dist"
INSTALL_DIR="/Applications"
install=0
dry_run=0

for arg in "$@"; do
  case "$arg" in
    --install) install=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '+'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "macOS only" >&2; exit 1; }
cd "$ROOT"

run uv sync --group desktop
run uv run --group desktop pyinstaller \
  --noconfirm --clean --windowed \
  --name "$APP_NAME" \
  --icon "$ROOT/assets/EmailVault.icns" \
  --osx-bundle-identifier "$BUNDLE_ID" \
  --collect-data email_vault \
  --collect-data webview \
  --collect-submodules webview \
  --collect-submodules uvicorn \
  --distpath "$DIST" \
  --workpath "$ROOT/build/pyinstaller" \
  --specpath "$ROOT/build" \
  "$ROOT/packaging/app_entry.py"

app="$DIST/$APP_NAME.app"
echo "built: $app"

if [[ "$install" -eq 1 ]]; then
  target="$INSTALL_DIR/$APP_NAME.app"
  if [[ -e "$target" ]]; then
    echo "replacing existing $target"
    run rm -rf "$target"
  fi
  run ditto "$app" "$target"
  echo "installed: $target"
fi
