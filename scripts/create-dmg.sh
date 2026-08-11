#!/bin/bash
set -e

APP_NAME="GhostType"
VERSION="1.0.0"

# Signing and notarization are opt-in through the environment, so a contributor
# without an Apple Developer account still gets a working (unsigned) DMG and the
# release path is one `export` away rather than a separate script to remember.
#
#   export GHOSTTYPE_SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
#   export GHOSTTYPE_NOTARY_PROFILE="GhostType"   # xcrun notarytool store-credentials
SIGN_IDENTITY="${GHOSTTYPE_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${GHOSTTYPE_NOTARY_PROFILE:-}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$(mktemp -d)/build"
STAGING_DIR="$(mktemp -d)/dmg-staging"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/dist"
APPCAST="${PROJECT_DIR}/appcast.xml"
SIGN_UPDATE="${PROJECT_DIR}/tools/sparkle/sign_update"

echo "==================================="
echo "  GhostType DMG Builder"
echo "==================================="
echo ""

# Check for Xcode command line tools
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools required."
    echo "Install: xcode-select --install"
    exit 1
fi

# Build
echo "[1/5] Building ${APP_NAME} (Release)..."
xcodebuild \
    -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    build 2>&1 | grep -E "BUILD|error:" || true

APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build failed."
    exit 1
fi
echo "  Build succeeded."

# Re-sign everything with the chosen identity, inside out.
#
# Deepest-first ordering matters: each container is sealed over its contents,
# so re-signing a framework after its XPC services would invalidate the seal.
if [ -n "$SIGN_IDENTITY" ]; then
    echo "  Signing app with: ${SIGN_IDENTITY}"

    # See scripts/embed-llama.sh for why the hardened runtime is opt-in: it
    # requires a Team ID that only a real Developer ID provides, and applying it
    # with a self-signed or ad-hoc identity produces an app that cannot launch.
    SIGN_FLAGS=(--force --sign "$SIGN_IDENTITY")
    if [ "${GHOSTTYPE_HARDENED_RUNTIME:-0}" = "1" ]; then
        SIGN_FLAGS=(--force --options runtime --timestamp --sign "$SIGN_IDENTITY")
    fi

    sign_one() {
        codesign "${SIGN_FLAGS[@]}" "$1"
    }

    # Mach-O files first (Sparkle's Autoupdate, the XPC binaries, llama dylibs).
    while IFS= read -r -d '' item; do
        sign_one "$item"
    done < <(find "$APP_PATH/Contents" -depth -type f \
        \( -name '*.dylib' -o -perm -u+x \) ! -name 'GhostType' -print0)

    # Then the bundles that contain them.
    while IFS= read -r -d '' item; do
        sign_one "$item"
    done < <(find "$APP_PATH/Contents" -depth \
        \( -name '*.xpc' -o -name '*.app' -o -name '*.framework' \) -print0)

    codesign "${SIGN_FLAGS[@]}" \
        --entitlements "${PROJECT_DIR}/${APP_NAME}/${APP_NAME}.entitlements" \
        "$APP_PATH"

    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
else
    echo "  GHOSTTYPE_SIGN_IDENTITY unset: shipping an unsigned app."
    echo "  Users will see the 'unidentified developer' warning on first launch."
fi

# Stage DMG contents
echo "[2/5] Preparing DMG contents..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create DMG
echo "[3/5] Creating DMG..."
TEMP_DMG="${OUTPUT_DIR}/${APP_NAME}-temp.dmg"
rm -f "$TEMP_DMG" "${OUTPUT_DIR}/${DMG_NAME}"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$TEMP_DMG" \
    -quiet

# Convert to compressed read-only DMG
hdiutil convert \
    "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DIR}/${DMG_NAME}" \
    -quiet

rm -f "$TEMP_DMG"

# Sign, notarize, and staple the DMG.
#
# Stapling matters as much as notarizing: without the attached ticket, Gatekeeper
# has to reach Apple to verify, so a user opening the app offline still gets
# blocked. Sparkle delivers updates as DMGs through this same script, so skipping
# this step would break every auto-update, not just the first install.
if [ -n "$SIGN_IDENTITY" ]; then
    echo "  Signing DMG..."
    codesign --force --sign "$SIGN_IDENTITY" "${OUTPUT_DIR}/${DMG_NAME}"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    echo "  Notarizing (this takes a few minutes)..."
    if ! xcrun notarytool submit "${OUTPUT_DIR}/${DMG_NAME}" \
        --keychain-profile "$NOTARY_PROFILE" --wait; then
        echo "Error: notarization failed."
        echo "  Inspect it with: xcrun notarytool log <submission-id> --keychain-profile ${NOTARY_PROFILE}"
        exit 1
    fi
    xcrun stapler staple "${OUTPUT_DIR}/${DMG_NAME}"
    xcrun stapler validate "${OUTPUT_DIR}/${DMG_NAME}"
    spctl -a -t open --context context:primary-signature -v "${OUTPUT_DIR}/${DMG_NAME}"
else
    echo "  GHOSTTYPE_NOTARY_PROFILE unset: skipping notarization."
fi

# Cleanup
echo "[4/5] Cleaning up build tree..."
rm -rf "$BUILD_DIR" "$STAGING_DIR"

DMG_SIZE=$(du -h "${OUTPUT_DIR}/${DMG_NAME}" | cut -f1)

# Sign for Sparkle and update appcast.xml
echo "[5/5] Signing DMG and updating appcast..."

if [ ! -x "$SIGN_UPDATE" ]; then
    echo "Error: sign_update tool not found at ${SIGN_UPDATE}."
    echo "Download Sparkle 2 tools and place sign_update under tools/sparkle/."
    exit 1
fi

SIGN_OUTPUT="$("$SIGN_UPDATE" "${OUTPUT_DIR}/${DMG_NAME}")"
ED_SIG=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
DMG_LENGTH=$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [ -z "$ED_SIG" ] || [ -z "$DMG_LENGTH" ]; then
    echo "Error: failed to parse sign_update output:"
    echo "$SIGN_OUTPUT"
    exit 1
fi

BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${PROJECT_DIR}/${APP_NAME}/Info.plist")
PUB_DATE=$(LC_TIME=C date "+%a, %d %b %Y %H:%M:%S %z")
DOWNLOAD_URL="https://github.com/mk668a/GhostType/releases/download/v${VERSION}/${DMG_NAME}"
RELEASE_LINK="https://github.com/mk668a/GhostType/releases/tag/v${VERSION}"
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${PROJECT_DIR}/${APP_NAME}/Info.plist" 2>/dev/null || echo "14.0")
# LSMinimumSystemVersion in this project is the build-setting variable token;
# fall back to the explicit deployment target if PlistBuddy returns it.
case "$MIN_OS" in *MACOSX_DEPLOYMENT_TARGET*|"") MIN_OS="14.0" ;; esac

# Generate the new <item>, then run a Python pass to insert/replace it.
python3 - "$APPCAST" "$VERSION" "$BUILD_NUMBER" "$PUB_DATE" "$DOWNLOAD_URL" "$RELEASE_LINK" "$ED_SIG" "$DMG_LENGTH" "$MIN_OS" <<'PY'
import sys, re, pathlib
appcast_path, version, build, pub_date, download_url, release_link, ed_sig, length, min_os = sys.argv[1:]
appcast = pathlib.Path(appcast_path)
text = appcast.read_text()

# Drop any existing item for this shortVersionString so re-running is idempotent.
pattern = re.compile(
    r"\s*<item>(?:(?!</item>).)*?<sparkle:shortVersionString>"
    + re.escape(version)
    + r"</sparkle:shortVersionString>.*?</item>",
    re.DOTALL,
)
text = pattern.sub("", text)

item = (
    "        <item>\n"
    f"            <title>Version {version}</title>\n"
    f"            <link>{release_link}</link>\n"
    f"            <sparkle:version>{build}</sparkle:version>\n"
    f"            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>\n"
    f"            <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>\n"
    f"            <pubDate>{pub_date}</pubDate>\n"
    "            <enclosure\n"
    f"                url=\"{download_url}\"\n"
    f"                sparkle:edSignature=\"{ed_sig}\"\n"
    f"                length=\"{length}\"\n"
    "                type=\"application/octet-stream\" />\n"
    "        </item>\n"
)

# Insert right after <description>...</description> (or before </channel> as a fallback).
if "<description>" in text and "</description>" in text:
    text = text.replace("</description>\n        <language>en</language>\n",
                        "</description>\n        <language>en</language>\n" + item, 1)
else:
    text = text.replace("    </channel>", item + "    </channel>", 1)

appcast.write_text(text)
PY

echo ""
echo "==================================="
echo "  DMG created and signed!"
echo "==================================="
echo ""
echo "  File:      dist/${DMG_NAME}"
echo "  Size:      ${DMG_SIZE}"
echo "  EdDSA sig: ${ED_SIG:0:20}…"
echo "  appcast.xml updated with v${VERSION}."
echo ""
echo "  Next steps:"
echo "    1. git add appcast.xml && git commit -m 'release: v${VERSION}'"
echo "    2. gh release create v${VERSION} dist/${DMG_NAME} --title 'v${VERSION}' --notes-file ..."
echo "    3. git push origin main (so the new appcast is reachable via raw.githubusercontent.com)"
echo ""
