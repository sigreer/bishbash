#!/bin/bash
apt update
apt upgrade -y
apt install autojump sshpass -y
echo ". /usr/share/autojump/autojump.sh" > ~/.bashrc
source ~/.bashrc
mkdir /tilt/scripts -p
scp root@192.168.201.221:/mnt/rn1t3z3-25tb/tilt/hostconfig/.credentials /tilt/scripts/
sshpass -f /tilt/scripts/.credentials scp root@192.168.201.221:/mnt/rn1t3z3-25tb/tilt/certificates/CAs/* /usr/local/share/ca-certificates/
update-ca-certificates
cat <<EOT >> ~/.ssh/config
Host nas1
	Hostname 192.168.201.221
	User root
EOT
cd /tilt/scripts
sshpass -f .credentials scp root@192.168.201.221:/mnt/rn1t3z3-25tb/tilt/scripts/* /tilt/scripts/
chmod +x /tilt/scripts/*


sshpass -f .credentials scp nas1:/mnt/rn1t3z3-25tb/hostconfig/known_hosts ~/.ssh/
sshpass -f .credentials scp nas1:/mnt/rn1t3z3-25tb/hostconfig/authorized_keys ~/.ssh/
#echo "|1|m11o3V8aePiHnTQwfCXoJeYPapU=|jmVWTdsB8xh7Rrx80H03K8HPW80= ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLghRwSKtH9vBC8F9w81bIHMT63ymevyDa+ROXMN1ZpG3A3uVtl9Hhib/jBF6ZyhYSTf4CCnHGfe+qn8jUGvT70=" > ~/.ssh/known_hosts
#echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDiuehYmqyRuzVfDjjmBLteTyI8N4vHsGy2LyU4qV4dMyEAH39xj0QhjFghvUWpJtqHCNxMTriR1/rXP1jNDJ+vPNym4uN0IDyRcyAOoaYVRu/4gBeqZmJ2vMJh9Ql4XIy0MRlXsYoMnycEox2EL0cxfvHW0P1P3Sw6cKVhHeKEkT9xDuDqpPPyGZyyH5TlBQak7L6X9ohRlt1GAn5//EaooG5ZvNMwDPNnxwdpUp6MxtGUDj9o8dszkd+uW6bB/qSpmjPYfM09pclhAaZA5qxfbOBhuRLeOcQXoEk2sykS8U22opG6iUiRUb6KkAyn1YG0OMg8okszp7f44eKtJoqaa19GTroK3IOMxEiURjTU7qvMPsorweJN2d8snEEPKrntEYxhT3/HudBs0mVz/wN/TfkelYXxFxV6CnxUZAUOiSDNjqlJuPjQlCddoZWBB43OQtAl2L4Ws1c8QPZkbL08Nj9b6PsIdiRDfhuHwvj0Gi/vPD6O4hNayb2FrXH2T38= simon@SiDesktop" > ~/.ssh/authorized_keys


