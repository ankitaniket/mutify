#!/usr/bin/env bash
#
# Mutify one-line installer.
#
# Usage (the repo is private, so we go through the gh CLI for auth):
#
#   gh auth login   # one-time, if not already
#   gh api repos/ankitaniket/mutify/contents/install.sh \
#     --jq .content | base64 -d | bash
#
# Or, simpler — clone-then-run:
#
#   gh repo clone ankitaniket/mutify /tmp/mutify-install \
#     && bash /tmp/mutify-install/install.sh
#
# What it does:
#   1. Downloads the latest Mutify release DMG from GitHub (via gh CLI)
#   2. Mounts it
#   3. Copies Mutify.app into /Applications
#   4. Strips the quarantine attribute (so macOS Gatekeeper does NOT show
#      the "Apple cannot verify this app" / "damaged" warning)
#   5. Unmounts the DMG
#   6. Launches Mutify
#
# Requires: macOS 13+, gh CLI (authenticated), hdiutil (built-in).
#

set -euo pipefail

REPO="ankitaniket/mutify"
APP_NAME="Mutify"
INSTALL_DIR="/Applications"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

# ─── sanity checks ────────────────────────────────────────────────────────────

if [[ "$(uname -s)" != "Darwin" ]]; then
  red "✗ Mutify only runs on macOS."
  exit 1
fi

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
if (( MACOS_MAJOR < 13 )); then
  red "✗ Mutify requires macOS 13 (Ventura) or later. You have $(sw_vers -productVersion)."
  exit 1
fi

for cmd in curl hdiutil xattr osascript pgrep gh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    red "✗ Required command not found: $cmd"
    if [[ "$cmd" == "gh" ]]; then
      red "  Install GitHub CLI:  brew install gh   (then: gh auth login)"
    fi
    exit 1
  fi
done

# The repo is private, so we need an authenticated gh session to fetch the asset.
if ! gh auth status >/dev/null 2>&1; then
  red "✗ GitHub CLI is not authenticated. Run:  gh auth login"
  exit 1
fi

# ─── temp workspace ───────────────────────────────────────────────────────────

TMP=$(mktemp -d)
MOUNT_DIR="$TMP/mount"
mkdir -p "$MOUNT_DIR"

cleanup() {
  if [[ -d "$MOUNT_DIR" ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

# ─── fetch + download latest release DMG via gh CLI ──────────────────────────

bold "→ Looking up the latest Mutify release on github.com/${REPO}…"

LATEST_TAG=$(gh release view --repo "$REPO" --json tagName --jq .tagName 2>/dev/null || true)
if [[ -z "${LATEST_TAG:-}" ]]; then
  red "✗ Could not find any releases on ${REPO}."
  red "  Check https://github.com/${REPO}/releases"
  exit 1
fi
dim "  Latest release: $LATEST_TAG"

bold "→ Downloading Mutify DMG…"
gh release download "$LATEST_TAG" \
  --repo "$REPO" \
  --pattern "*.dmg" \
  --dir "$TMP" \
  --clobber

DMG_PATH=$(ls "$TMP"/*.dmg 2>/dev/null | head -1)
if [[ -z "${DMG_PATH:-}" || ! -f "$DMG_PATH" ]]; then
  red "✗ DMG download failed."
  exit 1
fi
DMG_NAME=$(basename "$DMG_PATH")
dim "  Downloaded: $DMG_NAME"

# ─── mount ────────────────────────────────────────────────────────────────────

bold "→ Mounting DMG…"
hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_DIR"

if [[ ! -d "$MOUNT_DIR/${APP_NAME}.app" ]]; then
  red "✗ DMG does not contain ${APP_NAME}.app"
  exit 1
fi

# ─── quit running instance ────────────────────────────────────────────────────

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  bold "→ Quitting running ${APP_NAME}…"
  osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
  sleep 1
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 1
fi

# ─── install ──────────────────────────────────────────────────────────────────

DEST="${INSTALL_DIR}/${APP_NAME}.app"

bold "→ Installing to ${DEST}…"
if [[ -e "$DEST" ]]; then
  rm -rf "$DEST"
fi

# /Applications usually requires no sudo when owned by the current user.
if ! cp -R "$MOUNT_DIR/${APP_NAME}.app" "$DEST" 2>/dev/null; then
  bold "  /Applications needs admin rights — you may be prompted for your password."
  sudo cp -R "$MOUNT_DIR/${APP_NAME}.app" "$DEST"
fi

# ─── strip quarantine — this is the magic that bypasses Gatekeeper ───────────

bold "→ Removing quarantine attribute (bypasses Gatekeeper warning)…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || \
  sudo xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# ─── verify code signature ────────────────────────────────────────────────────

if codesign --verify --deep --strict "$DEST" >/dev/null 2>&1; then
  dim "  Signature verified."
else
  dim "  (Code signature is ad-hoc — that's expected for this build.)"
fi

# ─── launch ───────────────────────────────────────────────────────────────────

bold "→ Launching Mutify…"
open "$DEST"

echo
green "✓ Mutify installed successfully."
echo
echo "  • Look for the mic icon in your menu bar (top-right)."
echo "  • Press the global shortcut to mute/unmute (default: ⌘⇧0)."
echo "  • On first toggle, macOS will ask for Microphone permission — click Allow."
echo
echo "  Source & docs: https://github.com/${REPO}"
echo
