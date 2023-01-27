#!/bin/bash
fPrefix=$(printf '%q\n' "${PWD##*/}")
 for month in 0{1..9} {10..12} ; do
        mv "./"*${fPrefix}${month}* "./"$month
 done
