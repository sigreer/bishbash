#!/bin/bash
## This script searches dir1 for vscode-workspace files and creates symlinks to them in dir2
## This is so that I can add dir2 as to my desktop panel in KDE and quickly open any of projects
# Define your source and destination directories
dir1="$1"
dir2="$2"

# Find all .vscode-workspace files in the source directory
find "$dir1" -type f -name "*.code-workspace" | while read -r file; do
  # Extract the filename from the full path
  filename=$(basename "$file")
  
  # Define the target symlink path
  symlink="$dir2/$filename"
  
  # Check if the symlink already exists
  if [ ! -L "$symlink" ]; then
    ln -s "$file" "$symlink"
    echo "Created symlink: $symlink -> $file"
  else
    echo "Symlink already exists: $symlink"
  fi
done