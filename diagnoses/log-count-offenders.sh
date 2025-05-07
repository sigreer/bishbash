#!/bin/bash

DATE="2024-04-30"
CUTOFF=$(date -d "$DATE" +%s)

echo "Counting offenders since ${DATE} (epoch: $CUTOFF)"

journalctl --user --output=short-unix | awk -v cutoff="$CUTOFF" '
{
    if (NF < 3) next
    if ($1 ~ /^[0-9]+$/ && match($0, / ([^[]]+)\[[0-9]+\]:/, m)) {
        ts_epoch = $1
        if (ts_epoch < cutoff) next
        cmd = m[1]
        ts = strftime("%Y-%m-%d", ts_epoch)
        count[ts,cmd]++
    }
}
END {
    if (length(count) == 0) {
        print "No matching log entries found after cutoff."
    } else {
        for (k in count) print count[k], k
    }
}' | sort -nr
