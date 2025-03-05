#!/bin/bash

# Grants a user ZFS permissions (snapshot, send, receive) for a specified dataset and its children.
# It can be used to enable permissions on local or remote datasets.
#
# Usage:
#   Local:  ./zfsallow.sh [user] [dataset]
#   Remote: ./zfsallow.sh user@host
#
# The script uses default values, which can be overridden by .env file or command-line arguments.
# Priority: CLI arguments > .env file > default values

# Default values (lowest priority)
DEFAULT_MAIN_DATASET="t2b"
DEFAULT_USER="$(whoami)"

# Load environment variables from .env file if it exists (medium priority)
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Define variables (can be overridden by .env or CLI arguments)
MAIN_DATASET="${ZFSALLOW_MAIN_DATASET:-$DEFAULT_MAIN_DATASET}"
USER="${ZFSALLOW_USER:-$DEFAULT_USER}"

# Parse command-line arguments (highest priority)
if [ $# -eq 1 ]; then
    if [[ "$1" == *"@"* ]]; then
        # SSH user and host specified
        SSH_USER_HOST="$1"
        REMOTE_COMMAND="sudo zfs allow $USER snapshot,send,receive $MAIN_DATASET && for dataset in \$(zfs list -H -o name -r $MAIN_DATASET); do sudo zfs allow $USER snapshot,send,receive \$dataset; done"
        ssh "$SSH_USER_HOST" "$REMOTE_COMMAND"
        echo "Permissions applied remotely for $USER on $MAIN_DATASET and its child datasets on $SSH_USER_HOST."
        exit 0
    else
        # Only dataset specified
        MAIN_DATASET="$1"
    fi
elif [ $# -eq 2 ]; then
    # User and dataset specified
    USER="$1"
    MAIN_DATASET="$2"
fi

# Apply the permissions to the parent dataset
sudo zfs allow $USER snapshot,send,receive $MAIN_DATASET

# Loop through child datasets and apply the same permissions
for dataset in $(zfs list -H -o name -r $MAIN_DATASET); do
    sudo zfs allow $USER snapshot,send,receive $dataset
done

echo "Permissions applied recursively for $USER on $MAIN_DATASET and its child datasets."
