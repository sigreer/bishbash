#!/bin/bash

# Check if an argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <zpool_name or /dev/device_path>"
    exit 1
fi

input=$1

unmount_datasets() {
    local pool=$1
    echo "Unmounting datasets in zpool: $pool"
    datasets=$(zfs list -H -o name -r "$pool")
    for dataset in $datasets; do
        echo "Unmounting $dataset..."
        zfs unmount "$dataset"
    done
}

unmount_zvols() {
    local pool=$1
    echo "Unmounting zvols in zpool: $pool"
    zvols=$(zfs list -H -o name -r -t volume "$pool")
    for zvol in $zvols; do
        echo "Unmounting $zvol..."
        zvol_device="/dev/zvol/$zvol"
        if mountpoint=$(findmnt -n -o TARGET "$zvol_device"); then
            echo "Unmounting $zvol_device from $mountpoint"
            umount "$mountpoint"
        else
            echo "$zvol_device is not mounted"
        fi
    done
}

detach_datasets_and_pool() {
    local pool=$1
    echo "Detaching datasets, zvols, and zpool: $pool"
    
    # Detach all child datasets and zvols
    zfs list -H -o name,type -r "$pool" | while read -r dataset type; do
        if [ "$dataset" != "$pool" ]; then
            echo "Detaching $dataset..."
            
            if [ "$type" = "filesystem" ]; then
                zfs set canmount=noauto "$dataset"
            elif [ "$type" = "volume" ]; then
                echo "Setting properties for zvol $dataset..."
                zfs set readonly=on "$dataset"
                zfs set snapdev=hidden "$dataset"
            fi
        fi
    done
    
    # Detach the zpool
    echo "Detaching zpool $pool..."
    zpool export "$pool"
}

if [[ $input == /dev/* ]]; then
    # Device path provided, unmount all associated zpools
    echo "Processing all zpools associated with $input..."
    
    # Get all zpools associated with the device
    zpools=$(zpool status | grep "$input" | awk '{print $1}')
    
    if [ -z "$zpools" ]; then
        echo "No zpools found associated with $input"
        exit 1
    fi
    
    for zpool in $zpools; do
        unmount_datasets "$zpool"
        unmount_zvols "$zpool"
        detach_datasets_and_pool "$zpool"
    done
else
    # Zpool name provided, unmount its datasets and zvols, then detach
    unmount_datasets "$input"
    unmount_zvols "$input"
    detach_datasets_and_pool "$input"
fi

echo "Unmounting and detaching operations completed."
