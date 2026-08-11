#!/usr/bin/env bash
#
# Xcode build phase: stage vendor/llama into the app bundle.
#
# Kept as a script rather than inline shell in project.pbxproj so it can be run
# and debugged on its own, and so the diff for a change to it is readable.
#
# Runs `fetch-llama.sh` first, which means a fresh clone builds without any
# manual setup step — the embedded backend is part of the build, not a
# prerequisite the contributor has to discover from the README.

set -euo pipefail

: "${SRCROOT:?must run from an Xcode build phase}"
: "${BUILT_PRODUCTS_DIR:?must run from an Xcode build phase}"
: "${CONTENTS_FOLDER_PATH:?must run from an Xcode build phase}"

"$SRCROOT/scripts/fetch-llama.sh"

VENDOR_DIR="$SRCROOT/vendor/llama"
FRAMEWORKS_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Frameworks"
MACOS_DIR="$BUILT_PRODUCTS_DIR/$EXECUTABLE_FOLDER_PATH"
RESOURCES_DIR="$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"

if [[ ! -x "$VENDOR_DIR/llama-server" ]]; then
    echo "warning: vendor/llama is missing, so this build has no embedded backend. Run scripts/fetch-llama.sh."
    exit 0
fi

# Apple's bundle layout puts helper executables in Contents/MacOS and shared
# libraries in Contents/Frameworks. Keeping llama.cpp in Contents/Resources
# worked, but it is the layout notarization and `codesign --verify` are least
# used to, and there is no upside to being unusual here.
mkdir -p "$FRAMEWORKS_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

# Leftovers from the old Resources/llama layout would still be signed and
# sealed into the bundle, so an incremental build has to clear them.
rm -rf "$RESOURCES_DIR/llama"

for DYLIB in "$VENDOR_DIR"/*.dylib; do
    cp -p "$DYLIB" "$FRAMEWORKS_DIR/$(basename "$DYLIB")"
done
cp -p "$VENDOR_DIR/llama-server" "$MACOS_DIR/llama-server"
[[ -f "$VENDOR_DIR/LICENSE-llama.cpp" ]] && cp -p "$VENDOR_DIR/LICENSE-llama.cpp" "$RESOURCES_DIR/"

# Every llama.cpp binary resolves its siblings through `@rpath` with an rpath of
# `@loader_path`. That still holds for the dylibs, which now sit together in
# Frameworks, but llama-server moved one directory away from them and has to be
# pointed back. The copy above is always a pristine one from vendor/, so this
# rewrite starts from `@loader_path` on every build.
install_name_tool -rpath @loader_path @executable_path/../Frameworks "$MACOS_DIR/llama-server"

# Nested executables need their own signature, and llama-server has to be able
# to load its sibling dylibs through `@rpath` (its rpath is `@loader_path`).
#
# The hardened runtime turns on library validation, which only admits libraries
# whose Team ID matches the process. An ad-hoc signature has no Team ID, so two
# ad-hoc binaries never match each other and llama-server fails at launch with
# "different Team IDs". A real Developer ID stamps the same team on all of them,
# so the runtime is safe there and required for notarization.
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"

if [[ "$IDENTITY" == "-" ]]; then
    SIGN_ARGS=(--force --sign -)
else
    SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
fi

# Dylibs first, executable last: `install_name_tool` above invalidated
# llama-server's signature, so it has to be signed after every edit to it.
for DYLIB in "$VENDOR_DIR"/*.dylib; do
    codesign "${SIGN_ARGS[@]}" "$FRAMEWORKS_DIR/$(basename "$DYLIB")"
done
codesign "${SIGN_ARGS[@]}" "$MACOS_DIR/llama-server"

DYLIB_COUNT="$(find "$VENDOR_DIR" -name '*.dylib' | wc -l | tr -d ' ')"
echo "embed-llama: staged llama-server into MacOS/ and $DYLIB_COUNT dylibs into Frameworks/"
