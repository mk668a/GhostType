#!/bin/bash
set -e

APP_NAME="GhostType"
SCHEME="GhostType"
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

echo ""
echo "[2/3] Installing to ${INSTALL_DIR}/${APP_NAME}.app..."

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
