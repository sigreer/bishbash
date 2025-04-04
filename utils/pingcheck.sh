#!/bin/bash

waitping() {
    while true; do
        echo -n "Checking..."
        if ping -c 1 "$1" &>/dev/null; then
            echo -e "\rHost $1 is responding!"
            break
        fi
        echo -ne "\r\033[K"  # Clear the line
        sleep 1
    done
}
waitping $1