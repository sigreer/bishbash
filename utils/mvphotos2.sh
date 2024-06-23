#!/bin/bash

src_dir="$1"
dest_base_dir="$2"

# Function to check if filename matches the pattern YYYYMMDD_HHmmss.ext
function is_valid_filename {
    local filename="$1"
    if [[ "$filename" =~ ^[0-9]{8}_[0-9]{6}\..+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Loop through files in the source directory
for file in "$src_dir"/*; do
    filename=$(basename "$file")

    if is_valid_filename "$filename"; then
        month="${filename:4:2}"
        dest_dir="$dest_base_dir/$month"
        dest_file="$dest_dir/$filename"

        # Create the destination directory if it does not exist
        mkdir -p "$dest_dir"

        if [ -f "$dest_file" ]; then
            # File exists in the destination directory
            src_size=$(stat -c%s "$file")
            dest_size=$(stat -c%s "$dest_file")

            if [ "$src_size" -gt "$dest_size" ]; then
                mv "$file" "$dest_file"
                echo "DELDST for $filename in $dest_dir"
            elif [ "$src_size" -lt "$dest_size" ]; then
                rm "$file"
                echo "DELSRC for $filename in $dest_dir"
            else
                if cmp -s "$file" "$dest_file"; then
                    rm "$file"
                    echo "DELSRC for $filename in $dest_dir"
                else
                    mv "$file" "$dest_file"
                    echo "DELDST for $filename in $dest_dir"
                fi
            fi
        else
            # File does not exist in the destination directory
            mv "$file" "$dest_file"
            echo "NOMTCH for $filename in $dest_dir"
        fi
    fi
done
