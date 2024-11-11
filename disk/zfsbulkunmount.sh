#!/bin/bash

# List all child datasets of nvme1
datasets=$(zfs list -H -o name -r nvme1 | grep '^nvme1/')

# Loop through each dataset and unmount it
for dataset in $datasets; do
    echo "Unmounting $dataset..."
    zfs unmount $dataset
done

echo "All child datasets of nvme1 have been unmounted."
