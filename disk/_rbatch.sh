#!/bin/bash

max_jobs=2
current_jobs=0

# Check if exactly two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /local/source_dir user@host:/remote/target_dir"
    exit 1
fi

# Assign arguments to variables
source_dir="$1"
target_dir="$2"

# Check if the source directory exists
if [ ! -d "$source_dir" ]; then
    echo "Error: Source directory '$source_dir' does not exist."
    exit 1
fi

# Loop through all subdirectories in the source directory
for d in "$source_dir"/*/; do
    # Ensure it's a directory before syncing
    [ -d "$d" ] || continue

    # Check if we have reached the maximum number of concurrent jobs
    while [ "$current_jobs" -ge "$max_jobs" ]; do
        wait -n
        current_jobs=$((current_jobs - 1))
    done

    # Perform rsync in the background
    rsync -avzh "$d" "${target_dir}/$(basename "$d")" >> "rbatch.log" &
    current_jobs=$((current_jobs + 1))
    echo "Transferring $(basename "$d")"
done

# Wait for all background rsync jobs to complete
wait

echo "All transfers are complete."