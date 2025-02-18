#!/bin/bash

###
# Script Name: remap_ICs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the initial condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###

APRUNS="srun --mem=0 --ntasks=1 --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --account=gsienkf"

INPUT_DIR=${INPUT_DIR-"inputs/"}
FIX_DIR=${FIX_DIR-"fix/mom6_arctic_grid/"}
OUTPUT_DIR=${OUTPUT_DIR-"intercom/"}


OUT_FILE_PATH="${OUTPUT_DIR}${OUT_FILE-"mom6_IC.nc"}"

VRT_FILE_PATH="${FIX_DIR}${VRT_FILE-"ocean_vgrid.nc"}"

H_WGT_FILE_PATH="${FIX_DIR}${H_WGT_FILE-"rtofs2arctic_h.nc"}"
U_WGT_FILE_PATH="${FIX_DIR}${U_WGT_FILE-"rtofs2arctic_u.nc"}"
V_WGT_FILE_PATH="${FIX_DIR}${V_WGT_FILE-"rtofs2arctic_v.nc"}"

SSH_VARNAME=${SSH_VARNAME-"ssh"}
SSH_SRC_FILE_PATH="${INPUT_DIR}${SSH_SRC_FILE-"rtofs_global_ssh_ic.nc"}"

TMP_VARNAME=${TMP_VARNAME-"pot_temp"}
SAL_VARNAME=${SAL_VARNAME-"salinity"}
TS_SRC_FILE_PATH="${INPUT_DIR}${TS_SRC_FILE-"rtofs_global_ts_ic.nc"}"

U_VARNAME=${U_VARNAME-"u"}
V_VARNAME=${V_VARNAME-"v"}
UV_SRC_FILE_PATH="${INPUT_DIR}${UV_SRC_FILE-"rtofs_global_uv_ic.nc"}"

ANGLE_VARNAME=${ANGLE_VARNAME-"angle_dx"}
ANGLE_SRC_FILE_PATH="${FIX_DIR}${ANGLE_SRC_FILE-"ocean_hgrid.nc"}"
CONVERT_ANGLE=${CONVERT_ANGLE-"True"}

DZ_VARNAME=${DZ_VARNAME-"dz"}
TIME_VARNAME=${TIME_VARNAME-"MT"}

echo "Calling remapping script for SSH Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name $SSH_VARNAME \
    --src_file ${SSH_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DZ_VARNAME} \
    --time_name ${TIME_VARNAME}
echo ""

echo "Calling remapping script for Temperature Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name $TMP_VARNAME \
    --src_file ${TS_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DZ_VARNAME} \
    --time_name ${TIME_VARNAME}
echo ""

echo "Calling remapping script for Salinity Variable"
${APRUNS} python rtofs_to_mom6.py \
    --var_name $SAL_VARNAME \
    --src_file ${TS_SRC_FILE_PATH} \
    --wgt_file ${H_WGT_FILE_PATH} \
    --vrt_file ${VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DZ_VARNAME} \
    --time_name ${TIME_VARNAME}
echo ""

echo "Calling remapping script for U-V vectors"
${APRUNS} python rtofs_to_mom6.py \
    --var_name $U_VARNAME $V_VARNAME $ANGLE_VARNAME \
    --src_file ${UV_SRC_FILE_PATH} ${UV_SRC_FILE_PATH} ${ANGLE_SRC_FILE_PATH} \
    --wgt_file ${U_WGT_FILE_PATH} ${V_WGT_FILE_PATH} \
    --vrt_file ${VRT_FILE_PATH} \
    --out_file ${OUT_FILE_PATH} \
    --dz_name ${DZ_VARNAME} \
    --time_name ${TIME_VARNAME} \
    --convert_angle_to_center ${CONVERT_ANGLE}
