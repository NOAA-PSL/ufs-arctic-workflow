#!/bin/bash

NAMELIST_FILE="config.in"

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

mkdir -p ${WORK_DIR}/intercom

## Run Atmosphere prep
#cd ${ATM_WORK_DIR}
#
#mkdir -p ${ATM_WORK_DIR}/intercom/grid/${CASE}
#${NLN} ${ATM_GRID_DIR}/* ${ATM_WORK_DIR}/intercom/grid/${CASE}/.
#
#./exhafs_atm_ic.sh
#./exhafs_atm_lbc.sh
#
#mv ${ATM_WORK_DIR}/intercom/chgres/*.nc ${WORK_DIR}/intercom/.

# Run Ocean prep
cd ${OCN_WORK_DIR}
./run_init.sh

mv ${OCN_WORK_DIR}/intercom/*.nc ${WORK_DIR}/intercom/.
cp ${OCN_WORK_DIR}/MOM_input ${WORK_DIR}/intercom/.
