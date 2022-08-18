#!/bin/bash
## Check if root and sudo if not
if [[ $EUID > 0 ]]
  then echo "Not currently running as root" && sudo -s
  exit
fi

## Check if envvars exist and create if not
{
if [ -f /etc/tilt/.envvars ]; then
    source /etc/tilt/.envvars
    echo ".envvars file found and sourced"
  else
    mkdir -p /etc/tilt/
    touch /etc/tilt/.envvars
    echo ".envvars file created"
fi    
if [ -z "$tiltdir" ]
      then
        echo "no local path set, please select one (eg /tilt)"
        read tiltdir      
      else
        echo "path exists"
fi
if [ -z "$nas1pass" ]
      then
      echo "NAS password:"
      read -s nas1pass
      else
      echo "password exists"  
fi
if [ -z "$nas1host" ]
    then
    echo "NAS Server FQDN or IP:"
    read nas1host
fi
if [ -z "$nas1basedir" ]
    then
    echo "NAS server base dir (eg. /files/basedir)"
    read nas1basedir
fi
if [ -z "$nas1user" ]
    then
    echo "NAS server SSH user (eg. root)"
    read nas1user
fi
rm /etc/tilt/.envvars
touch /etc/tilt/.envvars
cat <<EOT >> /etc/tilt/.envvars
    tiltdir=$tiltdir
    nas1pass=$nas1pass
    nas1host=$nas1host
    nas1basedir=$nas1basedir
    nas1user=$nas1user
EOT
echo "Environment Variables File:"
cat /etc/tilt/.envvars
}

## Update the system
apt update
apt upgrade -y

## Install common apps - Autojump
if [ ! -f "/usr/share/autojump/autojump.sh" ]
  then
    apt install autojump -y
    echo ". /usr/share/autojump/autojump.sh" > ~/.bashrc
    source ~/.bashrc
    echo "AUTOJUMP NEWLY CONFIGURED"
  else
    echo "AUTOJUMP ALREADY CONFIGURED"
fi

## Install sshpass
apt install sshpass -y

## Set hostname
#echo "Please name this machine. It's currently called $HOSTNAME"
#read new_hostname
#hostnamectl set-hostname $new_hostname

## Create /tilt directory and download contents from local NAS
if [ ! -d "$tiltdir" ]
  then
  mkdir $tiltdir
fi
if [ ! -d "$tiltdir/scripts" ]
  then
  mkdir $tiltdir/scripts
fi
if [ ! -d "$tiltdir/hostconfig" ]
  then
  mkdir $tiltdir/hostconfig
fi
if [ ! -d "$tiltdir/certificates" ]
  then
  mkdir $tiltdir/certificates
fi
sshpass -p $nas1pass scp -r $nas1user@$nas1host:$nas1basedir/scripts/* $tiltdir/scripts/       
sshpass -p $nas1pass scp -r $nas1user@$nas1host:$nas1basedir/hostconfig/* $tiltdir/hostconfig/
chmod +x $tiltdir/scripts/*

source $tiltdir/scripts/installcommonapps.sh

echo "Finished"

## Set up certificates
while true; do
    read -p "Install Tilt root CAs?" yn
    case $yn in
        [Yy]* ) installcerts(); break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
installcerts() {
source $tiltdir/scripts/certsetup.sh
}

## Set up SSH keys and modify SSH Daemon
source $tiltdir/scripts/sshsetup.sh
