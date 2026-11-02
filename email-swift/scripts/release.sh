#!/usr/bin/env bash
# Build the DMG for the version in VERSION and publish it as a GitHub Release (tag v<version>).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="v$VERSION"
DMG="$ROOT/dist/EmailVault-$VERSION.dmg"
TAP_REPO="mortalxu98/homebrew-tap"
CASK_PATH="Casks/email-vault.rb"
DRY_RUN=0
UPDATE_TAP=1

usage() {
  cat <<USAGE
Usage: scripts/release.sh [--dry-run]

Publishes Email Vault $VERSION (from VERSION) as GitHub Release $TAG with the DMG attached.
Bump VERSION and commit before running. Requires: clean main branch pushed to origin, gh login.

Then bumps the Homebrew cask in $TAP_REPO to the new version and checksum.

Options:
  --dry-run   Check preconditions and print the release notes; publish nothing.
  --skip-tap  Don't update the Homebrew cask.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-tap) UPDATE_TAP=0; shift ;;
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

# Conventional-commit subjects of one type since the previous tag, prefix stripped.
commits_of() {
  git log --no-merges --format='%s' "$PREV_TAG..HEAD" \
    | sed -nE "s/^$1(\([^)]*\))?!?: (.*)/- \2/p"
}

# Prefer the curated CHANGELOG.md section for this version; fall back to commit subjects.
CHANGELOG="$ROOT/../CHANGELOG.md"
CHANGES=""
if [[ -f "$CHANGELOG" ]]; then
  CHANGES="$(awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { on = 1; next }
    on && /^## \[/ { exit }
    on && /^\[[^]]+\]: / { exit }
    on { print }
  ' "$CHANGELOG" | awk 'NF || seen { seen = 1; print }')"
fi

if [[ -n "$CHANGES" ]]; then
  :
elif [[ -z "$PREV_TAG" ]]; then
  CHANGES="首个发布版本：邮箱与平台账号管理、加密安全备注、续费提醒、Touch ID 解锁、修改主密码、自动锁定。完整功能见 [README](https://github.com/mortalxu98/email-vault#readme)。"
else
  FEATS="$(commits_of feat)"
  FIXES="$(commits_of '(fix|perf)')"
  CHANGES=""
  [[ -n "$FEATS" ]] && CHANGES+=$'### 新功能\n\n'"$FEATS"$'\n\n'
  [[ -n "$FIXES" ]] && CHANGES+=$'### 修复\n\n'"$FIXES"$'\n'
  [[ -n "$CHANGES" ]] || CHANGES="维护性更新。"
fi

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

echo "==> Released: $(gh release view "$TAG" --json url --jq .url)"

# --- Homebrew cask ------------------------------------------------------------
update_tap() {
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/emailvault-tap.XXXXXX")"
  # shellcheck disable=SC2064  # expand now: $work is local to this function
  trap "rm -rf '$work' '$NOTES_FILE'" EXIT
  gh repo clone "$TAP_REPO" "$work" -- --quiet
  sed -i '' -E \
    -e "s/^  version \"[^\"]+\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \"[0-9a-f]+\"/  sha256 \"$SHA\"/" \
    "$work/$CASK_PATH"
  if git -C "$work" diff --quiet; then
    echo "==> Cask already at $VERSION"
    return
  fi
  git -C "$work" commit --quiet -am "email-vault $VERSION"
  git -C "$work" push --quiet
  echo "==> Updated $TAP_REPO/$CASK_PATH to $VERSION"
}

if [[ "$UPDATE_TAP" -eq 1 ]]; then
  if gh repo view "$TAP_REPO" >/dev/null 2>&1; then
    update_tap
  else
    echo "warning: $TAP_REPO not found; skipped cask update" >&2
  fi
fi
