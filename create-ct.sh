#!/bin/bash

# --- Failsafes & Error Handling ---
set -e # Exit immediately on unexpected command failures
trap 'echo -e "\n❌ Script aborted by user."; exit 1' INT

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run as root."
  exit 1
fi

# Ensure this is a Proxmox environment by checking for required tools
if ! command -v pct &> /dev/null || ! command -v pvesh &> /dev/null; then
  echo "❌ Error: Proxmox tools (pct, pvesh) not found. Are you running this on a Proxmox host?"
  exit 1
fi

# Retrieve the next available container ID safely
NEXT_ID=$(pvesh get /cluster/nextid 2>/dev/null || true)
if [ -z "$NEXT_ID" ]; then
  echo "❌ Error: Could not retrieve the next available cluster ID. Is your cluster healthy?"
  exit 1
fi

echo "----------------------------------------"
echo "Found next available ID: $NEXT_ID"
echo "----------------------------------------"

TEMPLATE_DIR="/var/lib/vz/template/cache"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "❌ Error: Template directory $TEMPLATE_DIR does not exist."
  exit 1
fi

# Safely load available templates into an array
templates=()
while IFS= read -r file; do
  templates+=("$file")
done < <(find "$TEMPLATE_DIR" -maxdepth 1 -type f \( -name '*.tar.gz' -o -name '*.tar.zst' -o -name '*.tar.xz' \) -exec basename {} \; | sort)

if [ ${#templates[@]} -eq 0 ]; then
  echo "❌ Error: No templates found in $TEMPLATE_DIR"
  echo "Please download or create a template first via the Proxmox UI or CLI."
  exit 1
fi

echo "Available templates found on 'local' storage:"
echo "----------------------------------------"

for i in "${!templates[@]}"; do
  echo " [$i] ${templates[$i]}"
done
echo "----------------------------------------"

# Disable exit-on-error temporarily for interactive read loops
set +e

# --- Interactive Prompts with Validation ---

# Template Selection
while true; do
  read -p "Select a template number [0-$((${#templates[@]}-1))]: " TEMP_INDEX
  if [[ "$TEMP_INDEX" =~ ^[0-9]+$ ]] && [ "$TEMP_INDEX" -ge 0 ] && [ "$TEMP_INDEX" -lt "${#templates[@]}" ]; then
    break
  else
    echo "⚠️ Invalid selection. Please enter a number between 0 and $((${#templates[@]}-1))."
  fi
done

SELECTED_TEMPLATE="$TEMPLATE_DIR/${templates[$TEMP_INDEX]}"
echo "👉 Selected: ${templates[$TEMP_INDEX]}"
echo "----------------------------------------"

# Hostname
while true; do
  read -p "Enter Container Name (hostname): " CT_NAME
  if [[ "$CT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    break
  else
    echo "⚠️ Invalid hostname. Use only letters, numbers, hyphens, and underscores. Cannot be empty."
  fi
done

# CPU Cores
read -p "Enter CPU Cores (default: 1): " CT_CORES
CT_CORES=${CT_CORES:-1}
if ! [[ "$CT_CORES" =~ ^[0-9]+$ ]]; then CT_CORES=1; fi

# RAM
read -p "Enter RAM in MB (default: 512): " CT_RAM
CT_RAM=${CT_RAM:-512}
if ! [[ "$CT_RAM" =~ ^[0-9]+$ ]]; then CT_RAM=512; fi

# Network Bridge
read -p "Enter Network Bridge (default: vmbr0): " CT_BRIDGE
CT_BRIDGE=${CT_BRIDGE:-vmbr0}

# IPv4 Configuration
while true; do
  read -p "Enter IPv4 Address (e.g., 192.168.1.50/24 or 'dhcp'): " CT_IP
  if [ "$CT_IP" == "dhcp" ]; then
    break
  elif [[ "$CT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    break
  else
    echo "⚠️ Invalid format. Must be 'dhcp' or include a valid subnet mask (e.g., 10.0.0.5/24)."
  fi
done

if [ "$CT_IP" != "dhcp" ]; then
  read -p "Enter IPv4 Gateway (leave blank if none): " CT_GW
fi

# IPv6 Configuration
while true; do
  read -p "Enter IPv6 Address (e.g., 2001:db8::50/64, 'dhcp', or leave blank for none): " CT_IP6
  if [ -z "$CT_IP6" ] || [ "$CT_IP6" == "dhcp" ]; then
    break
  elif [[ "$CT_IP6" =~ .*/[0-9]+$ ]]; then
    break
  else
    echo "⚠️ Invalid format. Must be 'dhcp', empty, or include a prefix (e.g., /64)."
  fi
done

if [ -n "$CT_IP6" ] && [ "$CT_IP6" != "dhcp" ]; then
  read -p "Enter IPv6 Gateway (leave blank if none): " CT_GW6
fi

# Disk Size
read -p "Enter Disk Size in GB (default: 4): " CT_DISK
CT_DISK=${CT_DISK:-4}
if ! [[ "$CT_DISK" =~ ^[0-9]+$ ]]; then CT_DISK=4; fi

# Storage Pool
read -p "Enter Proxmox Storage Name (default: local-lvm): " CT_STORE
CT_STORE=${CT_STORE:-local-lvm}

# Root Password
while true; do
  read -s -p "Enter root password for the new container: " CT_PASS
  echo ""
  if [ -n "$CT_PASS" ]; then
    break
  else
    echo "⚠️ Password cannot be empty."
  fi
done

# --- Formulate Configuration ---

NET_CONF="name=eth0,bridge=$CT_BRIDGE,ip=$CT_IP"
if [ -n "$CT_GW" ] && [ "$CT_IP" != "dhcp" ]; then
  NET_CONF="$NET_CONF,gw=$CT_GW"
fi

if [ -n "$CT_IP6" ]; then
  NET_CONF="$NET_CONF,ip6=$CT_IP6"
  if [ -n "$CT_GW6" ] && [ "$CT_IP6" != "dhcp" ]; then
    NET_CONF="$NET_CONF,gw6=$CT_GW6"
  fi
fi

echo "----------------------------------------"
echo "Creating Container $NEXT_ID ($CT_NAME)..."
echo "Specs: ${CT_CORES} Core(s), ${CT_RAM}MB RAM, ${CT_DISK}GB Disk on ${CT_STORE}"
echo "----------------------------------------"

# Re-enable exit-on-error for the creation phase
set -e

# Execute Proxmox Container Creation
pct create "$NEXT_ID" "$SELECTED_TEMPLATE" \
  --hostname "$CT_NAME" \
  --cores "$CT_CORES" \
  --memory "$CT_RAM" \
  --net0 "$NET_CONF" \
  --rootfs "$CT_STORE:$CT_DISK" \
  --unprivileged 1 \
  --password "$CT_PASS"

echo "----------------------------------------"
echo "🎉 Success! Container $NEXT_ID has been created."
echo "Start it using: pct start $NEXT_ID"
echo "----------------------------------------"
