#!/bin/bash
# ==============================================================================
# Clean Script
# Description: Safely removes temporary output directories generated during prep.
# ==============================================================================

set -eo pipefail

# ================================= #
# Logging & Error Handling Helpers  #
# ================================= #

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

export TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# ================================= #
# Functions                         #
# ================================= #

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Description:
  Safely removes the 'atm', 'ocn', 'ice', and 'intercom' directories 
  located specifically in: ${TOP_DIR}

Options:
  -h, --help     Show this help message and exit
  -v, --verbose  Enable verbose bash debugging (set -x)
EOF
}

# ================================= #
# Main Logic & Argument Parsing     #
# ================================= #

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            set -x
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

log_info "Starting cleanup in: ${TOP_DIR}"

TARGET_DIRS=("atm" "ocn" "ice" "intercom")

for dir in "${TARGET_DIRS[@]}"; do
    TARGET_PATH="${TOP_DIR}/${dir}"
    
    if [[ -d "$TARGET_PATH" ]]; then
        log_info "Removing directory: ${TARGET_PATH}"
        rm -rf "$TARGET_PATH"
    else
        log_warn "Directory not found, skipping: ${TARGET_PATH}"
    fi
done

log_info "Cleanup complete."
exit 0
