#!/bin/bash
set -euo pipefail

debug=true
force=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            force=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

dnf_conf="/etc/dnf/dnf.conf"
kernel_exclude_line="exclude=kernel* kernel-core* kernel-modules* kernel-modules-core*"
script_lock_line="# LOCK: kernel upgrade in progress"

# Detect ZFS DKMS module version
zfs_src_dir=$(find /usr/src -maxdepth 1 -type d -name "zfs-*" | sort -V | tail -n1)
if [[ -z "$zfs_src_dir" ]]; then
    echo "❌ No ZFS source directory found in /usr/src"
    exit 1
fi
zfsdkms_version=$(basename "$zfs_src_dir" | sed 's/^zfs-//')
dkms_name="zfs"
dkms_version="${zfsdkms_version}-1"
dkms_src="/usr/src/${dkms_name}-${dkms_version}"

# Link DKMS source path if necessary
if [[ ! -d "$dkms_src" ]]; then
    echo "==> Creating DKMS-expected directory: $dkms_src"
    sudo ln -sf "$zfs_src_dir" "$dkms_src"
fi

# Add debug output for DKMS setup
if [[ "$debug" == "true" ]]; then
    echo "==> Debug: DKMS setup"
    echo "ZFS source dir: $zfs_src_dir"
    echo "DKMS version: $dkms_version"
    echo "DKMS name: $dkms_name"
    echo "DKMS source: $dkms_src"
fi

# Function to check ZFS version compatibility
check_zfs_compatibility() {
    local kernel_ver=$1
    
    # Get installed ZFS version
    zfs_version=$(rpm -q zfs --qf '%{VERSION}-%{RELEASE}\n' 2>/dev/null)
    if [[ -z "$zfs_version" ]]; then
        echo "❌ ZFS package not found"
        return 1
    fi
    
    # Extract major and minor version
    zfs_major=$(echo "$zfs_version" | cut -d. -f1)
    zfs_minor=$(echo "$zfs_version" | cut -d. -f2)
    
    # Extract kernel major and minor version
    kernel_major=$(echo "$kernel_ver" | cut -d. -f1)
    kernel_minor=$(echo "$kernel_ver" | cut -d. -f2)
    
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: ZFS version: $zfs_version"
        echo "==> Debug: Kernel version: $kernel_ver"
    fi
    
    # Check compatibility based on known version constraints
    if [[ "$zfs_version" == "2.3.1-1.fc41" ]]; then
        if [[ "$kernel_major" -gt 6 ]] || [[ "$kernel_major" -eq 6 && "$kernel_minor" -gt 13 ]]; then
            echo "❌ ZFS 2.3.1 is not compatible with kernel $kernel_ver"
            return 1
        fi
    fi
    
    return 0
}

# Function to ensure kernel headers are installed
ensure_kernel_headers() {
    local kernel_ver=$1
    local build_path="/lib/modules/$kernel_ver/build"
    
    if [[ -d "$build_path" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "==> Debug: Kernel headers already installed for $kernel_ver"
        fi
        return 0
    fi
    
    echo "==> Installing kernel headers for $kernel_ver"
    
    # Check ZFS compatibility first
    if ! check_zfs_compatibility "$kernel_ver"; then
        echo "❌ Kernel $kernel_ver is not compatible with installed ZFS version"
        return 1
    fi
    
    # Try to install the headers with conflict resolution
    if ! sudo dnf5 install -y --allowerasing --skip-broken "kernel-devel-$kernel_ver.x86_64"; then
        echo "❌ Failed to install kernel headers for $kernel_ver"
        return 1
    fi
    
    if [[ ! -d "$build_path" ]]; then
        echo "❌ Kernel headers not found after installation: $build_path"
        return 1
    fi
    
    return 0
}

# Function to check if ZFS kernel module exists for a given kernel
zfs_module_exists_for_kernel() {
    local kernel_ver="$1"
    local found=0
    # Check for zfs.ko in common locations
    if [[ -f "/lib/modules/${kernel_ver}/extra/zfs.ko" ]] || [[ -f "/lib/modules/${kernel_ver}/zfs/zfs.ko" ]]; then
        found=1
    fi
    # Check with modinfo (succeeds if module is available for this kernel)
    if modinfo -k "$kernel_ver" zfs &>/dev/null; then
        found=1
    fi
    if [[ $found -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a kernel version supports ZFS
check_zfs_support() {
    local kernel_ver=$1
    local build_path="/lib/modules/$kernel_ver/build"
    
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: Checking ZFS support for $kernel_ver"
        echo "==> Debug: Build path: $build_path"
    fi
    
    # Ensure kernel headers are installed
    if ! ensure_kernel_headers "$kernel_ver"; then
        return 1
    fi
    
    # Try to build ZFS module for this kernel
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: Running DKMS build command"
        sudo dkms build -m "$dkms_name" -v "$dkms_version" -k "$kernel_ver"
    else
        if ! sudo dkms build -m "$dkms_name" -v "$dkms_version" -k "$kernel_ver" &>/dev/null; then
            echo "❌ ZFS not compatible with kernel $kernel_ver"
            return 1
        fi
    fi
    
    # After build, check for actual ZFS kernel module
    if ! zfs_module_exists_for_kernel "$kernel_ver"; then
        echo "❌ ZFS kernel module not found for $kernel_ver after build"
        return 1
    fi
    
    return 0
}

# Function to get installed kernel versions
get_installed_kernels() {
    # First try rpm directly
    if command -v rpm &> /dev/null; then
        rpm -qa kernel-core | sed 's/kernel-core-//' | sed 's/\.x86_64$//' | sort -V
        return $?
    fi
    
    # Fallback to dnf5 if rpm fails
    if command -v dnf5 &> /dev/null; then
        dnf5 list installed kernel-core | awk 'NR>1 {print $2}' | sed 's/\.x86_64$//' | sort -V
        return $?
    fi
    
    echo "❌ Neither rpm nor dnf5 available to list kernels"
    return 1
}

# Function to find the most recent ZFS-supported kernel
find_latest_zfs_kernel() {
    echo "==> Finding latest available kernel-core"
    
    # First ensure repositories are up to date
    echo "==> Updating repositories..."
    if ! sudo dnf5 update -y --refresh &>/dev/null; then
        echo "❌ Failed to update repositories"
        return 1
    fi
    
    # Try multiple methods to get the latest kernel
    echo "==> Querying available kernels..."
    
    # Method 1: Try dnf5 repoquery
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: Trying dnf5 repoquery"
    fi
    latest_kernel=$(dnf5 repoquery --latest-limit=1 kernel-core.x86_64 2>/dev/null)
    
    # Method 2: If that fails, try dnf5 list
    if [[ -z "$latest_kernel" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "==> Debug: dnf5 repoquery failed, trying dnf5 list"
        fi
        latest_kernel=$(dnf5 list --available kernel-core.x86_64 | awk 'NR>1 {print $2}' | head -n1)
    fi
    
    # Method 3: If that fails, try rpm
    if [[ -z "$latest_kernel" ]]; then
        if [[ "$debug" == "true" ]]; then
            echo "==> Debug: dnf5 list failed, trying rpm"
        fi
        latest_kernel=$(rpm -q --whatprovides kernel-core --qf '%{VERSION}-%{RELEASE}\n' | sort -V | tail -n1)
    fi
    
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: Latest kernel query result: $latest_kernel"
    fi
    
    if [[ -z "$latest_kernel" ]]; then
        echo "❌ No kernel-core found in repositories"
        return 1
    fi
    
    # Clean up the kernel version string
    kernelver=$(echo "$latest_kernel" | sed 's/^kernel-core-//' | sed 's/^0://;s/\.x86_64$//')
    if [[ "$debug" == "true" ]]; then
        echo "==> Debug: Parsed kernel version: $kernelver"
    fi
    
    if [[ -z "$kernelver" ]]; then
        echo "❌ Could not parse kernel version from: $latest_kernel"
        return 1
    fi
    
    echo "Found kernel package: $latest_kernel"
    
    # Check ZFS compatibility first
    if ! check_zfs_compatibility "$kernelver"; then
        echo "❌ Latest kernel ($kernelver) is not compatible with installed ZFS version"
        # Try to find the most recent installed kernel that supports ZFS
        echo "==> Checking installed kernels for ZFS support..."
        installed_kernels=($(get_installed_kernels))
        for ((i=${#installed_kernels[@]}-1; i>=0; i--)); do
            kernel="${installed_kernels[$i]}"
            echo "  Checking $kernel..."
            if check_zfs_compatibility "$kernel"; then
                echo "✓ Found ZFS-compatible kernel: $kernel"
                echo "$kernel"
                return 0
            fi
        done
        return 1
    fi
    
    # Check if this kernel supports ZFS
    echo "==> Checking ZFS support for $kernelver"
    if check_zfs_support "$kernelver"; then
        echo "✓ ZFS supported"
        echo "$kernelver"
        return 0
    else
        echo "❌ Latest kernel ($kernelver) does not support ZFS"
        # Try to find the most recent installed kernel that supports ZFS
        echo "==> Checking installed kernels for ZFS support..."
        installed_kernels=($(get_installed_kernels))
        for ((i=${#installed_kernels[@]}-1; i>=0; i--)); do
            kernel="${installed_kernels[$i]}"
            echo "  Checking $kernel..."
            if check_zfs_support "$kernel"; then
                echo "✓ Found ZFS-supported kernel: $kernel"
                echo "$kernel"
                return 0
            fi
        done
        return 1
    fi
}

# Function to verify and update kernel state
verify_and_update_kernel() {
    echo "==> Verifying current kernel state"
    
    # Get current running kernel (must have ZFS support to boot)
    current_kernel=$(uname -r)
    echo "Current running kernel: $current_kernel"
    
    # Get all installed kernels
    echo "==> Checking installed kernels..."
    installed_kernels=($(get_installed_kernels))
    if [[ ${#installed_kernels[@]} -eq 0 ]]; then
        echo "❌ No installed kernels found"
        return 1
    fi
    
    echo "Installed kernels:"
    for kernel in "${installed_kernels[@]}"; do
        echo "  - $kernel"
    done
    
    # Find the most recent ZFS-supported kernel
    echo "==> Finding latest ZFS-supported kernel..."
    latest_zfs_kernel=$(find_latest_zfs_kernel)
    if [[ -z "$latest_zfs_kernel" ]]; then
        echo "❌ Could not find a ZFS-supported kernel"
        return 1
    fi
    
    echo "Most recent ZFS-supported kernel: $latest_zfs_kernel"
    
    # Check if this kernel is already installed
    kernel_installed=false
    for kernel in "${installed_kernels[@]}"; do
        if [[ "$kernel" == "$latest_zfs_kernel" ]]; then
            kernel_installed=true
            break
        fi
    done
    
    if [[ "$kernel_installed" == "true" ]]; then
        echo "==> Kernel $latest_zfs_kernel is already installed"
    else
        echo "==> Installing kernel $latest_zfs_kernel"
        full_kernelver="$latest_zfs_kernel.x86_64"
        
        # Temporarily disable kernel exclusion
        if grep -q "^${kernel_exclude_line}$" "$dnf_conf"; then
            echo "==> Temporarily disabling kernel exclusion for kernel installation"
            sudo sed -i "s/^${kernel_exclude_line}$/#${kernel_exclude_line}/" "$dnf_conf"
        fi
        
        # Install kernel-devel first
        echo "==> Installing kernel-devel-$full_kernelver"
        if ! sudo dnf5 install -y "kernel-devel-$full_kernelver"; then
            echo "❌ Failed to install kernel-devel-$full_kernelver"
            # Re-enable kernel exclusion
            if grep -q "^#${kernel_exclude_line}$" "$dnf_conf"; then
                sudo sed -i "s/^#${kernel_exclude_line}$/${kernel_exclude_line}/" "$dnf_conf"
            fi
            return 1
        fi
        changes_made+=("Installed kernel-devel for $latest_zfs_kernel")
        
        # Install kernel-core
        echo "==> Installing kernel-core-$full_kernelver"
        if ! sudo dnf5 install -y "kernel-core-$full_kernelver"; then
            echo "❌ Failed to install kernel-core-$full_kernelver"
            # Re-enable kernel exclusion
            if grep -q "^#${kernel_exclude_line}$" "$dnf_conf"; then
                sudo sed -i "s/^#${kernel_exclude_line}$/${kernel_exclude_line}/" "$dnf_conf"
            fi
            return 1
        fi
        changes_made+=("Installed kernel-core for $latest_zfs_kernel")
        
        # Re-enable kernel exclusion
        if grep -q "^#${kernel_exclude_line}$" "$dnf_conf"; then
            echo "==> Re-enabling kernel exclusion after kernel installation"
            sudo sed -i "s/^#${kernel_exclude_line}$/${kernel_exclude_line}/" "$dnf_conf"
        fi
        
        # Rebuild initramfs
        echo "==> Rebuilding initramfs for $latest_zfs_kernel"
        initramfs_path="/boot/initramfs-${full_kernelver}.img"
        if ! sudo dracut --force "$initramfs_path" "$full_kernelver"; then
            echo "❌ Failed to build initramfs for $full_kernelver"
            return 1
        fi
        changes_made+=("Rebuilt initramfs for $latest_zfs_kernel")
        
        # Install ZFS module
        echo "==> Installing ZFS module into new kernel"
        if ! sudo dkms install -m "$dkms_name" -v "$dkms_version" -k "$latest_zfs_kernel"; then
            echo "❌ Failed to install ZFS module for $latest_zfs_kernel"
            return 1
        fi
        changes_made+=("Built and installed ZFS module for $latest_zfs_kernel")
    fi
    
    # Set GRUB to boot the ZFS-supported kernel
    echo "==> Setting GRUB default to Fedora $latest_zfs_kernel"
    sudo grubby --set-default "/boot/vmlinuz-${latest_zfs_kernel}.x86_64"
    changes_made+=("Set default boot kernel to $latest_zfs_kernel")
    
    # Confirm default kernel and initramfs
    grub_default=$(sudo grubby --default-kernel)
    initramfs_path="/boot/initramfs-${latest_zfs_kernel}.x86_64.img"
    if [[ -f "$initramfs_path" ]]; then
        initramfs_status="Present"
    else
        initramfs_status="Missing" 
    fi

    echo
    echo "==================== SUMMARY ===================="
    if [[ ${#changes_made[@]} -eq 0 ]]; then
        echo "No changes were made."
    else
        echo "Changes made during this run:"
        for change in "${changes_made[@]}"; do
            echo "  - $change"
        done
    fi
    echo "-----------------------------------------------"
    echo "Kernel elected for boot: $latest_zfs_kernel"
    echo "GRUB default kernel:    $grub_default"
    echo "Initramfs for kernel:   $initramfs_path ($initramfs_status)"
    echo "================================================"
    
    return 0
}

# Function to check for script lock and ensure kernel exclusion
setup_dnf() {
    echo "==> Setting up DNF config for kernel upgrade"
    
    # Check for existing lock
    if grep -q "^${script_lock_line}$" "$dnf_conf"; then
        if [[ "$force" == "true" ]]; then
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
    # First remove any existing exclusion
    sudo sed -i "/^exclude=kernel/d" "$dnf_conf"
    # Then add the commented version
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
        # First remove the commented exclusion
        sudo sed -i "/^#exclude=kernel/d" "$dnf_conf"
        # Then add the uncommented version
        echo "${kernel_exclude_line}" | sudo tee -a "$dnf_conf" >/dev/null
        
        # Verify the change
        if ! grep -q "^exclude=kernel" "$dnf_conf"; then
            echo "❌ Failed to re-enable kernel exclusion"
            exit 1
        fi
    fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Check if dnf5 is available
if ! command -v dnf5 &> /dev/null; then
    echo "❌ dnf5 is not installed"
    exit 1
fi

# Check if dkms is available
if ! command -v dkms &> /dev/null; then
    echo "❌ dkms is not installed"
    exit 1
fi

# Check if dracut is available
if ! command -v dracut &> /dev/null; then
    echo "❌ dracut is not installed"
    exit 1
fi

# Check if grub2-set-default is available
if ! command -v grub2-set-default &> /dev/null; then
    echo "❌ grub2-set-default is not installed"
    exit 1
fi

# Setup dnf.conf before proceeding
setup_dnf

# Cleanup function to ensure dnf.conf is restored on script exit
cleanup() {
    local exit_code=$?
    cleanup_dnf
    exit $exit_code
}

# Set up trap to ensure cleanup runs on script exit
trap cleanup EXIT

# Track changes
changes_made=()

# Verify and update kernel state
verify_and_update_kernel

