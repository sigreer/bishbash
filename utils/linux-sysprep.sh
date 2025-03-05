#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to check command success
check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

# Get new hostname and search domain
read -p "Enter new hostname: " newhostname
read -p "Enter search domain: " newsearchdomain

echo "=== Starting VM decloning process ==="

# 1. Set new hostname
echo "Setting new hostname..."
hostnamectl set-hostname "$newhostname"
check_command "Setting hostname"

# 2. Backup and regenerate machine-id
echo "Handling machine-id..."
if [ -f "/etc/machine-id" ]; then
    cp /etc/machine-id /root/old-machine-id
    check_command "Backing up machine-id"
    
    # Store old machine-id for reference
    oldmachineid=$(cat /root/old-machine-id)
    echo "Old machine ID: ${oldmachineid}"
    
    rm /etc/machine-id
    check_command "Removing old machine-id"
fi

# Generate new machine-id
systemd-machine-id-setup
check_command "Generating new machine-id"
newmachineid=$(cat /etc/machine-id)
echo "New machine ID: ${newmachineid}"

# 3. Update hosts file
echo "Updating hosts file..."
cp /etc/hosts /root/old-hosts
check_command "Backing up hosts file"

# Update hosts file with new hostname
sed -i "/127\.0\.1\.1/ s/.*/127.0.1.1\t${newhostname}/g" /etc/hosts
check_command "Updating hostname in hosts file"

# Add search domain if not present
if ! grep -q "^search ${newsearchdomain}" /etc/hosts; then
    echo "search ${newsearchdomain}" >> /etc/hosts
fi

# 4. Regenerate SSH host keys
echo "Regenerating SSH host keys..."
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server 2>/dev/null || ssh-keygen -A
check_command "Regenerating SSH keys"

# 5. Clear cloud-init state if present
if command -v cloud-init >/dev/null 2>&1; then
    echo "Clearing cloud-init state..."
    cloud-init clean --logs
    rm -rf /var/lib/cloud/instances/*
fi

# 6. Clear unique identifiers from NetworkManager if present
if [ -d "/var/lib/NetworkManager" ]; then
    echo "Clearing NetworkManager state..."
    rm -f /var/lib/NetworkManager/secret_key
    rm -f /var/lib/NetworkManager/seen-bssids
    rm -f /var/lib/NetworkManager/timestamps
fi

# 7. Clear system journal
echo "Clearing system journal..."
journalctl --rotate
journalctl --vacuum-time=1s

# 8. Clear temporary files
echo "Clearing temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*

# 9. Clear bash history
echo "Clearing bash history..."
rm -f /root/.bash_history
rm -f /home/*/.bash_history

echo "=== VM decloning complete ==="
echo "New hostname: ${newhostname}"
echo "New machine-id: ${newmachineid}"
echo "Please reboot the system for all changes to take effect"