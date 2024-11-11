#!/bin/bash

# Variables
SOURCE_POOL="z1"
SOURCE_DATASETS=("example1" "example2") # List of datasets to back up
REMOTE_USER="username"
REMOTE_HOST="10.1.1.1"
REMOTE_POOL="tank"
REMOTE_DATASET_ROOT="data/set"
REMOTE_SSH_PORT=22

# Generate a timestamp
TIMESTAMP=$(date +%Y%m%d%H%M%S)

for DATASET in "${SOURCE_DATASETS[@]}"; do
  # Create a snapshot
  SNAPSHOT_NAME="${SOURCE_POOL}/${DATASET}@${TIMESTAMP}"
  echo "creating snapshot $SNAPSHOT_NAME"
  zfs snapshot -r $SNAPSHOT_NAME

  # Check if the snapshot was created successfully
  if [ $? -ne 0 ]; then
    echo "Failed to create snapshot for ${DATASET}. Skipping..."
    continue
  fi

  # Send the snapshot to the remote TrueNAS SCALE device
  echo "sending $SNAPSHOT_NAME"
  zfs send -R $SNAPSHOT_NAME | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $REMOTE_SSH_PORT ${REMOTE_USER}@${REMOTE_HOST} "sudo zfs receive -F ${REMOTE_POOL}/${REMOTE_DATASET_ROOT}/${DATASET}_backup"

  # Cleanup old snapshots (optional, retain the last 7 snapshots)
  echo "cleaning up old snapshots locally"
  zfs list -t snapshot -o name -s creation -d 1 ${SOURCE_POOL}/${DATASET} | grep '@' | head -n -7
  #| xargs -n 1 zfs destroy
  echo "cleaning up old snapshots remotely"
  # Optionally, clean up old snapshots on the remote TrueNAS SCALE device
  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $REMOTE_SSH_PORT ${REMOTE_USER}@${REMOTE_HOST} "sudo zfs list -t snapshot -o name -s creation -d 1 ${REMOTE_POOL}/${REMOTE_DATASET_ROOT}/${DATASET}_backup | grep '@' | head -n -7
  #| xargs -n 1 zfs destroy"

  # Logging
  echo "Snapshot ${SNAPSHOT_NAME} sent to ${REMOTE_HOST}:${REMOTE_POOL}/${DATASET}_backup at $(date)" >> /var/log/zfs_snapshot_send.log
  echo "Snapshot ${SNAPSHOT_NAME} sent to ${REMOTE_HOST}:${REMOTE_POOL}/${DATASET}_backup at $(date)" >> /mnt/disks/z1/Admin/logs/bkup2sgh.log
done