#!/bin/bash
#SBATCH --job-name=ufs_prep
#SBATCH --account=ufs-artic # Edit job account
#SBATCH --partition=u1-compute
#SBATCH --time=30:00
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=slurm_%j.log

set -eo pipefail

# To run:
#1. Clone the workflow and then update submodules: `git submodule update --init --recursive`
#2. Open `submit_build.sh` and adjust the test run start date, run length, account, system, compiler, and run directory as needed.
#3. Run the workflow: 
#  - `sbatch submit_build.sh`
#  - `sbatch submit_build.sh --norun` to setup the run directoy without submitting the model run.

# ================================= #
# User-adjusted parameters          #
# ================================= #

# Current available dates are:
# 2019/10/28, 2020/02/27, 2020/07/02, 2020/07/09, 2020/08/27
export CDATE=20191028       # Start date in YYYYMMDD format
export NHRS=3               # Run length in hours (Max: 240)
export ATM_RES='C185'       # Atmospheric resolution: C185 (50km) or C918 (11km)

export SACCT="$SLURM_JOB_ACCOUNT"    # SET THIS IN LINE 3 ABOVE
export SYSTEM="ursa"        # ursa, hera
export COMPILER="intelllvm" # gnu, intel, intelllvm

# Location to create run directory (will run in RUN_DIR/JOB_NAME)
export RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp"
export JOB_NAME="${ATM_RES}_${CDATE}_${NHRS}HRS"

# ================================= #
# Logging & Error Handling Helpers  #
# ================================= #

log_info()  { echo -e "(info) $1"; }
log_warn()  { echo -e "(Warn) $1"; }
log_error() { echo -e "[ERROR] $1" >&2; }
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

export CONFIG_DIR="${TOP_DIR}/config"
[ -d "$CONFIG_DIR" ] || error_exit "Config directory not found: $CONFIG_DIR"

export SCRIPT_DIR="${TOP_DIR}/workflow"
[ -d "$SCRIPT_DIR" ] || error_exit "Script directory not found: $SCRIPT_DIR"

export MODEL_DIR="${RUN_DIR}/${JOB_NAME}"
export STATUS_DIR="${MODEL_DIR}/.status"


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
        log_info "Skipping UFS compile; executable already exists at: ${UFS_DIR}/build/ufs_model"
    fi
}


# Helper function for rendering config files 
render_template() {
    if [[ "$ATM_RES" == "C185" ]]; then
        NPX=156
        NPY=126
    elif [[ "$ATM_RES" == "C918" ]]; then
        NPX=726
        NPY=576
    fi

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
    log_info "Populating model run directory in: ${MODEL_DIR}..."

    YEAR="${CDATE:0:4}"
    MONTH="${CDATE:4:2}"
    DAY="${CDATE:6:2}"

    mkdir -p "${MODEL_DIR}"/{INPUT,OUTPUT,RESTART,history,modulefiles} || error_exit "Could not create subdirectories in ${MODEL_DIR}."
   
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
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/data_table ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/diag_table ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/fd_ufs.yaml ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/field_table ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/module-setup.sh ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/noahmptable.tbl ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/ufs.configure ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/input.nml ${MODEL_DIR}/.
    cp -P ${CONFIG_DIR}/templates/${ATM_RES}/MOM_input ${MODEL_DIR}/.

    ln -sf ${ATM_RES}.facsf.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.facsf.tile1.nc                
    ln -sf ${ATM_RES}.slope_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.slope_type.tile1.nc       
    ln -sf ${ATM_RES}.soil_color.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_color.tile1.nc  
    ln -sf ${ATM_RES}.substrate_temperature.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.substrate_temperature.tile1.nc  
    ln -sf ${ATM_RES}.vegetation_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_type.tile1.nc
    ln -sf ${ATM_RES}.maximum_snow_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.maximum_snow_albedo.tile1.nc  
    ln -sf ${ATM_RES}.snowfree_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.snowfree_albedo.tile1.nc  
    ln -sf ${ATM_RES}.soil_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_type.tile1.nc   
    ln -sf ${ATM_RES}.vegetation_greenness.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_greenness.tile1.nc
    
    render_template "${CONFIG_DIR}/templates/${ATM_RES}/ice_in" "${MODEL_DIR}/ice_in"
    render_template "${CONFIG_DIR}/templates/${ATM_RES}/diag_table" "${MODEL_DIR}/diag_table"
    render_template "${CONFIG_DIR}/templates/${ATM_RES}/model_configure" "${MODEL_DIR}/model_configure"
    render_template "${CONFIG_DIR}/templates/${ATM_RES}/job_card" "${MODEL_DIR}/job_card"
    render_template "${CONFIG_DIR}/templates/${ATM_RES}/input.nml" "${MODEL_DIR}/input.nml"

    log_info "Model run directory successfully built."

}

prep() {
    log_info "Preparing initial and lateral boundary conditions..."

    export PREP_DIR="${MODEL_DIR}/PREP"
    mkdir -p "${PREP_DIR}"

    (
        local NAMELIST_FILE="${CONFIG_DIR}/config.in"

        module purge
        module purge
        module use /contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core || error_exit "Failed to find module path /contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core"
        module load stack-oneapi || error_exit "Failed to load stack-oneapi module."
        module load nco || error_exit "Failed to load nco module."
        module load cdo || error_exit "Failed to load cdo module."
        
        local CONDA_SH="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/etc/profile.d/conda.sh"
        [ -f "$CONDA_SH" ] || error_exit "Conda init script not found at: $CONDA_SH"
        source "$CONDA_SH"
        export PATH="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/miniconda3/bin:$PATH"
        conda activate ufs-arctic || error_exit "Failed to activate conda environment: ufs-artic"
        
        source "$NAMELIST_FILE" || error_exit "Namelist file not found: $NAMELIST_FILE"

        # Preparing file paths
        cd "${PREP_DIR}"
        mkdir -p ${PREP_DIR}/intercom

        # --- Run ocean init ---
        log_info "Starting ocean prep..."
        if [ -f "${STATUS_DIR}/ocn.done" ]; then
            log_info "-> Ocean prep already completed. Skipping."
        else 
            mkdir -p "${OCN_RUN_DIR}/intercom"
            (cd ${OCN_SCRIPT_DIR} && ./run_ocn_prep.sh) || error_exit "Ocean prep: run_ocn_prep.sh failed."
            rsync -a "${OCN_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
            touch "${STATUS_DIR}/ocn.done"
        fi

        # --- Run ice init ---
        log_info "Starting ice prep..."
        if [ -f "${STATUS_DIR}/ice.done" ]; then
            log_info "-> Ice prep already completed. Skipping."
        else
            mkdir -p "${ICE_RUN_DIR}/intercom"
            ln -sf "${ICE_SCRIPT_DIR}"/*   "${ICE_RUN_DIR}"/.
            ln -sf "${ICE_SRC_GRID_DIR}"/* "${ICE_RUN_DIR}"/.
            ln -sf "${ICE_DST_GRID_DIR}"/* "${ICE_RUN_DIR}"/.
            ln -sf "${ICE_INPUT_DIR}"/*    "${ICE_RUN_DIR}"/.
            (cd "${ICE_RUN_DIR}" && ./run_ice_prep.sh) || error_exit "Ice prep: run_ice_prep.sh failed"
            rsync -a "${ICE_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
            touch "${STATUS_DIR}/ice.done"
        fi

        # --- Run atm init ---
        log_info "Starting atmosphere prep..."
        if [ -f "${STATUS_DIR}/atm.done" ]; then
            log_info "-> Atmosphere prep already completed. Skipping."
        else
            mkdir -p "${ATM_RUN_DIR}/intercom/"
            ln -sf "${ATM_SCRIPT_DIR}"/* "${ATM_RUN_DIR}/."
            (cd ${ATM_RUN_DIR} && ./run_atm_prep.sh) || error_exit "Atmosphere prep: run_atm_prep.sh failed"
            rsync -a "${ATM_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
            touch "${STATUS_DIR}/atm.done"
        fi
    ) || error_exit "Prep script failed."

    ln -sf "${PREP_DIR}"/intercom/* "${MODEL_DIR}"/INPUT/. || error_exit "Failed to link files from ${PREP_DIR}/intercom to ${MODEL_DIR}/INPUT"

    log_info "Input file generation complete."

}

run_model() {
    log_info "Submitting model run..."
    (cd "${MODEL_DIR}" && sbatch job_card) || error_exit "Job submission failed."
}

help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --norun        Setup the run directory without submitting the job to the scheduler."
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

log_info "Starting workflow for Date: $CDATE | Res: $ATM_RES | Length: ${NHRS}h"

if [ ! -d "$MODEL_DIR" ]; then
    log_info "Creating new run directory: $MODEL_DIR"
    mkdir -p "${MODEL_DIR}"/{INPUT,OUTPUT,RESTART,history,modulefiles,.status}
else
    log_warn "Run directory already exists in ${MODEL_DIR}. Resuming run setup based on existing files."
fi

if [ ! -d "$STATUS_DIR" ]; then
    mkdir -p "$STATUS_DIR"
fi

compile

if [ ! -f "${STATUS_DIR}/setup.done" ]; then
    setup
    touch "${STATUS_DIR}/setup.done"
else
    log_info "Setup phase already completed. Skipping."
fi

if [ ! -f "${STATUS_DIR}/prep.done" ]; then
    prep
    touch "${STATUS_DIR}/prep.done"
else
    log_info "Prep phase already completed. Skipping."
fi

if [[ "$SUBMIT_JOB" == true ]]; then
    run_model
else
    log_warn "Skipping job submission because --norun was specified."
fi

log_info "Workflow script completed successfully. Model directory located at: ${MODEL_DIR}."
