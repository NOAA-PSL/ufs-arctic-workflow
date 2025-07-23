#!/bin/bash
set -e -x -o pipefail

###
# Script Name: remap_ICs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the initial condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###

# !!! EDIT srun details if needed
APRUNS=${APRUNS:-"srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --account=${SACCT}"}

INPUT_DIR=${OCN_RUN_DIR}/inputs/
OUTPUT_DIR=${OCN_RUN_DIR}/intercom/

OUT_FILE_PATH="${OUTPUT_DIR}${OUT_FILE:-"mom6_IC.nc"}"

H_WGT_FILE_PATH="${INPUT_DIR}${H_WGT_FILE:-"rtofs2arctic_h.nc"}"
U_WGT_FILE_PATH="${INPUT_DIR}${U_WGT_FILE:-"rtofs2arctic_u.nc"}"
V_WGT_FILE_PATH="${INPUT_DIR}${V_WGT_FILE:-"rtofs2arctic_v.nc"}"

SSH_VARNAME=${SSH_VARNAME:-"ssh"}
SSH_SRC_FILE_PATH="${INPUT_DIR}${SSH_SRC_FILE:-"rtofs_global_ssh_ic.nc"}"

TMP_VARNAME=${TMP_VARNAME:-"pot_temp"}
TMP_SRC_FILE_PATH="${INPUT_DIR}${TMP_SRC_FILE:-"rtofs_global_ts_ic.nc"}"

SAL_VARNAME=${SAL_VARNAME:-"salinity"}
SAL_SRC_FILE_PATH="${INPUT_DIR}${SAL_SRC_FILE:-"rtofs_global_ts_ic.nc"}"

U_VARNAME=${U_VARNAME:-"u"}
U_SRC_FILE_PATH="${INPUT_DIR}${U_SRC_FILE:-"rtofs_global_uv_ic.nc"}"

V_VARNAME=${V_VARNAME:-"v"}
V_SRC_FILE_PATH="${INPUT_DIR}${V_SRC_FILE:-"rtofs_global_uv_ic.nc"}"

SRC_ANG_NAME=${SRC_ANG_NAME:-"angle_dx"}
SRC_ANG_FILE_PATH="${INPUT_DIR}${SRC_ANG_FILE:-"ocean_hgrid.nc"}"
SRC_CONVERT_ANG=${SRC_CONVERT_ANG:-"True"}

DST_ANG_NAME=${DST_ANG_NAME:-"angle_dx"}
DST_ANG_FILE_PATH="${INPUT_DIR}${DST_ANGLE_FILE:-"ocean_hgrid.nc"}"
DST_CONVERT_ANG=${DST_CONVERT_ANG:-"True"}

SRC_VRT_NAME=${SRC_VRT_NAME:-"dz"}
SRC_VRT_FILE_PATH="${INPUT_DIR}${SRC_VRT_FILE:-"ocean_vgrid.nc"}"

DST_VRT_NAME=${DST_VRT_NAME:-"dz"}
DST_VRT_FILE_PATH="${INPUT_DIR}${DST_VRT_FILE:-"ocean_vgrid.nc"}"

TIME_VARNAME=${TIME_VARNAME:-"MT"}

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
echo ""

echo "Calling remapping script for Temperature Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${TMP_VARNAME} \
    --src_file ${TMP_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}
echo ""

echo "Calling remapping script for Salinity Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${SAL_VARNAME} \
    --src_file ${SAL_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}
echo ""

echo "Calling remapping script for SSH Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name ${SSH_VARNAME} \
    --src_file ${SSH_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${DST_VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DST_VRT_NAME} \
    --time_name ${TIME_VARNAME}
