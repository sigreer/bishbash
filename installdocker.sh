#!/bin/bash
COMPOSE_VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d')

echo "Updating System"
apt update
echo "Upgrading System"
apt upgrade -y
echo "Removing previous installations"
apt-get remove docker docker-engine docker.io containerd runc
echo "Installing dependencies"
apt -y install apt-transport-https ca-certificates curl gnupg2 software-properties-common
echo "Installing Docker GPG key"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "Adding Docker repository to apt sources"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
echo "Installing Docker"
apt install -y docker-ce docker-ce-cli containerd.io
echo "Download latest stable binary for Docker Compose"
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
echo "Making docker-compose binary executable"
chmod +x /usr/local/bin/docker-compose
curl -L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
echo "Installation complete"
DOCKERVERSION=$(docker -v)
DOCKERCOMPOSEVERSION=$(docker-compose -v)
echo "Installed $DOCKERVERSION and $DOCKERCOMPOSEVERSION"



download/v2.10.0/docker-compose-Linux-x86_64