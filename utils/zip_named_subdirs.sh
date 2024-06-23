#!/bin/bash

basedir=/tank/BayouLocal/
outputdir=$basedir
# Check if the input file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_text_file_with_subdirs>"
    exit 1
fi

# Read the file line by line
while IFS= read -r subdir; do
    # Check if the directory exists
    if [ -d "${basedir}${subdir}" ]; then
        # Create a zip file for the directory
        zip -r "${outputdir}${subdir}.zip" "${basedir}${subdir}"
        echo "Zipped $subdir to ${subdir}.zip in $outputdir"
    else
        echo "Directory $subdir does not exist. Skipping..."
    fi
done < "$1"
