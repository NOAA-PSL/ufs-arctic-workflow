#!/bin/bash

set -e -o pipefail
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

yyyy=${CDATE:0:4}
mm=${CDATE:4:2}
dd=${CDATE:6:2}
hh=${CDATE:8:2}

#sssss=$((hh*60*60))
sssss=10800

export APRUNS=${APRUNS}
export ICE_RUN_DIR=${ICE_RUN_DIR}
export ICE_SRC_FILE=${ICE_SRC_FILE}
export ICE_DST_FILE=${ICE_DST_FILE}
export ICE_WGT_FILE=${ICE_WGT_FILE}
export ICE_SRC_ANG_FILE=${ICE_SRC_ANG_FILE}
export ICE_DST_ANG_FILE=${ICE_DST_ANG_FILE}

METHOD="neareststod"

# Generate weight files if they don't exit
echo "Generating ice IC files"
if [ ! -e ${ICE_WGT_FILE} ]; then
    echo "File ${ICE_WGT_FILE} does not exist. Creating file..."
    ${APRUNS} ESMF_RegridWeightGen -s ${ICE_SRC_FILE} -d ${ICE_DST_FILE} -w ${ICE_WGT_FILE} -m ${METHOD} --dst_loc center --netCDF4 --dst_regional --ignore_degenerate
fi

python interp_ice.py \
    --wgt_file  $ICE_WGT_FILE \
    --src_file  iced.$yyyy-$mm-$dd-$sssss.nc \
    --src_angl  ${ICE_SRC_ANG_FILE} \
    --msk_file  ${ICE_DST_FILE} \
    --dst_angl  ${ICE_DST_ANG_FILE} \
    --out_file  "${ICE_RUN_DIR}/intercom/replay_ice.arctic_grid.${yyyy}-${mm}-${dd}-${hh}-${sssss}.nc"
echo "Ice IC file generation complete"
