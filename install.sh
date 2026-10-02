#!/usr/bin/env bash
#
# Installer for Omarchy Mouse Plugin
# Author: Jason Stewart (Optimist Prime)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="$HOME/.local/bin/omarchy-mouse-control"
PLUGIN_TARGET="$HOME/.config/omarchy/plugins/optimistprime.mouse"

echo "=== Omarchy Mouse Plugin Installer ==="

# Check dependencies
echo "-> Checking dependencies..."
for cmd in ratbagctl python3 hyprctl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "⚠️ Warning: '$cmd' is not installed in PATH."
    if [[ "$cmd" == "ratbagctl" ]]; then
      echo "   Please install libratbag / ratbagd (e.g. 'sudo pacman -S libratbag') and ensure ratbagd is active."
    fi
  else
    echo "   [✓] $cmd"
  fi
done

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Install CLI helper
echo "-> Installing CLI helper to $BIN_TARGET..."
install -m 755 "$SCRIPT_DIR/omarchy-mouse-control" "$BIN_TARGET"

# Install shell plugin
echo "-> Installing Omarchy shell plugin to $PLUGIN_TARGET..."
mkdir -p "$PLUGIN_TARGET"
install -m 644 "$SCRIPT_DIR/manifest.json" "$PLUGIN_TARGET/manifest.json"
install -m 644 "$SCRIPT_DIR/Panel.qml" "$PLUGIN_TARGET/Panel.qml"
install -m 755 "$SCRIPT_DIR/omarchy-mouse-control" "$PLUGIN_TARGET/omarchy-mouse-control"

# Rescan and validate
if command -v omarchy >/dev/null 2>&1; then
  echo "-> Validating plugin with Omarchy..."
  omarchy plugin validate "$PLUGIN_TARGET"
  
  if command -v omarchy-shell >/dev/null 2>&1; then
    echo "-> Rescanning shell plugins..."
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi
  
  echo ""
  echo "✅ Installation complete!"
  echo "To enable on your bar, ensure it is added to your shell.json (bar.layout.right) or run:"
  echo "   omarchy plugin enable optimistprime.mouse right"
  echo "   omarchy restart shell"
fi
