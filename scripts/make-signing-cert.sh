#!/usr/bin/env bash
#
# Creates a free, self-signed code signing certificate so that GhostType's
# signature stays the same across rebuilds.
#
# Why this exists
# ---------------
# An ad-hoc signature (`codesign --sign -`) produces a designated requirement
# that is nothing but the binary's own hash:
#
#     designated => cdhash H"c6327a0e21052c70a4fbfe3218fca963b8b32e81"
#
# macOS keys Accessibility and Input Monitoring grants to that requirement, and
# the hash changes on every single build. So every rebuild, and every update
# delivered to a user through Sparkle, silently invalidates the permissions the
# app needs to do anything at all. The toggle stays visibly on in System
# Settings while the app is actually being denied, which is about the worst
# possible failure mode: it looks like a bug in the app.
#
# Signing with a certificate instead moves the requirement onto the certificate,
# which does not change when the code does:
#
#     designated => identifier "com.ghosttype.app" and certificate leaf = H"..."
#
# This does nothing for Gatekeeper. The certificate is self-signed, so the app
# is still not notarized and users still approve it by hand on first launch.
# Notarization needs a paid Apple Developer account; this script is about
# permissions surviving updates, which is a separate problem and free to fix.
#
# Usage:
#   scripts/make-signing-cert.sh                   # create it
#   security find-identity -v -p codesigning       # confirm it exists
#
# Then build with it:
#   export GHOSTTYPE_SIGN_IDENTITY="GhostType Self-Signed"
#   ./scripts/install.sh

set -euo pipefail

CERT_NAME="${GHOSTTYPE_CERT_NAME:-GhostType Self-Signed}"
DAYS="${GHOSTTYPE_CERT_DAYS:-3650}"

if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
    echo "A certificate named \"$CERT_NAME\" already exists."
    echo
    echo "Use it with:"
    echo "  export GHOSTTYPE_SIGN_IDENTITY=\"$CERT_NAME\""
    echo
    echo "To start over, delete it in Keychain Access (login keychain > My Certificates)."
    exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# `extendedKeyUsage = codeSigning` is the part that matters: without it,
# codesign refuses the identity. basicConstraints must say this is not a CA,
# or the certificate is treated as an intermediate and rejected.
cat > "$WORK_DIR/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[ dn ]
CN = $CERT_NAME

[ ext ]
basicConstraints       = critical, CA:false
keyUsage               = critical, digitalSignature
extendedKeyUsage       = critical, codeSigning
subjectKeyIdentifier   = hash
EOF

echo "Generating a self-signed code signing certificate: $CERT_NAME"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$WORK_DIR/key.pem" \
    -out "$WORK_DIR/cert.pem" \
    -days "$DAYS" \
    -config "$WORK_DIR/openssl.cnf" 2>/dev/null

# Two non-obvious requirements, both found by trying the alternatives:
#
#   * The PKCS12 must use the legacy PBE algorithms. OpenSSL 3 defaults to
#     AES-256 with a SHA-256 MAC, and macOS answers "MAC verification failed
#     during PKCS12 import (wrong password?)" for a file whose password is
#     perfectly correct.
#   * The password cannot be empty. An empty-password bundle fails the same
#     way. The value does not matter and never leaves this script, since the
#     key lives in the keychain afterwards.
P12_PASSWORD="ghosttype-transient"

openssl pkcs12 -export \
    -inkey "$WORK_DIR/key.pem" \
    -in "$WORK_DIR/cert.pem" \
    -out "$WORK_DIR/bundle.p12" \
    -name "$CERT_NAME" \
    -keypbe PBE-SHA1-3DES \
    -certpbe PBE-SHA1-3DES \
    -macalg sha1 \
    -passout "pass:$P12_PASSWORD" 2>/dev/null

echo
echo "Importing into your login keychain."
echo

# -T grants codesign access to the private key up front, so signing does not
# prompt on every build.
security import "$WORK_DIR/bundle.p12" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$P12_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

# Trust it for code signing only. This is the user's own trust domain, so it
# needs no sudo and affects nobody else's machine.
echo
echo "Marking it trusted for code signing (this will prompt for your password)."
security add-trusted-cert \
    -p codeSign \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    "$WORK_DIR/cert.pem"

echo
if security find-identity -v -p codesigning | grep -q "$CERT_NAME"; then
    echo "Done. The identity is available:"
    security find-identity -v -p codesigning | grep "$CERT_NAME"
    echo
    echo "Build with it:"
    echo "  export GHOSTTYPE_SIGN_IDENTITY=\"$CERT_NAME\""
    echo "  ./scripts/install.sh"
    echo
    echo "The first launch after switching from ad-hoc still needs the old grants"
    echo "cleared: remove GhostType from System Settings > Privacy & Security >"
    echo "Accessibility and Input Monitoring with the minus button, then approve"
    echo "it once more. From then on rebuilds should keep their permissions."
else
    echo "The certificate was imported but does not show up as a codesigning identity."
    echo "Open Keychain Access, find \"$CERT_NAME\" in the login keychain, and set"
    echo "its Code Signing trust to \"Always Trust\"."
    exit 1
fi
