#!/bin/bash
## Lists details of a SAS disks attached to a system with columnns for dev, serial, powered on time and manufactured date
## The intended purpose of the script is to identify which disks belong to the same batch

for drive in /dev/sd[a-z]; do
  if smartctl -i $drive | grep -q "SAS"; then
    serial=$(smartctl -i $drive | grep "Serial number" | awk '{print $3}')
    power_on_hours=$(smartctl -A $drive | grep "Accumulated" | awk '{print $6}');
    manufacture_date=$(smartctl -A $drive | grep "Manufactured in" | awk '{print $4, $5, $6}')
    echo "Drive: $drive, Serial: $serial, Power On Hours: $power_on_hours, Manufactured Date: $manufacture_date"
  fi
done
