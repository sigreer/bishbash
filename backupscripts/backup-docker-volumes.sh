#!/bin/bash

# Default settings
ENV_FILE="$HOME/.env"
BACKUP_TYPE="all"
INTERACTIVE=true
RUNNING_ONLY="yes"
TEMP_BACKUP_DIR=""

# Function to create and setup temporary directory
setup_temp_dir() {
    TEMP_BACKUP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_BACKUP_DIR/volumes"
    mkdir -p "$TEMP_BACKUP_DIR/bind_mounts"
    mkdir -p "$TEMP_BACKUP_DIR/config"
}

# Function to cleanup temporary directory
cleanup_temp_dir() {
    if [[ -n "$TEMP_BACKUP_DIR" && -d "$TEMP_BACKUP_DIR" ]]; then
        rm -rf "$TEMP_BACKUP_DIR"
    fi
}

# Trap to ensure cleanup on script exit
trap cleanup_temp_dir EXIT

# Function to show usage
show_usage() {
    echo "Usage: $(basename $0) <backup|show> <dir|container> <name> [options]"
    echo "Options:"
    echo "  --all           Backup both named volumes and bind mounts (default)"
    echo "  --named-vols    Backup only named volumes"
    echo "  --bind-mounts   Backup only bind mounts"
    echo "  --env-path=#    Specify custom .env file path"
    echo "  --silent        Suppress all interactive prompts"
    echo "  --running=#     Only process running containers (yes|no, default: yes)"
    exit 1
}

# Parse command line arguments
COMMAND=""
MODE=""
NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        backup|show)
            COMMAND="$1"
            shift
            ;;
        dir|container)
            MODE="$1"
            shift
            ;;
        --all)
            BACKUP_TYPE="all"
            shift
            ;;
        --named-vols)
            BACKUP_TYPE="named"
            shift
            ;;
        --bind-mounts)
            BACKUP_TYPE="bind"
            shift
            ;;
        --env-path=*)
            ENV_FILE="${1#*=}"
            shift
            ;;
        --silent)
            INTERACTIVE=false
            shift
            ;;
        --running=*)
            RUNNING_ONLY="${1#*=}"
            if [[ ! "$RUNNING_ONLY" =~ ^(yes|no)$ ]]; then
                echo "Error: --running flag must be 'yes' or 'no'"
                exit 1
            fi
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            ;;
        *)
            if [[ -z "$NAME" ]]; then
                NAME="$1"
                shift
            else
                echo "Unexpected argument: $1"
                show_usage
            fi
            ;;
    esac
done

# Validate required arguments
if [[ -z "$COMMAND" ]] || [[ -z "$MODE" ]] || [[ -z "$NAME" ]]; then
    show_usage
fi

# Load environment variables from .env file
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "Warning: .env file not found at $ENV_FILE"
fi

# Configuration
# Check if required environment variables are set
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="/root/backup"  # Default value
    echo "Warning: BACKUP_DIR not set in .env, using default: $BACKUP_DIR"
fi

if [[ -z "$x" ]]; then
    BASE_DOCKER_DIR="/root/docker"  # Default value
    echo "Warning: BASE_DOCKER_DIR not set in .env, using default: $BASE_DOCKER_DIR"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to calculate volume size in MB
calculate_volume_size() {
    local VOLUME_PATH=$1
    local SIZE_MB=$(/usr/bin/du -sm "$VOLUME_PATH" | /usr/bin/cut -f1)
    echo "$SIZE_MB"
}

# Function to backup a single volume
backup_volume() {
    local VOLUME=$1
    local VOLUME_PATH=$(docker volume inspect "$VOLUME" --format '{{ .Mountpoint }}')

    if [[ -z "$VOLUME_PATH" ]]; then
        echo "Skipping $VOLUME (could not determine mount point)"
        return
    fi

    # Calculate volume size before backup
    local VOLUME_SIZE=$(calculate_volume_size "$VOLUME_PATH")
    echo "Volume size: ${VOLUME_SIZE}MB"

    if [[ $VOLUME_SIZE -gt 500 ]]; then
        read -p "Warning: Volume size exceeds 500MB. Proceed with backup? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping backup of $VOLUME"
            return
        fi
    fi

    # Create a tar backup in the temporary directory
    local BACKUP_FILE="$TEMP_BACKUP_DIR/volumes/${VOLUME}.tar"
    tar -cf "$BACKUP_FILE" -C "$VOLUME_PATH" .
    echo "Backed up $VOLUME"
}

# Function to backup bind mount
backup_bind_mount() {
    local SOURCE_PATH=$1
    local MOUNT_NAME=$2
    
    if [[ ! -e "$SOURCE_PATH" ]]; then
        echo "Skipping $MOUNT_NAME (source path not accessible)"
        return
    fi

    # If it's a file, copy it directly
    if [[ -f "$SOURCE_PATH" ]]; then
        cp "$SOURCE_PATH" "$TEMP_BACKUP_DIR/bind_mounts/${MOUNT_NAME}"
        echo "Backed up bind mount file $MOUNT_NAME"
        return
    fi

    # If it's a directory, backup its contents
    if [[ -d "$SOURCE_PATH" ]]; then
        # Calculate size before backup
        local MOUNT_SIZE=$(calculate_volume_size "$SOURCE_PATH")
        echo "Bind mount size: ${MOUNT_SIZE}MB"

        if [[ $MOUNT_SIZE -gt 500 ]] && [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Warning: Bind mount size exceeds 500MB. Proceed with backup? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Skipping backup of $MOUNT_NAME"
                return
            fi
        fi

        local BACKUP_FILE="$TEMP_BACKUP_DIR/bind_mounts/${MOUNT_NAME}.tar"
        tar -cf "$BACKUP_FILE" -C "$SOURCE_PATH" .
        echo "Backed up bind mount directory $MOUNT_NAME"
        return
    fi
}

# Function to get volume size for display
get_volume_size_display() {
    local PATH=$1
    local SIZE_MB=$(/usr/bin/du -sm "$PATH" 2>/dev/null | /usr/bin/cut -f1)
    if [[ -z "$SIZE_MB" ]]; then
        echo "N/A"
    else
        echo "${SIZE_MB}M"
    fi
}

# New function to check if a container is running
is_container_running() {
    local SERVICE_NAME=$1
    local PROJECT_NAME=$2
    local COMPOSE_FILE=$3
    
    # First check if there's a container_name specified in the compose file
    local CONTAINER_NAME=$(docker compose -f "$COMPOSE_FILE" config --format json | \
        jq -r --arg service "$SERVICE_NAME" '.services[$service].container_name // empty')
    
    if [[ ! -z "$CONTAINER_NAME" ]]; then
        # Use the explicit container name if specified
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            return 0
        fi
    else
        # Try both underscore and hyphen formats for dynamic names
        local CONTAINER_NAME_UNDERSCORE="${PROJECT_NAME}_${SERVICE_NAME}-1"
        local CONTAINER_NAME_HYPHEN="${PROJECT_NAME}-${SERVICE_NAME}-1"
        
        # Check if container exists and is running with either naming format
        if docker ps --format '{{.Names}}' | grep -qE "^(${CONTAINER_NAME_UNDERSCORE}|${CONTAINER_NAME_HYPHEN})$"; then
            return 0
        fi
    fi
    
    return 1
}

# Function to process a single compose file
process_compose_file() {
    local COMPOSE_FILE=$1
    echo "Processing compose file: $COMPOSE_FILE"
    local JSON_CONFIG=$(docker compose -f "$COMPOSE_FILE" config --format json)
    
    if [[ "$BACKUP_TYPE" != "bind" ]]; then
        # Get named volumes if they exist
        if echo "$JSON_CONFIG" | jq -e '.volumes' >/dev/null 2>&1; then
            local VOLUMES=$(echo "$JSON_CONFIG" | jq -r '.volumes | keys[]')
            if [[ ! -z "$VOLUMES" ]]; then
                echo "Found named volumes: $VOLUMES"
                for VOLUME in $VOLUMES; do
                    # Check if any service using this volume is running
                    local VOLUME_USED=false
                    local SERVICES=$(echo "$JSON_CONFIG" | jq -r '.services | keys[]')
                    for SERVICE in $SERVICES; do
                        if [[ "$RUNNING_ONLY" == "no" ]] || is_container_running "$SERVICE" "$NAME" "$COMPOSE_FILE"; then
                            VOLUME_USED=true
                            break
                        fi
                    done
                    
                    if [[ "$VOLUME_USED" == "true" ]]; then
                        backup_volume "${NAME}_$VOLUME"
                    else
                        echo "Skipping volume ${NAME}_$VOLUME (no running containers using it)"
                    fi
                done
            fi
        fi
    fi

    if [[ "$BACKUP_TYPE" != "named" ]]; then
        # Get services with bind mounts
        local SERVICES=$(echo "$JSON_CONFIG" | jq -r '.services | to_entries[] | select(.value.volumes != null) | .key')
        for SERVICE in $SERVICES; do
            if [[ "$RUNNING_ONLY" == "yes" ]] && ! is_container_running "$SERVICE" "$NAME" "$COMPOSE_FILE"; then
                echo "Skipping bind mounts for service $SERVICE (container not running)"
                continue
            fi
            
            # Get bind mounts for this service
            local BIND_MOUNTS=$(echo "$JSON_CONFIG" | \
                jq -r --arg service "$SERVICE" '[ .services[$service].volumes? // [] | .[]? | 
                    if type == "string" then
                        select(contains(":")) | split(":")[0]
                    elif type == "object" then
                        select(.type == "bind") | .source
                    else
                        empty
                    end
                ] | unique[]')
            
            if [[ ! -z "$BIND_MOUNTS" ]]; then
                echo "Processing bind mounts for service $SERVICE"
                echo "$BIND_MOUNTS" | while read -r mount; do
                    # Resolve relative paths to absolute paths
                    if [[ "$mount" == "./"* ]]; then
                        local FULL_PATH="$(cd "$(dirname "$COMPOSE_FILE")" && cd "$(dirname "${mount#./}")" && pwd)/$(basename "${mount#./}")"
                    else
                        local FULL_PATH="$mount"
                    fi
                    
                    local MOUNT_NAME=$(basename "$mount")
                    backup_bind_mount "$FULL_PATH" "${NAME}_${SERVICE}_${MOUNT_NAME}"
                done
            fi
        done
    fi
}

# Function to show volumes and bind mounts in compose file
show_compose_file() {
    local COMPOSE_FILE=$1
    echo "Processing compose file: $COMPOSE_FILE"
    local JSON_CONFIG=$(docker compose -f "$COMPOSE_FILE" config --format json)
    local FOUND_MOUNTS=false
    
    # Show named volumes if they exist
    if echo "$JSON_CONFIG" | jq -e '.volumes' >/dev/null 2>&1; then
        local VOLUMES=$(echo "$JSON_CONFIG" | jq -r '.volumes | keys[]')
        if [[ ! -z "$VOLUMES" ]]; then
            echo -e "\nNamed volumes:"
            echo "$VOLUMES" | while read -r volume; do
                local FULL_VOLUME="${NAME}_$volume"
                local VOLUME_PATH=$(docker volume inspect "$FULL_VOLUME" --format '{{ .Mountpoint }}' 2>/dev/null)
                local SIZE=$(get_volume_size_display "$VOLUME_PATH")
                printf "%-50s %10s\n" "- $FULL_VOLUME" "$SIZE"
            done
            FOUND_MOUNTS=true
        fi
    fi

    # Show bind mounts - improved jq query for all volume formats
    local BIND_MOUNTS=$(echo "$JSON_CONFIG" | \
        jq -r '[ .services | to_entries[] | .value.volumes? // [] | .[]? | 
            if type == "string" then
                select(contains(":")) | split(":")[0]
            elif type == "object" then
                select(.type == "bind") | .source
            else
                empty
            end
        ] | unique[]')
    
    if [[ ! -z "$BIND_MOUNTS" ]]; then
        echo -e "\nBind mounts:"
        local SERVICES=$(echo "$JSON_CONFIG" | jq -r '.services | keys[]')
        for SERVICE in $SERVICES; do
            local RUNNING=""
            if is_container_running "$SERVICE" "$NAME" "$COMPOSE_FILE"; then
                RUNNING="(running)"
            else
                RUNNING="(stopped)"
            fi
            echo "Service: $SERVICE $RUNNING"
            
            # Resolve relative paths to absolute paths
            if [[ "$mount" == "./"* ]]; then
                local FULL_PATH="$(dirname "$COMPOSE_FILE")/${mount#./}"
            else
                local FULL_PATH="$mount"
            fi
            local SIZE=$(get_volume_size_display "$FULL_PATH")
            printf "%-50s %10s\n" "- $mount" "$SIZE"
        done
        FOUND_MOUNTS=true
    fi

    if [[ "$FOUND_MOUNTS" == "false" ]]; then
        echo -e "\nNo volumes or bind mounts found"
    fi
}

# Function to create final backup archive
create_final_backup() {
    local PROJECT_NAME=$1
    local COMPOSE_FILE=$2
    
    # Create the backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Create a config/files directory for loose files
    mkdir -p "$TEMP_BACKUP_DIR/config/files"
    
    # Copy compose file to temp directory
    cp "$COMPOSE_FILE" "$TEMP_BACKUP_DIR/config/compose.yml"
    
    # Copy all files from the compose file's directory (excluding subdirectories)
    local COMPOSE_DIR=$(dirname "$COMPOSE_FILE")
    find "$COMPOSE_DIR" -maxdepth 1 -type f ! -name "compose.yml" -exec cp {} "$TEMP_BACKUP_DIR/config/files/" \;
    
    # Create final backup archive
    local FINAL_BACKUP="$BACKUP_DIR/${PROJECT_NAME}_${TIMESTAMP}.tar.gz"
    tar -czf "$FINAL_BACKUP" -C "$TEMP_BACKUP_DIR" .
    
    echo "Created final backup archive: $FINAL_BACKUP"
}

# Modified handle_directory_mode function
handle_directory_mode() {
    local DIR_PATH=$1
    local OPERATION=$2
    local FULL_PATH="$BASE_DOCKER_DIR/$DIR_PATH"
    
    # Extract the project name from the last component of the path
    local PROJECT_NAME=$(basename "$DIR_PATH")
    
    if [[ ! -d "$FULL_PATH" ]]; then
        echo "Error: Directory $FULL_PATH does not exist"
        exit 1
    fi

    # Find all compose files recursively
    local COMPOSE_FILES=$(find "$FULL_PATH" -type f -regextype posix-extended -regex '.*/((docker-)?compose)(\.[\w-]+)?\.(yaml|yml)$')
    
    if [[ -z "$COMPOSE_FILES" ]]; then
        echo "No compose files found in $FULL_PATH"
        exit 1
    fi

    # Count number of compose files
    local FILE_COUNT=$(echo "$COMPOSE_FILES" | wc -l)
    echo "Found $FILE_COUNT compose file(s)"
    
    while IFS= read -r file; do
        if [[ $FILE_COUNT -gt 1 ]] && [[ "$INTERACTIVE" == "true" ]]; then
            read -p "Process compose file $file? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                continue
            fi
        fi
        
        # Create temporary directory for this backup
        setup_temp_dir
        
        if [[ "$OPERATION" == "show" ]]; then
            NAME="$PROJECT_NAME" show_compose_file "$file"
        else
            NAME="$PROJECT_NAME" process_compose_file "$file"
            create_final_backup "$PROJECT_NAME" "$file"
        fi
        
        # Cleanup temporary directory
        cleanup_temp_dir
    done <<< "$COMPOSE_FILES"
}

# Function to handle container mode
handle_container_mode() {
    local CONTAINER_NAME=$1
    
    if [[ "$BACKUP_TYPE" != "bind" ]]; then
        # Get named volumes
        local VOLUMES=$(docker inspect "$CONTAINER_NAME" | jq -r '.[0].Mounts[] | select(.Type == "volume") | .Name')
        if [[ ! -z "$VOLUMES" ]]; then
            echo "Found volumes for container $CONTAINER_NAME: $VOLUMES"
            for VOLUME in $VOLUMES; do
                backup_volume "$VOLUME"
            done
        fi
    fi

    if [[ "$BACKUP_TYPE" != "named" ]]; then
        # Get bind mounts
        local BIND_MOUNTS=$(docker inspect "$CONTAINER_NAME" | \
            jq -r '.[0].Mounts[] | select(.Type == "bind") | [.Source, .Destination] | @tsv')
        if [[ ! -z "$BIND_MOUNTS" ]]; then
            echo "Found bind mounts for container $CONTAINER_NAME"
            while IFS=$'\t' read -r source dest; do
                local MOUNT_NAME=$(basename "$dest")
                backup_bind_mount "$source" "${CONTAINER_NAME}_${MOUNT_NAME}"
            done <<< "$BIND_MOUNTS"
        fi
    fi
}

# Main script
case "$COMMAND" in
    "backup")
        case "$MODE" in
            "dir")
                handle_directory_mode "$NAME" "backup"
                ;;
            "container")
                handle_container_mode "$NAME"
                ;;
        esac
        echo "All backups completed."
        ;;
    "show")
        case "$MODE" in
            "dir")
                handle_directory_mode "$NAME" "show"
                ;;
            "container")
                echo -e "\nMounts for container $NAME:"
                docker inspect "$NAME" | jq -r '.[0].Mounts[] | 
                    "Type: " + .Type + "\n" +
                    "Source: " + .Source + "\n" +
                    "Destination: " + .Destination + "\n"'
                ;;
        esac
        ;;
esac
