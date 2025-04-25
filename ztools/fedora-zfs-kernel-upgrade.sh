#!/bin/bash
set -euo pipefail

debug=true

dnf_conf="/etc/dnf/dnf.conf"
kernel_exclude_line="exclude=kernel* kernel-core* kernel-modules* kernel-modules-core*"

# Check and comment the exclude line if needed
echo "==> Checking DNF kernel exclusion"
if grep -q "^${kernel_exclude_line}$" "$dnf_conf"; then
    echo "==> Commenting out kernel exclusion in DNF config"
    sudo sed -i "s/^${kernel_exclude_line}$/#${kernel_exclude_line}/" "$dnf_conf"
fi

echo "==> Finding latest available kernel-core"
latest_kernel=$(dnf5 repoquery --latest-limit=1 kernel-core.x86_64)
if [[ -z "$latest_kernel" ]]; then
  echo "❌ No kernel-core found."
  exit 1
fi
echo "Found kernel package: $latest_kernel"

kernelver=$(echo "$latest_kernel" | sed 's/^kernel-core-//' | sed 's/^0://;s/\.x86_64$//')
full_kernelver="$kernelver.x86_64"
echo "Parsed kernel version: $kernelver"
echo "Full kernel version: $full_kernelver"

echo "==> Checking for matching kernel-devel-$full_kernelver"
if ! dnf5 repoquery kernel-devel-$full_kernelver &>/dev/null; then
  echo "❌ No matching kernel-devel found."
  exit 1
fi

# Install kernel-devel first
echo "==> Installing kernel-devel-$full_kernelver"
sudo dnf5 install -y kernel-devel-$full_kernelver

# Download RPMs for dry-run test
dldir="/usr/src/kernels"
echo "==> Downloading kernel-core RPM"
sudo rm -rf "$dldir/$full_kernelver"
dnf5 download --destdir="$dldir" kernel-core-$full_kernelver

# Extract kernel-devel
echo "==> Extracting kernel-devel"
mkdir -p "$dldir/$full_kernelver"
rpm2cpio "$dldir/kernel-devel-${full_kernelver}.rpm" | (cd "$dldir/$full_kernelver" && cpio -idm)

# Find extracted kernel source path
extracted_path=$(find "$dldir/$full_kernelver/usr/src/kernels" -type d -name "$kernelver*" | head -n1)
if [[ -z "$extracted_path" || ! -d "$extracted_path" ]]; then
  echo "❌ Could not find extracted kernel source path"
  exit 1
fi
echo "Extracted kernel source path: $extracted_path"

# Symlink kernel headers for DKMS compatibility
build_path="/lib/modules/$kernelver/build"
echo "==> Creating temporary symlink: $build_path"
sudo mkdir -p "$(dirname "$build_path")"
sudo ln -sf "$extracted_path" "$build_path"

# Detect ZFS DKMS module version
zfs_src_dir=$(find /usr/src -maxdepth 1 -type d -name "zfs-*" | sort -V | tail -n1)
zfsdkms_version=$(basename "$zfs_src_dir" | sed 's/^zfs-//')
dkms_name="zfs-zfs"
dkms_version="${zfsdkms_version}-1"
dkms_src="/usr/src/${dkms_name}-${dkms_version}"

# Link DKMS source path if necessary
if [[ ! -d "$dkms_src" ]]; then
  echo "==> Creating DKMS-expected directory: $dkms_src"
  sudo ln -sf "$zfs_src_dir" "$dkms_src"
fi

# Before the DKMS check, store the status
dkms_status=$(sudo dkms status)

# Add debug output for the check itself
if [[ "$debug" == "true" ]]; then
  echo "==> Debug: DKMS check pattern: ^${dkms_name}/${dkms_version}[,:]"
  echo "==> Debug: DKMS status output:"
  echo "$dkms_status"
fi

# Use the stored status for the check
if echo "$dkms_status" | grep -q "^${dkms_name}/${dkms_version}[,:]"; then
  echo "==> ZFS module ${dkms_name}/${dkms_version} already in DKMS tree"
else
  echo "==> Registering ${dkms_name}/${dkms_version} in DKMS"
  sudo dkms add -m "$dkms_name" -v "$dkms_version"
fi

# Move the general debug output here
if [[ "$debug" == "true" ]]; then
  echo "Kernel version: $kernelver"
  echo "DKMS version: $dkms_version"
  echo "DKMS name: $dkms_name"
  echo "DKMS source: $dkms_src"
  echo "DKMS module: ${dkms_name}/${dkms_version}"
fi

# Build DKMS module
echo "==> Building ${dkms_name} for kernel $kernelver"

if ! sudo dkms build -m "$dkms_name" -v "$dkms_version" -k "$kernelver"; then
  echo "❌ DKMS build failed — ZFS not compatible with $kernelver"
  sudo rm -f "$build_path"
  exit 1
fi

echo
echo "✅ DKMS build succeeded for $dkms_name on kernel $kernelver"
echo "==> Proceeding with kernel installation..."

echo "==> Installing kernel-core..."
sudo dnf5 install -y kernel-core-$full_kernelver

echo "==> Rebuilding initramfs for $kernelver"
initramfs_path="/boot/initramfs-${full_kernelver}.img"
if ! sudo dracut --force "$initramfs_path" "$full_kernelver"; then
  echo "❌ Failed to build initramfs for $full_kernelver"
  exit 1
fi

# Verify initramfs was created
if [[ ! -f "$initramfs_path" ]]; then
  echo "❌ Initramfs not found after generation: $initramfs_path"
  exit 1
fi

echo "==> Installing ZFS module into new kernel"
sudo dkms install -m "$dkms_name" -v "$dkms_version" -k "$kernelver"

# Set GRUB default
echo "==> Setting GRUB default to Fedora $full_kernelver"
sudo grub2-set-default "Fedora Linux ($full_kernelver)"

echo "==> Cleaning up temporary symlink"
sudo rm -f "$build_path"

echo
echo "✅ Kernel $kernelver with ZFS $dkms_version is installed."
echo "📦 Initramfs: $initramfs_path"
echo "🚀 GRUB default set to: Fedora Linux ($full_kernelver)"
echo "🛠  Reboot to use it, then verify with 'uname -r'"
echo "🧼  Don't forget to uncomment 'exclude=kernel*' in /etc/dnf/dnf.conf"

# Restore the kernel exclusion line
echo "==> Restoring kernel exclusion in DNF config"
if grep -q "^#${kernel_exclude_line}$" "$dnf_conf"; then
    sudo sed -i "s/^#${kernel_exclude_line}$/${kernel_exclude_line}/" "$dnf_conf"
else
    echo "==> Adding kernel exclusion to DNF config"
    echo "${kernel_exclude_line}" | sudo tee -a "$dnf_conf" >/dev/null
fi
