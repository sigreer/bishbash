#!/bin/bash

# Timestamp for log collection
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
LOG_DIR="$HOME/system_logs_$TIMESTAMP"
mkdir -p "$LOG_DIR"

echo "Collecting logs from previous boot. Output will be saved in $LOG_DIR"

# Collect system journal logs from previous boot
journalctl --no-pager --boot -1 > "$LOG_DIR/journalctl_previous_boot.log"

# Collect kernel logs from previous boot
journalctl --no-pager -k --boot -1 > "$LOG_DIR/kernel_logs_previous_boot.log"

# Collect previous Xorg/Wayland logs
cp -v ~/.local/share/sddm/xorg-session.log "$LOG_DIR/xorg-session_previous.log" 2>/dev/null
cp -v ~/.local/share/sddm/xorg-session-errors.log "$LOG_DIR/xorg-session-errors_previous.log" 2>/dev/null
cp -v ~/.local/share/sddm/wayland-session.log "$LOG_DIR/wayland-session_previous.log" 2>/dev/null
cp -v ~/.local/share/sddm/wayland-session-errors.log "$LOG_DIR/wayland-session-errors_previous.log" 2>/dev/null

# Collect GPU logs from previous boot (AMD)
journalctl --no-pager -k -g 'amdgpu' --boot -1 > "$LOG_DIR/amdgpu_previous_boot.log"

# Collect NVMe errors
nvme error-log /dev/nvme0 > "$LOG_DIR/nvme0_errors.log" 2>/dev/null
nvme error-log /dev/nvme1 > "$LOG_DIR/nvme1_errors.log" 2>/dev/null

# Collect ZFS logs from previous boot
journalctl --no-pager -u zfs-mount -u zfs-import -u zfs-zed --boot -1 > "$LOG_DIR/zfs_previous_boot.log"

# Collect SMART info for all drives
for disk in /dev/nvme* /dev/sd*; do
  smartctl -a "$disk" > "$LOG_DIR/smart_${disk##*/}.log" 2>/dev/null
done

# Collect memory error logs (EDAC) from previous boot
journalctl --no-pager -k -g 'EDAC' --boot -1 > "$LOG_DIR/memory_errors_previous_boot.log"

# List running kernel modules in the previous session (only if crash logs were recorded)
journalctl --no-pager -k --boot -1 | grep "Modules linked in" > "$LOG_DIR/kernel_modules_previous_boot.log"

# Save a list of installed packages (for debugging driver versions)
rpm -qa > "$LOG_DIR/installed_packages.log"

echo "Log collection complete. Logs are stored in $LOG_DIR"
23:38:19.470 UTC user@1000.service wp-event-dispatcher: <WpAsyncEventHook:0x561acccb8ea0> failed: <WpSiStandardLink:0x561accfd3ae0> link failed: 1 of 1 PipeWire links failed to activate
