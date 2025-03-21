#!/bin/bash

CONFIG_DIR="/scratch2/BMC/gsienkf/Kristin.Barton/repos/NOAA-PSL/ufs-arctic-workflow/run/config_files/2020_08_25_12_3HR"
NAMELIST_FILE="$CONFIG_DIR/config.in"

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

mkdir -p ${RUN_DIR}/intercom
mkdir -p ${ATM_RUN_DIR}
mkdir -p ${OCN_RUN_DIR}

# Run Atmosphere prep
mkdir -p ${ATM_RUN_DIR}/intercom/grid/${CASE}
${NLN} ${ATM_GRID_DIR}/* ${ATM_RUN_DIR}/intercom/grid/${CASE}/.

cd ${ATM_SCRIPT_DIR}
./exhafs_atm_ic.sh
./exhafs_atm_lbc.sh

mv ${ATM_RUN_DIR}/intercom/chgres/*.nc ${RUN_DIR}/intercom/.

mkdir -p ${OCN_RUN_DIR}/
mkdir -p ${OCN_RUN_DIR}/intercom

# Run Ocean prep
cd ${OCN_SCRIPT_DIR}
./run_init.sh

mv ${OCN_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.

cp ${CONFIG_DIR}/* ${RUN_DIR}/intercom/.
