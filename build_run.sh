#!/bin/bash
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
export CDATE=20191028 #YYYYMMDD
export NHRS=3 # Max run length is 240 Hours
export ATM_RES='C185' # C185 (50km) / C918 (11km)

export SACCT="ufs-artic" # Job submission account
export SYSTEM="ursa" # ursa, hera
export COMPILER="intelllvm" # gnu, intel, intelllvm

export RUN_DIR="/scratch4/BMC/${SACCT}/${USER}" # Location to create run directory

# ================================= #
# Below does not need to be changed #
# ================================= #

export FIX_DIR="/scratch4/BMC/ufs-artic/Kristin.Barton/files/ufs_arctic_development/fix_files"
export TOP_DIR=$(pwd)

if [[ "$ATM_RES" == "C185" ]]; then
    NPX=156
    NPY=126
elif [[ "$ATM_RES" == "C918" ]]; then
    NPX=726
    NPY=576
else
    echo "Error: Atmosphere resolution $ATM_RES is invalid; options are C918 or C185." >&2
    exit 1
fi

# Compile model
UFS_DIR=${TOP_DIR}/ufs-weather-model
compile() {
    if [ ! -f "${UFS_DIR}/build/ufs_model" ]; then
        echo "Compiling UFS"
        if [ -f "{UFS_DIR}/build" ]; then
            cd ${UFS_DIR}/build
            make clean
        fi
        cd ${UFS_DIR}
        module use modulefiles
        module load ufs_${SYSTEM}.${COMPILER}.lua
        CMAKE_FLAGS="-DDEBUG=OFF -DAPP=S2S -DREGIONAL_MOM6=ON -DMOVING_NEST=OFF -DCCPP_SUITES=FV3_GFS_v17_coupled_p8_ugwpv1" ./build.sh
        echo "Compilation Complete"
    else
        echo "Skipping compile; UFS executable exists: ${UFS_DIR}/build/ufs_model"
    fi
}

# Run initial condition prep
PREP_DIR=${TOP_DIR}/prep
prep() {
    echo "Running input file prep script"
    cd ${PREP_DIR}
    ./run_prep.sh --clean --all
    cd ${TOP_DIR}
    echo "Input File Generation Complete"
}

# Make a new run directory
setup() {
    YEAR=${CDATE:0:4}
    MONTH=${CDATE:4:2}
    DAY=${CDATE:6:2}
    base="${RUN_DIR}/${YEAR}-${MONTH}-${DAY}_${NHRS}HRS"
    count=1
    MODEL_DIR=${base}
    while [ -e "$MODEL_DIR" ]; do
        MODEL_DIR="${base}_${count}"
        ((count++))
    done
   
    ln -sfn "${MODEL_DIR}" "${TOP_DIR}/run"
    
    # Populate run directories
    mkdir -p ${MODEL_DIR}
    mkdir -p ${MODEL_DIR}/INPUT
    mkdir -p ${MODEL_DIR}/OUTPUT
    mkdir -p ${MODEL_DIR}/RESTART
    mkdir -p ${MODEL_DIR}/history
    mkdir -p ${MODEL_DIR}/modulefiles
    
    # Populate INPUT directory
    cp -P ${PREP_DIR}/intercom/* ${MODEL_DIR}/INPUT/.
    ln -s gfs_data.tile7.nc ${MODEL_DIR}/INPUT/gfs_data.nc
    ln -s sfc_data.tile7.nc ${MODEL_DIR}/INPUT/sfc_data.nc
    ln -s gfs_bndy.tile7.000.nc ${MODEL_DIR}/INPUT/gfs.bndy.nc
    cp -P ${FIX_DIR}/mesh_files/${ATM_RES}/sfc/*.nc ${MODEL_DIR}/.
    cp -P ${FIX_DIR}/mesh_files/${ATM_RES}/*.nc ${MODEL_DIR}/INPUT/.
    cp -P ${FIX_DIR}/input_grid_files/ocn/* ${MODEL_DIR}/INPUT/.
    cp -P ${FIX_DIR}/input_grid_files/ice/* ${MODEL_DIR}/INPUT/.
    cp -P ${FIX_DIR}/datasets/run_dir/* ${MODEL_DIR}/.
    cp -P ${UFS_DIR}/modulefiles/ufs_${SYSTEM}.${COMPILER}.lua ${MODEL_DIR}/modulefiles/modules.fv3.lua
    cp -P ${UFS_DIR}/modulefiles/ufs_common.lua ${MODEL_DIR}/modulefiles/.
    cp -P ${UFS_DIR}/build/ufs_model ${MODEL_DIR}/fv3.exe

    ln -s ${ATM_RES}_mosaic.nc                  ${MODEL_DIR}/INPUT/grid_spec.nc
    ln -s ${ATM_RES}_oro_data.tile7.halo0.nc    ${MODEL_DIR}/INPUT/oro_data.nc 
    ln -s ${ATM_RES}_grid.tile7.halo0.nc        ${MODEL_DIR}/INPUT/grid.tile7.halo0.nc
    ln -s ${ATM_RES}_grid.tile7.halo4.nc        ${MODEL_DIR}/INPUT/grid.tile7.halo4.nc 
    ln -s ${ATM_RES}_oro_data.tile7.halo4.nc    ${MODEL_DIR}/INPUT/oro_data.tile7.halo4.nc
    ln -s ${ATM_RES}_oro_data_ls.tile7.halo0.nc ${MODEL_DIR}/INPUT/oro_data_ls.nc
    ln -s ${ATM_RES}_oro_data_ss.tile7.halo0.nc ${MODEL_DIR}/INPUT/oro_data_ss.nc
    
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

    ln -s ${ATM_RES}.facsf.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.facsf.tile1.nc                
    ln -s ${ATM_RES}.slope_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.slope_type.tile1.nc       
    ln -s ${ATM_RES}.soil_color.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_color.tile1.nc  
    ln -s ${ATM_RES}.substrate_temperature.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.substrate_temperature.tile1.nc  
    ln -s ${ATM_RES}.vegetation_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_type.tile1.nc
    ln -s ${ATM_RES}.maximum_snow_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.maximum_snow_albedo.tile1.nc  
    ln -s ${ATM_RES}.snowfree_albedo.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.snowfree_albedo.tile1.nc  
    ln -s ${ATM_RES}.soil_type.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.soil_type.tile1.nc   
    ln -s ${ATM_RES}.vegetation_greenness.tile7.halo4.nc ${MODEL_DIR}/${ATM_RES}.vegetation_greenness.tile1.nc
    
    # Adjust config templates for specific case
    awk -v y="$YEAR" -v m="$MONTH" -v d="$DAY" '
      {
        gsub(/YEAR/, y)
        gsub(/MONTH/,   m)
        gsub(/DAY/,   d)
        print
      }
    ' ${PREP_DIR}/config_files/templates/ice_in > ${MODEL_DIR}/ice_in 
    
    awk -v y="$YEAR" -v m="$MONTH" -v d="$DAY" '
      {
        gsub(/YEAR/, y)
        gsub(/MONTH/,   m)
        gsub(/DAY/,   d)
        print
      }
    ' ${PREP_DIR}/config_files/templates/diag_table > ${MODEL_DIR}/diag_table
    
    awk -v y="$YEAR" -v m="$MONTH" -v d="$DAY" -v h="$NHRS" '
      {
        gsub(/YEAR/, y)
        gsub(/MONTH/,   m)
        gsub(/DAY/,   d)
        gsub(/NHRS/,   h)
        print
      }
    ' ${PREP_DIR}/config_files/templates/model_configure > ${MODEL_DIR}/model_configure
    
    awk -v y="$YEAR" -v m="$MONTH" -v d="$DAY" -v h="$NHRS" -v a="$SACCT" '
      {
        gsub(/YEAR/, y)
        gsub(/MONTH/,   m)
        gsub(/DAY/,   d)
        gsub(/NHRS/,   h)
        gsub(/SACCT/,   a)
        print
      }
    ' ${PREP_DIR}/config_files/templates/job_card > ${MODEL_DIR}/job_card

    awk -v x="$NPX" -v y="$NPY" -v r="$ATM_RES" '
      {
        gsub(/NPX/,  x)
        gsub(/NPY/,  y)
        gsub(/CRES/, r)
        print
      }
    ' ${PREP_DIR}/config_files/templates/input.nml > ${MODEL_DIR}/input.nml
    
    cd ${PREP_DIR}
    ./clean.sh
    echo " ===== "
    echo ""
    echo "Model run directory built in ${MODEL_DIR}"
}

run_model() {
    echo "Submitting model run"
    cd ${TOP_DIR}/run
    sbatch job_card
}

help() {
    echo "Usage: $0 [--norun] [-v]"
    exit 1
}

# Run logic
SUBMIT_JOB=true
export VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      export VERBOSE=true
      shift
      ;;
    --norun)
      RUN_COMMANDS=false
      shift
      ;;
    *)
      echo "Error: Unknown option '$1'" >&2
      exit 1
      ;;
  esac
done

echo $VERBOSE
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

compile
echo ""
prep
echo ""
setup
echo ""
if [[ "$SUBMIT_JOB" == true ]]; then
    run_model
fi
