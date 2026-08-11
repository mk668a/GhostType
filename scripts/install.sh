#!/bin/bash
set -e

APP_NAME="GhostType"
SCHEME="GhostType"

# Signing identity, if one is configured.
#
# Without it the build is ad-hoc signed, and an ad-hoc signature's designated
# requirement is the binary's own hash. macOS keys Accessibility and Input
# Monitoring grants to that requirement, so every rebuild looks like a
# different app and quietly loses its permissions while System Settings still
# shows the toggle switched on.
#
# Run scripts/make-signing-cert.sh once to create a free self-signed identity,
# then export GHOSTTYPE_SIGN_IDENTITY to keep permissions across rebuilds.
SIGN_IDENTITY="${GHOSTTYPE_SIGN_IDENTITY:-}"
BUILD_DIR="$(mktemp -d)/build"
INSTALL_DIR="/Applications"

echo "==================================="
echo "  GhostType Installer"
echo "==================================="
echo ""

# Check for Xcode command line tools
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools are required."
    echo "Install with: xcode-select --install"
    exit 1
fi

# Find project directory (script is in scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[1/3] Building ${APP_NAME}..."
xcodebuild \
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -arch arm64 \
    build 2>&1 | tail -3

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed. ${APP_NAME}.app not found."
    exit 1
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "  Re-signing with: ${SIGN_IDENTITY}"
    # Inside out: a container seals its contents, so nested code has to be
    # signed before the bundle that holds it.
    while IFS= read -r -d '' item; do
        codesign --force --sign "$SIGN_IDENTITY" "$item"
    done < <(find "$APP_PATH/Contents" -depth -type f \
        \( -name '*.dylib' -o -perm -u+x \) ! -name "$APP_NAME" -print0)
    while IFS= read -r -d '' item; do
        codesign --force --sign "$SIGN_IDENTITY" "$item"
    done < <(find "$APP_PATH/Contents" -depth \
        \( -name '*.xpc' -o -name '*.app' -o -name '*.framework' \) -print0)
    codesign --force --sign "$SIGN_IDENTITY" \
        --entitlements "${PROJECT_DIR}/${APP_NAME}/${APP_NAME}.entitlements" \
        "$APP_PATH"
    echo "  Designated requirement:"
    codesign -d -r- "$APP_PATH" 2>&1 | grep designated | sed 's/^/    /'
else
    echo "  GHOSTTYPE_SIGN_IDENTITY unset: ad-hoc signed."
    echo "  Accessibility and Input Monitoring will need re-granting after this build."
    echo "  Run scripts/make-signing-cert.sh once to stop that happening."
fi

echo ""
echo "[2/3] Installing to ${INSTALL_DIR}/${APP_NAME}.app..."

# Quit the running copy before touching the bundle.
#
# Replacing an app underneath a live process leaves that process pointing at a
# bundle that no longer exists, and macOS reports it as
# "the code on disk does not match what is running" (errSecCSStaticCodeChanged).
# tccd cannot read a valid identity for such a process, so it refuses to match
# the Accessibility grant, and approving the app while it is in that state
# records the grant against an identity nothing will ever have again. The
# symptom is a permission that appears granted in System Settings while the app
# insists it is missing.
if pgrep -f "${INSTALL_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1; then
    echo "  Quitting the running ${APP_NAME}..."
    osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -f "${INSTALL_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || break
        sleep 0.5
    done
    pkill -f "${INSTALL_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
    sleep 1
fi

# Remove old version if exists
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
    echo "  Removing previous version..."
    rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

cp -R "$APP_PATH" "${INSTALL_DIR}/"

echo ""
echo "[3/3] Cleaning up..."
rm -rf "$BUILD_DIR"

echo ""
echo "==================================="
echo "  Installation complete!"
echo "==================================="
echo ""
echo "  ${APP_NAME}.app has been installed to ${INSTALL_DIR}/"
echo ""
echo "  To launch:"
echo "    open /Applications/${APP_NAME}.app"
echo ""
echo "  On first launch, grant Accessibility permission:"
echo "    System Settings > Privacy & Security > Accessibility"
echo ""
echo "  Make sure your LLM server is running (e.g., LM Studio)"
echo "  before using GhostType."
echo ""
