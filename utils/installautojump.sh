#!/bin/bash
apt install autojump sshpass -y
echo ". /usr/share/autojump/autojump.sh" > ~/.bashrc
source "${HOME}/.bashrc"
