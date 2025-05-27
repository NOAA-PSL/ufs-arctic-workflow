#!/bin/bash

CONFIG_DIR="/scratch2/BMC/gsienkf/Kristin.Barton/stmp/stmp2/Kristin.Barton/FV3_RT/workflow_updates_23May2025/run/config_files/2020_08_25_12_3HR_CICE6"
NAMELIST_FILE="$CONFIG_DIR/config.in"

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

mkdir -p ${RUN_DIR}/intercom

# Atmosphere prep
mkdir -p ${ATM_RUN_DIR}
mkdir -p ${ATM_RUN_DIR}/intercom/grid/${CASE}
${NLN} ${ATM_GRID_DIR}/* ${ATM_RUN_DIR}/intercom/grid/${CASE}/.
cd ${ATM_SCRIPT_DIR}
./exhafs_atm_ic.sh
./exhafs_atm_lbc.sh
mv ${ATM_RUN_DIR}/intercom/chgres/*.nc ${RUN_DIR}/intercom/.

# Ocean prep
mkdir -p ${OCN_RUN_DIR}
mkdir -p ${OCN_RUN_DIR}/intercom
cd ${OCN_SCRIPT_DIR}
./run_init.sh
mv ${OCN_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.

# Ice prep 
mkdir -p ${ICE_RUN_DIR}
mkdir -p ${ICE_RUN_DIR}/intercom
cd ${ICE_SCRIPT_DIR}
./run_ice.sh
mv ${ICE_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.

# Retrieve config files
cp ${CONFIG_DIR}/* ${RUN_DIR}/intercom/.
