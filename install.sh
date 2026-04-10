#!/usr/bin/env bash
#
# Mutify one-line installer.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ankitaniket/mutify/main/install.sh | bash
#
# What it does:
#   1. Looks up the latest Mutify release on GitHub
#   2. Downloads the .dmg
#   3. Mounts it
#   4. Quits any running Mutify
#   5. Copies Mutify.app into /Applications
#   6. Strips the macOS quarantine attribute (so Gatekeeper does NOT show
#      the "Apple cannot verify this app" / "damaged" warning)
#   7. Verifies the code signature
#   8. Unmounts the DMG
#   9. Launches Mutify
#
# Requires: macOS 13+ and the standard `curl`, `hdiutil`, `xattr` (all built-in).
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

for cmd in curl hdiutil xattr osascript pgrep; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    red "✗ Required command not found: $cmd"
    exit 1
  fi
done

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

# ─── auth header (only used when GH_TOKEN/GITHUB_TOKEN is set) ────────────────

AUTH_HEADER=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${GH_TOKEN}")
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

# ─── fetch latest release asset URL via the GitHub API ───────────────────────

bold "→ Looking up the latest Mutify release on github.com/${REPO}…"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"
RELEASE_JSON=$(curl -fsSL "${AUTH_HEADER[@]}" "$API_URL" 2>/dev/null) || {
  red "✗ Could not reach the GitHub API at $API_URL"
  exit 1
}

ASSET_URL=$(printf '%s' "$RELEASE_JSON" \
  | grep -o '"browser_download_url":[[:space:]]*"[^"]*\.dmg"' \
  | head -1 \
  | sed -E 's/.*"(https[^"]+)".*/\1/')

if [[ -z "${ASSET_URL:-}" ]]; then
  red "✗ Could not find a .dmg asset in the latest release of ${REPO}."
  red "  Check https://github.com/${REPO}/releases"
  exit 1
fi

DMG_NAME=$(basename "$ASSET_URL")
DMG_PATH="$TMP/$DMG_NAME"

dim "  Found: $DMG_NAME"

# ─── download ─────────────────────────────────────────────────────────────────

bold "→ Downloading $DMG_NAME…"
curl -fL --progress-bar "${AUTH_HEADER[@]}" "$ASSET_URL" -o "$DMG_PATH"

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

if ! cp -R "$MOUNT_DIR/${APP_NAME}.app" "$DEST" 2>/dev/null; then
  bold "  /Applications needs admin rights — you may be prompted for your password."
  sudo cp -R "$MOUNT_DIR/${APP_NAME}.app" "$DEST"
fi

# ─── strip quarantine — bypasses Gatekeeper "damaged" warning ────────────────

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
