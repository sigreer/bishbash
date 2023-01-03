#!/bin/bash
echo "Updating System"
apt update
echo "Upgrading System"
apt upgrade -y
echo "Removing previous installations"
apt-get remove docker docker-engine docker.io containerd runc
echo "Installing dependencies"
apt -y install ca-certificates curl gnupg lsb-release
echo "Installing Docker GPG key"
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin

COMPOSE_VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')
COMPOSE_DESTINATION=/usr/local/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s)-$(uname -m) -o $COMPOSE_DESTINATION
chmod +x $COMPOSE_DESTINATION