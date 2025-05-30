#!/bin/bash

# Verbose debug output for all steps
set -x

echo "Querying panel IDs from plasmashell..."
panelIds=$(qdbus org.kde.plasmashell /PlasmaShell evaluateScript 'print(panelIds);')
echo "Raw panelIds string: '$panelIds'"
# Split panelIds into array
IFS=',' read -ra panels <<< "$panelIds"
echo "Parsed panel IDs: ${panels[@]} (count: ${#panels[@]})"

# Check number of panels
if [ ${#panels[@]} -eq 2 ]; then
    echo "Found two containers with values: ${panels[@]}, continuing."
    echo "Restarting plasmashell..."
    kquitapp6 plasmashell
    echo "Switching lastScreen values for panel ${panels[0]}..."
    sed -i '/\[Containments\]\['${panels[0]}'\]/,/^$/{s/lastScreen=1/PLACEHOLDER/; s/lastScreen=0/lastScreen=1/; s/PLACEHOLDER/lastScreen=0/}' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    echo "Switching lastScreen values for panel ${panels[1]}..."
    sed -i '/\[Containments\]\['${panels[1]}'\]/,/^$/{s/lastScreen=1/PLACEHOLDER/; s/lastScreen=0/lastScreen=1/; s/PLACEHOLDER/lastScreen=0/}' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    echo "Restarting plasmashell in background..."
    kstart plasmashell &
elif [ ${#panels[@]} -eq 1 ]; then
    echo "Only one panel in use"
    exit 1
elif [ ${#panels[@]} -gt 2 ]; then
    echo "More than two panels being used. Panel IDs: ${panels[@]}"
    exit 1
else
    echo "Error: Invalid panel configuration. Raw panelIds: '$panelIds'"
    exit 1
fi

set +x


