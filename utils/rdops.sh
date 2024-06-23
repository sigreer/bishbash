#!/bin/bash

HOSTS=$HOSTS_LIST
# Load the .env file
#source .env

# Split the HOSTS variable into an array
IFS=',' read -ra HOST_ARRAY <<< "$HOSTS"

# Function to check if a host is online
is_host_online() {
    local host=$1
    ping -c 1 -W 1 "$host" &> /dev/null  # Ping the host with a timeout of 1 second
    return $?  # Return the exit status of the ping command
}

# Loop through each host, check if it's online, and execute the command if it is
for HOST in "${HOST_ARRAY[@]}"; do
    if is_host_online "$HOST"; then
        echo "===== Output for $HOST (Online) ====="
        ssh "$HOST" "sudo /usr/bin/dops"
    else
        echo "===== $HOST is Offline ====="
    fi
    echo -e "\n"  # Double line break
done
