#!/usr/bin/env bash
# AuditX launcher script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo " AuditX — Security Audit Platform"
echo "   Launching Quickshell app..."
echo ""

# Optional: check python3
if ! command -v python3 &>/dev/null; then
    echo "python3 not found. Please install Python 3."
    exit 1
fi

# Add ~/.local/bin to PATH in case it's not exported globally
export PATH="$HOME/.local/bin:$PATH"

# Launch quickshell with the app path
exec quickshell --path "$SCRIPT_DIR/shell.qml"
