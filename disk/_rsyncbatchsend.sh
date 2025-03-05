#!/bin/bash

host="nas1"
source="/backup2/ZZZ/"
dirs=("tmpro" "snubnub" "ZZZlocal" "stash" "0.PLAYLISTS" "privpron")
target="/mnt/tyson/ZZZ/"
zfs_pool="tyson"

if [ ! -d $target ]
then
    mkdir -p $target
fi

total_size=0
declare -A dir_sizes

# Calculate the size of local directories
for i in ${dirs[@]}
do
    dirsize=$(du -sb $source/$i | awk '{print $1}')
    dir_sizes[$i]=$dirsize
    total_size=$((total_size + dirsize))
    echo "$i: $(numfmt --to=iec $dirsize)"
done

echo "Total size: $(numfmt --to=iec $total_size)"

# Check available space on the remote host's ZFS pool
available_space=$(ssh $host "zfs list -o available -Hp $zfs_pool" | awk '{print $1}')

# Convert available space to bytes for comparison
available_space_bytes=$(numfmt --from=iec $available_space)

if (( available_space_bytes < total_size )); then
    echo "Error: Not enough space in the remote ZFS pool. Required: $(numfmt --to=iec $total_size), Available: $available_space"
    exit 1
fi

transferred_size=0

# Use rsync to push directories to the remote host asynchronously
for i in ${dirs[@]}
do
    rsync -avzh $source/$i $host:$target/$i &
    transferred_size=$((transferred_size + dir_sizes[$i]))
    percent_transferred=$(awk "BEGIN {printf \"%.2f\", ($transferred_size/$total_size)*100}")
    echo "Transferred $percent_transferred% of total"
done

wait

echo "Total transferred: $(numfmt --to=iec $transferred_size)"

ssh $host "zfs list $zfs_pool"