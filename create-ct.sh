#!/bin/bash

NEXT_ID=$(pvesh get /cluster/nextid)
echo "----------------------------------------"
echo "Found next available ID: $NEXT_ID"
echo "----------------------------------------"

TEMPLATE_DIR="/var/lib/vz/template/cache"

if [ ! -d "$TEMPLATE_DIR" ] || [ -z "$(ls -A "$TEMPLATE_DIR" 2>/dev/null)" ]; then
    echo "❌ Error: No templates found in $TEMPLATE_DIR"
    echo "Please download or create a template first."
    exit 1
fi

echo "Available templates found on 'local' storage:"
echo "----------------------------------------"

templates=()
while IFS= read -r file; do
    templates+=("$file")
done < <(ls "$TEMPLATE_DIR" | grep -E '\.tar\.(gz|zst|xz)$')

for i in "${!templates[@]}"; do
    echo "  [$i] ${templates[$i]}"
done
echo "----------------------------------------"

read -p "Select a template number [0-$((${#templates[@]}-1))]: " TEMP_INDEX

if ! [[ "$TEMP_INDEX" =~ ^[0-9]+$ ]] || [ "$TEMP_INDEX" -lt 0 ] || [ "$TEMP_INDEX" -ge "${#templates[@]}" ]; then
    echo "❌ Error: Invalid selection. Please run again."
    exit 1
fi

SELECTED_TEMPLATE="$TEMPLATE_DIR/${templates[$TEMP_INDEX]}"
echo "👉 Selected: ${templates[$TEMP_INDEX]}"
echo "----------------------------------------"

read -p "Enter Container Name (hostname): " CT_NAME
read -p "Enter Network Bridge (default: vmbr0): " CT_BRIDGE
CT_BRIDGE=${CT_BRIDGE:-vmbr0}

read -p "Enter IP Address (e.g., 192.168.1.50/24 or 'dhcp'): " CT_IP
if [ "$CT_IP" != "dhcp" ] && [[ ! "$CT_IP" =~ "/" ]]; then
    echo "❌ Error: Static IPs require a subnet mask (e.g., /24). Please run again."
    exit 1
fi

read -p "Enter Gateway IP (leave blank for DHCP): " CT_GW

read -p "Enter Disk Size in GB (default: 4): " CT_DISK
CT_DISK=${CT_DISK:-4}

read -p "Enter Proxmox Storage Name (default: local-lvm): " CT_STORE
CT_STORE=${CT_STORE:-local-lvm}

read -s -p "Enter root password for the new container: " CT_PASS
echo ""

NET_CONF="name=eth0,bridge=$CT_BRIDGE,ip=$CT_IP"
if [ -n "$CT_GW" ] && [ "$CT_IP" != "dhcp" ]; then
    NET_CONF="$NET_CONF,gw=$CT_GW"
fi

echo "----------------------------------------"
echo "Creating Container $NEXT_ID ($CT_NAME)..."
echo "----------------------------------------"

pct create "$NEXT_ID" "$SELECTED_TEMPLATE" \
  --hostname "$CT_NAME" \
  --net0 "$NET_CONF" \
  --rootfs "$CT_STORE:$CT_DISK" \
  --unprivileged 1 \
  --password "$CT_PASS"

if [ $? -eq 0 ]; then
    echo "----------------------------------------"
    echo "🎉 Success! Container $NEXT_ID has been created."
    echo "Start it using: pct start $NEXT_ID"
    echo "----------------------------------------"
else
    echo "❌ An error occurred during container creation."
fi
