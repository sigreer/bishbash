#!/bin/bash

updateandinstall () {
    apt update
    apt install -y handbrake-cli ffmpeg
}

tdarrinst () {
mkdir /root/tdarrinst
mount 10.10.1.121:/mnt/nvme1/mediaserver/tdarrinst /root/tdarrinst
cd /root/tdarrinst
tar -xzvf tdarrbot.tar.gz -C /
cd /tdarrbot
}

mountmedia () {
mkdir -p /tdarrbot/Videos/{Movies,TV}
mount 10.10.1.121:/mnt/rn1t3z3-25tb/sghome/TV /tdarrbot/Videos/TV
mount 10.10.1.121:/mnt/rn1t3z3-25tb/sghome/Movies /tdarrbot/Videos/Movies
mkdir /tdarrbot/tdarr-temp
mount 10.10.1.121:/mnt/nvme1/mediaserver/tdarr/transcode-cache /tdarrbot/tdarr-temp
}

editconfig () {

#thisnodeip=$(/sbin/ip -o -4 addr list vmbr0 | awk '{print $4}' | cut -d/ -f1)
#sed -i "s/PUTNODEIPHERE/${thisnodeip}/g" ./configs/Tdarr_Node_Config.json
thisnodename=$(hostname)
sed -i "s/PUTNODENAMEHERE/${thisnodename}/g" ./configs/Tdarr_Node_Config.json
}

updateandinstall
tdarrinst
mountmedia
editconfig
