#!/bin/bash
set -e -x -o pipefail

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

If no task options are provided, all tasks are run by default.
Examples:
  $0                 # runs ocn, ice, atm
  $0 --ocn           # runs only ocn
  $0 --ocn,atm       # runs ocn and atm (not ice)
  $0 --clean --ocn   # runs ./clean.sh once, then ocn only
  $0 --clean --all   # runs ./clean.sh once, then ocn, ice, atm
EOF
}

# Show help if requested
for arg in "$@"; do
    case "$arg" in
        --help)
            show_help
            exit 0
            ;;
    esac
done

# Change config directory to run case
CONFIG_DIR="./config_files/2020-08-27-03_6HR"
NAMELIST_FILE="$CONFIG_DIR/config.in"

module use /contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core
module load stack-oneapi
module load nco

source /scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/etc/profile.d/conda.sh
export PATH="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/bin:$PATH"
conda activate ufs-arctic

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

mkdir -p ${RUN_DIR}/intercom

run_ocn() {
    # Ocean prep
    mkdir -p ${OCN_RUN_DIR}
    mkdir -p ${OCN_RUN_DIR}/intercom
    cd ${OCN_SCRIPT_DIR}
    ./run_init.sh
    mv ${OCN_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.
    TASK_RAN=true
}

run_ice() {
    # Ice prep 
    mkdir -p ${ICE_RUN_DIR}
    mkdir -p ${ICE_RUN_DIR}/intercom
    ${NLN} ${ICE_SCRIPT_DIR}/* ${ICE_RUN_DIR}/.
    ${NLN} ${ICE_SRC_GRID_DIR}/* ${ICE_RUN_DIR}/.
    ${NLN} ${ICE_DST_GRID_DIR}/* ${ICE_RUN_DIR}/.
    ${NLN} ${ICE_INPUT_DIR}/* ${ICE_RUN_DIR}/.
    cd ${ICE_RUN_DIR}
    ./run_ice.sh
    mv ${ICE_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.
    TASK_RAN=true
}

run_atm() {
    # Atmosphere prep
    mkdir -p ${ATM_RUN_DIR}
    mkdir -p ${ATM_RUN_DIR}/intercom/
    #${NLN} ${FIX_DIR}/${ATM_DST_CASE}/* ${ATM_RUN_DIR}/intercom/.
    ${NLN} ${ATM_SCRIPT_DIR}/* ${ATM_RUN_DIR}/.
    cd ${ATM_RUN_DIR}
    ./arctic_atm_prep.sh
    mv ${ATM_RUN_DIR}/intercom/*.nc ${RUN_DIR}/intercom/.
    TASK_RAN=true
}

# Default parameters
CLEAN=false
RUN_OCN=false
RUN_ICE=false
RUN_ATM=false
TASK_RAN=false

if [$# -eq 0]; then
    RUN_OCN=true
    RUN_ICE=true
    RUN_ATM=true
fi

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=true ;;
        --ocn)  RUN_OCN=true ;;
        --ice)  RUN_ICE=true ;;
        --atm)  RUN_ATM=true ;;
        --all)  RUN_OCN=true; RUN_ICE=true; RUN_ATM=true ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

$CLEAN && [ -f ./clean.sh ] && ./clean.sh

$RUN_OCN && run_ocn
$RUN_ICE && run_ice
$RUN_ATM && run_atm

# Retrieve config files
$TASK_RAN && cp ${CONFIG_DIR}/* ${RUN_DIR}/intercom/.
exit 0
