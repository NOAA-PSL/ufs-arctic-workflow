#!/bin/bash
# SLURM Defualts: Will be overridden by wrapper script when run
#SBATCH --job-name=ufs_workflow
#SBATCH --partition=u1-compute
#SBATCH --time=60:00
#SBATCH --nodes=2
#SBATCH --ntasks=4
#SBATCH --output=slurm_prep_%j.log

set -eo pipefail

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
# Default Parameters & CLI Parsing  #
# ================================= #

export CDATE=""
export NHRS=""
export SACCT="$SLURM_JOB_ACCOUNT"
export ATM_RES=""

RUN_DIR=""
JOB_NAME=""

export SYSTEM="ursa"
export COMPILER="intelllvm"
export UFS_DIR=""

RUN_STEP="all"
SUBMIT_JOB=true

help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Required Options:"
    echo " --date YYYYMMDD      Start date (e.g., 20191028)"
    echo " --hours N            Run length in hours (Max: 240)"
    echo " --res RES            Atmospheric resolution (C185 or C918)"
    echo ""
    echo "Optional Configuration:"
    echo " --run-dir PATH       Path to place the workflow output directory"
    echo "                      Default: /scratch4/BMC/\${SACCT}/\${USER}/stmp"
    echo " --job-name NAME      Name of the job. Will be used to create run directory."
    echo "                      Defualt: \${ATM_RES}/_\${CDATE}_\${NHRS}HRS"
    echo " --system SYS         System name (ursa, hera). Default: ursa"
    echo " --compiler COMP      Compiler name (gnu, intel, intelllvm). Default: intelllvm"
    echo " --ufs-dir PATH       Path to an EXISTING compiled UFS model directory."
    echo "                      If provided, skips compilation and uses this directory."
    echo ""
    echo "Workflow Control:"
    echo " --step STEP          Run only a specific step. Options:"
    echo "                      all (default), compile, setup, prep_ocn, prep_ice, prep_atm, run"
    echo " --norun              Setup the entire run directory, but DO NOT submit the final job."
    echo " -h, --help           Display this help message and exit."
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --date) export CDATE="$2"; shift 2 ;;
        --hours) export NHRS="$2"; shift 2 ;;
        --res) export ATM_RES="$2"; shift 2 ;;
        --run-dir) RUN_DIR="$2"; shift 2 ;;
        --job-name) JOB_NAME="$2"; shift 2 ;;
        --system) export SYSTEM="$2"; shift 2 ;;
        --compiler) export COMPILER="$2"; shift 2 ;;
        --ufs-dir) export UFS_DIR="$2"; shift 2 ;;
        --step) RUN_STEP="$2"; shift 2 ;;
        --norun) SUBMIT_JOB=false; shift 1 ;;
        -h|--help) help ;;
        *) echo "Error: Unknown option '$1'. Use -h or --help for usage." >&2; exit ;;
    esac
done

# Validate the required arguments
if [[ -z "$CDATE" || -z "$NHRS" || -z "$ATM_RES" ]]; then
    error_exit "Missing required arguments: --date, --hours, --account, and --res are required. Use --help for more information"
fi

if [[ -z "$RUN_DIR" ]]; then
    RUN_DIR="/scratch4/BMC/${SACCT}/${USER}/stmp"
fi

if [[ -z "$JOB_NAME" ]]; then
    JOB_NAME="${ATM_RES}_${CDATE}_${NHRS}HRS"
fi

# ================================= #
# System Paths & Validation         #
# ================================= #

if [[ -n "$SLURM_SUBMIT_DIR" ]]; then
    if [[ "$(basename "$SLURM_SUBMIT_DIR")" == "workflow" ]]; then
        export TOP_DIR="$(dirname "$SLURM_SUBMIT_DIR")"
    else
        export TOP_DIR="$SLURM_SUBMIT_DIR"
    fi
else
    export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    export TOP_DIR="$(dirname "$SCRIPT_DIR")"
fi

[ -d "$TOP_DIR" ] || error_exit "Top directory not found: $TOP_DIR"

export FIX_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/files/ufs_arctic_development/fix_files"
export CONFIG_DIR="${TOP_DIR}/config"
export MODEL_DIR="${RUN_DIR}/${JOB_NAME}"
export STATUS_DIR="${MODEL_DIR}/.status"

conda_env="/scratch4/BMC/ufs-artic/Kristin.Barton/envs/ufs-arctic"
module_path="/contrib/spack-stack/spack-stack-1.9.3/envs/ue-oneapi-2024.2.1/install/modulefiles/Core"


# ================================= #
# Functions                         #
# ================================= #

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
    log_info "Populating model run directory in: ${MODEL_DIR} ..."

    YEAR="${CDATE:0:4}"
    MONTH="${CDATE:4:2}"
    DAY="${CDATE:6:2}"

    mkdir -p "${MODEL_DIR}"/{INPUT,OUTPUT,RESTART,history,modulefiles} || error_exit "Could not create subdirectories in ${MODEL_DIR}"
   
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
    ln -sf "${UFS_DIR}/build/ufs_model" "${MODEL_DIR}/fv3.exe"

    if [ -f "${UFS_DIR}/build/build_metadata.txt" ]; then
        cp -P "${UFS_DIR}/build/build_metadata.txt" "${MODEL_DIR}/ufs_build_metadata.txt"
    else
        echo "Source Executable: ${UFS_DIR}/build/ufs_model" > "${MODEL_DIR}/fv3_build_metadata.txt"
        echo "Note: Provided executable directory did not contain build metadata." >> "${MODEL_DIR}/fv3_build_metadata.txt"
    fi

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

prep_init() {
    export PREP_DIR="${MODEL_DIR}/PREP"
    mkdir -p "${PREP_DIR}/intercom"
    mkdir -p "${MODEL_DIR}/INPUT"
    local NAMELIST_FILE="${CONFIG_DIR}/config.in"
    source "$NAMELIST_FILE" || error_exit "Namelist file not found: $NAMELIST_FILE"
}

prep_ocn() {
    log_info "Starting ocean prep..."
    if [ -f "${STATUS_DIR}/ocn.done" ]; then
        log_info "-> Ocean prep already completed. Skipping."
    else 
        mkdir -p "${OCN_RUN_DIR}/intercom"
        (cd ${OCN_SCRIPT_DIR} && ./run_ocn_prep.sh) || error_exit "Ocean prep: run_ocn_prep.sh failed."
        mv "${OCN_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
        touch "${STATUS_DIR}/ocn.done"
    fi

    ln -sf "${PREP_DIR}"/intercom/* "${MODEL_DIR}"/INPUT/.
}

prep_ice() {
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
        mv "${ICE_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
        touch "${STATUS_DIR}/ice.done"
    fi

    ln -sf "${PREP_DIR}"/intercom/* "${MODEL_DIR}"/INPUT/.
}

prep_atm() {
    log_info "Starting atmosphere prep..."
    if [ -f "${STATUS_DIR}/atm.done" ]; then
        log_info "-> Atmosphere prep already completed. Skipping."
    else
        mkdir -p "${ATM_RUN_DIR}/intercom/"
        ln -sf "${ATM_SCRIPT_DIR}"/* "${ATM_RUN_DIR}/."
        (cd ${ATM_RUN_DIR} && ./run_atm_prep.sh) || error_exit "Atmosphere prep: run_atm_prep.sh failed"
        mv "${ATM_RUN_DIR}"/intercom/*.nc "${PREP_DIR}"/intercom/.
        touch "${STATUS_DIR}/atm.done"
    fi

    ln -sf "${PREP_DIR}"/intercom/* "${MODEL_DIR}"/INPUT/.
}

run_model() {
    log_info "Submitting model run..."
    (cd "${MODEL_DIR}" && sbatch job_card) || error_exit "Job submission failed."
}

# ================================= #
# Main Execution Logic              #
# ================================= #

log_info "Starting workflow for Date: $CDATE | Res: $ATM_RES | Length: ${NHRS}h"

module purge
module use ${module_path} || error_exit "Failed to find module path ${module_path}"
module load stack-oneapi || error_exit "Failed to load stack-oneapi module."
module load nco || error_exit "Failed to load nco module."
module load cdo || error_exit "Failed to load cdo module."
module load rdhpcs-conda || error_exit "Failed to load rdhpcs-conda module."
conda activate ${conda_env} || error_exit "Failed to activate conda environment: ${conda_env}"

if [ ! -d "$MODEL_DIR" ]; then
    log_info "Creating new run directory: $MODEL_DIR"
    mkdir -p "${MODEL_DIR}"/{INPUT,OUTPUT,RESTART,history,modulefiles,.status}
else
    log_warn "Run directory already exists in ${MODEL_DIR} Resuming run setup based on existing files."
fi

mkdir -p "$STATUS_DIR"

if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "setup" ]]; then
    if [ ! -f "${STATUS_DIR}/setup.done" ]; then
        setup
        touch "${STATUS_DIR}/setup.done"
    else
        log_info "Setup phase already completed. Skipping."
    fi
fi

if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "prep" || "$RUN_STEP" == "prep_ocn" || "$RUN_STEP" == "prep_ice" || "$RUN_STEP" == "prep_atm" ]]; then prep_init; fi
if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "prep" || "$RUN_STEP" == "prep_ocn" ]]; then prep_ocn; fi
if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "prep" || "$RUN_STEP" == "prep_ice" ]]; then prep_ice; fi
if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "prep" || "$RUN_STEP" == "prep_atm" ]]; then prep_atm; fi

if [[ "$RUN_STEP" == "all" || "$RUN_STEP" == "run" ]]; then
    if [[ "$SUBMIT_JOB" == true ]]; then
        run_model
    else
        log_warn "Skipping job submission because --norun was specified."
    fi
fi

conda deactivate || error_exit "Failed to deactivate conda environment"
log_info "Workflow script completed successfully. Model directory located at: ${MODEL_DIR}"
