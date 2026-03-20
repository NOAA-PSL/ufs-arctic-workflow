#!/bin/bash
# ==============================================================================
# Initial Condition Prep Script
# Description: Prepares input files for Ocean, Ice, and Atmosphere components.
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
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
error_exit() {
    log_error "$1"
    exit 1
}

# ================================= #
# Functions                         #
# ================================= #

show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --help        Show this help message and exit
  --clean       Run ./clean.sh once before executing tasks
  --ocn         Run Ocean prep
  --ice         Run Ice prep
  --atm         Run Atmosphere prep
  --all         Run all three tasks (ocn, ice, atm)
EOF
}

setup() {
    log_info "Setting up environment and loading modules..."

    if [[ -z "$PREP_DIR" ]]; then
        error_exit "PREP_DIR variable is not set in the environment."
    fi

    mkdir -p "${PREP_DIR}/intercom"
    mkdir -p "${PREP_DIR}/.status"

    local NAMELIST_FILE="./config_files/config.in"
    
    module purge
    module use /contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core || error_exit "Failed to find module path /contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core"
    module load stack-oneapi || error_exit "Failed to load stack-oneapi module."
    module load nco || error_exit "Failed to load nco module."
    module load cdo || error_exit "Failed to load cdo module."
    
    local CONDA_SH="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/etc/profile.d/conda.sh"
    [ -f "$CONDA_SH" ] || error_exit "Conda init script not found at: $CONDA_SH"
    source "$CONDA_SH"

    export PATH="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/bin:$PATH"
    conda activate ufs-arctic || error_exit "Failed to activate conda environment: ufs-arctic"
    
    source "$NAMELIST_FILE" || error_exit "Namelist file not found: $NAMELIST_FILE"

    mkdir -p ${PREP_DIR}/intercom
}

run_ocn() {
    local STATUS_FILE="${TOP_DIR}/.status/ocn.done"

    if [ -f "${STATUS_FILE}" ]; then
        log_info "Ocean prep already completed. Skipping."
        return 0
    fi

    log_info "Starting ocean prep..."
    mkdir -p "${OCN_RUN_DIR}/intercom"
    
    (cd ${OCN_SCRIPT_DIR} && ./run_init.sh) || error_exit "Ocean prep: run_init.sh failed."

    rsync -a "${OCN_RUN_DIR}"/intercom/*.nc "${PREP_DIR}/intercom/"
    
    touch "$STATUS_FILE"
}

run_ice() {
    local STATUS_FILE="${TOP_DIR}/.status/ice.done"

    if [ -f "${STATUS_FILE}" ]; then
        log_info "Ice prep already completed. Skipping."
        return 0
    fi

    log_info "Starting ice prep..."
    mkdir -p "${ICE_RUN_DIR}/intercom"

    ln -sf "${ICE_SCRIPT_DIR}"/*   "${ICE_RUN_DIR}"/.
    ln -sf "${ICE_SRC_GRID_DIR}"/* "${ICE_RUN_DIR}"/.
    ln -sf "${ICE_DST_GRID_DIR}"/* "${ICE_RUN_DIR}"/.
    ln -sf "${ICE_INPUT_DIR}"/*    "${ICE_RUN_DIR}"/.
    
    (cd "${ICE_RUN_DIR}" && ./run_ice.sh) || error_exit "Ice prep: run_ice.sh failed"

    rsync -a "${ICE_RUN_DIR}"/intercom/*.nc "${PREP_DIR}/intercom/"
    
    touch "$STATUS_FILE"
}

run_atm() {
    local STATUS_FILE="${TOP_DIR}/.status/atm.done"

    if [ -f "${STATUS_FILE}" ]; then
        log_info "Atmosphere prep already completed. Skipping."
        return 0
    fi

    log_info "Starting atmosphere prep..."
    mkdir -p "${ATM_RUN_DIR}/intercom/"
    ln -sf "${ATM_SCRIPT_DIR}"/* "${ATM_RUN_DIR}/."

    (cd ${ATM_RUN_DIR} && ./arctic_atm_prep.sh) || error_exit "Atmosphere prep: arctic_atm_prep.sh failed"

    rsync -a "${ATM_RUN_DIR}"/intercom/*.nc "${PREP_DIR}/intercom/"
    
    touch "$STATUS_FILE"
}

# ================================= #
# Main Logic & Argument Parsing     #
# ================================= #

# Default parameters
CLEAN=false
RUN_OCN=false
RUN_ICE=false
RUN_ATM=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean) CLEAN=true; shift ;;
        --ocn)   RUN_OCN=true; shift ;;
        --ice)   RUN_ICE=true; shift ;;
        --atm)   RUN_ATM=true; shift ;;
        --all)   RUN_OCN=true; RUN_ICE=true; RUN_ATM=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *)
            error_exit "Unknown option: $1\nUse --help for usage information."
    esac
done

[[ "$VERBOSE" == "true" ]] && set -x

if [[ "$CLEAN" == "true" ]] && [[ -f "${TOP_DIR}/prep/clean.sh" ]]; then 
    (cd "${TOP_DIR}/prep" && ./clean.sh)
    rm -rf "${TOP_DIR}/.status"
    rm "${TOP_DIR}/prep_*.log"
fi

if [[ "$RUN_OCN" == "true" || "$RUN_ICE" == "true" || "$RUN_ATM" == "true" ]]; then
    setup
    [[ "$RUN_OCN" == "true" ]] && run_ocn
    [[ "$RUN_ICE" == "true" ]] && run_ice
    [[ "$RUN_ATM" == "true" ]] && run_atm
else
    [[ "$CLEAN" == "false" ]] && log_warn "No prep tasks specified."
fi

log_info "Prep script finished successfully."
exit 0
