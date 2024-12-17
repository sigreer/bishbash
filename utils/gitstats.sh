#!/bin/bash

# Define the base directory containing all your repositories
BASE_DIR="/tank/NextcloudSideSys/Dev/sigreer"

# Initialize counters
total_added=0
total_deleted=0

# Loop through each repository
for repo in "$BASE_DIR"/*; do
  if [ -d "$repo/.git" ]; then
    cd "$repo" || continue
    echo "Checking repository: $(basename "$repo")"

    # Run the command to count lines added and deleted today
    result=$(git log --since="midnight" --author="$(git config user.name)" --pretty=tformat: --numstat | awk '{ added += $1; deleted += $2 } END { print added, deleted }')

    # Extract added and deleted counts from the result
    added=$(echo "$result" | awk '{print $1}')
    deleted=$(echo "$result" | awk '{print $2}')

    # Update the total counters
    total_added=$((total_added + added))
    total_deleted=$((total_deleted + deleted))
  fi
done

echo ""
echo ""
echo "Developer stats for today:"
echo ""
# Display the final result
echo "Lines of code created: $total_added"
echo "Lines of code deleted: $total_deleted"
echo "Total code updates:    $((total_added + total_deleted))"
