#!/bin/bash
[[ -e /etc/os-release ]] && . /etc/os-release && osname=$(echo "$NAME") && osversion=$VERSION_ID # freedesktop.org and systemd
[[ -e /etc/lsb-release ]] && . /etc/lsb-release && osname=$DISTRIB_ID && osversion=$DISTRIB_RELEASE # For some versions of Debian/Ubuntu without lsb_release command
#[[ -e /etc/debian_version ]] && osversion=`. /etc/debian_verion`; osname="Debian" # Older Debian/Ubuntu/etc.
[[ -e /etc/SuSe-release ]] && osname="SuSe" ## Incomplete
[[ -e /etc/redhat-release ]] && osname="Redhat" ## Incomplete
[[ -z $osname ]] && osname=$(uname -s) ## If still empty use uname -s
[[ -z $osversion ]] && osversion=$(uname -r) ## If still empty use uname -r


installautojump () { 
    cd ~/
    git clone git://github.com/wting/autojump.git
    cd autojump
    ./install.py
    [[ -e "/usr/share/autojump" ]] && cd ~/ 
    rm -R ./autojump 
    }

installaj () { aji=1; while [ $aji -le 3 ]; do installautojump aji=$(( aji++ )); done }

[[ -z $XDG_CURRENT_DESKTOP ]] && systemtype="server" || systemtype="desktop" ## OK
[[ $systemtype == "desktop" ]] && sessiontype=$(echo $GDMSESSION$XDG_SESSION_TYPE) && desktopenv=$(echo $XDG_CURRENT_DESKTOP) ## OK
[[ -e "/usr/bin/autojump" ]] && autojumppath="/usr/bin/autojump" && autojumpinst="Yes" || echo "/usr/bin/autojump doesn't exist" ## OK
[[ $SHELL =~ "zsh" ]] && currentshell="zsh" && shellconfigfile="~/.zshrc" || echo "Shell not zsh"

filecontents=$(cd ~/ && grep ".*autojump.*" .${currentshell}rc) 
[[ -z $filecontents ]] && installaj || autojumploaded="Yes" 

cat << EndOfMessage
OS Name: $osname
OS Version: $osversion
System Type: $systemtype
Desktop Environment: $desktopenv
Session: $sessiontype
Current User's Shell: $SHELL
Autojump Installed: $autojumpinst
EndOfMessage
exit

