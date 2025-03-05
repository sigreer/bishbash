#!/bin/bash

# Set the source directory
SOURCE_DIR="$1"

# Ensure the source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Process each file in the source directory
for file in "$SOURCE_DIR"/*.{jpg,jpeg,png,mp4,mov}; do
    # Ensure it's a file
    [[ -f "$file" ]] || continue

    # Extract the filename
    filename=$(basename -- "$file")
    
    # Use regex to extract the date (YYYYMMDD) part
    if [[ "$filename" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})[-_] ]]; then
        year="${BASH_REMATCH[1]}"
        month="${BASH_REMATCH[2]}"
        
        # Create the target directory in source directory
        target_dir="$SOURCE_DIR/$month"
        mkdir -p "$target_dir"
        
        # Move the file
        mv -v "$file" "$target_dir/"
    else
        echo "Skipping unrecognized file: $filename"
    fi
done

echo "Sorting complete."
