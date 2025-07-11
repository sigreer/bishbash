#!/bin/bash

source  ~/.config/.powercontrol

# .powercontrol should define: POWERCONTROL_HOSTS=(nas1 nas2 nas3)

# Main function for power control
power_control() {
    local host="$1"
    local action="$2"

    # Check if host is in the allowed list
    if [[ ! " ${POWERCONTROL_HOSTS[@]} " =~ " ${host} " ]]; then
        echo "Unknown host: $host. Supported hosts: ${POWERCONTROL_HOSTS[*]}"
        exit 1
    fi

    case "$action" in
        off)
            # Test if host is reachable
            ping -c 2 -W 2 "$host" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "$host is unreachable. Shutting down local system immediately."
                sudo shutdown -h now
                exit 0
            else
                echo "$host is reachable. Sending remote shutdown command."
                ssh "$host" 'sudo shutdown -h now'
                echo "Shutting down local system."
                sudo shutdown -h now
            fi
            ;;
        on)
            echo "Power on for $host not implemented."
            ;;
        *)
            echo "Unknown action: $action. Use 'on' or 'off'."
            exit 1
            ;;
    esac
}

# Main CLI logic
HOST="$1"
ACTION="$2"

if [ -z "$HOST" ] || [ -z "$ACTION" ]; then
    echo "Usage: $0 <host> <on|off>"
    exit 1
fi

power_control "$HOST" "$ACTION"

