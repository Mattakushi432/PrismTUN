#!/usr/bin/env bash
# Downloads the latest sing-box universal binary (arm64 + x86_64) from GitHub releases.
# Minimum supported version: 1.10.0
# Output: PrismTUN/Resources/Binaries/sing-box

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_ROOT}/PrismTUN/Resources/Binaries"
OUTPUT="${OUTPUT_DIR}/sing-box"

echo "▶ Fetching latest sing-box release info from GitHub..."
RELEASE_JSON=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/SagerNet/sing-box/releases/latest")

# Parse tag_name with python3 (bundled on macOS) or fallback to sed
TAG=$(echo "$RELEASE_JSON" | python3 -c \
    "import sys,json; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null || \
    echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "$TAG" ]; then
    echo "error: Failed to determine latest sing-box tag from GitHub API." >&2
    exit 1
fi

VERSION="${TAG#v}"
echo "▶ Latest sing-box: ${VERSION} (tag: ${TAG})"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

ARM64_URL="https://github.com/SagerNet/sing-box/releases/download/${TAG}/sing-box-${VERSION}-darwin-arm64.tar.gz"
AMD64_URL="https://github.com/SagerNet/sing-box/releases/download/${TAG}/sing-box-${VERSION}-darwin-amd64.tar.gz"

echo "▶ Downloading arm64 binary..."
curl -fsSL "$ARM64_URL" -o "${WORK_DIR}/arm64.tar.gz"
tar -xzf "${WORK_DIR}/arm64.tar.gz" -C "$WORK_DIR" --strip-components=1
mv "${WORK_DIR}/sing-box" "${WORK_DIR}/sing-box-arm64"

echo "▶ Downloading amd64 binary..."
curl -fsSL "$AMD64_URL" -o "${WORK_DIR}/amd64.tar.gz"
tar -xzf "${WORK_DIR}/amd64.tar.gz" -C "$WORK_DIR" --strip-components=1
mv "${WORK_DIR}/sing-box" "${WORK_DIR}/sing-box-amd64"

echo "▶ Creating universal binary with lipo..."
mkdir -p "$OUTPUT_DIR"
lipo -create \
    "${WORK_DIR}/sing-box-arm64" \
    "${WORK_DIR}/sing-box-amd64" \
    -output "$OUTPUT"
chmod 755 "$OUTPUT"

echo "✓ sing-box ${VERSION} saved to ${OUTPUT}"
