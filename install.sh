#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_BIN="${SCRIPT_DIR}/auditx-cli.py"
GUI_BIN="${SCRIPT_DIR}/launch.sh"

chmod +x "$CLI_BIN" "$GUI_BIN"

if [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif command -v sudo >/dev/null 2>&1; then
    INSTALL_DIR="/usr/local/bin"
else
    echo "Could not find a valid installation directory."
    echo "Run directly:"
    echo "  CLI: python3 $CLI_BIN"
    echo "  GUI: $GUI_BIN"
    exit 1
fi

ln -sf "$CLI_BIN" "$INSTALL_DIR/auditx-cli"
ln -sf "$GUI_BIN" "$INSTALL_DIR/auditx-gui"
ln -sf "$GUI_BIN" "$INSTALL_DIR/auditx"

echo "Installed successfully to $INSTALL_DIR:"
echo "  auditx-cli -> $CLI_BIN"
echo "  auditx-gui -> $GUI_BIN"
echo "  auditx     -> $GUI_BIN (default GUI launcher)"
