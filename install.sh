#!/bin/bash
# bun-sticky installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Wolfe-Jam/bun-sticky-zig/main/install.sh | bash

set -e

REPO="Wolfe-Jam/bun-sticky-zig"
VERSION="v1.0.5"
INSTALL_DIR="${HOME}/.local/bin"

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  linux)  PLATFORM="linux" ;;
  darwin) PLATFORM="macos" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64)  ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  arm64)   ARCH="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

BINARY="faf-${PLATFORM}-${ARCH}"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY}"

echo "Installing bun-sticky (faf)..."
echo "  Platform: ${PLATFORM}-${ARCH}"
echo "  Version:  ${VERSION}"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download binary
echo "Downloading ${BINARY}..."
curl -fsSL "$URL" -o "${INSTALL_DIR}/faf"
chmod +x "${INSTALL_DIR}/faf"

echo ""
echo "Installed to ${INSTALL_DIR}/faf"
echo ""

# Check if in PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo "Add to your PATH:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

echo "Run: faf score"
