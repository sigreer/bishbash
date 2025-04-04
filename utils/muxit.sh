#!/bin/bash

# Check if a prefix argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <prefix>"
    exit 1
fi

PREFIX="$1"

# Function to check if a tmux session exists
session_exists() {
    tmux ls | grep -q "^${1}:"
}

# Create or connect to tmux sessions
for i in {1..4}; do
    SESSION_NAME="${PREFIX}${i}"
    if session_exists "$SESSION_NAME"; then
        echo "Session $SESSION_NAME already exists. Connecting..."
    else
        echo "Creating session $SESSION_NAME..."
        tmux new-session -d -s "$SESSION_NAME"
    fi
done

# Start a new tmux window to organize the sessions, or select it if it already exists
if ! session_exists "${PREFIX}1"; then
    echo "Failed to find ${PREFIX}1. Exiting."
    exit 1
fi

tmux new-window -t "${PREFIX}1" -n grid
tmux select-window -t "${PREFIX}1":grid

# Split the window into a grid layout
tmux select-window -t "${PREFIX}1":grid
tmux split-window -h   # Split right
tmux split-window -v   # Split bottom right
tmux select-pane -t 0
tmux split-window -v   # Split bottom left

# Attach each pane to the corresponding session
tmux select-pane -t 0
tmux send-keys "tmux attach-session -t ${PREFIX}1" C-m
tmux select-pane -t 1
tmux send-keys "tmux attach-session -t ${PREFIX}2" C-m
tmux select-pane -t 2
tmux send-keys "tmux attach-session -t ${PREFIX}3" C-m
tmux select-pane -t 3
tmux send-keys "tmux attach-session -t ${PREFIX}4" C-m

# Attach to the grid window in session1
tmux attach-session -t "${PREFIX}1"