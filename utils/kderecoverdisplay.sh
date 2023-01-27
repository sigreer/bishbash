#!/bin/bash

cp -a ~/.config/kdedefaults/kwinrc ~/.config/kdedefaults/kwinrc.bkup
rm -f ~/.config/kdedefaults/kwinrc
echo "Done."
while true; do
	read -p "Restart?" yn
	case $yn in
	[Yy]* ) reboot now;;
	[Nn]* ) exit;;
	*) echo "Answer the question, dickhead";;
	esac
done
