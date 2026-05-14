#!/bin/bash
set -e

APP_NAME="GhostType"

echo "Uninstalling ${APP_NAME}..."

# Quit if running
pkill -x "$APP_NAME" 2>/dev/null || true

# Remove app
if [ -d "/Applications/${APP_NAME}.app" ]; then
    rm -rf "/Applications/${APP_NAME}.app"
    echo "  Removed /Applications/${APP_NAME}.app"
else
    echo "  ${APP_NAME}.app not found in /Applications"
fi

# Remove preferences
PLIST="$HOME/Library/Preferences/com.ghosttype.app.plist"
if [ -f "$PLIST" ]; then
    rm -f "$PLIST"
    echo "  Removed preferences"
fi

echo ""
echo "GhostType has been uninstalled."
echo "Note: Accessibility permission may remain in System Settings."
