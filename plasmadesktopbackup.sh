#!/bin/bash
mkdir -p ~/tempbackup/{.config,.local}
cp ~/.config/lattedockrc ~/tempbackup/.config/
cp -R ~/.config/lattedock ~/tempbackup/.config/
cp ~/.config/{plasmawindowedrc,plasmarc,plasma-org.kde.plasma.desktop-appletsrc,plasmanotifyrc,plasma-localerc,plasma-emojierrc} ~/tempbackup/.config/cp -R ~/.config/plasma-workspace ~/tempbackup/.config/
NAME=desktop_configuration_backup$(date '+%Y-%m-%d')
tar -cvzf "$NAME.tar.gz" ~/tempbackup/*
echo "$NAME.tar.gz copied to $pwd"
rm -R ~/tempbackup
echo "temporary files removed"
echo "complete"
exit 0
