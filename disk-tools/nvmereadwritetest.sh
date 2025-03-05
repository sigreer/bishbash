#!/bin/bash
# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
fi
# Function to test read speed
test_read_speed() {
    local device=$1
    echo "Testing read speed for $device"
    hdparm -tT /dev/$device
}

# Function to test write speed
test_write_speed() {
    local mountpoint=$1
    local testfile="$mountpoint/testfile.tmp"
    echo "Testing write speed for $mountpoint"
    
    # Writing 1 GB file to test speed
    sync; dd if=/dev/zero of=$testfile bs=1M count=1024 conv=fdatasync,notrunc; sync
    
    # Remove the test file after the test
    rm -f $testfile
}

# Devices and their corresponding mount points
declare -A devices
devices=( ["nvme0n1"]="${DEVPATH1}" ["nvme1n1"]="${DEVPATH2}" ["nvme2n1"]="${DEVPATH3}" )

# Test each device
for device in "${!devices[@]}"; do
    test_read_speed $device
    test_write_speed ${devices[$device]}
done
