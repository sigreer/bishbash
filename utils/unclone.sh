#!/bin/bash

read -p "Enter new hostname:" newhostname
read -p "Enter search domain:" newsearchdomain

echo "setting new hostname"
sudo hostnamectl set-hostname "$newhostname"
echo "backing up machine-id"
sudo cp /etc/machine-id /root/old-machine-id
echo "deleting old machine-id"
sudo rm /etc/machine-id
oldmachineid=$(sudo cat /root/old-machine-id)
sudo echo "old machine id: ${oldmachineid}"
sudo systemd-machine-id-setup
newmachineid=$(sudo cat /etc/machine-id)
sudo echo "new machine id: ${newmachineid}"
echo "backing up hosts file"
sudo cp /etc/hosts /root/old-hosts
echo "changing hosts file to include new hostname"
sudo sed -i "/127\.0\.1\.1/ s/.*/127\.0\.1\.1\t${newhostname}/g" ./hosts
sudo sed -i "/^127\.0\.1\.1 $newhostname/a search $newsearchdomain" /etc/hosts
echo "DONE. GONE FOREVER."