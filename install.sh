#!/bin/bash

# --- Failsafes ---
set -e # Exit immediately on error

if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run the installer as root."
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo "❌ Error: 'curl' is not installed but is required to download the script."
  exit 1
fi

echo "Installing create-ct to /usr/local/bin/..."

# Pull the main script directly from the GitHub repository
SCRIPT_URL="https://raw.githubusercontent.com/J0eyS/Proxmox-LXC-Creator/main/create-ct.sh"

# Using --fail to ensure we catch 404s or network errors
if ! curl -sSL --fail "$SCRIPT_URL" -o /usr/local/bin/create-ct; then
  echo "❌ Error: Failed to download the script. Please check your internet connection or the repository URL."
  exit 1
fi

# Grant executable permissions
chmod +x /usr/local/bin/create-ct

echo "✅ Installation complete! You can now type 'create-ct' in your terminal to create a new LXC."
