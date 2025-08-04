#!/bin/bash
set -e -x -o pipefail

CONFIG_DIR="./config_files/2020_08_27_03_6HR/"
NAMELIST_FILE="$CONFIG_DIR/config.in"

if [[ -f "$NAMELIST_FILE" ]]; then
    source "$NAMELIST_FILE"
else
    echo "Namelist file $NAMELIST_FILE not found!"
    exit 1
fi

module use ${UFSUTILS_DIR}/modulefiles
module load build.${SYSTEM}.intel

mkdir -p ${RUN_DIR}/intercom

# Atmosphere prep
mkdir -p ${ATM_RUN_DIR}
mkdir -p ${ATM_RUN_DIR}/intercom/
#${NLN} ${FIX_DIR}/${ATM_DST_CASE}/* ${ATM_RUN_DIR}/intercom/.
${NLN} ${ATM_SCRIPT_DIR}/* ${ATM_RUN_DIR}/.
cd ${ATM_RUN_DIR}
./arctic_atm_prep.sh
mv ${ATM_RUN_DIR}/intercom/*.nc ${RUN_DIR}/intercom/.

# Ocean prep
mkdir -p ${OCN_RUN_DIR}
mkdir -p ${OCN_RUN_DIR}/intercom
cd ${OCN_SCRIPT_DIR}
./run_init.sh
mv ${OCN_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.

## Ice prep 
#mkdir -p ${ICE_RUN_DIR}
#mkdir -p ${ICE_RUN_DIR}/intercom
#cd ${ICE_SCRIPT_DIR}
#./run_ice.sh
#mv ${ICE_RUN_DIR}/intercom/* ${RUN_DIR}/intercom/.

# Retrieve config files
cp ${CONFIG_DIR}/* ${RUN_DIR}/intercom/.
