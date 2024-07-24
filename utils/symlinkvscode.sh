#!/bin/bash
## This script searches dir1 for code-workspace files and creates desktop shortcuts to them in dir2
## This is so that I can add dir2 as a launcher panel to quickly open up project workspaces.

dir1="$1"
dir2="$2"

# Find all .code-workspace files in the source directory
find "$dir1" -type f -name "*.code-workspace" | while read -r file; do
  # Extract the filename from the full path
  filename=$(basename "$file" .code-workspace)
  
  # Define the target desktop shortcut path
  shortcut="$dir2/$filename.desktop"
  
  # Check if the desktop shortcut already exists
  if [ ! -f "$shortcut" ]; then
    # Create the desktop shortcut file
    cat <<EOL > "$shortcut"
[Desktop Entry]
Version=1.0
Type=Application
Name=$filename
Exec=$HOME/.local/bin/cursor "$file"
Icon=$HOME/.local/share/icons/funkysquaredance/scalable/apps/cursor.svg
Terminal=false

EOL
    echo "Created desktop shortcut: $shortcut"
    sudo chmod +x $shortcut
    echo "Made shortcut executable"
  else
    echo "Desktop shortcut already exists: $shortcut"
  fi

done