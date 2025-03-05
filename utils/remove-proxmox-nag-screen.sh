#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Path to the proxmoxlib.js file
PROXMOX_LIB="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

# Check if the file exists
if [ ! -f "$PROXMOX_LIB" ]; then
    echo "Error: $PROXMOX_LIB not found"
    exit 1
fi

# Apply the modification to remove the subscription nag
sed -Ezi.bak "s/(function\(orig_cmd\) \{)/\1\n\torig_cmd\(\);\n\treturn;/g" "$PROXMOX_LIB"

# Detect environment and restart appropriate service
if systemctl list-units --full -all | grep -q "pveproxy.service"; then
    echo "Proxmox VE detected - Restarting pveproxy service..."
    systemctl restart pveproxy.service
elif systemctl list-units --full -all | grep -q "proxmox-backup-proxy.service"; then
    echo "Proxmox Backup Server detected - Restarting proxmox-backup-proxy service..."
    systemctl restart proxmox-backup-proxy.service
else
    echo "Error: Neither Proxmox VE nor Proxmox Backup Server detected"
    exit 1
fi

echo "Subscription nag screen has been removed successfully" 