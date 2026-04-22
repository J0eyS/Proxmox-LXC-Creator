# Proxmox LXC Creator 🚀

An interactive bash script designed to run directly on a Proxmox VE host terminal. It scans your local storage for existing LXC templates, prompts you to select one, calculates the next available Container ID automatically, and creates a customized container on the fly.

## 📦 Installation

To install this tool on your Proxmox server, copy and paste this one-liner into your Proxmox host shell:

```bash
curl -sSL https://raw.githubusercontent.com/J0eyS/Proxmox-LXC-Creator/main/install.sh | bash
```

## 🛠️ Usage

Once the installer is finished, simply run the global command from any directory:

```bash
create-ct
```

## ⚙️ Prompts Included
- **Template Selection**: Scans `/var/lib/vz/template/cache` dynamically for `.tar.zst`, `.tar.gz`, and `.tar.xz` images.
- **Hostname**: Sets the desired hostname.
- **Network Bridge**: Defaults to `vmbr0`.
- **IP Assignment**: Supports standard static formats with a CIDR mask (e.g., `192.168.1.50/24`) or `dhcp`.
- **Target Storage**: Defines where the container's disk will deploy (defaults to `local-lvm`).
- **Password Masking**: Safely prompts for a secure root password without printing the keystrokes to the terminal.
