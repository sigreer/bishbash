#!/bin/bash

removeunderscore() {
 for i in _*; do
  mv "${i}" "${i:1}";
 done
}
 
replaceunderscores() {
 substr="_"
 for file in *; do
  if [[ $file == *"$substr"* ]];
  then 
    mv "$file" "$(echo "$file" | tr '_' ' ')" 
  fi; done
}

nfosubdirs() {
 for d in *.nfo; do
  if [[ ! -d "$d%.nfo" ]]; then
    nd="${d%.nfo}"
    mkdir "${nd}"
    mv "${nd}"*.* "${nd}"/
  fi; done
}

scriptname=`basename "$0"`

usage() {
        echo "######## USAGE #########"
        echo "./${scriptname} <argument>"
        echo "arguments:"
        echo "nfosubdirs - converts nfo filenames to directories and moves associated files"
        echo "leadingunderscore - removes leading underscores"
        echo "removeunderscores - replaces all underscores with whitespace"
}

if [[ $1 == "nfosubdirs" ]]; then
        nfosubdirs;
        echo "Converted nfo files to dirs and copied similar filenames into dir"
elif [[ $1 == "leadingunderscore" ]]; then
        leadingunderscore
        echo "Removed leading underscores from filenames";
elif [[ $1 == "replaceunderscores" ]]; then
        replaceunderscores
        echo "Replaced underscores in filenames with whitespace";
else
        usage;
fi
