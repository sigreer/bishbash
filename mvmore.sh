#!/bin/bash
source="my/source"
destination="me@myserver:~/"
apps=($(ls))
cd $source
for i in "${apps[@]}"; do
        scp -r "$i" "$destination";
        echo "scp -r" "$i" "$destination";
done;
