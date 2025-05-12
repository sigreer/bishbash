#!/bin/bash

# Usage: ./script.sh host1 host2 host3 ...

for HOST in "$@"; do
  echo "=== Checking $HOST ==="

  # 1. Check if 2375 or 2376 is open
  if ssh "$HOST" "ss -lnt | grep -q ':2375 '" ; then
    echo "Port 2375 is open on $HOST"
  elif ssh "$HOST" "ss -lnt | grep -q ':2376 '" ; then
    echo "Port 2376 is open on $HOST"
  else
    echo "Neither 2375 nor 2376 is open. Configuring..."

    # 2. Check for /etc/docker/daemon.json
    if ! ssh "$HOST" "[ -f /etc/docker/daemon.json ]"; then
      echo "Creating /etc/docker/daemon.json"
      ssh "$HOST" "echo '{\"hosts\": [\"unix:///var/run/docker.sock\", \"tcp://0.0.0.0:2375\"]}' | sudo tee /etc/docker/daemon.json"
    else
      # 3. Ensure hosts key is present and correct
      echo "Ensuring 'hosts' key in daemon.json"
      ssh "$HOST" "
        sudo jq '.hosts |= (if . == null then [\"unix:///var/run/docker.sock\", \"tcp://0.0.0.0:2375\"] else (if (index(\"tcp://0.0.0.0:2375\") == null) then . + [\"tcp://0.0.0.0:2375\"] else . end | if (index(\"unix:///var/run/docker.sock\") == null) then . + [\"unix:///var/run/docker.sock\"] else . end) end)' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.tmp && sudo mv /etc/docker/daemon.json.tmp /etc/docker/daemon.json
      "
    fi

    # 4. Create systemd override if not present
    ssh "$HOST" "sudo mkdir -p /etc/systemd/system/docker.service.d"
    ssh "$HOST" "if [ ! -f /etc/systemd/system/docker.service.d/override.conf ]; then
      echo -e '[Service]\nExecStart=\nExecStart=/usr/bin/dockerd' | sudo tee /etc/systemd/system/docker.service.d/override.conf
    fi"

    # 5. Reload and restart Docker
    ssh "$HOST" "sudo systemctl daemon-reload && sudo systemctl restart docker"
  fi

  # 6. Check Docker status
  if ssh "$HOST" "systemctl is-active --quiet docker"; then
    echo "Docker is running on $HOST"
  else
    echo "Docker is NOT running on $HOST"
    ssh "$HOST" "systemctl status docker --no-pager"
  fi

  echo
done
