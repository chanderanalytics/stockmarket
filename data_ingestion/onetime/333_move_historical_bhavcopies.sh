#!/bin/bash

# Move historical Bhavcopy files to their respective historical directories

# Base directory
BASE_DIR="/Users/chanderbhushan/stockmkt/data/bhavcopies"

# Source and destination directories
NSE_SRC="${BASE_DIR}/nse"
NSE_DEST="${BASE_DIR}/nse-hist"
BSE_SRC="${BASE_DIR}/bse"
BSE_DEST="${BASE_DIR}/bse-hist"

# Get today's date in the format used in filenames (YYYYMMDD)
TODAY=$(date +"%Y%m%d")

# Function to create directory if it doesn't exist
ensure_dir_exists() {
    if [ ! -d "$1" ]; then
        echo "Creating directory: $1"
        mkdir -p "$1"
    fi
}

# Function to move historical files
move_historical_files() {
    local src_dir="$1"
    local dest_dir="$2"
    
    # Create destination directory if it doesn't exist
    ensure_dir_exists "$dest_dir"
    
    # Find and move files that don't have today's date in their names
    find "$src_dir" -type f -not -name "*${TODAY}*" | while read -r file; do
        # Get just the filename
        filename=$(basename "$file")
        echo "Moving: $filename to ${dest_dir}/"
        mv "$file" "${dest_dir}/"
    done
}

# Main execution
echo "=== Starting Bhavcopy Historical File Mover ==="

# Process NSE files
if [ -d "$NSE_SRC" ]; then
    echo "Processing NSE files..."
    move_historical_files "$NSE_SRC" "$NSE_DEST"
else
    echo "NSE source directory not found: $NSE_SRC"
fi

# Process BSE files
if [ -d "$BSE_SRC" ]; then
    echo "Processing BSE files..."
    move_historical_files "$BSE_SRC" "$BSE_DEST"
else
    echo "BSE source directory not found: $BSE_SRC"
fi

echo "=== Operation completed ==="
