#!/bin/bash

# Store current directory
CURRENT_DIR=$(pwd)

# Install required packages
sudo dnf install dkms kernel-devel-$(uname -r) gcc make git -y
if [ $? -ne 0 ]; then
    echo "Error: Failed to install required packages"
    exit 1
fi

# Move to /usr/src/ for module compilation
cd /usr/src/

# Check if repository already exists
if [ ! -d "zenpower3" ]; then
    sudo git clone https://github.com/AliEmreSenel/zenpower3.git
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone repository"
        cd "$CURRENT_DIR"
        exit 1
    fi
fi

cd zenpower3
if [ ! -f "Makefile" ]; then
    echo "Error: Makefile not found in zenpower3 directory"
    cd "$CURRENT_DIR"
    exit 1
fi

# Set KERNEL_SRC environment variable
export KERNEL_SRC=/usr/src/kernels/$(uname -r)

# Clean any previous build
sudo make clean

# Compile the module
sudo make KERNEL_SRC=$KERNEL_SRC
if [ $? -ne 0 ]; then
    echo "Error: Failed to compile module"
    cd "$CURRENT_DIR"
    exit 1
fi

sudo make install
if [ $? -ne 0 ]; then
    echo "Error: Failed to install module"
    cd "$CURRENT_DIR"
    exit 1
fi

sudo cp zenpower.ko "/lib/modules/$(uname -r)/extra/zenpower.ko"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy module"
    cd "$CURRENT_DIR"
    exit 1
fi

sudo depmod
sudo modprobe zenpower

# Verify module installation
if lsmod | grep -q "zenpower"; then
    echo "Success: zenpower module is loaded"
else
    echo "Error: Failed to load zenpower module"
    cd "$CURRENT_DIR"
    exit 1
fi

# Return to original directory
cd "$CURRENT_DIR"
