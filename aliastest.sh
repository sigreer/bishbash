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

aliases_general=$(cat <<EOF
alias myip='curl ifconfig.me'
alias sortsize='ls --human-readable --size -1 -S --classify'
alias sortmodified="/bin/ls -lt | awk '{print \$6,\$7,\$8,\$9,\$10}' "
alias logtail='tail -f -n 50 /var/log/syslog'
EOF
)

aliases_docker=$(cat <<EOB
alias recomp2='docker-compose down && docker-compose up'
alias comp2='docker-compose up'
alias recomp='docker compose down && docker-compose up'
alias comp='docker compose up'
alias comped='nano docker-compose.yml'
alias compbk='cp docker-compose.yml docker-compose.backup"$(date)".yml'
EOB
)

if [[ $osname == "ManjaroLinux" ]] && [[ -e ~/.${currentshell}rc ]]; then
    [[ -e "~/.zsh_custom_aliases" ]] && rm ~/.zsh_custom_aliases && echo "deleted ~/.zsh_custom_aliases.   Recreating..."
cat > ~/.zsh_custom_aliases <<ALIASES 
${aliases_general}
${aliases_docker}
ALIASES
grep -qxF 'source ~/.zsh_custom_aliases' ~/.zshrc || echo 'source ~/.zsh_custom_aliases' >> ~/.zshrc
source ~/.zsh_custom_aliases
else
    echo "Errored, exiting"
    exit
fi
echo "script finished"
exit