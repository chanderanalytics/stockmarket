# Set log file with date and timestamp
log_datetime=$(date +%Y%m%d_%H%M%S)
log_file="log/test_import_${log_datetime}.log"

set -e
set -o pipefail 