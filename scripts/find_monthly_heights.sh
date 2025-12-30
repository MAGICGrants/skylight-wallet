#!/bin/bash

# Script to find the first block height of each month and update get_height_by_date.dart
# Usage: ./find_monthly_heights.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DART_FILE="$SCRIPT_DIR/../lib/util/get_height_by_date.dart"
RPC_URL="http://localhost:18081/json_rpc"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install it with: sudo pacman -S jq (Arch) or sudo apt install jq (Debian/Ubuntu)"
    exit 1
fi

# Check if Dart file exists
if [ ! -f "$DART_FILE" ]; then
    echo "Error: Dart file not found at $DART_FILE"
    exit 1
fi

# Extract the last entry from the dates map
# Format in file: "2023-12": 3029759,
LAST_LINE=$(grep -E '^\s*"[0-9]{4}-[0-9]{1,2}":\s*[0-9]+,' "$DART_FILE" | tail -1)
LAST_DATE=$(echo "$LAST_LINE" | sed -E 's/.*"([0-9]{4}-[0-9]{1,2})".*/\1/')
LAST_HEIGHT=$(echo "$LAST_LINE" | sed -E 's/.*:\s*([0-9]+).*/\1/')

echo "Last entry in Dart file: $LAST_DATE -> height $LAST_HEIGHT"

# Get block header by height
get_block_timestamp() {
    local height=$1
    local response
    response=$(curl -s "$RPC_URL" -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_block_header_by_height\",\"params\":{\"height\":$height}}")
    
    # Check for error
    if echo "$response" | grep -q '"error"'; then
        echo "ERROR"
        return
    fi
    
    # Extract timestamp using jq
    echo "$response" | jq -r '.result.block_header.timestamp'
}

# Convert timestamp to year and month (no leading zero on month)
get_year_month() {
    local timestamp=$1
    local year=$(date -u -d "@$timestamp" "+%Y")
    local month=$(date -u -d "@$timestamp" "+%-m")  # %-m removes leading zero
    echo "$year-$month"
}

# Get day of month from timestamp
get_day() {
    local timestamp=$1
    date -u -d "@$timestamp" "+%-d"
}

# Convert timestamp to human-readable date
get_readable_date() {
    local timestamp=$1
    date -u -d "@$timestamp" "+%Y-%m-%d %H:%M:%S UTC"
}

# Check if a month already exists in the file
month_exists() {
    local date=$1
    grep -q "\"$date\":" "$DART_FILE"
}

# Insert a new entry into the Dart file after the current last entry
insert_entry() {
    local new_date=$1
    local new_height=$2
    
    # Skip if month already exists
    if month_exists "$new_date"; then
        echo "  -> Skipped (already exists in file)"
        return 0
    fi
    
    local new_entry="  \"$new_date\": $new_height,"
    
    # Find the line number of the last date entry in the file
    local line_num=$(grep -nE '^\s*"[0-9]{4}-[0-9]{1,2}":\s*[0-9]+,' "$DART_FILE" | tail -1 | cut -d: -f1)
    
    if [ -z "$line_num" ]; then
        echo "Error: Could not find any date entries in the Dart file"
        return 1
    fi
    
    # Insert new entry after that line
    head -n "$line_num" "$DART_FILE" > "$DART_FILE.tmp"
    echo "$new_entry" >> "$DART_FILE.tmp"
    tail -n +"$((line_num + 1))" "$DART_FILE" >> "$DART_FILE.tmp"
    mv "$DART_FILE.tmp" "$DART_FILE"
    
    echo "  -> Written to file"
}

START_HEIGHT=$((LAST_HEIGHT + 1))
echo "Starting from height: $START_HEIGHT"
echo "Looking for months after: $LAST_DATE"
echo "---"

current_height=$START_HEIGHT
current_month="$LAST_DATE"

while true; do
    # Show progress on same line
    printf "\rProcessing height: %d" "$current_height"
    
    timestamp=$(get_block_timestamp "$current_height")
    
    if [ "$timestamp" == "ERROR" ] || [ "$timestamp" == "null" ] || [ -z "$timestamp" ]; then
        echo ""  # New line after progress
        echo "Reached end of blockchain or error at height $current_height"
        break
    fi
    
    year_month=$(get_year_month "$timestamp")
    day=$(get_day "$timestamp")
    
    # If month changed, record this block as first of new month
    if [ "$year_month" != "$current_month" ]; then
        readable_date=$(get_readable_date "$timestamp")
        echo ""  # New line after progress
        echo "First block of $year_month: height $current_height ($readable_date)"
        
        # Write to file immediately
        insert_entry "$year_month" "$current_height"
        
        current_month="$year_month"
        
        ((current_height++))
    elif [ "$day" -lt 28 ]; then
        # Safe to skip ahead by 1000 blocks when before 28th of month
        ((current_height += 1000))
    else
        ((current_height++))
    fi
done

echo "---"
echo "Done!"
