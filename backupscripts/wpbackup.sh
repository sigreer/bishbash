#!/bin/bash
source .wpbackup.env
cd ~/
mysqldump -u $user -p$pass --add-drop-table -h $host $db | bzip2 -c > backup.sql.bz2
cp -Rp
