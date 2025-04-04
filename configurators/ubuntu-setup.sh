#!/bin/bash

# Exit on any error
set -e

# Update package lists and install prerequisites
apt update
apt install -y curl wget apt-transport-https ca-certificates software-properties-common gnupg nmap iperf3 zoxide

# Install nala package manager
echo "deb [arch=amd64] https://deb.volian.org/volian/ scar main" | tee /etc/apt/sources.list.d/volian-archive-scar-unstable.list
gpg --keyserver keyserver.ubuntu.com --recv-keys A87015F3DA22D980
gpg --export A87015F3DA22D980 | sudo tee /etc/apt/trusted.gpg.d/volian-archive-scar-unstable.gpg > /dev/null
apt update && apt install -y nala

# Add nala function to .bashrc only if not already present
if ! grep -q "nala" ~/.bashrc; then
    cat <<EOF >> ~/.bashrc
apt() {
if [[ -e /usr/bin/nala ]]; then
  command nala "\$@"
else
  command apt "\$@"
fi
}
EOF
fi

# Install Docker and Docker Compose
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Better Docker PS (dops)
wget https://github.com/Mikescher/better-docker-ps/releases/download/v1.12/dops_linux-amd64 -O /usr/local/bin/dops
chmod +x /usr/local/bin/dops

# Install zoxide
zoxide init bash
if ! grep -q "zoxide" ~/.bashrc; then
    echo "eval "$(zoxide init bash)" >> ~/.bashrc
fi

# Set up automatic updates
apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# Create required directories
mkdir -p /root/docker /root/scripts /root/backup

. ~/.bashrc

# Add success message
echo "Setup completed successfully!"

