#!/bin/bash
## Add authorised keys, disable password login and allow root pubkey login
touch ~/.ssh/authorized_keys
cat /tilt/hostconfig/publickeys/*.pub > ~/.ssh/authorized_keys
sed -i '/PermitRootLogin/c\PermitRootLogin prohibit-password' /etc/ssh/sshd_config
sed -i '/PubKeyAuth/c\PubkeyAuthentication yes' /etc/ssh/sshd_config
sed -i '/PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
systemctl restart sshd
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
printf "${RED}SSH KEYS SET UP!${NC}\n"
