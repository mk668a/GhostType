# Sparkle 2 CLI tools

The release script (`scripts/create-dmg.sh`) needs `sign_update` from Sparkle 2
to produce the Ed25519 signature embedded in `appcast.xml`. The binaries are
not checked in; download them once per machine:

```sh
SPARKLE_VERSION=2.9.2
TMP=$(mktemp -d)
curl -sL -o "$TMP/sparkle.tar.xz" \
  "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
tar -xJf "$TMP/sparkle.tar.xz" -C "$TMP"
cp "$TMP"/bin/{generate_keys,sign_update} tools/sparkle/
rm -rf "$TMP"
```

The private signing key lives in the macOS Keychain (created by `generate_keys`
on first use). The public key is embedded in `GhostType/Info.plist` as
`SUPublicEDKey` so Sparkle running on the client side verifies updates.

If you ever need to recover the public key for a new build machine, run
`./tools/sparkle/generate_keys -p` to print it without overwriting the existing
private key.
