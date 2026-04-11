#!/usr/bin/env bash
#
# One-time Sparkle key bootstrap helper.
#
# This script does NOT generate keys for you (the private key should never pass
# through any tool that didn't create it). It only checks state and prints the
# exact commands to run interactively.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SPARKLE_BIN="${SPARKLE_BIN:-$HOME/Downloads/sparkle-tools/bin}"
GENERATE_KEYS="$SPARKLE_BIN/generate_keys"

echo "==> Checking Sparkle CLI tools at $SPARKLE_BIN"
if [[ ! -x "$GENERATE_KEYS" ]]; then
    cat <<EOM
Sparkle CLI tools not found.

To install, run in a separate terminal:
    cd ~/Downloads
    URL=\$(curl -s https://api.github.com/repos/sparkle-project/Sparkle/releases/latest \\
        | grep browser_download_url | grep tar.xz | head -1 | cut -d '"' -f 4)
    curl -LO "\$URL"
    mkdir -p ~/Downloads/sparkle-tools
    tar -xf Sparkle-*.tar.xz -C ~/Downloads/sparkle-tools

Then re-run this script.
EOM
    exit 1
fi

echo "==> Checking login Keychain for an existing Sparkle private key"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if security find-generic-password \
        -s "https://sparkle-project.org" \
        -a "ed25519" \
        "$KEYCHAIN" >/dev/null 2>&1; then
    echo "    ✅ found — your private key is already in the Keychain."
    echo
    echo "    Public key (paste this into project.yml as SUPublicEDKey if missing):"
    "$GENERATE_KEYS" 2>/dev/null | grep -A1 SUPublicEDKey | tail -1 | sed 's/.*<string>//' | sed 's|</string>||'
else
    echo "    ❌ not found"
    echo
    cat <<EOM
No Sparkle private key in your Keychain yet.

To create one (this is interactive — do NOT run it through Claude):
    $GENERATE_KEYS

It will:
  • generate an EdDSA keypair
  • store the PRIVATE key in your login Keychain
  • print the PUBLIC key to your terminal

Then export the private key and back it up immediately:
    $GENERATE_KEYS -x ~/Desktop/sparkle_private.key
    open -e ~/Desktop/sparkle_private.key
    # paste contents into 1Password / Bitwarden / iCloud Keychain
    rm -P ~/Desktop/sparkle_private.key

Finally, add the PUBLIC key to project.yml under target settings:
    SUPublicEDKey: "<the-base64-string-here>"

Then re-run this script to verify.
EOM
    exit 1
fi

echo
echo "==> Verifying SUPublicEDKey is set in project.yml"
if grep -q '^[[:space:]]*SUPublicEDKey:' project.yml; then
    PUB_KEY="$(grep '^[[:space:]]*SUPublicEDKey:' project.yml | sed -E 's/.*"([^"]+)".*/\1/')"
    echo "    ✅ found: $PUB_KEY"
else
    echo "    ❌ missing — add it to project.yml under the Mutify target's settings.base"
    exit 1
fi

echo
echo "✅ Sparkle is ready. Use scripts/release.sh <version> to cut a release."
