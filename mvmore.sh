#!/bin/bash
destination="simon@10.10.1.42:~/"
apps=($(ls))
for i in "${apps[@]}"; do
        scp -r "$i" "$destination";
        echo "scp -r" "$i" "$destination";
done;
