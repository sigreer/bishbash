#!/bin/bash

if [[ -z $1 ]]; then
	echo "Usage:"
	echo "luks2enc /dev/sdX vault"
	exit 1
fi

# Replace /dev/sdX with your target disk (e.g., /dev/sdb)
DISK=$1

# Optional: Clear existing partition table and data
sgdisk --zap-all $DISK
dd if=/dev/zero of=$DISK bs=1M count=100 status=progress

# Set up LUKS2 encryption with a strong cipher and key size
CRYPT_NAME=$2
LUKS_OPTIONS="--cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000"

# Format the disk with LUKS2
cryptsetup luksFormat $LUKS_OPTIONS $DISK

# Open the encrypted disk
cryptsetup open $DISK $CRYPT_NAME

# Create a filesystem on the encrypted disk
mkfs.ext4 /dev/mapper/$CRYPT_NAME

# Mount the encrypted disk to /mnt
mkdir -p /mnt/$CRYPT_NAME
mount /dev/mapper/$CRYPT_NAME /mnt/$CRYPT_NAME

# Display encryption information
cryptsetup luksDump $DISK

echo "Disk encryption complete. Mounted at /mnt/$CRYPT_NAME."
