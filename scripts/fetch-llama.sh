#!/usr/bin/env bash
#
# Fetches the prebuilt llama.cpp server that GhostType bundles for its
# embedded backend, and stages the minimum set of files the app needs.
#
# GhostType links nothing against llama.cpp: it launches `llama-server` as a
# child process and talks to it over loopback HTTP, which is the same surface
# it uses for LM Studio, Ollama, and vLLM. Vendoring the official release
# binary rather than building from source keeps this a download instead of a
# toolchain dependency for anyone cloning the repo.
#
# Usage:
#   scripts/fetch-llama.sh                 # host architecture
#   LLAMA_ARCH=x64 scripts/fetch-llama.sh  # force Intel
#   LLAMA_BUILD=b10356 scripts/fetch-llama.sh
#
# Set GHOSTTYPE_SKIP_LLAMA=1 to make this a no-op (used by CI jobs that only
# need to type-check the Swift).

set -euo pipefail

if [[ "${GHOSTTYPE_SKIP_LLAMA:-0}" == "1" ]]; then
    echo "fetch-llama: GHOSTTYPE_SKIP_LLAMA=1, skipping."
    exit 0
fi

# Pinned so a build is reproducible and a llama.cpp regression cannot land in
# a GhostType release without someone bumping this line on purpose.
LLAMA_BUILD="${LLAMA_BUILD:-b10356}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/llama"
STAMP_FILE="$VENDOR_DIR/.build-version"

if [[ -z "${LLAMA_ARCH:-}" ]]; then
    case "$(uname -m)" in
        arm64) LLAMA_ARCH="arm64" ;;
        x86_64) LLAMA_ARCH="x64" ;;
        *) echo "fetch-llama: unsupported architecture $(uname -m)" >&2; exit 1 ;;
    esac
fi

STAMP_VALUE="$LLAMA_BUILD-$LLAMA_ARCH"

if [[ -f "$STAMP_FILE" ]] && [[ "$(cat "$STAMP_FILE")" == "$STAMP_VALUE" ]] && [[ -x "$VENDOR_DIR/llama-server" ]]; then
    echo "fetch-llama: $STAMP_VALUE already staged."
    exit 0
fi

ASSET="llama-$LLAMA_BUILD-bin-macos-$LLAMA_ARCH.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_BUILD/$ASSET"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "fetch-llama: downloading $ASSET"
if ! curl -fsSL --retry 3 -o "$WORK_DIR/llama.tar.gz" "$URL"; then
    echo "fetch-llama: could not download $URL" >&2
    echo "fetch-llama: check that build $LLAMA_BUILD still has a macOS $LLAMA_ARCH asset." >&2
    exit 1
fi

tar xzf "$WORK_DIR/llama.tar.gz" -C "$WORK_DIR"

EXTRACTED="$(find "$WORK_DIR" -maxdepth 2 -name 'llama-server' -type f | head -1)"
if [[ -z "$EXTRACTED" ]]; then
    echo "fetch-llama: llama-server not found in the archive" >&2
    exit 1
fi
SOURCE_DIR="$(dirname "$EXTRACTED")"

# The release ships ~60 binaries; GhostType runs exactly one of them. Walk the
# @rpath dependencies transitively so the app bundle carries llama-server and
# the dylibs it actually opens, rather than 24 MB of CLI tools we never launch.
declare -a QUEUE=("llama-server")
declare -a KEEP=("llama-server")

contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

while [[ ${#QUEUE[@]} -gt 0 ]]; do
    CURRENT="${QUEUE[0]}"
    QUEUE=("${QUEUE[@]:1}")

    while read -r DEP; do
        [[ -z "$DEP" ]] && continue
        # The binaries use `@rpath` with an rpath of `@loader_path`, so every
        # bundled dependency resolves to a sibling file.
        NAME="${DEP#@rpath/}"
        [[ "$NAME" == "$DEP" ]] && continue          # absolute system path
        [[ -f "$SOURCE_DIR/$NAME" ]] || continue
        if ! contains "$NAME" "${KEEP[@]}"; then
            KEEP+=("$NAME")
            QUEUE+=("$NAME")
        fi
    done < <(otool -L "$SOURCE_DIR/$CURRENT" 2>/dev/null | tail -n +2 | awk '{print $1}')
done

rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"

for FILE in "${KEEP[@]}"; do
    cp -p "$SOURCE_DIR/$FILE" "$VENDOR_DIR/$FILE"
done

# Some dylibs are versioned with symlink aliases (libggml.dylib ->
# libggml.0.19.0.dylib). `cp -p` resolved those into real files above, which is
# what we want inside an app bundle: no dangling links after signing.
cp -p "$SOURCE_DIR/LICENSE" "$VENDOR_DIR/LICENSE-llama.cpp" 2>/dev/null || true
chmod +x "$VENDOR_DIR/llama-server"

echo "$STAMP_VALUE" > "$STAMP_FILE"

TOTAL="$(du -sh "$VENDOR_DIR" | awk '{print $1}')"
echo "fetch-llama: staged ${#KEEP[@]} files ($TOTAL) in vendor/llama"
