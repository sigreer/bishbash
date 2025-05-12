#!/bin/bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

usage() {
  echo "Usage: $0 [destination_dir]"
  echo "  destination_dir: Optional. Overrides COPY_PPT_DESTINATION_DIR from config."
}

CONFIG_FILE="$HOME/.config/bishbash/copy-new-files-from-ppt.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config file $CONFIG_FILE not found!" >&2
  exit 1
fi
. "$CONFIG_FILE"

# Check for required variable
if [[ -z "${COPY_PPT_DESTINATION_DIR:-}" ]]; then
  echo "COPY_PPT_DESTINATION_DIR not set in config!" >&2
  exit 1
fi

destination_dir="${COPY_PPT_DESTINATION_DIR}"
if [[ $# -gt 1 ]]; then
  usage
  exit 1
elif [[ $# -eq 1 ]]; then
  destination_dir="$1"
fi

log "Destination directory: $destination_dir"
mkdir -p "$destination_dir/new"
cd "$destination_dir/new"

log "Detecting camera..."
if ! gphoto2 --auto-detect; then
  log "Camera not detected!" >&2
  exit 2
fi

log "Getting all files from camera..."
if ! gphoto2 --get-all-files; then
  log "Failed to get files from camera!" >&2
  exit 3
fi

cd "$destination_dir"

log "Syncing files..."
rsync -av "$destination_dir/new/" "$destination_dir/"

number_of_files=$(find "$destination_dir/new" -type f | wc -l)

log "Removing temporary directory..."
rm -rf "$destination_dir/new"

log "Deleting all files from camera..."
if ! gphoto2 --delete-all-files; then
  log "Failed to delete files from camera!" >&2
  exit 4
fi

log "Done, copied $number_of_files files."
log "Deleted the files from the camera."