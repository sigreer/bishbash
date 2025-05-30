#!/bin/bash
echo "This script will copy the kwinrc file to a backup location and then delete the original to force a display reset"

cp -a ~/.config/kdedefaults/kwinrc ~/.config/kdedefaults/kwinrc.bkup
rm -f ~/.config/kdedefaults/kwinrc
ln -s ~/.config/kdedefaults/kwinrc $HOME/kwinrc.bkup
echo "Copied ~/.config/kdedefaults/kwinrc to ~/.config/kdedefaults/kwinrc.bkup"
echo "symlinked in home dir as you will probably forget this location"
while true; do
	read -p "Restart?" yn
	case $yn in
	[Yy]* ) reboot now;;
	[Nn]* ) exit;;
	*) echo "Answer the question, dickhead";;
	esac
done
