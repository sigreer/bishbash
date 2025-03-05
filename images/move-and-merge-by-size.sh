#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 source_dir target_dir"
    exit 1
fi

source_dir="$1"
target_dir="$2"

if [ ! -d "$source_dir" ]; then
    echo "Error: Source directory does not exist"
    exit 1
fi

if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
fi

find "$source_dir" -type f | while read -r source_file; do
    relative_path="${source_file#$source_dir/}"
    target_file="$target_dir/$relative_path"
    target_dir_path=$(dirname "$target_file")
    
    if [ ! -d "$target_dir_path" ]; then
        mkdir -p "$target_dir_path"
    fi
    
    if [ -f "$target_file" ]; then
        source_size=$(stat -c%s "$source_file")
        target_size=$(stat -c%s "$target_file")
        
        if [ "$source_size" -lt "$target_size" ]; then
            cp "$source_file" "$target_file"
            echo "Copied (smaller): $relative_path"
        else
            echo "Skipped (larger or equal): $relative_path"
        fi
    else
        cp "$source_file" "$target_file"
        echo "Copied (new): $relative_path"
    fi
done
