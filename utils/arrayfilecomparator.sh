#!/bin/bash

sourcefile="sourcefile.csv"
filter="filter.txt"
readarray -t a < "${filter}"
    for i in "${a[@]}"; do
        #sed -i "/$i/d" ${sourcefile}
        grep "$i" $sourcefile >> output.csv
    done