#!/bin/bash
# disk usage without network shares
tail=`mount | awk '/nfs/ {print $3}' | sed ':a;N;$!ba;s/\n/ --exclude /g'`
ncdu --exclude $tail /
