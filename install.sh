#!/bin/bash
echo "Installing create-ct to /usr/local/bin/..."

# Pull the main script directly from your GitHub
curl -sSL https://githubusercontent.com -o /usr/local/bin/create-ct

# Grant run permissions
chmod +x /usr/local/bin/create-ct

echo "Installation complete! You can now type 'create-ct' in your terminal."
