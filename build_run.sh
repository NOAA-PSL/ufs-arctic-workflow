#!/bin/bash
#SBATCH --job-name=ufs_prep
#SBATCH --account=ufs-artic
#SBATCH --partition=u1-compute
#SBATCH --time=30:00
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=prep_%j.log

set -eo pipefail

# To run:
#   1. Clone the workflow and then update submodules: `git submodule update --init --recursive`
#   2. Open `build_run.sh` and adjust the test run start date, run length, account, system, compiler, and run directory as needed.
#   3. Run the workflow:
#     `./build.sh` to automatically submit the job after setup.
#     `./build.sh --norun` to setup the run directoy without submitting the job.

# ================================= #
# User-adjusted parameters          #
# ================================= #

# Current available dates are:
# 2019/10/28, 2020/02/27, 2020/07/02, 2020/07/09, 2020/08/27
export CDATE=20191028       # Start date in YYYYMMDD format
export NHRS=3               # Run length in hours (Max: 240)
export ATM_RES='C185'       # Atmospheric resolution: C185 (50km) or C918 (11km)

export SACCT="ufs-artic"    # Job submission account
export SYSTEM="ursa"        # ursa, hera
export COMPILER="intelllvm" # gnu, intel, intelllvm

# Location to create run directory (will run in RUN_DIR/JOB_NAME)
export RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp"
export JOB_NAME="${ATM_RES}_${CDATE}_${NHRS}HRS"

# ================================= #
# Logging & Error Handling Helpers  #
# ================================= #

# Define ANSI color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
error_exit() {
    log_error "$1"
    exit 1
}

# ================================= #
# System Paths & Validation         #
# ================================= #

export FIX_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/files/ufs_arctic_development/fix_files"
[ -d "$FIX_DIR" ]  || error_exit "Fix directory not found: $FIX_DIR"

if [ -n "$SLURM_SUBMIT_DIR" ]; then
    export TOP_DIR="$SLURM_SUBMIT_DIR"
else
    export TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
fi
[ -d "$TOP_DIR" ]  || error_exit "build_run.sh script directory not found: $TOP_DIR."

export UFS_DIR="${TOP_DIR}/ufs-weather-model"
[ -d "$UFS_DIR" ]  || error_exit "UFS Model directory not found: $UFS_DIR. Did you pull submodules?"

export PREP_DIR="${TOP_DIR}/prep"
[ -d "$PREP_DIR" ] || error_exit "Prep directory not found: $PREP_DIR"


if [[ "$ATM_RES" == "C185" ]]; then
    NPX=156
    NPY=126
elif [[ "$ATM_RES" == "C918" ]]; then
    NPX=726
    NPY=576
else
    echo "Error: Atmosphere resolution $ATM_RES is invalid.  Valid options: C918, C185." >&2
    exit 1
fi

# ================================= #
# Functions                         #
# ================================= #

# Compile model
compile() {
    if [ ! -f "${UFS_DIR}/build/ufs_model" ]; then
        log_info "UFS executable not found. Starting compilation..."

        if [ -d "${UFS_DIR}/build" ]; then
            log_warn "Existing build directory found. Running 'make clean'..."
            (cd "${UFS_DIR}/build" && make clean)
        fi

        (
            cd "${UFS_DIR}"
            module use modulefiles || error_exit "Failed to find modulefiles."
            module load "ufs_${SYSTEM}.${COMPILER}.lua" || error_exit "Failed to load module: ufs_${SYSTEM}.${COMPILER}.lua. Did you run: git submodule update --init --recursive ?"
            log_info "Running CMake and build scripts..."
            CMAKE_FLAGS="-DDEBUG=OFF -DAPP=S2S -DREGIONAL_MOM6=ON -DMOVING_NEST=OFF -DCCPP_SUITES=FV3_GFS_v17_coupled_p8_ugwpv1" ./build.sh
        )
        log_info "Compilation Complete"
    else
        log_info "Skipping compile; UFS executable already exists at: ${UFS_DIR}/build/ufs_model"
    fi
}

prep() {
    log_info "Preparing input files for run..."
    (cd "${PREP_DIR}" && ./run_prep.sh --all) || error_exit "Prep script failed."
    log_info "Input file generation complete"
}

# Helper function for rendering config files 
render_template() {
    local src="$1"
    local dest="$2"

    [ -f "$src" ] || error_exit "Template file missing: $src"

    sed -e "s|YEAR|${YEAR}|g" \
        -e "s|MONTH|${MONTH}|g" \
        -e "s|DAY|${DAY}|g" \
        -e "s|NHRS|${NHRS}|g" \
        -e "s|SACCT|${SACCT}|g" \
        -e "s|NPX|${NPX}|g" \
        -e "s|NPY|${NPY}|g" \
        -e "s|CRES|${ATM_RES}|g" \
        "${src}" > "${dest}" || error_exit "Failed to render template: $src"
}

# Make a new run directory
setup() {
    YEAR="${CDATE:0:4}"
    MONTH="${CDATE:4:2}"
    DAY="${CDATE:6:2}"

    local base="${RUN_DIR}/${JOB_NAME}"
    local count=1
    MODEL_DIR="${base}"

    if [ ! -d "$MODEL_DIR" ]; then
        log_info "Creating new run directory: $MODEL_DIR"
        mkdir -p "${MODEL_DIR}"/{INPUT,OUTPUT,RESTART,history,modulefiles}
    else
        log_warn "Run directory already exists. Resuming run setup based on existing files."
    fi
   
    ln -sfn "${MODEL_DIR}" "${TOP_DIR}/run"
    
    # Populate INPUT directory
    cp -P "${PREP_DIR}"/intercom/* "${MODEL_DIR}"/INPUT/.

    (
        cd "${MODEL_DIR}/INPUT"
        ln -sf gfs_data.tile7.nc gfs_data.nc
        ln -sf sfc_data.tile7.nc sfc_data.nc
        ln -sf gfs_bndy.tile7.000.nc gfs.bndy.nc

        ln -sf "${ATM_RES}_mosaic.nc" grid_spec.nc
        ln -sf "${ATM_RES}_oro_data.tile7.halo0.nc" oro_data.nc
        ln -sf "${ATM_RES}_grid.tile7.halo0.nc" grid.tile7.halo0.nc
        ln -sf "${ATM_RES}_grid.tile7.halo4.nc" grid.tile7.halo4.nc
        ln -sf "${ATM_RES}_oro_data.tile7.halo4.nc" oro_data.tile7.halo4.nc
        ln -sf "${ATM_RES}_oro_data_ls.tile7.halo0.nc" oro_data_ls.nc
        ln -sf "${ATM_RES}_oro_data_ss.tile7.halo0.nc" oro_data_ss.nc
    )

    cp -P "${FIX_DIR}/mesh_files/${ATM_RES}/sfc/"*.nc "${MODEL_DIR}/"
    cp -P "${FIX_DIR}/mesh_files/${ATM_RES}/"*.nc "${MODEL_DIR}/INPUT/"
    cp -P "${FIX_DIR}/input_grid_files/ocn/"* "${MODEL_DIR}/INPUT/"
    cp -P "${FIX_DIR}/input_grid_files/ice/"* "${MODEL_DIR}/INPUT/"
    cp -P "${FIX_DIR}/datasets/run_dir/"* "${MODEL_DIR}/"

    cp -P "${UFS_DIR}/modulefiles/ufs_${SYSTEM}.${COMPILER}.lua" "${MODEL_DIR}/modulefiles/modules.fv3.lua"
    cp -P "${UFS_DIR}/modulefiles/ufs_common.lua" "${MODEL_DIR}/modulefiles/"
    cp -P "${UFS_DIR}/build/ufs_model" "${MODEL_DIR}/fv3.exe"

    # Add fixed config files
    cp -P ${PREP_DIR}/config_files/templates/data_table ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/diag_table ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/fd_ufs.yaml ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/field_table ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/module-setup.sh ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/noahmptable.tbl ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/ufs.configure ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/input.nml ${MODEL_DIR}/.
    cp -P ${PREP_DIR}/config_files/templates/MOM_input ${MODEL_DIR}/.

    ln -sf ${ATM_RES}.facsf.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.facsf.tile1.nc                
    ln -sf ${ATM_RES}.slope_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.slope_type.tile1.nc       
    ln -sf ${ATM_RES}.soil_color.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_color.tile1.nc  
    ln -sf ${ATM_RES}.substrate_temperature.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.substrate_temperature.tile1.nc  
    ln -sf ${ATM_RES}.vegetation_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_type.tile1.nc
    ln -sf ${ATM_RES}.maximum_snow_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.maximum_snow_albedo.tile1.nc  
    ln -sf ${ATM_RES}.snowfree_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.snowfree_albedo.tile1.nc  
    ln -sf ${ATM_RES}.soil_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_type.tile1.nc   
    ln -sf ${ATM_RES}.vegetation_greenness.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_greenness.tile1.nc
    
    render_template "${PREP_DIR}/config_files/templates/ice_in" "${MODEL_DIR}/ice_in"
    render_template "${PREP_DIR}/config_files/templates/diag_table" "${MODEL_DIR}/diag_table"
    render_template "${PREP_DIR}/config_files/templates/model_configure" "${MODEL_DIR}/model_configure"
    render_template "${PREP_DIR}/config_files/templates/job_card" "${MODEL_DIR}/job_card"
    render_template "${PREP_DIR}/config_files/templates/input.nml" "${MODEL_DIR}/input.nml"
    
    (cd "${PREP_DIR}" && ./clean.sh)

    log_info "Model run directory successfully built at:"
    log_info "--> ${MODEL_DIR}"

}

run_model() {
    log_info "Submitting model run..."
    (cd "${TOP_DIR}/run" && sbatch job_card) || error_exit "Job submission failed."
}

help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --norun        Setup the run directory without submitting the job to the scheduler."
    echo "  -v, --verbose  Enable verbose bash debugging (set -x)."
    echo "  -h, --help     Display this help message and exit."
    exit 0
}

# ================================= #
# Main Execution Logic              #
# ================================= #

SUBMIT_JOB=true
export VERBOSE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      export VERBOSE="true"
      shift
      ;;
    --norun)
      SUBMIT_JOB=false
      shift
      ;;
    -h|--help)
      help
      ;;
    *)
      echo "Error: Unknown option '$1'. Use -h or --help for usage." >&2
      help
      ;;
  esac
done

if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log_info "Starting workflow for Date: $CDATE | Res: $ATM_RES | Length: ${NHRS}h"

STATUS_DIR="${TOP_DIR}/.status"
mkdir -p "$STATUS_DIR"
PREP_STATUS="${STATUS_DIR}/prep_${JOB_NAME}.done"
SETUP_STATUS="${STATUS_DIR}/setup_${JOB_NAME}.done"

compile

if [ ! -f "$PREP_STATUS" ]; then
    # WARNING: You may need to remove --clean here so run_prep.sh doesn't delete partial progress
    prep
    touch "$PREP_STATUS"
else
    log_info "Prep phase already completed. Skipping."
fi

if [ ! -f "$SETUP_STATUS" ]; then
    setup
    touch "$SETUP_STATUS"
else
    log_info "Setup phase already completed. Skipping."
fi

if [[ "$SUBMIT_JOB" == true ]]; then
    run_model
else
    log_warn "Skipping job submission because --norun was specified."
fi

log_info "Workflow script completed successfully."
