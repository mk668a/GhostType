#!/bin/bash
set -e

APP_NAME="GhostType"
VERSION="0.1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$(mktemp -d)/build"
STAGING_DIR="$(mktemp -d)/dmg-staging"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/dist"

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
echo "[1/4] Building ${APP_NAME} (Release)..."
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

# Stage DMG contents
echo "[2/4] Preparing DMG contents..."
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create DMG
echo "[3/4] Creating DMG..."
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

# Cleanup
echo "[4/4] Cleaning up..."
rm -rf "$BUILD_DIR" "$STAGING_DIR"

DMG_SIZE=$(du -h "${OUTPUT_DIR}/${DMG_NAME}" | cut -f1)

echo ""
echo "==================================="
echo "  DMG created successfully!"
echo "==================================="
echo ""
echo "  File: dist/${DMG_NAME}"
echo "  Size: ${DMG_SIZE}"
echo ""
echo "  Users can install by:"
echo "    1. Open ${DMG_NAME}"
echo "    2. Drag GhostType to Applications"
echo "    3. Launch from Applications"
echo ""
