#!/bin/bash

cd /usr/src/zenpower3

sudo make dkms-uninstall
git pull
sudo make dkms-install
