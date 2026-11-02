#!/usr/bin/env bash
# Build the DMG for the version in VERSION and publish it as a GitHub Release (tag v<version>).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="v$VERSION"
DMG="$ROOT/dist/EmailVault-$VERSION.dmg"
DRY_RUN=0

usage() {
  cat <<USAGE
Usage: scripts/release.sh [--dry-run]

Publishes Email Vault $VERSION (from VERSION) as GitHub Release $TAG with the DMG attached.
Bump VERSION and commit before running. Requires: clean main branch pushed to origin, gh login.

Options:
  --dry-run   Check preconditions and print the release notes; publish nothing.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

# --- preconditions -----------------------------------------------------------
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION '$VERSION' is not MAJOR.MINOR.PATCH"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main"
[[ -z "$(git status --porcelain)" ]] || die "working tree not clean"
gh auth status >/dev/null 2>&1 || die "gh is not logged in"
git fetch --quiet --tags origin
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || die "HEAD differs from origin/main; push first"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  die "tag $TAG already exists; bump VERSION"
fi
if gh release view "$TAG" >/dev/null 2>&1; then
  die "release $TAG already exists on GitHub"
fi

# --- notes -------------------------------------------------------------------
PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
RANGE="${PREV_TAG:+$PREV_TAG..}HEAD"
CHANGES="$(git log --no-merges --format='- %s' "$RANGE" | grep -E '^- (feat|fix|perf)(\(|:)' || true)"
[[ -n "$CHANGES" ]] || CHANGES="- 维护性更新"

build_notes() {
  local sha="$1"
  cat <<NOTES
## 安装

1. 下载下方的 \`EmailVault-$VERSION.dmg\`，双击打开。
2. 把 **Email Vault** 拖到「应用程序」。升级时选择「替换」，数据保存在 \`~/.local/share/email-vault/\`，不受影响。
3. 首次打开：本应用未经 Apple 公证，系统会提示无法验证开发者。点「完成」，然后到
   **系统设置 → 隐私与安全性**，在页面底部点「仍要打开」。只需操作一次。

   也可以在终端执行：\`xattr -dr com.apple.quarantine "/Applications/Email Vault.app"\`

要求 macOS 14 或更高版本，Apple 芯片。

## 更新内容

$CHANGES

## 校验

\`\`\`
SHA-256  $sha  EmailVault-$VERSION.dmg
\`\`\`
NOTES
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "==> Would release $TAG (previous: ${PREV_TAG:-none})"
  echo
  build_notes "<computed after build>"
  exit 0
fi

# --- build & publish ---------------------------------------------------------
"$ROOT/scripts/package-dmg.sh"
[[ -f "$DMG" ]] || die "$DMG not found"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

NOTES_FILE="$(mktemp "${TMPDIR:-/tmp}/emailvault-notes.XXXXXX")"
trap 'rm -f "$NOTES_FILE"' EXIT
build_notes "$SHA" > "$NOTES_FILE"

echo "==> Tagging $TAG"
git tag -a "$TAG" -m "Email Vault $VERSION"
git push --quiet origin "$TAG"

echo "==> Publishing GitHub Release"
gh release create "$TAG" "$DMG" \
  --title "Email Vault $VERSION" \
  --notes-file "$NOTES_FILE" \
  --verify-tag

echo "==> Done: $(gh release view "$TAG" --json url --jq .url)"
