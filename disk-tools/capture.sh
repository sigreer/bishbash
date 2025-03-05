#!/bin/bash

compressionlevel=9

# Check if the user has provided an argument
if [ -z "$1" ]; then
  echo "Please provide an argument (disk name)."
  exit 1
fi

# Get the disk name from the user input
diskname=$1
disk=/dev/"$diskname"

# Check if the user has provided an argument
if [ -z "$2" ]; then
  echo "Please provide a filename."
  echo "./diskcapture.sh <DISK> <NAME>"
  echo "./diskcapture.sh /dev/sda myimage"
  exit 1
fi

filename="$2"

# Check if the disk exists
if [ ! -b "$disk" ]; then
  echo "The disk '$disk' does not exist."
  exit 1
fi


if [[ -e "${filename}.img.gz" || -L "${filename}.img.gz" ]]; then
    i=0
    while [[ -e "${filename}-${i}.img.gz" || -L "${filename}-${i}.img.gz" ]] ; do
        (( i++ ))
    done
    filename="${filename}-${i}"
fi

# Get the list of partitions on the disk
partitions=( $(ls /dev/ | grep -Eo "${diskname}"'[0-9]{1,4}') )
echo "${partitions[@]}"
block_size=$(blockdev --getbsz "$disk")

# Iterate over the partitions and calculate the total number of bytes
# Then calculate the total number of sectors according to block size
total_sectors=0
total_bytes=0
for partition in "${partitions[@]}"; do
  bytes=$(blockdev --getsize64 "/dev/${partition}")
  sectors=$((bytes / block_size))
  total_bytes=$((total_bytes + bytes))
  total_sectors=$((total_sectors + sectors))
  echo "Partition $partition: $bytes bytes     $sectors sectors       Block size: $block_size"
done
echo "$disk"
echo "$total_bytes bytes"
echo "$total_sectors" sectors
dd if=${disk} bs=${block_size} count=${total_sectors} | pv -s ${total_bytes} | gzip -${compressionlevel} > ${filename}
