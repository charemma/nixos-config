#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/charemma/nixos-config.git"
REPO_DIR="$HOME/code/nixos-config"
HOST="${1:-}"

if [ -z "$HOST" ]; then
  echo "Usage: ./bootstrap.sh <hostname>"
  echo "Available hosts:"
  ls -1 "$REPO_DIR/hosts/" 2>/dev/null || echo "  (clone repo first)"
  exit 1
fi

# Clone repo if not present
if [ ! -d "$REPO_DIR" ]; then
  mkdir -p "$HOME/code"
  git clone "$REPO_URL" "$REPO_DIR"
fi

# Check host exists
if [ ! -d "$REPO_DIR/hosts/$HOST" ]; then
  echo "Host '$HOST' not found in hosts/"
  exit 1
fi

# Set up /etc/nixos redirect
sudo tee /etc/nixos/flake.nix > /dev/null << EOF
{
  inputs.config.url = "path:${REPO_DIR}";
  outputs = { config, ... }: config;
}
EOF

sudo tee /etc/nixos/README > /dev/null << EOF
This system is managed via flake at ${REPO_DIR}
Rebuild: just rebuild (from that directory)
EOF

# Initial rebuild
echo "Building configuration for '$HOST'..."
sudo nixos-rebuild switch --flake "${REPO_DIR}#${HOST}"

echo "Done. From now on use 'just rebuild' in ${REPO_DIR}"
