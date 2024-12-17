#!/bin/bash

input_image_1="$1"
input_image_2="$2"
input_image_3="$3"
output_image="${input_image_1%.*}_cascade.png"
input_image_1_normalised="./${input_image_1%.*}_normalised.png"
input_image_2_normalised="./${input_image_2%.*}_normalised.png"
input_image_3_normalised="./${input_image_3%.*}_normalised.png"
input_image_1_shadow="./${input_image_1%.*}_shadow.png"
input_image_2_shadow="./${input_image_2%.*}_shadow.png"
input_image_3_shadow="./${input_image_3%.*}_shadow.png"
merged_tilted="./${input_image_1%.*}_${input_image_2%.*}_merged_tilted.png"
input_image_1_tilted="./${input_image_1%.*}_tilted.png"
input_image_2_tilted="./${input_image_2%.*}_tilted.png"
merged_tilted_shadow="./${input_image_1%.*}_${input_image_2%.*}_merged_tilted_shadow.png"
shadow_file="./shadow.png"
no_cleanup=false
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
error_log="${error_log:=./error.log}"
verbosity="${VERBOSITY:-2}" # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
console_output="${CONSOLE_OUTPUT:-1}"
file_output="${FILE_OUTPUT:-1}"

logThis() {
    local severity="$1"
    local log_message="$2"
    
    case "$severity" in
        0) log_level="ERROR" ;;
        1) log_level="WARN"  ;;
        2) log_level="INFO"  ;;
        3) log_level="DEBUG" ;;
        *) log_level="INFO"  ;;
    esac
    
    local level_num=$severity
    local log_entry="[$timestamp] $log_level: $log_message"
    
    if [ $level_num -le $verbosity ]; then
        if [ $console_output -eq 1 ]; then
            case "$log_level" in
                "ERROR") echo -e "\e[31m$log_entry\e[0m" >&2 ;; # Red
                "WARN")  echo -e "\e[33m$log_entry\e[0m" >&2 ;; # Yellow
                *)      echo "$log_entry" ;;
            esac
        fi
        if [ $file_output -eq 1 ]; then
            echo "$log_entry" >> "$error_log"
        fi
    fi
}

process_args() {
    no_cleanup=false
    input_files=()
    
    for arg in "$@"; do
        if [ "$arg" = "--no-cleanup" ]; then
            no_cleanup=true
        else
            input_files+=("$arg")
        fi
    done
    
    # Check for required number of input files
    if [ ${#input_files[@]} -ne 3 ]; then
        echo "Error: Script requires exactly 3 input images"
        echo "Usage: $0 image1 image2 image3 [--no-cleanup]"
        exit 1
    fi
    
    # Assign input files
    input_image_1="${input_files[0]}"
    input_image_2="${input_files[1]}"
    input_image_3="${input_files[2]}"
    
    # Check if files exist
    for img in "$input_image_1" "$input_image_2" "$input_image_3"; do
        if [ ! -f "$img" ]; then
            logThis 0 "File '$img' does not exist"
            exit 1
        fi
    done
}

normalize_height() {
    local target_height=768
    local target_width=1600
    local input_file="$1"
    local output_file="$2"
    local current_height=$(magick identify -format "%h" "$input_file")
    if [ "$current_height" -ne "$target_height" ]; then
        echo "Normalizing height of $input_file..."
        magick "$input_file" -resize "${target_width}x${target_height}" "$output_file"
    else
        cp "$input_file" "$output_file"
    fi
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error normalizing height"
        cleanup
        exit 1
    fi
}

shadow() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$shadow_file" ]; then
        logThis 0 "Error: Shadow file '$shadow_file' not found"
        cleanup
        exit 1
    fi
    nconvert    -wmopacity 70 \
            -wmflag top-center \
            -wmfile "$shadow_file" \
            -o "$output_file" \
            -overwrite \
            -out png -q 72 \
            "$input_file"
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error adding shadow"
        cleanup
        exit 1
    fi
}

right_perspective() {
    logThis 2 "Tilting right image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,0,0 0,768,0,768 1200,768,1080,668 1200,0,1080,100' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error tilting right image"
        cleanup
        exit 1
    fi
}

left_perspective() {
    logThis 2 "Tilting left image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,120,100 0,768,120,868 1200,768,1200,768 1200,0,1200,0' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error tilting left image"
        cleanup
        exit 1
    fi
}

merge_tilted_images() {
    logThis 3 "Attempting to merge tilted images: $1 and $2"
    # Verify input files exist
    if [ ! -f "$1" ] || [ ! -f "$2" ]; then
        logThis 0 "Input files for merge_tilted_images don't exist"
        return 1
    fi
    
    magick "$1" "$2" -background none +append "$3"
    local status=$?
    if [ $status -eq 0 ]; then
        logThis 2 "Successfully merged tilted images"
        # Verify output file was created
        if [ ! -f "$3" ]; then
            logThis 0 "Merged file wasn't created despite successful command"
            return 1
        fi
        return 0
    else
        logThis 0 "Error merging tilted images (status: $status)"
        return 1
    fi
}

add_shadow_to_tilted_images() {
    logThis 3 "Attempting to add shadow to tilted image: $1"
    # Verify input file exists
    if [ ! -f "$1" ]; then
        logThis 0 "Input file for add_shadow_to_tilted_images doesn't exist"
        return 1
    fi
    
    magick "$1" \
        \( +clone -background black -shadow "80x20+15+15" \) \
        +swap -background none -layers merge \
        "$2"
    local status=$?
    if [ $status -eq 0 ]; then
        logThis 2 "Successfully added shadow to tilted images"
        # Verify output file was created
        if [ ! -f "$2" ]; then
            logThis 0 "Shadow file wasn't created despite successful command"
            return 1
        fi
        return 0
    else
        logThis 0 "Error adding shadow to tilted images (status: $status)"
        return 1
    fi
}

add_shadow_to_center_image() {
    magick "$1" \
        \( +clone -background black -shadow "60x10+8+8" \) \
        +swap -background none -layers merge \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error adding shadow to center image"
        cleanup
        exit 1
    fi
}

overlay_tilted_images() {
    original_width=$(magick identify -format "%w" "$3")
    original_height=$(magick identify -format "%h" "$3")
    combined_width=$(magick identify -format "%w" "$1")
    combined_height=$(magick identify -format "%h" "$1")
    x_offset=$(( (combined_width - original_width) / 2 ))
    y_offset=0
    magick "$1" "$2" \
        -background none -geometry "+${x_offset}+${y_offset}" \
        -composite "$3"
    if [ $? -eq 0 ]; then
        logThis 2 "Done"
        return 0
    else
        logThis 0 "Error overlaying tilted images"
        cleanup
        exit 1
    fi
}

cleanup() {
    if [ "$no_cleanup" = true ]; then
        logThis 2 "Skipping cleanup..."
        return 0
    fi
    rm -f "$merged_tilted" "$merged_tilted_shadow" "$input_image_3_shadow" \
          "$input_image_1_normalised" "$input_image_2_normalised" "$input_image_3_normalised" \
          "$input_image_1_shadow" "$input_image_2_shadow" "$input_image_3_shadow" \
          "$input_image_1_tilted" "$input_image_2_tilted"
}

process_args "$@"
normalize_height "$input_image_1" "$input_image_1_normalised"
normalize_height "$input_image_2" "$input_image_2_normalised"
normalize_height "$input_image_3" "$input_image_3_normalised"
shadow "$input_image_1_normalised" "$input_image_1_shadow"
shadow "$input_image_2_normalised" "$input_image_2_shadow"
left_perspective "$input_image_1_shadow" "$input_image_1_tilted"
right_perspective "$input_image_2_shadow" "$input_image_2_tilted"
merge_tilted_images "$input_image_2_tilted" "$input_image_1_tilted" "$merged_tilted"
add_shadow_to_tilted_images "$merged_tilted" "$merged_tilted_shadow"
add_shadow_to_center_image "$input_image_3" "$input_image_3_shadow"
overlay_tilted_images "$merged_tilted_shadow" "$input_image_3_shadow" "$output_image"
cleanup
logThis 2 "Done"
logThis 2 "Created cascade image: $output_image"
