#!/bin/bash

# Count files in the current directory (excluding any subdirectory)
files_in_cwd=$(find . -maxdepth 1 -type f | wc -l)
# Count directories in the current directory (excluding any subdirectory)
dirs_in_cwd=$(find . -maxdepth 1 -type d | wc -l)  # This includes '.' itself

# Count files in subdirectories
files_in_subdirs=$(find . -mindepth 2 -type f | wc -l)
# Count directories in subdirectories
dirs_in_subdirs=$(find . -mindepth 2 -type d | wc -l)

# Total counts
total_files=$((files_in_cwd + files_in_subdirs))
total_dirs=$((dirs_in_cwd + dirs_in_subdirs - 1))  # Subtracting 1 to not count the current directory itself

# Display the results
echo "Files in current directory: $files_in_cwd"
echo "Directories in current directory: $((dirs_in_cwd - 1))"  # Subtracting 1 to not count the current directory itself
echo "Files in subdirectories: $files_in_subdirs"
echo "Directories in subdirectories: $dirs_in_subdirs"
echo "----------------------------------"
echo "Total files: $total_files"
echo "Total directories: $total_dirs"