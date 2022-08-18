#!/bin/bash
sshpass -p $nas1pass scp -r $nas1user@$nas1host:$nas1basedir/certificates/* $tiltdir/certificates/

chmod 400 $tiltbasedir/certificates/*
cp $tiltbasedir/certificates/CAs/* /usr/local/share/ca-certificates/
update-ca-certificates
