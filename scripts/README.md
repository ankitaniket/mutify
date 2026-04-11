# Mutify release scripts

## One-time setup

```bash
# Install Sparkle CLI tools (download tarball, extract to ~/Downloads/sparkle-tools)
cd ~/Downloads
URL=$(curl -s https://api.github.com/repos/sparkle-project/Sparkle/releases/latest \
    | grep browser_download_url | grep tar.xz | head -1 | cut -d '"' -f 4)
curl -LO "$URL"
mkdir -p ~/Downloads/sparkle-tools
tar -xf Sparkle-*.tar.xz -C ~/Downloads/sparkle-tools

# Verify everything is wired up
scripts/setup-sparkle-keys.sh
```

The private signing key lives in your **login Keychain only**. Back it up to a
password manager once — if you wipe this Mac without the backup, every Mutify
install in the wild loses its update path forever.

## Cutting a release

```bash
# Bump version, build, package, sign, regenerate appcast.xml
scripts/release.sh 1.1.0

# Review what changed
git diff project.yml appcast.xml

# Commit, tag, push
git add project.yml appcast.xml
git commit -m "Release 1.1.0"
git tag v1.1.0
git push origin main --tags

# Upload the DMG to GitHub Releases
gh release create v1.1.0 dist/Mutify-1.1.0.dmg \
    --title "Mutify 1.1.0" \
    --notes "Release notes here…"
```

That's it. Sparkle clients will see the new appcast item, verify the EdDSA
signature against the public key baked into their installed app, download the
DMG from the GitHub release URL, and update.

## Environment

If your Sparkle CLI tools live somewhere other than `~/Downloads/sparkle-tools/bin`,
set `SPARKLE_BIN` before running the scripts:

```bash
SPARKLE_BIN=/path/to/Sparkle/bin scripts/release.sh 1.1.0
```

## Things the scripts will refuse to do

- Run if `SUPublicEDKey` is missing from `project.yml`.
- Run if `sign_update` produces no signature (wrong/missing private key).
- Continue if a private-key file is anywhere in `git status`.
- Touch the public history with secrets.
