#!/bin/bash

host="host1"
source="/directory/source"
dirs=("directory1" "directory2" "directory3" "directory4" "directory5" "directory6")
target="/directory/target"
zfs_pool="zfs_pool"

if [ ! -d $target ]
then
    mkdir -p $target
fi

total_size=0
declare -A dir_sizes

for i in ${dirs[@]}
do
    dirsize=$(ssh $host "du -sb $source/$i" | awk '{print $1}')
    dir_sizes[$i]=$dirsize
    total_size=$((total_size + dirsize))
    echo "$i: $(numfmt --to=iec $dirsize)"
done

echo "Total size: $(numfmt --to=iec $total_size)"

# Check available space in the ZFS pool
available_space=$(zfs list -o available -Hp $zfs_pool | awk '{print $1}')

# Convert available space to bytes for comparison
available_space_bytes=$(numfmt --from=iec $available_space)

if (( available_space_bytes < total_size )); then
    echo "Error: Not enough space in the ZFS pool. Required: $(numfmt --to=iec $total_size), Available: $available_space"
    exit 1
fi

transferred_size=0

for i in ${dirs[@]}
do
    rsync -avzh $host:$source/$i $target/$i
    transferred_size=$((transferred_size + dir_sizes[$i]))
    percent_transferred=$(awk "BEGIN {printf \"%.2f\", ($transferred_size/$total_size)*100}")
    echo "Transferred $percent_transferred% of total"
done

echo "Total transferred: $(numfmt --to=iec $transferred_size)"

zfs list backup2