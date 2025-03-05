#!/bin/bash

sas3ircu_output=$(sas3ircu 0 display)
lsblk_output=$(lsblk -o WWN,HCTL,LOG-SEC,MAJ:MIN,MODE,MODEL,NAME,PARTFLAGS,PARTLABEL,PARTTYPE,PARTTYPENAME,PARTUUID,PHY-SEC,PATH,PKNAME,PTTYPE,PTUUID,REV,SIZE,START,STATE,SUBSYSTEMS,VENDOR)
lsscsi_output=$(lsscsi -g)
# zpool_output=$(zpool status "$poolname")

gather_disk_info() {
    local disk="$1"
    # local poolname="$2"

    disk_path="$disk"
    sg_readcap_output=$(sg_readcap -l "$disk")
    hctl=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $1}')
    device_type=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $2}')
    vendor=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $3}')
    model=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $4}')
    firmware=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $5}')
    scsi_address=$(echo "$lsscsi_output" | grep "$disk" | awk '{print $7}')

    prot_en=$(echo "$sg_readcap_output" | grep "Protection:" | awk -F'[,=]' '{print $2}')
    p_type=$(echo "$sg_readcap_output" | grep "Protection:" | awk -F'[,=]' '{print $4}')
    p_i_exponent=$(echo "$sg_readcap_output" | grep "Protection:" | awk -F'[,=]' '{print $6}')
    lbpme=$(echo "$sg_readcap_output" | grep "provisioning:" | awk -F'[,=]' '{print $2}')
    lbprz=$(echo "$sg_readcap_output" | grep "provisioning:" | awk -F'[,=]' '{print $2}')

    last_lba=$(echo "$sg_readcap_output" | grep "Last LBA" | awk -F'[,=(]' '{print $2}')
    last_lba_hex=$(echo "$sg_readcap_output" | grep "Last LBA" | awk -F'[,=(]' '{print $3}')
    logical_block_count=$(echo "$sg_readcap_output" | grep "Number of logical blocks=" | awk -F'[=,]' '{print $2}' | xargs)
    logical_block_size=$(echo "$sg_readcap_output" | grep "Logical block length=" | awk -F'[= ]' '{print $3}' | xargs)
    logical_blocks_per_physical_block=$(echo "$sg_readcap_output" | grep "Logical blocks per physical block exponent=" | awk -F'[= ]' '{print $6}' | xargs)
    physical_block_size=$(echo "$sg_readcap_output" | grep "physical block length=" | awk -F'[= ]' '{print $5}' | xargs)
    lowest_aligned_lba=$(echo "$sg_readcap_output" | grep "Lowest aligned LBA=" | awk -F'[= ]' '{print $3}' | xargs)
    logical_size_bytes=$(echo "$sg_readcap_output" | grep "Device size:" | awk -F'[= ]' '{print $3}' | xargs)
    logical_size_mib=$(echo "$sg_readcap_output" | grep "Device size:" | awk -F'[= ]' '{print $5}' | xargs)
    logical_size_gb=$(echo "$sg_readcap_output" | grep "Device size:" | awk -F'[= ]' '{print $7}' | xargs)
    logical_size_tb=$(echo "$sg_readcap_output" | grep "Device size:" | awk -F'[= ]' '{print $9}' | xargs)

    echo "PARSED FROM lsscsi"
    echo "disk_path: $disk_path"
    echo "hctl: $hctl"
    echo "device_type: $device_type"
    echo "vendor: $vendor"
    echo "model: $model"
    echo "firmware: $firmware"
    echo "scsi_address: $scsi_address"
    echo "--------------------------------"
    echo ""
    echo "PARSED FROM sg_readcap"
    echo "protection_type: $protection_type"
    echo "last_lba: $last_lba"
    echo "logical_block_count: $logical_block_count"
    echo "logical_block_size: $logical_block_size"
    echo "logical_blocks_per_physical_block: $logical_blocks_per_physical_block"
    echo "physical_block_size: $physical_block_size"
    echo "lowest_aligned_lba: $lowest_aligned_lba"
    echo "logical_size_bytes: $logical_size_bytes"
    echo "logical_size_mib: $logical_size_mib"
    echo "logical_size_gb: $logical_size_gb"
    echo "logical_size_tb: $logical_size_tb"

    return
}

# Ensure poolname is set correctly
poolname="tyson"  # or set this dynamically based on your requirements

gather_disk_info "/dev/sdb" "$poolname"

exit

# Loop through each disk (replace with actual disk identifiers)
for disk in /dev/sd*; do
    gather_disk_info "$disk" "poolname"
done

exit
# Remove trailing comma and close JSON array
disks_json="${disks_json%,}]"

# Write to disks.json
echo "$disks_json" > disks.json

# from sg_readcap -l /dev/sdX
protection_type
last_lba
last_lba_hex
logical_block_count
logical_block_size
logical_blocks_per_physical_block
physical_block_size
lowest_aligned_lba
logical_size_bytes
logical_size_mib
logical_size_gb
logical_size_tb

# from sas3ircu 0 display - controller info
controller_type
controller_firmware
controller_channel_description
controller_initiator_id
controller_slot_number
controller_segment_number
controller_bus
controller_busdevice
controller_function
controller_raid_support

# from sas3ircu 0 display - controlldevice info
initiator_id
device_type
enclosure_number
slot_number
sas_address
sas_state
sas_size_mb
sas_size_sectors
sas_manufacturer
model_number
firmware_revision
serial_number
unit_serial_number
guid
protocol
drive_type



# zpool status poolname
pool_name
pool_state