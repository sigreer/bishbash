#!/bin/bash

if [ -f ".env" ]; then
    source .env
elif [ -f "$HOME/.config/bishbash/.env" ]; then
    source "$HOME/.config/bishbash/.env"
else
    echo "Error: No .env file found in current directory or in $HOME/.config/bishbash/"
    exit 1
fi

nas_ip="$NAS_IP"
nas_ssh="$NAS_SSH"
IFS=':' read -ra mounts <<< "$MOUNTS"

unmountNAS() {
    echo "Unmounting NAS"
    
    for mount in "${mounts[@]}"; do
        echo "Processing $mount"
        
        if mountpoint -q "$mount"; then
            lsof "$mount" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u | while read pid; do
                echo "Terminating process $pid using $mount"
                kill "$pid"
            done
            
            echo "Unmounting $mount"
            if ! sudo umount -l "$mount"; then
                echo "Warning: Failed to unmount $mount"
            fi
        fi
    done
}

shutdownNAS() {
    echo "Shutting down NAS"
    if ! ssh "$nas_ssh" "sudo shutdown now"; then
        yad --error --text="Could not connect to NAS. Please try a normal shutdown." --title="NAS Shutdown Error"
        return 1
    fi
    
    echo "Waiting for NAS to power down..."
    yad --info \
        --title="NAS Shutdown" \
        --text="Waiting for NAS to shutdown, still responding to pings..." \
        --no-buttons &
        
    while ping -c 1 "$nas_ip" &> /dev/null; do
        sleep 2
    done
    
    pkill -f "yad --info.*NAS Shutdown"
    echo "NAS is offline"
}

shutdownDesktop() {
    echo "Shutting down desktop"
    sudo shutdown now
}

unmountNAS
echo "Unmounted NAS"
shutdownNAS
echo "Shut down NAS"
shutdownDesktop
echo "Bye Bye!"