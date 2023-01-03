#!/bin/bash
## This script deletes and redownloads the central script repo updates after escalating to root
if [[ $EUID > 0 ]]
  then echo "Not currently running as root" && sudo -s
  exit
fi
source /etc/tilt/.envvars
rm -r $tiltdir/scripts
#rm -r $tiltdir/hostconfig
rm /etc/cron.hourly/refresh.sh
mkdir $tiltdir/scripts
#mkdir $tiltdir/hostconfig
sshpass -p $nas1pass scp -r $nas1host:$nas1basedir/scripts/* $tiltdir/scripts/
#scp -r nas1.sghome:/files/tilt/tiltbasedir/hostconfig/* $tiltdir/hostconfig/
chmod +x $tiltdir/scripts/*
#source /tilt/scripts/certsetup.sh
cd /etc/cron.hourly
ln -s $tiltdir/scripts/refresh.sh tiltrefresh
