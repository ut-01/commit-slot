#!/bin/sh

# Minimal, POSIX-compliant installer for commit-slot
# Usage: curl -sL https://raw.githubusercontent.com/ut-01/commit-slot/main/install.sh | sh

set -e

REPO_URL="https://raw.githubusercontent.com/ut-01/commit-slot/main/commit-slot.sh"
INSTALL_DIR="$HOME/scripts"
SCRIPT_NAME="commit-slot.sh"
ALIAS="alias commit-slot='source $INSTALL_DIR/$SCRIPT_NAME'"

echo "🚀 Installing commit-slot..."

# 1. Create directory
mkdir -p "$INSTALL_DIR"

# 2. Download
echo "📥 Downloading..."
if ! curl -fsSL "$REPO_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "❌ Error: Failed to download commit-slot. Check your internet connection."
    exit 1
fi

# 3. Permissions & Sudo Warning
echo "🔧 Setting permissions..."
if ! chmod +x "$INSTALL_DIR/$SCRIPT_NAME"; then
    echo "⚠️  Warning: Failed to run chmod +x."
    echo "   This might be a permissions issue."
    echo "   Try running this script with sudo, or manually run:"
    echo "   sudo chmod +x $INSTALL_DIR/$SCRIPT_NAME"
    echo "   If that fails, create the directory first: mkdir -p $INSTALL_DIR"
    exit 1
fi

# 4. Setup Alias
echo "⚙️  Configuring shell alias..."

# Find existing config files or create a generic one if none are found
FOUND_CONFIG=""
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc" ]; then
        FOUND_CONFIG="$rc"
        break
    fi
done

# If no config found, create a default .profile
if [ -z "$FOUND_CONFIG" ]; then
    echo "⚠️  No standard shell config file found (.zshrc, .bashrc, .profile)."
    echo "   Creating a default profile to store the alias."
    FOUND_CONFIG="$HOME/.profile"
    touch "$FOUND_CONFIG"
fi

# Check if alias already exists to avoid duplicates
if grep -q "commit-slot" "$FOUND_CONFIG"; then
    echo "✅ Alias already exists in $FOUND_CONFIG. Skipping update."
else
    echo "$ALIAS" >> "$FOUND_CONFIG"
    echo "✅ Alias added to $FOUND_CONFIG"
fi

# 5. Final Instructions
echo ""
echo "✅ Installation Complete!"
echo "-------------------------------------------"
echo "To start using it in your current terminal:"
echo "   source $FOUND_CONFIG"
echo ""
echo "Or open a new terminal window."
echo "Try it out: commit-slot init && git commit -m 'Test'"
