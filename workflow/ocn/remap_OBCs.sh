#!/bin/bash
set -e -o pipefail

if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

###
# Script Name: remap_OBCs.sh
# Author: Kristin Barton (UFS Arctic Team)
# Contact: Kristin.Barton@noaa.gov
# Description:
#   This is the driver for the ocean boundary condition remapping steps. 
#   This script is called by the setup script, but can be run in isolation
###

APRUNS=${APRUNS}

INPUT_DIR=${OCN_RUN_DIR}/inputs/
OUTPUT_DIR=${OCN_RUN_DIR}/intercom/

OUT_FILE_PATH_BASE=${OUTPUT_DIR}${OCN_OUT_FILE_PATH_BASE}
WGT_FILE_PATH_BASE=${INPUT_DIR}${OCN_WGT_FILE_PATH_BASE}
DST_ANG_FILE_PATH_BASE=${INPUT_DIR}${OCN_ANG_FILE_PATH_BASE}
HGD_FILE_PATH_BASE=${INPUT_DIR}${OCN_ANG_FILE_PATH_BASE}
FILE_TAIL=${OCN_FILE_TAIL}

SSH_VARNAME=${OCN_SSH_VARNAME}
SSH_SRC_FILE_PATH="${INPUT_DIR}${OCN_SSH_SRC_FILE}"

TMP_VARNAME=${OCN_TMP_VARNAME}
TMP_VARNAME_OUT=${OCN_TMP_VARNAME_OUT:-$OCN_TMP_VARNAME}
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
DST_CONVERT_ANG=${OCN_DST_CONVERT_ANG}

SRC_VRT_NAME=${OCN_SRC_VRT_NAME}
SRC_VRT_FILE_PATH="${INPUT_DIR}${OCN_SRC_VRT_FILE}"

DST_VRT_NAME=${OCN_DST_VRT_NAME}
DST_VRT_FILE_PATH="${INPUT_DIR}${OCN_DST_VRT_FILE}"

TIME_VARNAME=${OCN_TIME_VARNAME}
TIME_VARNAME_OUT=${OCN_TIME_VARNAME_OUT:-$OCN_TIME_VARNAME}

########################
## UV-Vector Remapping #
########################

echo "Calling remapping script for U-V vectors"
start=1
end=4
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating Boundary ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    DST_ANG_FILE_PATH="${DST_ANG_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name $U_VARNAME $V_VARNAME \
        --src_file ${U_SRC_FILE_PATH} ${V_SRC_FILE_PATH} \
        --src_ang_name ${SRC_ANG_NAME} \
        --src_ang_file ${SRC_ANG_FILE_PATH} \
        --src_ang_supergrid ${SRC_CONVERT_ANG} \
        --dst_ang_name ${DST_ANG_NAME} \
        --dst_ang_file ${DST_ANG_FILE_PATH} \
        --dst_ang_supergrid ${DST_CONVERT_ANG} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT}
done
echo ""

##################################
# Temperature Variable Remapping #
##################################

echo "Calling remapping script for Temperature Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating Boundary ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${TMP_VARNAME} \
        --src_file ${TMP_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT} 
done
echo ""

###############################
# Salinity Variable Remapping #
###############################

echo "Calling remapping script for Salinity Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating Boundary ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${SAL_VARNAME} \
        --src_file ${SAL_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT} 
done
echo ""

##########################
# SSH Variable Remapping #
##########################

echo "Calling remapping script for SSH Variable"
for i in $(seq -f "%03g" $start $end); do
    echo "Interpolating Boundary ${i}"
    WGT_FILE_PATH="${WGT_FILE_PATH_BASE}${i}${FILE_TAIL}"
    OUT_FILE_PATH="${OUT_FILE_PATH_BASE}${i}${FILE_TAIL}"

    ${APRUNS} python rtofs_to_mom6.py \
        --var_name ${SSH_VARNAME} \
        --src_file ${SSH_SRC_FILE_PATH} \
        --wgt_file ${WGT_FILE_PATH} \
        --vrt_file ${DST_VRT_FILE_PATH} \
        --out_file ${OUT_FILE_PATH} \
        --dz_name ${DST_VRT_NAME} \
        --time_name ${TIME_VARNAME} \
        --time_name_out ${TIME_VARNAME_OUT} 
done
echo ""


#######################
# Format netcdf files #
#######################

echo "Formatting OBC files"
for i in $(seq -f "%03g" $start $end); do
    echo "Reformatting OBC_${i}"
    HGRID_PATH="${HGD_FILE_PATH_BASE}${i}.nc"
    OBC_PATH="${OUT_FILE_PATH_BASE}${i}.nc"

    ncrename -O -d ${DST_VRT_NAME},nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ${SSH_VARNAME},ssh_segment_${i} -v ${TMP_VARNAME},temp_segment_${i} -v ${SAL_VARNAME},salinity_segment_${i} -v ${U_VARNAME},u_segment_${i} -v ${V_VARNAME},v_segment_${i} ${OBC_PATH}
#    ncrename -O -d dz,nz_segment_${i} -d yh,ny_segment_${i} -d xh,nx_segment_${i} -v ssh,ssh_segment_${i} ${OBC_PATH}

#    ncap2 -O -s "ssh_segment_${i}[${TIME_VARNAME_OUT},ny_segment_${i},nx_segment_${i}] = ssh_segment_${i}(:,:,:);" ${OBC_PATH} ${OBC_PATH}

    ncap2 -O -s "dz_u_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_v_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH} 
    ncap2 -O -s "dz_ssh_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_salinity_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}
    ncap2 -O -s "dz_temp_segment_${i}[${TIME_VARNAME_OUT},nz_segment_${i},ny_segment_${i},nx_segment_${i}]=${DST_VRT_NAME}(:)" ${OBC_PATH} ${OBC_PATH}

    ncks -O -x -v ${DST_VRT_NAME} ${OBC_PATH} ${OBC_PATH} > /dev/null 2>&1

    if [ "$i" -eq "001" ] || [ "$i" -eq "002" ]; then
        ncap2 -A -v -s "lon_segment_${i}[nxp]=x(0,:)" ${HGRID_PATH} tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nxp]=y(0,:)" ${HGRID_PATH} tmp.nc
    fi
    if [ "$i" -eq "003" ] || [ "$i" -eq "004" ]; then
        ncap2 -A -v -s "lon_segment_${i}[nyp]=x(:,0)" ${HGRID_PATH} tmp.nc
        ncap2 -A -v -s "lat_segment_${i}[nyp]=y(:,0)" ${HGRID_PATH} tmp.nc
    fi

    ncrename -d nxp,nx_segment_${i} -d nyp,ny_segment_${i} tmp.nc

    ncap2 -A -v -s "lon_segment_${i}=lon_segment_${i}" tmp.nc ${OBC_PATH}
    ncap2 -A -v -s "lat_segment_${i}=lat_segment_${i}" tmp.nc ${OBC_PATH}

    rm tmp.nc
done
echo ""

