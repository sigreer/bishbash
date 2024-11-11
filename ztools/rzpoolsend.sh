#!/bin/bash

# Default values (lowest priority)
DEFAULT_LOCAL_DATASET="local_dataset"
DEFAULT_TARGET_DATASET="target_dataset"
DEFAULT_TARGET_HOST=""
DEFAULT_TARGET_USER=""
DEFAULT_TARGET_ZPOOL="target_zpool"

# Load environment variables from .env file if it exists (medium priority)
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Define variables (can be overridden by .env or CLI arguments)
TARGET_HOST="${RZPOOLSEND_TARGET_HOST:-$DEFAULT_TARGET_HOST}"
TARGET_USER="${RZPOOLSEND_TARGET_USER:-$DEFAULT_TARGET_USER}"
TARGET_ZPOOL="${RZPOOLSEND_TARGET_ZPOOL:-$DEFAULT_TARGET_ZPOOL}"

usage() {
    echo "Usage:"
    echo " $0 [local_dataset] [target_dataset]"
    echo " "
    echo "Example:"
    echo " $0 local_zpool/local_dataset target_zpool/target_dataset"
    echo " "
    echo "Options:"
    echo " --help    Display this help message"
}

# Check for --help argument
if [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# Check the number of arguments (highest priority)
if [ $# -eq 0 ]; then
    LOCAL_DATASET="${RZPOOLSEND_LOCAL_DATASET:-$DEFAULT_LOCAL_DATASET}"
    TARGET_DATASET="${RZPOOLSEND_TARGET_DATASET:-$DEFAULT_TARGET_DATASET}"
elif [ $# -eq 1 ]; then
    LOCAL_DATASET="$1"
    TARGET_DATASET="$1"
elif [ $# -eq 2 ]; then
    LOCAL_DATASET="$1"
    TARGET_DATASET="$2"
else
    usage
    exit 1
fi

# Validation checks
echo "Performing validation checks:"

# Check local privileges
if [ $(id -u) -eq 0 ] || zfs allow $LOCAL_DATASET | grep -q "send"; then
    echo "[✓] Local privileges: Sufficient"
else
    echo "[✗] Local privileges: Insufficient"
    exit 1
fi

# Function to execute command locally or via SSH
execute_command() {
    if [ -z "$TARGET_HOST" ]; then
        eval "$1"
    else
        ssh ${TARGET_USER}@${TARGET_HOST} "$1"
    fi
}

# Check target dataset and privileges
if execute_command "zfs list ${TARGET_ZPOOL}/${TARGET_DATASET} >/dev/null 2>&1"; then
    echo "[✓] Target dataset: Exists"
else
    echo "[✗] Target dataset: Does not exist"
    exit 1
fi

if [ -z "$TARGET_HOST" ] || execute_command "sudo -n true 2>/dev/null"; then
    echo "[✓] Target privileges: Sufficient"
else
    echo "[✗] Target privileges: Insufficient"
    exit 1
fi

# Check for conflicting datasets
if execute_command "zfs list -H -o name -r ${TARGET_ZPOOL}/${TARGET_DATASET} | grep -q '^${TARGET_ZPOOL}/${TARGET_DATASET}/${LOCAL_DATASET#*/}'"; then
    echo "[✗] Conflicting datasets: Found"
    exit 1
else
    echo "[✓] Conflicting datasets: None found"
fi

echo "Validation completed successfully."

# Get the list of child datasets
CHILD_DATASETS=$(zfs list -H -o name -r $LOCAL_DATASET)

# Iterate over each child dataset
for dataset in $CHILD_DATASETS; do
    SNAPSHOT_NAME="${dataset}@backup_$(date +%Y%m%d_%H%M%S)"
    
    echo "Creating snapshot: $SNAPSHOT_NAME"
    zfs snapshot $SNAPSHOT_NAME
    
    # Calculate the target dataset path
    TARGET_PATH="${TARGET_ZPOOL}/${TARGET_DATASET#*/}/${dataset#$LOCAL_DATASET/}"
    
    echo "Sending dataset $dataset to ${TARGET_PATH}"
    if [ -z "$TARGET_HOST" ]; then
        zfs send $SNAPSHOT_NAME | zfs receive -F ${TARGET_PATH}
    else
        zfs send $SNAPSHOT_NAME | ssh ${TARGET_USER}@${TARGET_HOST} "zfs receive -F ${TARGET_PATH}"
    fi
    
    # Clean up local snapshots older than 7 days for each dataset
    echo "Cleaning up local snapshots for $dataset older than 7 days"
    zfs list -t snapshot -o name -s creation | grep "${dataset}@" | head -n -7 | xargs -r -n 1 zfs destroy
done

echo "Backup completed."
