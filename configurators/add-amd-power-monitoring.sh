#!/bin/bash

# Store current directory
CURRENT_DIR=$(pwd)
dnf_conf="/etc/dnf/dnf.conf"
kernel_exclude_line="exclude=kernel* kernel-core* kernel-modules* kernel-modules-core*"
script_lock_line="# LOCK: kernel upgrade in progress"

check_module_installed() {
    if lsmod | grep -q "zenpower"; then
        echo "Already installed, exiting..."
        exit 0
    else
        echo "No zenpower module found, continuing..."
    fi
}


finished_check_module_installed() {
    if lsmod | grep -q "zenpower"; then
        echo "Success: zenpower module is loaded"
    else
        echo "Error: Failed to load zenpower module"
        exit 1
    fi
}

# Function to check for script lock and ensure kernel exclusion
setup_dnf() {
    echo "==> Setting up DNF config for kernel upgrade"
    
    # Check for existing lock
    if grep -q "^${script_lock_line}$" "$dnf_conf"; then
        if [[ "${force:-false}" == "true" ]]; then
            echo "⚠️  Force option used - removing existing lock"
            sudo sed -i "/^${script_lock_line}$/d" "$dnf_conf"
        else
            echo "❌ Another kernel upgrade is in progress (lock file present)"
            echo "    Use -f or --force to override"
            exit 1
        fi
    fi
    
    # Ensure kernel exclusion is enabled by default
    if ! grep -q "^exclude=kernel" "$dnf_conf"; then
        echo "==> Enabling kernel exclusion in DNF config"
        echo "${kernel_exclude_line}" | sudo tee -a "$dnf_conf" >/dev/null
    fi
    
    # Add script lock
    echo "$script_lock_line" | sudo tee -a "$dnf_conf" >/dev/null
    
    # Temporarily disable kernel exclusion for our upgrade
    echo "==> Temporarily disabling kernel exclusion for upgrade"
    # Remove any existing exclusion lines
    sudo sed -i "/^exclude=kernel/d;/^exclude=kernel\*/d" "$dnf_conf"
    # Add the commented version
    echo "#${kernel_exclude_line}" | sudo tee -a "$dnf_conf" >/dev/null
    
    # Verify the change
    if ! grep -q "^#exclude=kernel" "$dnf_conf"; then
        echo "❌ Failed to disable kernel exclusion"
        cleanup_dnf
        exit 1
    fi
}

# Function to remove script lock and re-enable kernel exclusion
cleanup_dnf() {
    echo "==> Cleaning up DNF config"
    
    # Always try to remove the lock, even if it doesn't exist
    sudo sed -i "/^${script_lock_line}$/d" "$dnf_conf"
    
    # Re-enable kernel exclusion
    if grep -q "^#exclude=kernel" "$dnf_conf"; then
        echo "==> Re-enabling kernel exclusion in DNF config"
        # Remove the commented exclusion
        sudo sed -i "/^#exclude=kernel/d;/^#exclude=kernel\*/d" "$dnf_conf"
        # Add the uncommented version
        echo "${kernel_exclude_line}" | sudo tee -a "$dnf_conf" >/dev/null
        # Verify the change
        if ! grep -q "^exclude=kernel" "$dnf_conf"; then
            echo "❌ Failed to re-enable kernel exclusion"
            exit 1
        fi
    fi
}

# Trap to always restore DNF config on exit
cleanup() {
    local exit_code=$?
    cleanup_dnf
    exit $exit_code
}
trap cleanup EXIT

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Install required packages
sudo dnf install dkms kernel-devel-$(uname -r) gcc make git -y
if [ $? -ne 0 ]; then
    echo "Error: Failed to install required packages"
    exit 1
fi

build_module() {
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
}

check_module_installed
setup_dnf
build_module
cleanup_dnf
finished_check_module_installed
