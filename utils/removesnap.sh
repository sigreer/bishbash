#!/bin/bash

snap remove --purge lxd
snap remove --purge core20
snap remove --purge snapd

apt autoremove --autoremove snapd

cat <<EOF > /etc/apt/prefereces.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

apt update