#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

primary_base_dir="$PRIMARY_BASE_DIR"
secondary_base_dir="$SECONDARY_BASE_DIR"

# Check for -n flag
no_compare=false
if [ "$1" == "-n" ]; then
    no_compare=true
    shift
fi

# Function to get image quality using ImageMagick
get_image_quality() {
    identify -verbose "$1" | grep Quality | awk '{print $2}'
}

# Function to get video bitrate using ffmpeg
get_bitrate() {
    ffmpeg -i "$1" 2>&1 | grep bitrate | awk '{print $6}'
}

# Function to handle image comparison and overwrite
compare_and_overwrite_image() {
    primary_file="$1"
    secondary_file="$2"
    log_file="$3"
    no_compare="$4"

    if [ "$no_compare" = true ]; then
        cp "$secondary_file" "$primary_file"
        echo "$primary_file" >> "$log_file"
        echo "Overwritten without comparison: $primary_file"
    else
        primary_quality=$(get_image_quality "$primary_file")
        secondary_quality=$(get_image_quality "$secondary_file")

        if [ "$secondary_quality" -gt "$primary_quality" ]; then
            cp "$secondary_file" "$primary_file"
            echo "$primary_file" >> "$log_file"
            echo "Overwritten: $primary_file (Primary Quality: $primary_quality, Secondary Quality: $secondary_quality)"
        fi
    fi
}

# Function to compare and overwrite files
compare_files() {
    # Iterate through subdirectories YYYY/MM
    for year in $(ls "$primary_base_dir"); do
        for month in $(ls "$primary_base_dir/$year"); do
            primary_dir="${primary_base_dir}/${year}/${month}/"
            secondary_dir="${secondary_base_dir}/${year}/${month}/"

            # Skip if secondary directory does not exist
            if [ ! -d "$secondary_dir" ]; then
                continue
            fi

            # Extracting the directory names for the log file
            log_file="overwritten_${year}-${month}.log"
            unhandled_file="unhandled_${year}-${month}.log"
            # Rename the log file if it already exists
            if [ -f "$log_file" ]; then
                mv "$log_file" "${log_file}_$(date +%Y%m%d%H%M%S)"
            fi

            # Rename the unhandled file if it already exists
            if [ -f "$unhandled_file" ]; then
                mv "$unhandled_file" "${unhandled_file}_$(date +%Y%m%d%H%M%S)"
            fi

            # Track handled files
            handled_files=()

            # Image comparison and overwrite
            find "${secondary_dir}" -iname "*.JPG" -print0 | sed 's/.JPG$//' | xargs -0 -I {} -P 4 bash -c '
                pic=$(basename "{}")
                primary_file="${primary_dir}/${pic}.jpg"
                secondary_file="${secondary_dir}/${pic}.JPG"

                if [ -f "$primary_file" ]; then
                    compare_and_overwrite_image "$primary_file" "$secondary_file" "$log_file" "$no_compare"
                    handled_files+=("$secondary_file")
                fi
            '

            # Video comparison and overwrite
            for ext in mp4 avi mkv; do
                find "${secondary_dir}" -iname "*.${ext}" -print0 | while IFS= read -r -d '' vid; do
                    vid_base=$(basename "$vid" .${ext})
                    primary_file="${primary_dir}/${vid_base}.${ext}"
                    secondary_file="${vid}"

                    if [ -f "$primary_file" ] && [ -f "$secondary_file" ]; then
                        primary_bitrate=$(get_bitrate "$primary_file")
                        secondary_bitrate=$(get_bitrate "$secondary_file")

                        if [ "$secondary_bitrate" -gt "$primary_bitrate" ]; then
                            cp "$secondary_file" "$primary_file"
                            echo "$primary_file" >> "$log_file"
                            echo "Overwritten: $primary_file (Primary Bitrate: $primary_bitrate, Secondary Bitrate: $secondary_bitrate)"
                        else
                            cp "$secondary_file" "${primary_dir}/${vid_base}-original.${ext}"
                            echo "${primary_dir}/${vid_base}-original.${ext}" >> "$log_file"
                            echo "Copied as original: ${primary_dir}/${vid_base}-original.${ext} (Primary Bitrate: $primary_bitrate, Secondary Bitrate: $secondary_bitrate)"
                        fi
                        handled_files+=("$secondary_file")
                    fi
                done
            done

            # Output unhandled files
            find "${secondary_dir}" -print0 | while IFS= read -r -d '' file; do
                if [[ ! " ${handled_files[@]} " =~ " ${file} " ]]; then
                    echo "$file" >> "$unhandled_file"
                    echo "Unhandled: $file"
                fi
            done
        done
    done
}

# Function to copy unhandled files
copy_unhandled_files() {
    for unhandled_file in unhandled_*.log; do
        while IFS= read -r file; do
            year=$(basename "$(dirname "$(dirname "$file")")")
            month=$(basename "$(dirname "$file")")
            primary_dir="${primary_base_dir}/${year}/${month}/"
            secondary_file="$file"
            primary_file="${primary_dir}/$(basename "$file")"

            if [ ! -f "$primary_file" ]; then
                cp "$secondary_file" "$primary_file"
                echo "Copied unhandled: $primary_file"
            fi
        done < "$unhandled_file"
    done
}

# Function to copy files with whitespace in their filenames
copy_files_with_whitespace() {
    for year in $(ls "$secondary_base_dir"); do
        for month in $(ls "$secondary_base_dir/$year"); do
            secondary_dir="${secondary_base_dir}/${year}/${month}/"
            primary_dir="${primary_base_dir}/${year}/${month}/"

            # Skip if secondary directory does not exist
            if [ ! -d "$secondary_dir" ]; then
                continue
            fi

            # Find and copy files with whitespace in their filenames
            find "$secondary_dir" -type f -name "* *" -print0 | while IFS= read -r -d '' file; do
                primary_file="${primary_dir}/$(basename "$file")"
                cp "$file" "$primary_file"
                echo "Copied file with whitespace: $primary_file"
            done
        done
    done
}

# Main script execution
case "$1" in
    compare)
        compare_files
        ;;
    copyunhandled)
        copy_unhandled_files
        ;;
    repairwhitespace)
        copy_files_with_whitespace
        ;;
    *)
        echo "Usage: $0 [-n] {compare|copyunhandled|repairwhitespace}"
        ;;
esac
