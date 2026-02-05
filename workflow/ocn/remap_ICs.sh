#!/bin/bash
set -e -o pipefail
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

###
# Script Name: remap_ICs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the initial condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###

# !!! EDIT srun details if needed
APRUNS=${APRUNS}

INPUT_DIR=${OCN_RUN_DIR}/inputs/
OUTPUT_DIR=${OCN_RUN_DIR}/intercom/

OUT_FILE_PATH="${OUTPUT_DIR}${OCN_IC_FILE}"

H_WGT_FILE_PATH="${INPUT_DIR}${OCN_WGT_FILE_BASE}_h.nc"
U_WGT_FILE_PATH="${INPUT_DIR}${OCN_WGT_FILE_BASE}_u.nc"
V_WGT_FILE_PATH="${INPUT_DIR}${OCN_WGT_FILE_BASE}_v.nc"

THK_VARNAME=${OCN_THK_VARNAME}
THK_SRC_FILE_PATH="${INPUT_DIR}${OCN_THK_SRC_FILE}"

SSH_VARNAME=${OCN_SSH_VARNAME}
SSH_SRC_FILE_PATH="${INPUT_DIR}${OCN_SSH_SRC_FILE}"

TMP_VARNAME=${OCN_TMP_VARNAME}
TMP_SRC_FILE_PATH="${INPUT_DIR}${OCN_TMP_SRC_FILE}"

SAL_VARNAME=${OCN_SAL_VARNAME}
SAL_SRC_FILE_PATH="${INPUT_DIR}${OCN_SAL_SRC_FILE}"

U_VARNAME=${OCN_U_VARNAME}
U_SRC_FILE_PATH="${INPUT_DIR}${OCN_U_SRC_FILE}"

V_VARNAME=${OCN_V_VARNAME}
V_SRC_FILE_PATH="${INPUT_DIR}${OCN_V_SRC_FILE}"

SRC_ANG_NAME=${OCN_SRC_ANG_NAME}
SRC_ANG_FILE_PATH="${INPUT_DIR}${OCN_SRC_ANG_FILE}"
SRC_CONVERT_ANG=${OCN_SRC_CONVERT_ANG}

DST_ANG_NAME=${OCN_DST_ANG_NAME}
DST_ANG_FILE_PATH="${INPUT_DIR}${OCN_DST_ANG_FILE}"
DST_CONVERT_ANG=${OCN_DST_CONVERT_ANG}

SRC_VRT_NAME=${OCN_SRC_VRT_NAME}
SRC_VRT_FILE_PATH="${INPUT_DIR}${OCN_SRC_VRT_FILE}"

DST_VRT_NAME=${OCN_DST_VRT_NAME}
DST_VRT_FILE_PATH="${INPUT_DIR}${OCN_DST_VRT_FILE}"

TIME_VARNAME=${OCN_TIME_VARNAME}

echo "Calling remapping script for U-V vectors"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${U_VARNAME} ${V_VARNAME} \
    --src_file ${U_SRC_FILE_PATH} ${V_SRC_FILE_PATH} \
    --src_ang_name ${SRC_ANG_NAME} \
    --src_ang_file ${SRC_ANG_FILE_PATH} \
    --src_ang_supergrid ${SRC_CONVERT_ANG} \
    --dst_ang_name ${DST_ANG_NAME} \
    --dst_ang_file ${DST_ANG_FILE_PATH} \
    --dst_ang_supergrid ${DST_CONVERT_ANG} \
    --wgt_file ${U_WGT_FILE_PATH} ${V_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}

echo "Calling remapping script for Temperature Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${TMP_VARNAME} \
    --src_file ${TMP_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}

echo "Calling remapping script for Salinity Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${SAL_VARNAME} \
    --src_file ${SAL_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}

echo "Calling remapping script for Thickness Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${THK_VARNAME} \
    --src_file ${THK_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}

echo "Calling remapping script for SSH Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${SSH_VARNAME} \
    --src_file ${SSH_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}

echo "Adding eta variable to IC file"
${APRUNS} python utils/add_eta.py \
    --file_name ${OUT_FILE_PATH} \
    --thickness_variable ${THK_VARNAME} \
    --time_dim ${TIME_VARNAME}
