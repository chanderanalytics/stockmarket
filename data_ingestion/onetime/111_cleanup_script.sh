#!/bin/bash

# Smart Cleanup Script for Stock Market Analysis Pipeline
# 1. Checks if the daily pipeline completed successfully today
# 2. If successful, cleans up output and rotates logs
# 3. Logs all actions to both console and log file

set -e  # Exit on error

# Configuration
WORKSPACE_DIR="/Users/chanderbhushan/stockmkt"
LOG_DIR="${WORKSPACE_DIR}/log"
OUTPUT_DIR="${WORKSPACE_DIR}/output"
# Get the appropriate log date (Friday for Sun/Mon, otherwise yesterday)
if [[ "$(uname)" == "Darwin" ]]; then
    # For macOS
    DAY_OF_WEEK=$(date +%u)  # 1=Mon, 7=Sun
    if [ "$DAY_OF_WEEK" = "1" ]; then  # Monday
        LOG_DATE=$(date -v-3d +%Y%m%d)  # Get Friday's date
    elif [ "$DAY_OF_WEEK" = "7" ]; then  # Sunday
        LOG_DATE=$(date -v-2d +%Y%m%d)  # Get Friday's date
    else
        LOG_DATE=$(date -v-1d +%Y%m%d)  # Get yesterday's date
    fi
else
    # For Linux
    DAY_OF_WEEK=$(date +%u)  # 1=Mon, 7=Sun
    if [ "$DAY_OF_WEEK" = "1" ]; then  # Monday
        LOG_DATE=$(date -d "3 days ago" +%Y%m%d)  # Get Friday's date
    elif [ "$DAY_OF_WEEK" = "7" ]; then  # Sunday
        LOG_DATE=$(date -d "2 days ago" +%Y%m%d)  # Get Friday's date
    else
        LOG_DATE=$(date -d "yesterday" +%Y%m%d)  # Get yesterday's date
    fi
fi
# Delete all logs by default
CLEANUP_LOG="${LOG_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).log"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Function to log messages with timestamp
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$CLEANUP_LOG"
}

# Function to check if pipeline ran successfully today
check_pipeline_success() {
    log_message "🔍 Searching for daily pipeline logs..."
    
    # Determine which log to check based on day of week
    local day_of_week=$(date +%u)  # 1=Mon, 7=Sun
    local log_pattern=""
    
    if [ "$day_of_week" = "1" ]; then  # Monday
        log_pattern="daily_pipeline_$(date -v-3d +%Y%m%d)_*.log"  # Friday's log
        log_message "📅 Monday detected - checking Friday's log"
    elif [ "$day_of_week" = "7" ]; then  # Sunday
        log_pattern="daily_pipeline_$(date -v-2d +%Y%m%d)_*.log"  # Friday's log
        log_message "📅 Sunday detected - checking Friday's log"
    else
        log_pattern="daily_pipeline_$(date -v-1d +%Y%m%d)_*.log"  # Yesterday's log
        log_message "📅 Weekday detected - checking yesterday's log"
    fi
    
    log_message "🔍 Looking for log file matching: ${log_pattern}"
    local latest_log=$(find "$LOG_DIR" -name "$log_pattern" -type f | head -1)
    
    if [ -z "$latest_log" ]; then
        log_message "⚠️  No matching log file found. Looking for any daily pipeline log..."
        latest_log=$(find "$LOG_DIR" -name "daily_pipeline_*.log" -type f | sort -r | head -1)
        
        if [ -z "$latest_log" ]; then
            log_message "❌ No daily pipeline logs found in ${LOG_DIR}"
            return 1
        fi
        log_message "ℹ️  Using log file: ${latest_log}"
    else
        log_message "🔍 Found log file: ${latest_log}"
    fi
    
    # Check for successful completion message
    if ! grep -q "✅ Completed Step 18: Save trade analysis to database" "$latest_log"; then
        log_message "❌ Completion message not found in log"
        log_message "To proceed with cleanup anyway, use: $0 --force"
        return 1
    fi
    
    log_message "✅ Pipeline completed successfully. Proceeding with cleanup."
    return 0
}

# Function to clean output directory
clean_output() {
    log_message "🧹 Cleaning output directory: ${OUTPUT_DIR}"
    if [ -d "${OUTPUT_DIR}" ]; then
        # Remove all files in output directory
        find "${OUTPUT_DIR}" -type f -delete
        log_message "✅ Output directory cleaned successfully"
    else
        log_message "ℹ️  Output directory not found: ${OUTPUT_DIR}"
    fi
}

# Function to clean up all log files
clean_logs() {
    log_message "🗑️  Deleting all log files..."
    if [ -d "${LOG_DIR}" ]; then
        # Delete all .log files in the log directory
        find "${LOG_DIR}" -type f -name "*.log" -delete
        log_message "✅ All log files have been deleted"
    else
        log_message "ℹ️  Log directory not found: ${LOG_DIR}"
    fi
}

# Main function
main() {
    log_message "🚀 Starting cleanup process"
    
    # Check if we should run cleanup
    if [ "$1" = "--force" ]; then
        log_message "⚡ Force mode enabled. Running cleanup without pipeline check."
    else
        if ! check_pipeline_success; then
            log_message "❌ Cleanup aborted due to pipeline check failure"
            exit 1
        fi
    fi
    
    # Perform cleanup
    clean_output
    # Clean up all log files by default
    clean_logs
    
    log_message "✨ Cleanup completed successfully"
}

# Execute main function with all arguments
main "$@"

exit 0
