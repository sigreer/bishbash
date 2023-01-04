#!/bin/bash
[[ -e /etc/os-release ]] && . /etc/os-release && osname=$(echo "$NAME") && osversion=$VERSION_ID # freedesktop.org and systemd
[[ -e /etc/lsb-release ]] && . /etc/lsb-release && osname=$DISTRIB_ID && osversion=$DISTRIB_RELEASE # For some versions of Debian/Ubuntu without lsb_release command
#[[ -e /etc/debian_version ]] && osversion=`. /etc/debian_verion`; osname="Debian" # Older Debian/Ubuntu/etc.
[[ -e /etc/SuSe-release ]] && osname="SuSe" ## Incomplete
[[ -e /etc/redhat-release ]] && osname="Redhat" ## Incomplete
[[ -z $osname ]] && osname=$(uname -s) ## If still empty use uname -s
[[ -z $osversion ]] && osversion=$(uname -r) ## If still empty use uname -r

instajdebbash () {
    apt update
    apt install autojump -y
    grep -qxF 'autojump' ~/.bashrc || echo '. /usr/share/autojump/autojump.sh' >> ~/.bashrc
    source ~/.bashrc
}

installautojump () {
    if [[ $osname =~ "Debian" || $osname =~ "buntu" && $currentshell == "bash" ]]; then
        instajdebbash
    else
        cd ~/
        git clone git://github.com/wting/autojump.git
        cd autojump
        ./install.py
        [[ -e "/usr/share/autojump" ]] && cd ~/ 
        rm -R ./autojump
    fi
    grep -qxF "autojump" ~/."$currentshell"rc || echo "Autojump isn't referenced in ~/."$currentshell"rc. Pleae check installation" && echo "Autojump installed"
    }

installaj () { aji=1; while [ $aji -le 3 ]; do installautojump aji=$(( aji++ )); done }

addajtoshell () {
    if [[ $currentshell == "bash" ]]; then
    echo '. /usr/share/autojump/autojump.sh' >> ~/.bashrc
    fi
}

[[ -z $XDG_CURRENT_DESKTOP ]] && systemtype="server" || systemtype="desktop" ## OK
[[ $systemtype == "desktop" ]] && sessiontype=$(echo $GDMSESSION$XDG_SESSION_TYPE) && desktopenv=$(echo $XDG_CURRENT_DESKTOP) ## OK
[[ -e "/usr/bin/autojump" ]] && autojumppath="/usr/bin/autojump" && autojumpinst="Yes" || echo "/usr/bin/autojump doesn't exist" ## OK
[[ $SHELL =~ "zsh" ]] && currentshell="zsh" && shellconfigfile="~/.zshrc"
[[ $SHELL =~ "bash" ]] && currentshell="bash" && shellconfigfile="~/.bashrc"
[[ -e /usr/share/autojump ]] || installaj && echo "Autojump not found, installing..."
filecontainsaj=$(cd ~/ && grep ".*autojump.*" .${currentshell}rc) 
[[ -z $filecontentsaj ]] && autojumploaded="No" && addajtoshell || autojumploaded="Yes" 

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

if [[ $systemtype == "server" ]]; then
aliases_docker=$(cat <<EOB
alias recomp2='docker-compose down && docker-compose up'
alias comp2='docker-compose up'
alias recomp='docker compose down && docker-compose up'
alias comp='docker compose up'
alias comped='nano docker-compose.yml'
alias compbk='cp docker-compose.yml docker-compose.backup`echo \$\("date"\)`.yml'
EOB
)
fi

aliases_git=$(cat <<EOB
alias quickpush='git add . && git commit -m "quickpush" && git push origin main'
EOB
)

function add_custom_aliases () {
    [[ -e ~/.${currentshell}rc ]] && echo "found ~/."$currentshell"rc"
    if [[ -e ~/.${currentshell}_custom_aliases ]]; then
        echo "Found ~/."$currentshell"_custom_aliases. Deleting..."
        rm ~/."$currentshell"_custom_aliases
        echo "Deleted ~/."$currentshell"_custom_aliases. Recreating..."
    fi
cat > ~/."$currentshell"_custom_aliases <<ALIASES 
${aliases_general}
${aliases_docker}
${aliases_git}
ALIASES
    [[ -e ~/."$currentshell"_custom_aliases ]] && echo "created ~/."$currentshell"_custom_aliases"
    echo "Checking for reference in ~/."$currentshell"rc for ~/."$currentshell"_custom_aliases"
    grep -qxF "source ~/.${currentshell}_custom_aliases" ~/."$currentshell"rc || echo "source ~/."$currentshell"_custom_aliases" >> ~/."$currentshell"rc && echo "Already present, continuing..."
    echo "Sourcing~/."$currentshell"_custom_aliases"
    source ~/."$currentshell"_custom_aliases
    echo "Done setting up aliases."
}

## MANJARO
if [[ $osname == "ManjaroLinux" ]]; then
    echo "Running on $osname $systemtype"
    add_custom_aliases
    exit
fi

## DEBIAN OR UBUNTU SERVER
if [[ $osname == "Debian" || $osname =~ "buntu" ]] && [[ $systemtype == "server" ]]; then
    echo "Running on $osname $systemtype"
    add_custom_aliases
    exit
fi
echo "script finished"
exit