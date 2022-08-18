#!/bin/bash
$websitedb = 
$websitedir
cd ~/
mysqldump -u webdb -pOliverTw1st --add-drop-table -h localhost tilttech | bzip2 -c > backup.sql.bz2
cp -Rp
