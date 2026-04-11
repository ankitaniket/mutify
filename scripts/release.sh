#!/usr/bin/env bash
#
# Mutify release script.
#
# Usage:
#     scripts/release.sh <new-version>     # e.g. scripts/release.sh 1.1.0
#
# What it does:
#   1. Validates inputs and tooling.
#   2. Bumps MARKETING_VERSION + CURRENT_PROJECT_VERSION in project.yml.
#   3. Regenerates Mutify.xcodeproj via xcodegen.
#   4. Builds a Release .app and packages it as dist/Mutify-<version>.dmg.
#   5. Signs the DMG using the Sparkle EdDSA key in your login Keychain.
#   6. Regenerates appcast.xml with generate_appcast (Sparkle's official tool).
#   7. Stops short of `git push` and `gh release create` so you can review.
#
# Security guardrails:
#   - Hard-fail if SUPublicEDKey is missing from project.yml.
#   - Hard-fail if signing produces no signature.
#   - Hard-fail if a private-key file would be committed.
#   - Never logs the private key.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ----- 1. Inputs & tooling ---------------------------------------------------

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <new-version>" >&2
    echo "Example: $0 1.1.0" >&2
    exit 1
fi
NEW_VERSION="$1"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version must look like X.Y.Z (got '$NEW_VERSION')" >&2
    exit 1
fi

SPARKLE_BIN="${SPARKLE_BIN:-$HOME/Downloads/sparkle-tools/bin}"
SIGN_UPDATE="$SPARKLE_BIN/sign_update"
GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"

for cmd in xcodegen xcodebuild hdiutil "$SIGN_UPDATE" "$GENERATE_APPCAST"; do
    if [[ ! -x "$cmd" ]] && ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required tool not found: $cmd" >&2
        echo "       set SPARKLE_BIN=/path/to/Sparkle/bin if Sparkle tools are elsewhere" >&2
        exit 1
    fi
done

# Make sure SUPublicEDKey is configured. Without it, Sparkle will reject every
# update, so shipping a release would be silently broken.
if ! grep -q '^[[:space:]]*SUPublicEDKey:' project.yml; then
    echo "Error: SUPublicEDKey is missing from project.yml" >&2
    echo "       Run scripts/setup-sparkle-keys.sh first." >&2
    exit 1
fi

# ----- 2. Bump version in project.yml ----------------------------------------

OLD_VERSION="$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' project.yml)"
echo "==> Bumping version: $OLD_VERSION -> $NEW_VERSION"

# Compute the next integer build number.
OLD_BUILD="$(awk -F'"' '/CURRENT_PROJECT_VERSION/ {print $2; exit}' project.yml)"
NEW_BUILD=$((OLD_BUILD + 1))

/usr/bin/sed -i '' \
    -e "s/MARKETING_VERSION: \"${OLD_VERSION}\"/MARKETING_VERSION: \"${NEW_VERSION}\"/" \
    -e "s/CURRENT_PROJECT_VERSION: \"${OLD_BUILD}\"/CURRENT_PROJECT_VERSION: \"${NEW_BUILD}\"/" \
    project.yml

# ----- 3. Regenerate the Xcode project ---------------------------------------

echo "==> Regenerating Xcode project"
xcodegen generate

# ----- 4. Build Release .app and package as DMG ------------------------------

DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

echo "==> Building Release .app"
xcodebuild \
    -project Mutify.xcodeproj \
    -scheme Mutify \
    -configuration Release \
    -derivedDataPath build \
    clean build \
    >/tmp/mutify-build.log 2>&1 || {
        echo "Error: build failed. See /tmp/mutify-build.log" >&2
        tail -30 /tmp/mutify-build.log >&2
        exit 1
    }

APP_PATH="$REPO_ROOT/build/Build/Products/Release/Mutify.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: built app not found at $APP_PATH" >&2
    exit 1
fi

# Defense-in-depth: confirm the built app actually has SUPublicEDKey.
if ! /usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
    echo "Error: built Mutify.app is missing SUPublicEDKey in Info.plist" >&2
    exit 1
fi

DMG_PATH="$DIST_DIR/Mutify-${NEW_VERSION}.dmg"
echo "==> Packaging $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Mutify ${NEW_VERSION}" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    >/dev/null

# ----- 5. Sign the DMG -------------------------------------------------------

echo "==> Signing DMG with Sparkle EdDSA key from Keychain"
SIGN_OUTPUT="$("$SIGN_UPDATE" "$DMG_PATH")"
if [[ -z "$SIGN_OUTPUT" ]] || [[ "$SIGN_OUTPUT" != *"sparkle:edSignature"* ]]; then
    echo "Error: sign_update produced no signature. Is the private key in your Keychain?" >&2
    exit 1
fi
echo "    $SIGN_OUTPUT"

# ----- 6. Regenerate appcast.xml ---------------------------------------------

echo "==> Regenerating appcast.xml"
"$GENERATE_APPCAST" \
    --download-url-prefix "https://github.com/ankitaniket/mutify/releases/download/v${NEW_VERSION}/" \
    "$DIST_DIR"

# generate_appcast writes dist/appcast.xml — promote it to the repo root.
if [[ -f "$DIST_DIR/appcast.xml" ]]; then
    mv "$DIST_DIR/appcast.xml" "$REPO_ROOT/appcast.xml"
fi

# ----- 7. Final guardrail: nothing private got staged ------------------------

if git status --porcelain | grep -E '(sparkle_private|ed25519.*\.key|\.private\.key)' >/dev/null; then
    echo "Error: a private key file appears in git status. Aborting before any commit." >&2
    exit 1
fi

echo
echo "✅ Release ${NEW_VERSION} prepared."
echo
echo "Next steps (review first, then run yourself):"
echo "    git diff project.yml appcast.xml"
echo "    git add project.yml appcast.xml"
echo "    git commit -m \"Release ${NEW_VERSION}\""
echo "    git tag v${NEW_VERSION}"
echo "    git push origin main --tags"
echo "    gh release create v${NEW_VERSION} ${DMG_PATH} --title \"Mutify ${NEW_VERSION}\" --notes \"...\""
