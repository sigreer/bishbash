#!/bin/bash

# Script: gitstats.sh
# Description: Calculates the total lines of code added and deleted today for either:
#             - A single git repository (if path points to a git repo)
#             - All git repositories in a directory (if path points to a directory containing repos)
# Usage: ./gitstats.sh <path>
# Example: ./gitstats.sh ~/projects          # For multiple repositories
#         ./gitstats.sh ~/projects/myrepo    # For a single repository

# Check if base directory argument is provided
if [ $# -ne 1 ]; then
    echo "This script calculates the total lines of code added and deleted today across git repositories"
    echo "Error: Path is required"
    echo "Usage: $0 <path>"
    echo "Examples:"
    echo "  $0 ~/projects          # For multiple repositories"
    echo "  $0 ~/projects/myrepo   # For a single repository"
    echo ""
    echo "Developer stats for today:"
    echo ""
    echo "Lines of code created: 20"
    echo "Lines of code deleted: 10"
    echo "Total code updates:    $((20 + 10))"
    exit 1
fi

# Check if the provided path exists
if [ ! -d "$1" ]; then
    echo "Error: Path '$1' does not exist"
    exit 1
fi

# Initialize counters
total_added=0
total_deleted=0

# Function to process a single repository
process_repo() {
    local repo_path="$1"
    cd "$repo_path" || return
    echo "Checking repository: $(basename "$repo_path")"

    # Run the command to count lines added and deleted today
    result=$(git log --since="midnight" --author="$(git config user.name)" --pretty=tformat: --numstat | awk '{ added += $1; deleted += $2 } END { print added, deleted }')

    # Extract added and deleted counts from the result
    added=$(echo "$result" | awk '{print $1}')
    deleted=$(echo "$result" | awk '{print $2}')

    # Update the total counters
    total_added=$((total_added + ${added:-0}))
    total_deleted=$((total_deleted + ${deleted:-0}))
}

# Check if the provided path is a git repository
if [ -d "$1/.git" ]; then
    # Single repository mode
    process_repo "$1"
else
    # Multiple repositories mode
    echo "Scanning for git repositories in: $1"
    # Loop through each repository
    for repo in "$1"/*; do
        if [ -d "$repo/.git" ]; then
            process_repo "$repo"
        fi
    done
fi

echo ""
echo ""
echo "Developer stats for today:"
echo ""
# Display the final result
echo "Lines of code created: $total_added"
echo "Lines of code deleted: $total_deleted"
echo "Total code updates:    $((total_added + total_deleted))"
